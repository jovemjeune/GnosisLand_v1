
pragma solidity ^0.8.13;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {GlUSD} from "./GlUSD.sol";
import {IAavePool} from "./interfaces/IAavePool.sol";
import {IEscrowNFT} from "./interfaces/IEscrowNFT.sol";
import {IMorphoMarket} from "./interfaces/IMorphoMarket.sol";
import {TreasuryStakingLibrary} from "./libraries/TreasuryStakingLibrary.sol";
import {TreasuryYieldLibrary} from "./libraries/TreasuryYieldLibrary.sol";
import {TreasuryShareLibrary} from "./libraries/TreasuryShareLibrary.sol";
contract TreasuryContract is Ownable, Initializable, UUPSUpgradeable, ReentrancyGuard {
    using SafeERC20 for IERC20;
    using Math for uint256;
    GlUSD public glusdToken; // GlUSD token (represents vault shares)
    IERC20 public usdcToken; // USDC token (underlying asset)
    IAavePool public aavePool; // Aave Pool contract interface
    IMorphoMarket public morphoMarket; // Morpho Market contract interface
    IMorphoMarket.MarketParams public morphoMarketParams; // Morpho market parameters for USDC
    address public escrowNFT; // EscrowNFT contract address
    address public lessonNFT; // LessonNFT contract address (authorized caller)
    address public vault; // Vault contract address (ERC4626)
    bool public paused; // Pause mechanism for emergency stops
    uint256 public totalAssetsStaked; // Total USDC staked in Morpho + Aave
    uint256 public totalShares; // Total GlUSD shares minted
    uint256 public morphoAssets; // USDC staked in Morpho
    uint256 public aaveAssets; // USDC staked in Aave
    uint256 public protocolFunds; // Total protocol funds (never mixed with staker funds)
    uint256 public morphoAllocationPercent; // 90%
    uint256 public aaveAllocationPercent; // 10%
    
    mapping(address => uint256) public underlyingBalanceOf; // User => USDC deposited/referral rewards (1:1 with GlUSD minted)
    mapping(address => uint256) public userShare; // User => Vault shares (ERC4626 shares from vault deposits)
    mapping(address => uint256) public totalWithdrawn; // User => Total USDC withdrawn (for Invariant 3)
    mapping(address => uint256) public referrerStakedCollateral; // Referrer => Total USDC staked from referrals
    mapping(address => uint256) public referrerShares; // Referrer => GlUSD shares from referrals
    mapping(address => uint256) public referrerTotalRewards; // Referrer => Total rewards earned
    mapping(address => uint256) public referrerStakes; 
    mapping(address => uint256) public userStakes; 
    mapping(address => uint256) public referrerTimeStamp;
    mapping(address => uint256) public userTimeStamp;

    uint256 public constant LOCK_PERIOD = 1 days; // 1 day lock period
    uint256 public constant MORPHO_ALLOCATION = 90; // 90% to Morpho
    uint256 public constant AAVE_ALLOCATION = 10; // 10% to Aave
    error zeroAddress();
    error insufficientBalance();
    error invalidAmount();
    error stakeStillLocked();
    error contractPaused();
    error unauthorizedCaller();
    error nothingToClaim();
    event USDCDeposited(address indexed user, uint256 assets, uint256 shares);
    event GlUSDRedeemed(address indexed user, uint256 shares, uint256 assets);
    event TreasuryFeeReceived(uint256 amount);
    event ReferralRewardStaked(
        address indexed referrer, address indexed referred, uint256 rewardAmount, uint256 sharesMinted
    );
    event AssetsStaked(address indexed protocol, uint256 amount);
    event StakeWithdrawn(address indexed user, uint256 amount, bool isReferral);
    event ContractPaused();
    event ContractUnpaused();
    event GlUSDPaymentProcessed(address indexed from, address indexed to, uint256 amount);
    event FundsClaimed(address indexed user, uint256 amount);
    event VaultWithdrawProcessed(address indexed user, uint256 glusdBurned, uint256 usdcSent);
    event GlUSDShareTracked(address indexed user, uint256 shares);

    constructor() Ownable(address(this)) {
        _disableInitializers();
    }
    function initialize(
        address _glusdToken,
        address _usdcToken,
        address _aavePool,
        address _morphoMarket,
        address _escrowNFT,
        address _lessonNFT,
        address initialOwner
    ) external initializer {
        if (_glusdToken == address(0) || _usdcToken == address(0) || initialOwner == address(0)) {
            revert zeroAddress();
        }
        glusdToken = GlUSD(_glusdToken);
        usdcToken = IERC20(_usdcToken);
        if (_aavePool != address(0)) {
            aavePool = IAavePool(_aavePool);
        }
        if (_morphoMarket != address(0)) {
            morphoMarket = IMorphoMarket(_morphoMarket);
        }

        escrowNFT = _escrowNFT;
        lessonNFT = _lessonNFT;
        morphoAllocationPercent = MORPHO_ALLOCATION;
        aaveAllocationPercent = AAVE_ALLOCATION;
        paused = false;
        _transferOwnership(initialOwner);
    }

    function _authorizeUpgrade(address) internal override onlyOwner {}
    function totalAssets() public view returns (uint256) {
        return totalAssetsStaked;
    }

    function convertToShares(uint256 assets) public view returns (uint256 shares) {
        if (totalShares == 0) return assets;
        return assets.mulDiv(totalShares, totalAssets(), Math.Rounding.Floor);
    }

    function convertToAssets(uint256 shares) public view returns (uint256 assets) {
        if (totalShares == 0) return 0;
        return shares.mulDiv(totalAssets(), totalShares, Math.Rounding.Floor);
    }

    function getWithdrawableAmount(address user, bool isReferral) public view returns (uint256 withdrawable) {
        uint256 stakes = isReferral ? referrerStakes[user] : userStakes[user];
        uint256 timeStampMode = isReferral ? referrerTimeStamp[user] : userTimeStamp[user]; 
        uint256 currentTime = block.timestamp;
        if (currentTime >= timeStampMode + LOCK_PERIOD && (timeStampMode > uint256(0))){
            withdrawable += stakes;
        }
    }


    function depositUSDC(uint256 amount) external nonReentrant {
        if (paused) revert contractPaused();
        if (amount == 0) revert invalidAmount();
        usdcToken.safeTransferFrom(msg.sender, address(this), amount);
        uint256 shares = amount;
        glusdToken.mint(msg.sender, shares);
        underlyingBalanceOf[msg.sender] += amount;
        totalShares += shares;
        emit USDCDeposited(msg.sender, amount, shares);
    }

    function redeemGlUSD(uint256 shares) external {
        if (shares == 0) {
            revert invalidAmount();
        }
        if (glusdToken.balanceOf(msg.sender) < shares) {
            revert insufficientBalance();
        }
        uint256 assets = convertToAssets(shares);

        if (assets < shares) {
            assets = shares;
        }
        glusdToken.burn(msg.sender, shares);
        if (totalShares >= shares) totalShares -= shares;

        if (underlyingBalanceOf[msg.sender] >= shares) {
            underlyingBalanceOf[msg.sender] -= shares;
        } else {
            underlyingBalanceOf[msg.sender] = 0;
        }
        totalWithdrawn[msg.sender] += shares;
        if (totalAssetsStaked >= assets) {
            totalAssetsStaked -= assets;
        }
        usdcToken.safeTransfer(msg.sender, assets);

        emit GlUSDRedeemed(msg.sender, shares, assets);
    }

    function withdrawStaked(uint256 amount, bool isReferral) external {
        if (amount == 0) revert invalidAmount();
        if (amount > getWithdrawableAmount(msg.sender, isReferral)) revert stakeStillLocked();
        
        // Update the mapping, not just local variable
        if (isReferral) {
            referrerStakes[msg.sender] -= amount;
            referrerStakedCollateral[msg.sender] -= amount;
        } else {
            userStakes[msg.sender] -= amount;
        }
        
        totalAssetsStaked -= amount;
        totalWithdrawn[msg.sender] += amount;
        usdcToken.safeTransfer(msg.sender, amount);
        emit StakeWithdrawn(msg.sender, amount, isReferral);
    }

    function receiveTreasuryFee(
        uint256 amount,
        address,
        address,
        bytes32,
        uint256 referralReward,
        address referrer
    ) external {
        if (paused) {
            revert contractPaused();
        }

        if (msg.sender != lessonNFT) {
            revert unauthorizedCaller();
        }

        if (amount == 0) {
            revert invalidAmount();
        }

        emit TreasuryFeeReceived(amount);

        if (referralReward > 0 && referrer != address(0)) {
            _processReferralReward(referralReward, referrer);
        }

        bool hasReferral = (referralReward > 0 && referrer != address(0));

        if (hasReferral) {
            protocolFunds += amount;
        } else {
            uint256 protocolFee = amount / 2;
            uint256 stakerFee = amount / 2;
            protocolFunds += protocolFee;
            _stakeAssets(stakerFee, address(this), false); // Stake for protocol (yield benefits all holders)
        }
    }

    function _processReferralReward(uint256 referralReward, address referrer) internal {
        underlyingBalanceOf[referrer] += referralReward;
        referrerStakedCollateral[referrer] += referralReward;
        uint256 shares = referralReward;
        referrerShares[referrer] += shares;
        referrerTotalRewards[referrer] += referralReward;
        totalShares += shares;
        glusdToken.mint(referrer, shares);
        emit ReferralRewardStaked(referrer, address(0), referralReward, shares);
    }

    function _stakeAssets(uint256 amount, address staker, bool isReferral) internal {
        (uint256 morphoAmount, uint256 aaveAmount) = TreasuryStakingLibrary.stakeAssets(
            usdcToken,
            morphoMarket,
            aavePool,
            morphoMarketParams,
            amount,
            morphoAllocationPercent
        );

        morphoAssets += morphoAmount;
        aaveAssets += aaveAmount;
        totalAssetsStaked += amount;

        if (morphoAmount > 0) emit AssetsStaked(address(morphoMarket), morphoAmount);
        if (aaveAmount > 0) emit AssetsStaked(address(aavePool), aaveAmount);
        if (isReferral) {
            if(referrerStakes[staker] == 0){
                referrerTimeStamp[staker] = block.timestamp;
                referrerStakes[staker]=amount;
            }
            else{
                referrerStakes[staker]+=amount;
            }
        } else {
            if(userStakes[staker] == 0){
                userTimeStamp[staker] = block.timestamp;
                userStakes[staker]=amount;
            }
            else{
                userStakes[staker]+=amount;
            }
        }
    }


    function validateReferralCode(bytes32 referralCode) public view returns (address referrer, uint256 tokenId) {
        if (escrowNFT == address(0)) {
            return (address(0), 0);
        }

        return IEscrowNFT(escrowNFT).validateReferralCode(referralCode);
    }

    function updateAavePool(address _newAavePool) external onlyOwner {
        aavePool = IAavePool(_newAavePool);
    }

    function updateMorphoMarket(address _newMorphoMarket) external onlyOwner {
        morphoMarket = IMorphoMarket(_newMorphoMarket);
    }

    function updateMorphoMarketParams(IMorphoMarket.MarketParams memory _marketParams) external onlyOwner {
        morphoMarketParams = _marketParams;
    }

    function updateEscrowNFT(address _newEscrowNft) external onlyOwner {
        escrowNFT = _newEscrowNft;
    }

    function updateLessonNFT(address _newLessonNFT) external onlyOwner {
        if (_newLessonNFT == address(0)) {
            revert zeroAddress();
        }
        lessonNFT = _newLessonNFT;
    }

    function pause() external onlyOwner {
        paused = true;
        emit ContractPaused();
    }

    function unpause() external onlyOwner {
        paused = false;
        emit ContractUnpaused();
    }

    /**
     * @notice Tracks user shares in vault when they deposit via ERC4626
     * @dev Called by vault when user deposits GlUSD. Updates userShare mapping.
     * @param user Address of the user depositing
     * @param shares Amount of vault shares minted (ERC4626 shares)
     */
    function trackGlUSDShare(address user, uint256 shares) external {
        if (msg.sender != vault) {
            revert unauthorizedCaller();
        }
        userShare[user] += shares;
        emit GlUSDShareTracked(user, shares);
    }

    /**
     * @notice Handles vault withdrawal using ERC4626
     * @dev Called by vault when user withdraws. Burns GlUSD and sends USDC.
     * Ensures user has enough GlUSD to maintain 1:1 ratio with USDC.
     * @param user Address of the user withdrawing
     * @param vaultShares Amount of vault shares being redeemed (ERC4626 shares)
     * @param usdcAmount Amount of USDC to send (calculated by vault using convertToAssets)
     * @param receiver Address to receive USDC
     */
    function handleVaultWithdraw(address user, uint256 vaultShares, uint256 usdcAmount, address receiver)
        external
        nonReentrant
    {
        if (msg.sender != vault || paused) {
            if (msg.sender != vault) revert unauthorizedCaller();
            revert contractPaused();
        }
        
        // Update user's vault shares (ERC4626 shares)
        if (userShare[user] >= vaultShares) {
            userShare[user] -= vaultShares;
        } else {
            userShare[user] = 0;
        }
        
        // Invariant 1: Maintain 1:1 ratio - use underlyingBalanceOf instead of vault-calculated amount
        // The vault may return more USDC due to yield appreciation, but we must maintain 1:1 with GlUSD
        uint256 userUnderlyingBalance = underlyingBalanceOf[user];
        uint256 actualWithdrawAmount = usdcAmount < userUnderlyingBalance ? usdcAmount : userUnderlyingBalance;
        
        // Burn GlUSD from vault (1:1 with actualWithdrawAmount to maintain invariant)
        if (actualWithdrawAmount > 0) {
            glusdToken.burn(address(vault), actualWithdrawAmount);
        }
        
        // Update underlying balance (maintain 1:1 ratio)
        if (underlyingBalanceOf[user] >= actualWithdrawAmount) {
            underlyingBalanceOf[user] -= actualWithdrawAmount;
        } else {
            underlyingBalanceOf[user] = 0;
        }
        totalWithdrawn[user] += actualWithdrawAmount;
        
        // Use actualWithdrawAmount for the rest of the function
        usdcAmount = actualWithdrawAmount;
        
        // Calculate user's share percentage for yield distribution
        uint256 userShares = userShare[user];
        uint256 totalVaultShares = _getTotalVaultShares();
        
        uint256 availableUSDC = usdcToken.balanceOf(address(this)) - protocolFunds;
        uint256 requested = 0;
        
        if (userShares > 0 && totalVaultShares > 0) {
            uint256 sharePercent = TreasuryShareLibrary.calculateSharePercent(userShares, totalVaultShares);
            (bool checkMorpho, bool checkAave, bool checkBoth) = TreasuryShareLibrary.getProtocolChecks(sharePercent);
            
            if (availableUSDC < usdcAmount) {
                if (checkBoth) {
                    requested += _requestFromMorpho(usdcAmount / 2);
                    requested += _requestFromAave(usdcAmount / 2);
                } else if (checkMorpho) {
                    requested = _requestFromMorpho(usdcAmount);
                } else if (checkAave) {
                    requested = _requestFromAave(usdcAmount);
                }
            }
        }
        
        uint256 toSend = availableUSDC + requested;
        if (toSend > usdcAmount) toSend = usdcAmount;
        if (toSend > 0) {
            usdcToken.safeTransfer(receiver, toSend);
        }
        
        emit VaultWithdrawProcessed(user, vaultShares, toSend);
    }

    /**
     * @notice Calculates claimable rewards for a user based on their ERC4626 vault shares
     * @dev Uses ERC4626 totalSupply() for share calculation: (availableYield * userShare) / totalSupply()
     * @param user Address of the user to check
     * @return claimable Amount of USDC rewards claimable
     */
    function getClaimableAmount(address user) external view returns (uint256 claimable) {
        uint256 userShares = userShare[user];
        if (userShares == 0) {
            return 0;
        }

        uint256 totalVaultShares = _getTotalVaultShares();
        if (totalVaultShares == 0) {
            return 0;
        }
        
        uint256 sharePercent = TreasuryShareLibrary.calculateSharePercent(userShares, totalVaultShares);
        (bool checkMorpho, bool checkAave, bool checkBoth) = TreasuryShareLibrary.getProtocolChecks(sharePercent);
        uint256 availableYield = 0;

        if (checkBoth) {
            availableYield += _getAvailableYieldFromMorpho();
            availableYield += _getAvailableYieldFromAave();
        } else if (checkMorpho) {
            availableYield = _getAvailableYieldFromMorpho();
        } else if (checkAave) {
            availableYield = _getAvailableYieldFromAave();
        }
        
        // Calculate reward using ERC4626 totalSupply: (availableYield * userShare) / totalSupply
        // ERC4626 uses 18 decimals by default, but we're working with actual share amounts
        claimable = (availableYield * userShares) / totalVaultShares;
        
        uint256 availableUSDC = usdcToken.balanceOf(address(this)) - protocolFunds;
        if (claimable > availableUSDC) {
            claimable = availableUSDC;
        }
    }

    /**
     * @notice Claims rewards for user based on their ERC4626 vault shares
     * @dev Ensures user has enough GlUSD to maintain 1:1 ratio before allowing claim
     * @param amount Amount of USDC to claim
     */
    function claim(uint256 amount) external nonReentrant {
        if (paused) {
            revert contractPaused();
        }

        // Invariant 2: Check 1-day lock period
        uint256 withdrawable = getWithdrawableAmount(msg.sender, false);
        if (withdrawable == 0) {
            uint256 stakes = userStakes[msg.sender];
            if (stakes == 0) {
                revert stakeStillLocked();
            }
            // Check if lock period has passed
            uint256 timeStamp = userTimeStamp[msg.sender];
            if (timeStamp > 0 && block.timestamp < timeStamp + LOCK_PERIOD) {
                revert stakeStillLocked();
            }
        }

        // Invariant 3: User must have withdrawn before claiming
        if (totalWithdrawn[msg.sender] == 0) {
            revert stakeStillLocked(); // Reuse error - user hasn't withdrawn yet
        }

        uint256 claimable = this.getClaimableAmount(msg.sender);
        if (claimable == 0) {
            revert nothingToClaim();
        }
        if (amount > claimable) {
            amount = claimable; // Claim maximum available
        }
        
        // Ensure user has enough GlUSD to maintain 1:1 ratio
        // underlyingBalanceOf (USDC) should equal GlUSD balance
        uint256 userGlUSDBalance = glusdToken.balanceOf(msg.sender);
        uint256 userUSDCBalance = underlyingBalanceOf[msg.sender];
        
        // User must have enough GlUSD to cover their USDC balance
        if (userGlUSDBalance < userUSDCBalance) {
            // Adjust claimable amount to ensure ratio is maintained
            uint256 shortfall = userUSDCBalance - userGlUSDBalance;
            if (amount > shortfall) {
                amount = amount - shortfall;
            } else {
                revert insufficientBalance(); // User doesn't have enough GlUSD
            }
        }
        
        uint256 availableUSDC = usdcToken.balanceOf(address(this)) - protocolFunds;

        if (availableUSDC < amount) {
            uint256 userShares = userShare[msg.sender];
            uint256 totalVaultShares = _getTotalVaultShares();
            uint256 sharePercent = TreasuryShareLibrary.calculateSharePercent(userShares, totalVaultShares);
            (bool checkMorpho, bool checkAave, bool checkBoth) = TreasuryShareLibrary.getProtocolChecks(sharePercent);

            if (checkBoth) {
                _requestFromMorpho(amount / 2);
                _requestFromAave(amount / 2);
            } else if (checkMorpho) {
                _requestFromMorpho(amount);
            } else if (checkAave) {
                _requestFromAave(amount);
            }
        }
        usdcToken.safeTransfer(msg.sender, amount);

        emit FundsClaimed(msg.sender, amount);
    }

    function handleGlUSDPayment(uint256 glusdAmount, address from, address to) external returns (bool) {
        if (paused) revert contractPaused();
        if (msg.sender != lessonNFT) revert unauthorizedCaller();
        if (glusdAmount == 0) revert invalidAmount();
        if (from == address(0) || to == address(0)) revert zeroAddress();
        IERC20(address(glusdToken)).safeTransferFrom(from, to, glusdAmount);
        emit GlUSDPaymentProcessed(from, to, glusdAmount);
        return true;
    }

    function updateVault(address _newVault) external onlyOwner {
        if (_newVault == address(0)) revert zeroAddress();
        vault = _newVault;
    }
    /**
     * @notice Gets total vault shares using ERC4626 totalSupply()
     * @dev ERC4626 totalSupply() returns total shares minted
     * @return Total vault shares
     */
    function _getTotalVaultShares() internal view returns (uint256) {
        if (vault == address(0)) {
            return 0;
        }
        // Use ERC4626 interface to get totalSupply (total shares)
        return IERC4626(vault).totalSupply();
    }

    function _requestFromMorpho(uint256 amount) internal returns (uint256) {
        uint256 withdrawn = TreasuryStakingLibrary.requestFromMorpho(morphoMarket, morphoMarketParams, usdcToken, amount, morphoAssets);
        if (withdrawn > 0) {
            morphoAssets -= withdrawn;
            totalAssetsStaked -= withdrawn;
        }
        return withdrawn;
    }
    function _requestFromAave(uint256 amount) internal returns (uint256) {
        uint256 withdrawn = TreasuryStakingLibrary.requestFromAave(aavePool, usdcToken, amount, aaveAssets);
        if (withdrawn > 0) {
            aaveAssets -= withdrawn;
            totalAssetsStaked -= withdrawn;
        }
        return withdrawn;
    }

    function _getAvailableYieldFromMorpho() internal view returns (uint256) {
        return TreasuryYieldLibrary.getAvailableYieldFromMorpho(morphoMarket, morphoMarketParams, morphoAssets);
    }
    function _getAvailableYieldFromAave() internal view returns (uint256) {
        return TreasuryYieldLibrary.getAvailableYieldFromAave(aavePool, usdcToken, aaveAssets);
    }
}
// ERC4626 interface is imported from OpenZeppelin, no need for custom IVault interface

