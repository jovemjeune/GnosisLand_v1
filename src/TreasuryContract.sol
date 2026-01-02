
pragma solidity ^0.8.13;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {GlUSD} from "./GlUSD.sol";
import {IAavePool} from "./interfaces/IAavePool.sol";
import {IMorphoMarket} from "./interfaces/IMorphoMarket.sol";
import {TreasuryStakingLibrary} from "./libraries/TreasuryStakingLibrary.sol";
import {TreasuryYieldLibrary} from "./libraries/TreasuryYieldLibrary.sol";
import {TreasuryShareLibrary} from "./libraries/TreasuryShareLibrary.sol";
interface IEscrowNFT {
    function validateReferralCode(bytes32 referralCode) external view returns (address referrer, uint256 tokenId);
}
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
    mapping(address => uint256) public GlUSD_shareOf; // User => GlUSD shares in vault (from Vault deposit)
    mapping(address => uint256) public totalWithdrawn; // User => Total USDC withdrawn (for Invariant 3)
    mapping(address => uint256) public referrerStakedCollateral; // Referrer => Total USDC staked from referrals
    mapping(address => uint256) public referrerShares; // Referrer => GlUSD shares from referrals
    mapping(address => uint256) public referrerTotalRewards; // Referrer => Total rewards earned
    struct Stake {
        uint256 amount; // Amount staked
        uint256 timestamp; // When stake was made
        bool isReferral; // true if from referral reward, false if from user deposit
    }
    mapping(address => Stake[]) public userStakes; // User => Array of stakes
    mapping(address => Stake[]) public referrerStakes; // Referrer => Array of referral reward stakes

    uint256 public constant LOCK_PERIOD = 1 days; // 1 day lock period
    uint256 public constant TREASURY_FEE_PERCENT = 10; // 10% of sales
    uint256 public constant USER_YIELD_PERCENT = 3; // 3% goes to users/teachers
    uint256 public constant REFERRAL_REWARD_PERCENT = 3; // 3% of purchase price to referrer
    uint256 public constant MORPHO_ALLOCATION = 90; // 90% to Morpho
    uint256 public constant AAVE_ALLOCATION = 10; // 10% to Aave
    error zeroAddress();
    error insufficientBalance();
    error invalidAmount();
    error notAuthorized();
    error stakeStillLocked();
    error noStakeFound();
    error contractPaused();
    error unauthorizedCaller();
    error nothingToClaim();
    error fundsNotAvailable();
    event USDCDeposited(address indexed user, uint256 assets, uint256 shares);
    event GlUSDRedeemed(address indexed user, uint256 shares, uint256 assets);
    event TreasuryFeeReceived(uint256 amount);
    event ReferralRewardStaked(
        address indexed referrer, address indexed referred, uint256 rewardAmount, uint256 sharesMinted
    );
    event AssetsStaked(address indexed protocol, uint256 amount);
    event YieldAccrued(uint256 totalYield);
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
        Stake[] memory stakes = isReferral ? referrerStakes[user] : userStakes[user];
        uint256 currentTime = block.timestamp;

        for (uint256 i = 0; i < stakes.length; i++) {
            if (currentTime >= stakes[i].timestamp + LOCK_PERIOD) {
                withdrawable += stakes[i].amount;
            }
        }
    }

    function getLockedAmount(address user, bool isReferral) public view returns (uint256 locked) {
        Stake[] memory stakes = isReferral ? referrerStakes[user] : userStakes[user];
        uint256 currentTime = block.timestamp;

        for (uint256 i = 0; i < stakes.length; i++) {
            if (currentTime < stakes[i].timestamp + LOCK_PERIOD) {
                locked += stakes[i].amount;
            }
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
        Stake[] storage stakes = isReferral ? referrerStakes[msg.sender] : userStakes[msg.sender];
        uint256 currentTime = block.timestamp;
        uint256 remaining = amount;
        for (uint256 i = 0; i < stakes.length && remaining > 0; i++) {
            if (currentTime >= stakes[i].timestamp + LOCK_PERIOD && stakes[i].amount > 0) {
                uint256 toWithdraw = stakes[i].amount < remaining ? stakes[i].amount : remaining;
                stakes[i].amount -= toWithdraw;
                remaining -= toWithdraw;
                if (stakes[i].amount == 0) {
                    stakes[i] = stakes[stakes.length - 1];
                    stakes.pop();
                    i--;
                }
            }
        }
        if (remaining > 0) revert insufficientBalance();
        if (isReferral) referrerStakedCollateral[msg.sender] -= amount;
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
        Stake memory newStake = Stake({amount: amount, timestamp: block.timestamp, isReferral: isReferral});
        if (isReferral) {
            referrerStakes[staker].push(newStake);
        } else {
            userStakes[staker].push(newStake);
        }
    }

    function _distributeYield(uint256 totalYield) internal {
        if (totalShares == 0 || totalYield == 0) {
            return;
        }

        totalAssetsStaked += totalYield;
        emit YieldAccrued(totalYield);
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

    function trackGlUSDShare(address user, uint256 shares) external {
        if (msg.sender != vault) {
            revert unauthorizedCaller();
        }
        GlUSD_shareOf[user] += shares;
        emit GlUSDShareTracked(user, shares);
    }

    function handleVaultWithdraw(address user, uint256 glusdShares, uint256 usdcAmount, address receiver)
        external
        nonReentrant
    {
        if (msg.sender != vault || paused) {
            if (msg.sender != vault) revert unauthorizedCaller();
            revert contractPaused();
        }
        uint256 usdcToSend = usdcAmount < glusdShares ? usdcAmount : glusdShares;
        glusdToken.burn(address(vault), glusdShares);
        if (underlyingBalanceOf[user] >= usdcToSend) {
            underlyingBalanceOf[user] -= usdcToSend;
        } else {
            underlyingBalanceOf[user] = 0;
        }
        totalWithdrawn[user] += usdcToSend;
        if (GlUSD_shareOf[user] >= glusdShares) {
            GlUSD_shareOf[user] -= glusdShares;
        } else {
            GlUSD_shareOf[user] = 0;
        }
        uint256 availableUSDC = usdcToken.balanceOf(address(this)) - protocolFunds;
        uint256 userShare = GlUSD_shareOf[user];
        uint256 totalVaultShares = _getTotalVaultShares();
        if (userShare > 0 && totalVaultShares > 0) {
            uint256 sharePercent = TreasuryShareLibrary.calculateSharePercent(userShare, totalVaultShares);
            (bool checkMorpho, bool checkAave, bool checkBoth) = TreasuryShareLibrary.getProtocolChecks(sharePercent);
            uint256 requested = 0;
            if (availableUSDC < usdcToSend) {
                if (checkBoth) {
                    requested += _requestFromMorpho(usdcToSend / 2);
                    requested += _requestFromAave(usdcToSend / 2);
                } else if (checkMorpho) {
                    requested = _requestFromMorpho(usdcToSend);
                } else if (checkAave) {
                    requested = _requestFromAave(usdcToSend);
                }
            }
            uint256 toSend = availableUSDC + requested;
            if (toSend > usdcToSend) toSend = usdcToSend;
            if (toSend > 0) usdcToken.safeTransfer(receiver, toSend);
            if (usdcAmount > usdcToSend && availableUSDC >= usdcToSend) {
                uint256 yieldAmount = usdcAmount - usdcToSend;
                uint256 yieldAvailable = availableUSDC - usdcToSend;
                if (yieldAvailable < yieldAmount) {
                    if (checkBoth) {
                        requested = _requestFromMorpho(yieldAmount / 2) + _requestFromAave(yieldAmount / 2);
                    } else if (checkMorpho) {
                        requested = _requestFromMorpho(yieldAmount);
                    } else if (checkAave) {
                        requested = _requestFromAave(yieldAmount);
                    }
                    yieldAvailable += requested;
                }
                if (yieldAvailable > yieldAmount) yieldAvailable = yieldAmount;
                if (yieldAvailable > 0) usdcToken.safeTransfer(receiver, yieldAvailable);
            }
        } else {
            uint256 toSend = availableUSDC >= usdcToSend ? usdcToSend : availableUSDC;
            if (toSend > 0) usdcToken.safeTransfer(receiver, toSend);
        }
        emit VaultWithdrawProcessed(user, glusdShares, usdcToSend);
    }

    function getClaimableAmount(address user) external view returns (uint256 claimable) {
        uint256 userShare = GlUSD_shareOf[user];
        if (userShare == 0) {
            return 0;
        }

        uint256 totalVaultShares = _getTotalVaultShares();
        if (totalVaultShares == 0) {
            return 0;
        }
        uint256 sharePercent = TreasuryShareLibrary.calculateSharePercent(userShare, totalVaultShares);
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
        claimable = (availableYield * userShare) / totalVaultShares;
        uint256 availableUSDC = usdcToken.balanceOf(address(this)) - protocolFunds;
        if (claimable > availableUSDC) {
            claimable = availableUSDC;
        }
    }

    function claim(uint256 amount) external nonReentrant {
        if (paused) {
            revert contractPaused();
        }

        uint256 withdrawable = getWithdrawableAmount(msg.sender, false);
        if (withdrawable == 0) {

            Stake[] memory stakes = userStakes[msg.sender];
            if (stakes.length > 0) {

                revert stakeStillLocked();
            }
        }

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
        uint256 availableUSDC = usdcToken.balanceOf(address(this)) - protocolFunds;

        if (availableUSDC < amount) {

            uint256 userShare = GlUSD_shareOf[msg.sender];
            uint256 totalVaultShares = _getTotalVaultShares();
            uint256 sharePercent = TreasuryShareLibrary.calculateSharePercent(userShare, totalVaultShares);
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
    function _getTotalVaultShares() internal view returns (uint256) {
        return vault == address(0) ? 0 : IVault(vault).totalSupply();
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
interface IVault {
    function totalSupply() external view returns (uint256);
}
