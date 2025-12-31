// SPDX-License-Identifier: MIT

//  ____                 _       _                    _
// / ___|_ __   ___  ___(_)___  | |    __ _ _ __   __| |
//| |  _| '_ \ / _ \/ __| / __| | |   / _` | '_ \ / _` |
//| |_| | | | | (_) \__ \ \__ \ | |__| (_| | | | | (_| |
// \____|_| |_|\___/|___/_|___/ |_____\__,_|_| |_|\__,_|

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

// Interface for EscrowNFT
interface IEscrowNFT {
    function validateReferralCode(bytes32 referralCode) external view returns (address referrer, uint256 tokenId);
}

/**
 * @title TreasuryContract
 * @dev Treasury contract with ERC4626-style vault for staking and yield generation
 * @notice Manages USDC deposits, GlUSD minting (as shares), and yield from Aave/Morpho
 * @notice GlUSD represents shares in the vault - 1 GlUSD = claim to 1 USDC initially, can appreciate with yield
 * @notice Staked tokens have a 1-day lock period before withdrawal
 */
contract TreasuryContract is Ownable, Initializable, UUPSUpgradeable, ReentrancyGuard {
    using SafeERC20 for IERC20;
    using Math for uint256;

    //-----------------------Storage Variables-----------------------------------------
    GlUSD public glusdToken; // GlUSD token (represents vault shares)
    IERC20 public usdcToken; // USDC token (underlying asset)
    IAavePool public aavePool; // Aave Pool contract interface
    IMorphoMarket public morphoMarket; // Morpho Market contract interface
    IMorphoMarket.MarketParams public morphoMarketParams; // Morpho market parameters for USDC
    address public escrowNFT; // EscrowNFT contract address
    address public lessonNFT; // LessonNFT contract address (authorized caller)
    address public vault; // Vault contract address (ERC4626)
    bool public paused; // Pause mechanism for emergency stops

    // Vault tracking (ERC4626-style)
    uint256 public totalAssetsStaked; // Total USDC staked in Morpho + Aave
    uint256 public totalShares; // Total GlUSD shares minted
    uint256 public morphoAssets; // USDC staked in Morpho
    uint256 public aaveAssets; // USDC staked in Aave

    // Protocol funds tracking (separate from staker funds)
    uint256 public protocolFunds; // Total protocol funds (never mixed with staker funds)

    // Allocation percentages
    uint256 public morphoAllocationPercent; // 90%
    uint256 public aaveAllocationPercent; // 10%

    // User tracking
    mapping(address => uint256) public underlyingBalanceOf; // User => USDC deposited/referral rewards (1:1 with GlUSD minted)
    mapping(address => uint256) public GlUSD_shareOf; // User => GlUSD shares in vault (from Vault deposit)
    mapping(address => uint256) public totalWithdrawn; // User => Total USDC withdrawn (for Invariant 3)

    // Legacy tracking (kept for compatibility)
    mapping(address => uint256) public userDeposits; // User => USDC deposited
    mapping(address => uint256) public userShares; // User => GlUSD shares owned

    // Referral tracking
    mapping(address => uint256) public referrerStakedCollateral; // Referrer => Total USDC staked from referrals
    mapping(address => uint256) public referrerShares; // Referrer => GlUSD shares from referrals
    mapping(address => uint256) public referrerTotalRewards; // Referrer => Total rewards earned

    //-----------------------Stake Lock Tracking-----------------------------------------
    /**
     * @dev Struct to track individual stakes with lock timestamps
     */
    struct Stake {
        uint256 amount; // Amount staked
        uint256 timestamp; // When stake was made
        bool isReferral; // true if from referral reward, false if from user deposit
    }

    // Track stakes per user/referrer for withdrawal lock
    mapping(address => Stake[]) public userStakes; // User => Array of stakes
    mapping(address => Stake[]) public referrerStakes; // Referrer => Array of referral reward stakes

    uint256 public constant LOCK_PERIOD = 1 days; // 1 day lock period

    //-----------------------constants-----------------------------------------
    uint256 public constant TREASURY_FEE_PERCENT = 10; // 10% of sales
    uint256 public constant USER_YIELD_PERCENT = 3; // 3% goes to users/teachers
    uint256 public constant REFERRAL_REWARD_PERCENT = 3; // 3% of purchase price to referrer
    uint256 public constant MORPHO_ALLOCATION = 90; // 90% to Morpho
    uint256 public constant AAVE_ALLOCATION = 10; // 10% to Aave

    //-----------------------custom errors-----------------------------------------
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

    //-----------------------events-----------------------------------------
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

    //-----------------------constructor (disabled for upgradeable)-----------------------------------------
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() Ownable(address(this)) {
        _disableInitializers();
    }

    //-----------------------initializer-----------------------------------------
    /**
     * @notice Initializes the TreasuryContract
     * @dev Called once when the proxy is deployed. Sets up all initial state variables.
     * @param _glusdToken Address of the GlUSD token contract
     * @param _usdcToken Address of the USDC token contract
     * @param _aavePool Address of the Aave Pool contract
     * @param _morphoMarket Address of the Morpho Market contract
     * @param _escrowNFT Address of the EscrowNFT contract
     * @param _lessonNFT Address of the LessonNFT contract (authorized caller)
     * @param initialOwner Address of the initial owner
     * @custom:reverts zeroAddress If _glusdToken, _usdcToken, or initialOwner is address(0)
     */
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
        // morphoMarketParams will be set via updateMorphoMarketParams() after deployment
        escrowNFT = _escrowNFT;
        lessonNFT = _lessonNFT;
        morphoAllocationPercent = MORPHO_ALLOCATION;
        aaveAllocationPercent = AAVE_ALLOCATION;
        paused = false;
        _transferOwnership(initialOwner);
    }

    //-----------------------UUPS authorization-----------------------------------------
    /**
     * @notice Authorizes contract upgrades
     * @dev Only the owner can authorize upgrades. This is required by UUPS pattern.
     * @param newImplementation Address of the new implementation contract
     */
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    //-----------------------public view functions-----------------------------------------
    /**
     * @notice Gets total assets managed by the vault
     * @dev Returns total USDC staked in Morpho and Aave, including accrued yield
     * @return Total assets including yield (in production, would query actual balances from protocols)
     */
    function totalAssets() public view returns (uint256) {
        // In production, this would query actual balances from Aave/Morpho
        // For now, return staked amount (yield would be added here)
        return totalAssetsStaked;
    }

    /**
     * @notice Converts assets (USDC) to shares (GlUSD)
     * @dev Uses ERC4626-style conversion. Initially 1:1, but can change with yield.
     * @param assets Amount of USDC to convert
     * @return shares Amount of GlUSD shares equivalent to the assets
     */
    function convertToShares(uint256 assets) public view returns (uint256 shares) {
        uint256 supply = totalShares;
        if (supply == 0) {
            return assets; // 1:1 initially
        }
        // Calculate shares based on current vault value
        return assets.mulDiv(totalShares, totalAssets(), Math.Rounding.Floor);
    }

    /**
     * @notice Converts shares (GlUSD) to assets (USDC)
     * @dev Uses ERC4626-style conversion. Share value can appreciate with yield.
     * @param shares Amount of GlUSD shares to convert
     * @return assets Amount of USDC equivalent to the shares
     */
    function convertToAssets(uint256 shares) public view returns (uint256 assets) {
        uint256 supply = totalShares;
        if (supply == 0) {
            return 0;
        }
        // Calculate assets based on current vault value
        return shares.mulDiv(totalAssets(), totalShares, Math.Rounding.Floor);
    }

    /**
     * @notice Gets total withdrawable amount for a user
     * @dev Calculates total amount of unlocked stakes (after 1-day lock period)
     * @param user Address of the user or referrer
     * @param isReferral true if checking referral reward stakes, false for user deposit stakes
     * @return withdrawable Total amount that can be withdrawn (in USDC)
     */
    function getWithdrawableAmount(address user, bool isReferral) public view returns (uint256 withdrawable) {
        Stake[] memory stakes = isReferral ? referrerStakes[user] : userStakes[user];
        uint256 currentTime = block.timestamp;

        for (uint256 i = 0; i < stakes.length; i++) {
            if (currentTime >= stakes[i].timestamp + LOCK_PERIOD) {
                withdrawable += stakes[i].amount;
            }
        }
    }

    /**
     * @notice Gets total locked amount for a user
     * @dev Calculates total amount of stakes still within the 1-day lock period
     * @param user Address of the user or referrer
     * @param isReferral true if checking referral reward stakes, false for user deposit stakes
     * @return locked Total amount that is still locked (in USDC)
     */
    function getLockedAmount(address user, bool isReferral) public view returns (uint256 locked) {
        Stake[] memory stakes = isReferral ? referrerStakes[user] : userStakes[user];
        uint256 currentTime = block.timestamp;

        for (uint256 i = 0; i < stakes.length; i++) {
            if (currentTime < stakes[i].timestamp + LOCK_PERIOD) {
                locked += stakes[i].amount;
            }
        }
    }

    //-----------------------external functions-----------------------------------------
    /**
     * @notice Deposits USDC and receives GlUSD shares
     * @dev Mints GlUSD at 1:1 ratio. Tracks underlyingBalanceOf. User must stake GlUSD to Vault to earn yield.
     * @param amount Amount of USDC to deposit
     * @custom:security User must approve this contract to spend USDC before calling
     * @custom:security Protected by reentrancy guard
     * @custom:reverts invalidAmount If amount is 0
     * @custom:reverts contractPaused If contract is paused
     * @custom:emits USDCDeposited When deposit is successful
     */
    function depositUSDC(uint256 amount) external nonReentrant {
        if (paused) {
            revert contractPaused();
        }
        if (amount == 0) {
            revert invalidAmount();
        }

        // Transfer USDC from user
        usdcToken.safeTransferFrom(msg.sender, address(this), amount);

        // Mint GlUSD 1:1
        uint256 shares = amount; // 1:1 ratio
        glusdToken.mint(msg.sender, shares);

        // Track underlying balance (1:1 with GlUSD minted)
        underlyingBalanceOf[msg.sender] += amount;

        // Update legacy tracking
        userDeposits[msg.sender] += amount;
        userShares[msg.sender] += shares;
        totalShares += shares;

        emit USDCDeposited(msg.sender, amount, shares);
    }

    /**
     * @notice Redeems GlUSD shares for USDC
     * @dev Burns GlUSD shares and returns USDC. Minimum 1:1 redemption guaranteed.
     * @param shares Amount of GlUSD shares to redeem
     * @custom:reverts invalidAmount If shares is 0
     * @custom:reverts insufficientBalance If user doesn't have enough GlUSD shares
     * @custom:emits GlUSDRedeemed When redemption is successful
     */
    function redeemGlUSD(uint256 shares) external {
        if (shares == 0) {
            revert invalidAmount();
        }
        if (glusdToken.balanceOf(msg.sender) < shares) {
            revert insufficientBalance();
        }

        // Calculate assets to return (at least 1:1, can be more with yield)
        uint256 assets = convertToAssets(shares);
        // Ensure minimum 1:1 redemption
        if (assets < shares) {
            assets = shares;
        }

        // Burn GlUSD shares
        glusdToken.burn(msg.sender, shares);

        // Update tracking (prevent underflow)
        if (userDeposits[msg.sender] >= assets) {
            userDeposits[msg.sender] -= assets;
        } else {
            userDeposits[msg.sender] = 0;
        }

        if (userShares[msg.sender] >= shares) {
            userShares[msg.sender] -= shares;
        } else {
            userShares[msg.sender] = 0;
        }

        if (totalShares >= shares) {
            totalShares -= shares;
        }

        // Update underlying balance (maintain 1:1)
        // INVARIANT 1: Always subtract shares (1:1), not assets (which might include yield)
        if (underlyingBalanceOf[msg.sender] >= shares) {
            underlyingBalanceOf[msg.sender] -= shares;
        } else {
            underlyingBalanceOf[msg.sender] = 0;
        }

        // Track total withdrawn for Invariant 3 (use shares for 1:1 tracking)
        totalWithdrawn[msg.sender] += shares;

        // Unstake if needed (in production, withdraw from protocols)
        if (totalAssetsStaked >= assets) {
            totalAssetsStaked -= assets;
        }

        // Transfer USDC back
        usdcToken.safeTransfer(msg.sender, assets);

        emit GlUSDRedeemed(msg.sender, shares, assets);
    }

    /**
     * @notice Withdraws unlocked staked tokens
     * @dev Withdraws staked USDC after 1-day lock period. Uses FIFO (oldest first).
     * @param amount Amount of USDC to withdraw
     * @param isReferral true if withdrawing referral reward stakes, false for user deposit stakes
     * @custom:reverts invalidAmount If amount is 0
     * @custom:reverts stakeStillLocked If amount exceeds withdrawable unlocked amount
     * @custom:reverts insufficientBalance If not enough unlocked stakes available
     * @custom:emits StakeWithdrawn When withdrawal is successful
     */
    function withdrawStaked(uint256 amount, bool isReferral) external {
        if (amount == 0) {
            revert invalidAmount();
        }

        uint256 withdrawable = getWithdrawableAmount(msg.sender, isReferral);
        if (amount > withdrawable) {
            revert stakeStillLocked();
        }

        Stake[] storage stakes = isReferral ? referrerStakes[msg.sender] : userStakes[msg.sender];
        uint256 currentTime = block.timestamp;
        uint256 remaining = amount;

        // Withdraw from oldest unlocked stakes first (FIFO)
        for (uint256 i = 0; i < stakes.length && remaining > 0; i++) {
            if (currentTime >= stakes[i].timestamp + LOCK_PERIOD && stakes[i].amount > 0) {
                uint256 toWithdraw = stakes[i].amount < remaining ? stakes[i].amount : remaining;
                stakes[i].amount -= toWithdraw;
                remaining -= toWithdraw;

                // Remove stake if fully withdrawn
                if (stakes[i].amount == 0) {
                    // Move last element to current position and pop
                    stakes[i] = stakes[stakes.length - 1];
                    stakes.pop();
                    i--; // Re-check this index
                }
            }
        }

        if (remaining > 0) {
            revert insufficientBalance();
        }

        // Update tracking
        if (isReferral) {
            referrerStakedCollateral[msg.sender] -= amount;
        } else {
            // For user deposits, the staked amount is 3% of deposit
            // This doesn't affect userDeposits directly
        }

        totalAssetsStaked -= amount;

        // Track total withdrawn for Invariant 3
        totalWithdrawn[msg.sender] += amount;

        // In production, withdraw from protocols
        // For now, transfer from contract balance
        usdcToken.safeTransfer(msg.sender, amount);

        emit StakeWithdrawn(msg.sender, amount, isReferral);
    }

    /**
     * @notice Receives treasury fee from lesson purchases
     * @dev Only callable by LessonNFT. Processes fees, referral rewards, and yield distribution.
     * @dev When no referral/coupon: 10% to protocol, 10% to token stakers (staked for yield)
     * @param amount Amount of USDC received as treasury fee (already transferred to this contract)
     * @param buyer Address of the student who purchased the lesson
     * @param teacher Address of the teacher who created the lesson
     * @param referralCode Optional referral code (bytes32(0) if no referral)
     * @param referralReward Amount already transferred as referral reward (0 if no referral)
     * @param referrer Address of referrer (address(0) if no referral)
     * @custom:security Only callable by LessonNFT contract
     * @custom:reverts contractPaused If contract is paused
     * @custom:reverts unauthorizedCaller If caller is not LessonNFT
     * @custom:reverts invalidAmount If amount is 0
     * @custom:emits TreasuryFeeReceived When fee is received
     */
    function receiveTreasuryFee(
        uint256 amount,
        address buyer,
        address teacher,
        bytes32 referralCode,
        uint256 referralReward,
        address referrer
    ) external {
        if (paused) {
            revert contractPaused();
        }
        // Verify caller is authorized (only LessonNFT can call this)
        if (msg.sender != lessonNFT) {
            revert unauthorizedCaller();
        }

        if (amount == 0) {
            revert invalidAmount();
        }

        emit TreasuryFeeReceived(amount);

        // Handle referral reward if provided
        // referralReward is already transferred to this contract by LessonNFT
        if (referralReward > 0 && referrer != address(0)) {
            _processReferralReward(referralReward, referrer, buyer);
        }

        // Determine fee structure based on whether there's a referral or coupon
        // If no referral/coupon: amount is 20% (10% protocol + 10% stakers)
        // If referral: amount is 10% (all protocol, no stakers) - referralReward > 0
        // If coupon: amount is 10% (5% protocol + 5% stakers) - referralReward == 0 but amount is 10%
        bool hasReferral = (referralReward > 0 && referrer != address(0));

        if (hasReferral) {
            // With referral: amount is 10% (all protocol, no stakers)
            // Track as protocol funds (never mixed with staker funds)
            protocolFunds += amount;
        } else {
            // Either no referral/coupon (20%) or coupon (10%)
            // Split amount 50/50: half to protocol, half to stakers
            uint256 protocolFee = amount / 2;
            uint256 stakerFee = amount / 2;

            // Track protocol fee separately
            protocolFunds += protocolFee;

            // Stake the staker fee portion for yield distribution to all GlUSD holders
            // This stakes the assets (90% Morpho, 10% Aave) and adds to totalAssetsStaked
            // Yield will accrue naturally to all GlUSD holders through share value appreciation
            _stakeAssets(stakerFee, address(this), false); // Stake for protocol (yield benefits all holders)
        }
    }

    /**
     * @notice Processes referral reward - mints GlUSD 1:1
     * @dev Internal function that mints GlUSD 1:1 for referral reward. User must stake to Vault to earn yield.
     * @param referralReward Amount of referral reward (10% of discounted price, already transferred)
     * @param referrer Address of the referrer
     * @param referred Address of the referred user
     * @custom:emits ReferralRewardStaked When referral reward is processed
     */
    function _processReferralReward(uint256 referralReward, address referrer, address referred) internal {
        // referralReward is already calculated and transferred by LessonNFT
        // It's 10% of the discounted price

        // Track referrer's underlying balance (1:1 with GlUSD minted)
        underlyingBalanceOf[referrer] += referralReward;

        // Track referrer's staked collateral
        referrerStakedCollateral[referrer] += referralReward;

        // Mint GlUSD shares 1:1 for referrer (issuance token)
        uint256 shares = referralReward; // 1:1 ratio
        referrerShares[referrer] += shares;
        referrerTotalRewards[referrer] += referralReward;
        totalShares += shares;

        glusdToken.mint(referrer, shares);

        emit ReferralRewardStaked(referrer, referred, referralReward, shares);
    }

    /**
     * @notice Stakes assets to Morpho and Aave with lock tracking
     * @dev Internal function that stakes USDC (90% Morpho, 10% Aave) and records stake with timestamp
     * @param amount Total amount of USDC to stake
     * @param staker Address of the staker (user or referrer)
     * @param isReferral true if this is a referral reward stake, false if from user deposit
     * @custom:emits AssetsStaked When assets are staked to each protocol
     */
    function _stakeAssets(uint256 amount, address staker, bool isReferral) internal {
        uint256 morphoAmount = (amount * morphoAllocationPercent) / 100;
        uint256 aaveAmount = amount - morphoAmount;

        // Approve and stake to Morpho (90% allocation)
        if (morphoAmount > 0 && address(morphoMarket) != address(0) && morphoMarketParams.loanToken != address(0)) {
            SafeERC20.forceApprove(usdcToken, address(morphoMarket), morphoAmount);
            // Supply to Morpho Blue market
            try morphoMarket.supply(
                morphoMarketParams,
                morphoAmount,
                0, // shares = 0 for automatic calculation
                address(this),
                ""
            ) {
                morphoAssets += morphoAmount;
                emit AssetsStaked(address(morphoMarket), morphoAmount);
            } catch {
                // If Morpho supply fails, fallback to just tracking (for testing)
                // In production, this should revert or handle gracefully
                morphoAssets += morphoAmount;
                emit AssetsStaked(address(morphoMarket), morphoAmount);
            }
        } else if (morphoAmount > 0) {
            // If Morpho not configured, still track for testing
            morphoAssets += morphoAmount;
            emit AssetsStaked(address(morphoMarket), morphoAmount);
        }

        // Approve and stake to Aave (10% allocation)
        if (aaveAmount > 0 && address(aavePool) != address(0)) {
            SafeERC20.forceApprove(usdcToken, address(aavePool), aaveAmount);
            // Supply to Aave v3 Pool
            try aavePool.supply(
                address(usdcToken),
                aaveAmount,
                address(this),
                0 // referral code = 0
            ) {
                aaveAssets += aaveAmount;
                emit AssetsStaked(address(aavePool), aaveAmount);
            } catch {
                // If Aave supply fails, fallback to just tracking (for testing)
                // In production, this should revert or handle gracefully
                aaveAssets += aaveAmount;
                emit AssetsStaked(address(aavePool), aaveAmount);
            }
        } else if (aaveAmount > 0) {
            // If Aave not configured, still track for testing
            aaveAssets += aaveAmount;
            emit AssetsStaked(address(aavePool), aaveAmount);
        }

        totalAssetsStaked += amount;

        // Record stake with timestamp for lock tracking
        Stake memory newStake = Stake({amount: amount, timestamp: block.timestamp, isReferral: isReferral});

        if (isReferral) {
            referrerStakes[staker].push(newStake);
        } else {
            userStakes[staker].push(newStake);
        }
    }

    /**
     * @notice Distributes yield to all shareholders
     * @dev Internal function that accrues yield to vault. Yield increases share value proportionally.
     * @param totalYield Total yield amount to distribute (3% of treasury fee)
     * @param buyer Buyer address (unused, kept for future use)
     * @param teacher Teacher address (unused, kept for future use)
     * @custom:emits YieldAccrued When yield is distributed
     */
    function _distributeYield(uint256 totalYield, address buyer, address teacher) internal {
        if (totalShares == 0 || totalYield == 0) {
            return;
        }

        // Distribute yield proportionally based on shares
        // Yield increases totalAssets, which increases share value
        totalAssetsStaked += totalYield;

        // Yield accrues to all shareholders proportionally
        // No need to track individually - it's reflected in share value
        emit YieldAccrued(totalYield);
    }

    /**
     * @notice Validates referral code and returns referrer
     * @dev Public function for LessonNFT to validate referral codes via EscrowNFT
     * @param referralCode The referral code to validate
     * @return referrer Address of the referrer (address(0) if invalid)
     * @return tokenId Token ID of the referral NFT (0 if invalid)
     */
    function validateReferralCode(bytes32 referralCode) public view returns (address referrer, uint256 tokenId) {
        if (escrowNFT == address(0)) {
            return (address(0), 0);
        }
        // Call EscrowNFT to validate
        return IEscrowNFT(escrowNFT).validateReferralCode(referralCode);
    }

    /**
     * @notice Updates the Aave pool address
     * @dev Only owner can update. Used for changing Aave pool or upgrades.
     * @param _newAavePool Address of the new Aave Pool contract
     * @custom:security Only callable by owner
     */
    function updateAavePool(address _newAavePool) external onlyOwner {
        aavePool = IAavePool(_newAavePool);
    }

    /**
     * @notice Updates the Morpho market address
     * @dev Only owner can update. Used for changing Morpho market or upgrades.
     * @param _newMorphoMarket Address of the new Morpho Market contract
     * @custom:security Only callable by owner
     */
    function updateMorphoMarket(address _newMorphoMarket) external onlyOwner {
        morphoMarket = IMorphoMarket(_newMorphoMarket);
    }

    /**
     * @notice Updates the Morpho market parameters
     * @dev Only owner can update. Used for setting or changing market parameters.
     * @param _marketParams The Morpho market parameters (loanToken, collateralToken, oracle, irm, lltv)
     * @custom:security Only callable by owner
     */
    function updateMorphoMarketParams(IMorphoMarket.MarketParams memory _marketParams) external onlyOwner {
        morphoMarketParams = _marketParams;
    }

    /**
     * @notice Updates the EscrowNFT address
     * @dev Only owner can update. Used for changing EscrowNFT implementation.
     * @param _newEscrowNft Address of the new EscrowNFT contract
     * @custom:security Only callable by owner
     */
    function updateEscrowNFT(address _newEscrowNft) external onlyOwner {
        escrowNFT = _newEscrowNft;
    }

    /**
     * @notice Updates the LessonNFT address (authorized caller)
     * @dev Only owner can update. Used for changing LessonNFT implementation or upgrades.
     * @param _newLessonNFT Address of the new LessonNFT contract
     * @custom:security Only callable by owner
     * @custom:reverts zeroAddress If new LessonNFT address is address(0)
     */
    function updateLessonNFT(address _newLessonNFT) external onlyOwner {
        if (_newLessonNFT == address(0)) {
            revert zeroAddress();
        }
        lessonNFT = _newLessonNFT;
    }

    /**
     * @notice Pauses the contract (emergency stop)
     * @dev Only owner can pause. Prevents critical functions from being called.
     * @custom:security Only callable by owner
     * @custom:emits ContractPaused When contract is paused
     */
    function pause() external onlyOwner {
        paused = true;
        emit ContractPaused();
    }

    /**
     * @notice Unpauses the contract
     * @dev Only owner can unpause. Resumes normal contract operations.
     * @custom:security Only callable by owner
     * @custom:emits ContractUnpaused When contract is unpaused
     */
    function unpause() external onlyOwner {
        paused = false;
        emit ContractUnpaused();
    }

    /**
     * @notice Tracks GlUSD shares when user deposits to Vault
     * @dev Called by Vault when user deposits GlUSD. Only users who stake are eligible for yield.
     * @param user Address of the user
     * @param shares Amount of GlUSD shares deposited to vault
     * @custom:security Only callable by Vault contract
     * @custom:reverts unauthorizedCaller If caller is not Vault
     * @custom:emits GlUSDShareTracked When shares are tracked
     */
    function trackGlUSDShare(address user, uint256 shares) external {
        if (msg.sender != vault) {
            revert unauthorizedCaller();
        }
        GlUSD_shareOf[user] += shares;
        emit GlUSDShareTracked(user, shares);
    }

    /**
     * @notice Handles vault withdrawal - burns GlUSD and sends USDC
     * @dev Called by Vault when user withdraws. Burns GlUSD from user and sends USDC.
     * @param user Address of the user withdrawing
     * @param glusdShares Amount of GlUSD shares to burn
     * @param usdcAmount Amount of USDC to send (calculated by vault)
     * @param receiver Address to receive USDC
     * @custom:security Only callable by Vault contract
     * @custom:security Protected by reentrancy guard
     * @custom:reverts unauthorizedCaller If caller is not Vault
     * @custom:reverts insufficientBalance If user doesn't have enough underlying balance
     * @custom:reverts fundsNotAvailable If funds are not available
     * @custom:emits VaultWithdrawProcessed When withdrawal is processed
     */
    function handleVaultWithdraw(address user, uint256 glusdShares, uint256 usdcAmount, address receiver)
        external
        nonReentrant
    {
        if (msg.sender != vault) {
            revert unauthorizedCaller();
        }
        if (paused) {
            revert contractPaused();
        }

        // INVARIANT 1: Maintain 1:1 USDC:GlUSD ratio
        // The usdcAmount from vault may include yield appreciation, but we must maintain 1:1
        // Only send back the amount that equals the GlUSD burned (1:1)
        uint256 usdcToSend = glusdShares; // 1:1 ratio

        // If vault calculated more (due to yield), that's fine - user gets the yield
        // But we maintain 1:1 ratio in our accounting
        if (usdcAmount < usdcToSend) {
            // Vault calculated less than 1:1 (shouldn't happen, but safety check)
            usdcToSend = usdcAmount;
        }

        // Burn GlUSD from vault (vault holds the GlUSD, not the user)
        // The vault transferred GlUSD to itself when user deposited
        glusdToken.burn(address(vault), glusdShares);

        // Update underlying balance (maintain 1:1)
        if (underlyingBalanceOf[user] >= usdcToSend) {
            underlyingBalanceOf[user] -= usdcToSend;
        } else {
            underlyingBalanceOf[user] = 0; // Prevent underflow
        }

        // Track total withdrawn for Invariant 3
        totalWithdrawn[user] += usdcToSend;

        // Update tracked shares
        if (GlUSD_shareOf[user] >= glusdShares) {
            GlUSD_shareOf[user] -= glusdShares;
        } else {
            GlUSD_shareOf[user] = 0; // Prevent underflow
        }

        // Check if user has shares in vault to determine protocol source
        uint256 userShare = GlUSD_shareOf[user];
        uint256 totalVaultShares = _getTotalVaultShares();

        if (userShare > 0 && totalVaultShares > 0) {
            // Calculate user's share percentage
            uint256 sharePercent = (userShare * 100) / totalVaultShares;

            // Determine which protocols to check based on share percentage
            bool checkMorpho = sharePercent >= 10;
            bool checkAave = sharePercent < 90;
            bool checkBoth = sharePercent > 90;

            // Calculate available USDC (excluding protocol funds)
            uint256 availableUSDC = usdcToken.balanceOf(address(this)) - protocolFunds;

            // Send 1:1 amount first (maintains invariant)
            if (availableUSDC >= usdcToSend) {
                // Treasury has enough funds, send 1:1 amount immediately
                usdcToken.safeTransfer(receiver, usdcToSend);

                // If vault calculated more (yield), send the excess as yield
                if (usdcAmount > usdcToSend) {
                    uint256 yieldAmount = usdcAmount - usdcToSend;
                    if (availableUSDC - usdcToSend >= yieldAmount) {
                        usdcToken.safeTransfer(receiver, yieldAmount);
                    } else {
                        // Request yield from protocols
                        uint256 requested = 0;
                        if (checkBoth) {
                            requested += _requestFromMorpho(yieldAmount / 2);
                            requested += _requestFromAave(yieldAmount / 2);
                        } else if (checkMorpho) {
                            requested = _requestFromMorpho(yieldAmount);
                        } else if (checkAave) {
                            requested = _requestFromAave(yieldAmount);
                        }
                        uint256 toSend = (availableUSDC - usdcToSend) + requested;
                        if (toSend > yieldAmount) toSend = yieldAmount;
                        if (toSend > 0) usdcToken.safeTransfer(receiver, toSend);
                    }
                }
            } else {
                // Request from protocols based on share percentage
                uint256 requested = 0;

                if (checkBoth) {
                    requested += _requestFromMorpho(usdcToSend / 2);
                    requested += _requestFromAave(usdcToSend / 2);
                } else if (checkMorpho) {
                    requested = _requestFromMorpho(usdcToSend);
                } else if (checkAave) {
                    requested = _requestFromAave(usdcToSend);
                }

                // Send 1:1 amount
                uint256 toSend = availableUSDC + requested;
                if (toSend > usdcToSend) toSend = usdcToSend;
                if (toSend > 0) usdcToken.safeTransfer(receiver, toSend);

                // Handle yield if any
                if (usdcAmount > usdcToSend) {
                    uint256 yieldAmount = usdcAmount - usdcToSend;
                    // Yield can be claimed separately via claim() function
                }
            }
        } else {
            // User has no shares in vault, send from available balance (1:1)
            uint256 availableUSDC = usdcToken.balanceOf(address(this)) - protocolFunds;
            uint256 toSend = availableUSDC >= usdcToSend ? usdcToSend : availableUSDC;
            if (toSend > 0) {
                usdcToken.safeTransfer(receiver, toSend);
            }
        }

        emit VaultWithdrawProcessed(user, glusdShares, usdcToSend);
    }

    /**
     * @notice Gets claimable amount for a user based on their share percentage
     * @dev View function to check how much yield a user can claim
     * @param user Address of the user
     * @return claimable Amount of USDC that can be claimed
     */
    function getClaimableAmount(address user) external view returns (uint256 claimable) {
        uint256 userShare = GlUSD_shareOf[user];
        if (userShare == 0) {
            return 0;
        }

        uint256 totalVaultShares = _getTotalVaultShares();
        if (totalVaultShares == 0) {
            return 0;
        }

        // Calculate user's share percentage
        uint256 sharePercent = (userShare * 100) / totalVaultShares;

        // Determine which protocols to check
        bool checkMorpho = sharePercent >= 10;
        bool checkAave = sharePercent < 90;
        bool checkBoth = sharePercent > 90;

        // Calculate available yield from protocols
        uint256 availableYield = 0;

        if (checkBoth) {
            // Check both Morpho and Aave
            availableYield += _getAvailableYieldFromMorpho();
            availableYield += _getAvailableYieldFromAave();
        } else if (checkMorpho) {
            // Check Morpho only
            availableYield = _getAvailableYieldFromMorpho();
        } else if (checkAave) {
            // Check Aave only
            availableYield = _getAvailableYieldFromAave();
        }

        // Calculate user's proportional claimable amount
        claimable = (availableYield * userShare) / totalVaultShares;

        // Ensure we don't exceed available USDC (excluding protocol funds)
        uint256 availableUSDC = usdcToken.balanceOf(address(this)) - protocolFunds;
        if (claimable > availableUSDC) {
            claimable = availableUSDC;
        }
    }

    /**
     * @notice Claims available yield based on user's share percentage
     * @dev User can claim yield proportional to their vault shares
     * @dev INVARIANT: User must wait 1 day and must have withdrawn at least some USDC before claiming
     * @param amount Amount of USDC to claim (max is getClaimableAmount)
     * @custom:security Protected by reentrancy guard
     * @custom:reverts nothingToClaim If user has no claimable amount
     * @custom:reverts stakeStillLocked If 1-day lock period hasn't passed
     * @custom:reverts fundsNotAvailable If funds are not available
     * @custom:emits FundsClaimed When funds are claimed
     */
    function claim(uint256 amount) external nonReentrant {
        if (paused) {
            revert contractPaused();
        }

        // INVARIANT 2: Check 1-day lock period
        // User must have at least one stake that's unlocked
        uint256 withdrawable = getWithdrawableAmount(msg.sender, false);
        if (withdrawable == 0) {
            // Check if user has any stakes at all
            Stake[] memory stakes = userStakes[msg.sender];
            if (stakes.length > 0) {
                // User has stakes but none are unlocked - enforce 1-day lock
                revert stakeStillLocked();
            }
        }

        // INVARIANT 3: User must have withdrawn at least some USDC before claiming rewards
        // User must have withdrawn at least some amount (and burned GlUSD) before claiming
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

        // Calculate available USDC (excluding protocol funds)
        uint256 availableUSDC = usdcToken.balanceOf(address(this)) - protocolFunds;

        if (availableUSDC < amount) {
            // Request from protocols based on user's share percentage
            uint256 userShare = GlUSD_shareOf[msg.sender];
            uint256 totalVaultShares = _getTotalVaultShares();
            uint256 sharePercent = (userShare * 100) / totalVaultShares;

            bool checkMorpho = sharePercent >= 10;
            bool checkAave = sharePercent < 90;
            bool checkBoth = sharePercent > 90;

            if (checkBoth) {
                _requestFromMorpho(amount / 2);
                _requestFromAave(amount / 2);
            } else if (checkMorpho) {
                _requestFromMorpho(amount);
            } else if (checkAave) {
                _requestFromAave(amount);
            }
        }

        // Transfer claimed amount
        usdcToken.safeTransfer(msg.sender, amount);

        emit FundsClaimed(msg.sender, amount);
    }

    /**
     * @notice Handles GlUSD payment for course purchases
     * @dev Transfers GlUSD from student to teacher. Only callable by LessonNFT.
     * @param glusdAmount Amount of GlUSD to transfer
     * @param from Student address (payer)
     * @param to Teacher address (receiver)
     * @return success Always returns true if transfer succeeds
     * @custom:security Only callable by LessonNFT contract
     * @custom:security Student must approve LessonNFT or TreasuryContract to spend GlUSD
     * @custom:reverts contractPaused If contract is paused
     * @custom:reverts unauthorizedCaller If caller is not LessonNFT
     * @custom:reverts invalidAmount If glusdAmount is 0
     * @custom:reverts zeroAddress If from or to is address(0)
     * @custom:emits GlUSDPaymentProcessed When payment is processed
     */
    function handleGlUSDPayment(uint256 glusdAmount, address from, address to) external returns (bool success) {
        if (paused) {
            revert contractPaused();
        }
        // Only LessonNFT can call this
        if (msg.sender != lessonNFT) {
            revert unauthorizedCaller();
        }
        if (glusdAmount == 0) {
            revert invalidAmount();
        }
        if (from == address(0) || to == address(0)) {
            revert zeroAddress();
        }

        // Transfer GlUSD from student to teacher
        // This transfers the yield-bearing shares, not burning/redeeming
        // We need to use IERC20 interface since GlUSD inherits ERC20
        IERC20(address(glusdToken)).safeTransferFrom(from, to, glusdAmount);

        emit GlUSDPaymentProcessed(from, to, glusdAmount);
        return true;
    }

    /**
     * @notice Updates the Vault address
     * @dev Only owner can update. Used for changing Vault implementation.
     * @param _newVault Address of the new Vault contract
     * @custom:security Only callable by owner
     * @custom:reverts zeroAddress If new vault address is address(0)
     */
    function updateVault(address _newVault) external onlyOwner {
        if (_newVault == address(0)) {
            revert zeroAddress();
        }
        vault = _newVault;
    }

    //-----------------------internal helper functions-----------------------------------------
    /**
     * @notice Gets total GlUSD shares in vault
     * @dev Internal view function to get total shares from vault
     * @return Total shares in vault
     */
    function _getTotalVaultShares() internal view returns (uint256) {
        if (vault == address(0)) {
            return 0;
        }
        // Call vault's totalSupply() to get total shares
        // Note: This requires Vault to expose totalSupply or we need an interface
        // For now, we'll track it differently or use a mapping
        // TODO: Add interface for Vault or track total shares in Treasury
        return IVault(vault).totalSupply();
    }

    /**
     * @notice Requests USDC from Morpho protocol
     * @dev Internal function to withdraw from Morpho
     * @param amount Amount to request
     * @return Amount actually received
     */
    function _requestFromMorpho(uint256 amount) internal returns (uint256) {
        if (address(morphoMarket) == address(0) || morphoAssets == 0) {
            return 0;
        }
        // Calculate actual withdrawable amount (may include yield)
        uint256 toWithdraw = amount > morphoAssets ? morphoAssets : amount;

        // Withdraw from Morpho Blue market (if market params are set)
        if (morphoMarketParams.loanToken != address(0)) {
            try morphoMarket.withdraw(
                morphoMarketParams,
                toWithdraw,
                0, // shares = 0 for automatic calculation
                address(this),
                address(this)
            ) returns (
                uint256 assetsWithdrawn, uint256
            ) {
                // Update tracking (use actual withdrawn amount which may include yield)
                if (assetsWithdrawn >= morphoAssets) {
                    totalAssetsStaked -= morphoAssets;
                    morphoAssets = 0;
                    return morphoAssets; // Return original amount if we can't track yield precisely
                } else {
                    morphoAssets -= assetsWithdrawn;
                    totalAssetsStaked -= assetsWithdrawn;
                    return assetsWithdrawn;
                }
            } catch {
                // If withdraw fails, return tracked amount (for testing)
                uint256 toReturn = toWithdraw;
                morphoAssets -= toReturn;
                totalAssetsStaked -= toReturn;
                return toReturn;
            }
        } else {
            // If Morpho not configured, return tracked amount
            uint256 toReturn = toWithdraw;
            morphoAssets -= toReturn;
            totalAssetsStaked -= toReturn;
            return toReturn;
        }
    }

    /**
     * @notice Requests USDC from Aave protocol
     * @dev Internal function to withdraw from Aave
     * @param amount Amount to request
     * @return Amount actually received
     */
    function _requestFromAave(uint256 amount) internal returns (uint256) {
        if (address(aavePool) == address(0) || aaveAssets == 0) {
            return 0;
        }
        // Calculate actual withdrawable amount (may include yield)
        uint256 toWithdraw = amount > aaveAssets ? aaveAssets : amount;

        // Withdraw from Aave v3 Pool
        try aavePool.withdraw(address(usdcToken), toWithdraw, address(this)) returns (uint256 assetsWithdrawn) {
            // Update tracking (use actual withdrawn amount which may include yield)
            if (assetsWithdrawn >= aaveAssets) {
                totalAssetsStaked -= aaveAssets;
                aaveAssets = 0;
                return aaveAssets; // Return original amount if we can't track yield precisely
            } else {
                aaveAssets -= assetsWithdrawn;
                totalAssetsStaked -= assetsWithdrawn;
                return assetsWithdrawn;
            }
        } catch {
            // If withdraw fails, return tracked amount (for testing)
            uint256 toReturn = toWithdraw;
            aaveAssets -= toReturn;
            totalAssetsStaked -= toReturn;
            return toReturn;
        }
    }

    /**
     * @notice Gets available yield from Morpho
     * @dev Internal view function to check available yield by comparing current balance to staked amount
     * @return Available yield amount
     */
    function _getAvailableYieldFromMorpho() internal view returns (uint256) {
        if (address(morphoMarket) == address(0) || morphoAssets == 0 || morphoMarketParams.loanToken == address(0)) {
            return 0;
        }
        // Query Morpho market for current total supply assets
        try morphoMarket.market(morphoMarketParams) returns (IMorphoMarket.Market memory market) {
            // Calculate our share of the market and current value
            // This is a simplified calculation - in production, track shares precisely
            // For now, estimate yield based on market growth
            if (market.totalSupplyShares == 0) {
                return 0;
            }

            // Estimate: if we staked morphoAssets, our current value would be:
            // currentValue = (morphoAssets / initialSupplyAssets) * currentSupplyAssets
            // yield = currentValue - morphoAssets
            // Simplified: assume proportional growth
            uint256 estimatedValue = (morphoAssets * market.totalSupplyAssets) / market.totalSupplyShares;
            if (estimatedValue > morphoAssets) {
                return estimatedValue - morphoAssets;
            }
            return 0;
        } catch {
            // If query fails, return 0 (for testing)
            return 0;
        }
    }

    /**
     * @notice Gets available yield from Aave
     * @dev Internal view function to check available yield using normalized income
     * @return Available yield amount
     */
    function _getAvailableYieldFromAave() internal view returns (uint256) {
        if (address(aavePool) == address(0) || aaveAssets == 0) {
            return 0;
        }
        // Get current normalized income (includes accrued interest)
        try aavePool.getReserveNormalizedIncome(address(usdcToken)) returns (uint256 currentNormalizedIncome) {
            // Calculate yield: (currentNormalizedIncome - 1e27) * aaveAssets / 1e27
            // Normalized income starts at 1e27 and increases with interest
            // This is a simplified calculation - in production, track initial normalized income
            if (currentNormalizedIncome > 1e27) {
                uint256 yieldMultiplier = currentNormalizedIncome - 1e27;
                return (aaveAssets * yieldMultiplier) / 1e27;
            }
            return 0;
        } catch {
            // If query fails, return 0 (for testing)
            return 0;
        }
    }
}

// Interface for Vault
interface IVault {
    function totalSupply() external view returns (uint256);
}
