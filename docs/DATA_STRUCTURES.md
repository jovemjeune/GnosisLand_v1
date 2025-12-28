# Gnosisland Data Structures

## TreasuryContract Storage

```
TreasuryContract {
    // Core Addresses
    GlUSD glusdToken;
    IERC20 usdcToken;
    address aavePool;
    address morphoMarket;
    address escrowNFT;
    address lessonNFT;
    address vault;
    bool paused;
    
    // Vault Tracking
    uint256 totalAssetsStaked;      // Total USDC in Morpho + Aave
    uint256 totalShares;             // Total GlUSD minted
    uint256 morphoAssets;            // USDC in Morpho
    uint256 aaveAssets;              // USDC in Aave
    
    // Protocol Funds (Separated)
    uint256 protocolFunds;            // Never mixed with staker funds
    
    // User Tracking
    mapping(address => uint256) underlyingBalanceOf;  // 1:1 with GlUSD
    mapping(address => uint256) GlUSD_shareOf;         // Vault shares
    
    // Legacy Tracking
    mapping(address => uint256) userDeposits;
    mapping(address => uint256) userShares;
    
    // Referral Tracking
    mapping(address => uint256) referrerStakedCollateral;
    mapping(address => uint256) referrerShares;
    mapping(address => uint256) referrerTotalRewards;
    
    // Stake Lock Tracking
    struct Stake {
        uint256 amount;
        uint256 timestamp;
        bool isReferral;
    }
    mapping(address => Stake[]) userStakes;
    mapping(address => Stake[]) referrerStakes;
}
```

## Vault Storage

```
Vault {
    // Core
    address treasuryContract;
    uint256 _virtualShares;          // Donation attack protection
    uint256 _virtualAssets;          // Donation attack protection
    
    // User Tracking
    mapping(address => uint256) GlUSD_shareOf;  // User => Vault shares
}
```

## LessonNFT Storage

```
LessonNFT {
    // Core
    string _name;
    string _symbol;
    uint256 price;
    uint256 originalPrice;
    uint256 latestNFTId;
    address onBehalf;                // Teacher address
    address treasuryContract;
    bool lessonsPaused;
    bytes data;
    address paymentToken;            // USDC
    address teacherNFT;
    
    // Lesson Data
    mapping(uint256 => bytes) nftData;
    mapping(uint256 => uint256) tokenToLesson;
    
    // User Balances
    mapping(address => uint256) userBalance;
    
    // Referral System
    mapping(address => address) referrers;
    mapping(address => bool) hasUsedReferralDiscount;
    
    // Coupon System
    mapping(bytes32 => bool) couponCodesUsed;
    mapping(bytes32 => address) couponCodeCreator;
}
```

## State Transitions

### Deposit Flow State

```
Initial: Student has 0 GlUSD, 0 vault shares
  ↓
depositUSDC(100 USDC)
  ↓
State: Student has 100 GlUSD, underlyingBalanceOf = 100
  ↓
deposit(100 GlUSD to Vault)
  ↓
State: Student has vaultShares, GlUSD_shareOf = shares
  ↓
Eligible for yield
```

### Withdrawal Flow State

```
Initial: Student has vaultShares, GlUSD_shareOf = X
  ↓
withdraw(assets)
  ↓
State: vaultShares burned, GlUSD_shareOf -= shares
  ↓
handleVaultWithdraw()
  ↓
State: GlUSD burned, underlyingBalanceOf -= assets
  ↓
USDC sent to student
```

### Claim Flow State

```
Initial: Student has GlUSD_shareOf = X, yield accrued
  ↓
getClaimableAmount()
  ↓
Calculate: sharePercent = (X * 100) / totalShares
  ↓
Determine protocol based on sharePercent
  ↓
claim(amount)
  ↓
Request from protocols if needed
  ↓
USDC sent to student
```

## Fee Distribution Matrix

| Scenario | Teacher | Protocol | Stakers | Referrer |
|----------|---------|----------|---------|----------|
| Normal | 80% | 10% | 10% | 0% |
| With Referral | 80% | 10% | 0% | 10% |
| With Coupon | 90% | 5% | 5% | 0% |

## Share Percentage Logic Table

| Share % | Protocols Checked | Request Distribution |
|---------|-------------------|---------------------|
| > 90% | Both (Morpho + Aave) | 50% Morpho, 50% Aave |
| >= 10% | Morpho Only | 100% Morpho |
| < 10% | Aave Only | 100% Aave |

## Yield Calculation

```
For each user:
  userShare = GlUSD_shareOf[user]
  totalShares = Vault.totalSupply()
  sharePercent = (userShare * 100) / totalShares
  
  if sharePercent > 90%:
      availableYield = morphoYield + aaveYield
  else if sharePercent >= 10%:
      availableYield = morphoYield
  else:
      availableYield = aaveYield
  
  userClaimable = (availableYield * userShare) / totalShares
  maxClaimable = min(userClaimable, availableUSDC - protocolFunds)
```

## Protocol Funds Tracking

```
Total USDC Balance = protocolFunds + stakerFunds

protocolFunds sources:
  - Referral fees: 10% (all protocol)
  - Normal fees: 10% (half of 20%)
  - Coupon fees: 5% (half of 10%)

stakerFunds sources:
  - User deposits
  - Referral rewards
  - Staker fee portion (10% or 5%)

Critical: protocolFunds is NEVER used for:
  - User withdrawals
  - Yield claims
  - Any staker operations
```

