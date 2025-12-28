# Treasury System Documentation

## Overview

The treasury system integrates with Aave and Morpho to generate yield from USDC deposits and distribute rewards to users, teachers, and referrers.

## Architecture

### Components

1. **GlUSD Token** (`GlUSD.sol`)
   - ERC20 token pegged 1:1 with USDC
   - Minted when users deposit USDC
   - Burned when users redeem GlUSD
   - UUPS upgradeable with ERC7201 storage

2. **TreasuryContract** (`TreasuryContract.sol`)
   - Manages USDC deposits and GlUSD minting
   - Integrates with Aave and Morpho for yield generation
   - Distributes yield to users and teachers
   - Handles referral rewards
   - UUPS upgradeable with ERC7201 storage

3. **LessonNFT Integration**
   - Updated to send 10% of sales to treasury
   - Supports referral tracking
   - Calls treasury for fee processing

## Fee Structure

### Sales Fees
- **10%** of each lesson purchase goes to treasury (5% with coupon code)
- **90%** goes to teacher (95% with coupon code)

### Treasury Fee Distribution
When treasury receives 10% fee:
- **3%** goes to users/teachers who deposited USDC (distributed proportionally)
- **3%** goes to referrer (if buyer was referred)
- Remaining goes to treasury reserves

### Yield Generation
- **3% of deposits** are allocated to yield protocols:
  - **90%** to Morpho
  - **10%** to Aave
- **3% of treasury fees** are also allocated to yield protocols

## User Flow

### 1. Deposit USDC
```solidity
treasury.depositUSDC(amount, referrerAddress);
```
- User deposits USDC
- Receives GlUSD at 1:1 ratio
- 3% of deposit allocated to Morpho (90%) and Aave (10%)
- Referrer can be set on first deposit

### 2. Purchase Lesson
```solidity
lessonNFT.buyLesson(lessonId, hasCoupon, paymentAmount, referrerAddress);
```
- 10% fee sent to treasury
- If buyer has referrer, 3% of purchase price staked for referrer
- 3% of fee distributed as yield to depositors

### 3. Redeem GlUSD
```solidity
treasury.redeemGlUSD(glusdAmount);
```
- User burns GlUSD
- Receives USDC at 1:1 ratio
- Deposit balance updated

### 4. Withdraw Yield
```solidity
treasury.withdrawYield(user, amount);
```
- User withdraws earned yield
- Yield is calculated based on deposit proportion

## Referral System

### How It Works
1. User sets referrer on first deposit or purchase
2. When referred user makes a purchase:
   - 3% of purchase price is staked for referrer
   - Staked amount allocated to Morpho (90%) and Aave (10%)
   - Referrer rewards tracked separately

### Referral Tracking
- `referrer(user)` - Get referrer address for a user
- `referrerRewards(referrer)` - Total rewards earned by referrer
- `referrerStaked(referrer)` - Amount staked from referrals

## Yield Distribution

### Calculation
Yield is distributed proportionally based on USDC deposits:
```
userYield = (totalYield * userDeposits) / totalDepositedUSDC
```

### Tracking
- `userYieldEarned(user)` - Yield earned by user
- `teacherYieldEarned(teacher)` - Yield earned by teacher
- `totalYieldGenerated()` - Total yield generated

## Aave & Morpho Integration

### Current Status
- Placeholder functions for Aave and Morpho integration
- Approval logic implemented
- Actual protocol calls need to be implemented based on:
  - Aave Pool interface
  - Morpho Market interface

### Implementation Notes
```solidity
// Aave integration (placeholder)
function _depositToAave(uint256 amount) internal {
    SafeERC20.forceApprove(usdcToken, aavePool, amount);
    // IPool(aavePool).supply(address(usdcToken), amount, address(this), 0);
}

// Morpho integration (placeholder)
function _depositToMorpho(uint256 amount) internal {
    SafeERC20.forceApprove(usdcToken, morphoMarket, amount);
    // MorphoMarket(morphoMarket).supply(address(usdcToken), amount, address(this), 0);
}
```

## Storage Structure

### ERC7201 Namespaces
- `gnosisland.storage.GlUSD` - GlUSD contract storage
- `gnosisland.storage.TreasuryContract` - Treasury contract storage

### Key Mappings
- `userDeposits[user]` - USDC deposited by user
- `userYieldEarned[user]` - Yield earned by user
- `teacherYieldEarned[teacher]` - Yield earned by teacher
- `referrers[user]` - Referrer for user
- `referrerRewards[referrer]` - Total rewards for referrer
- `referrerStaked[referrer]` - Staked amount for referrer

## Events

- `USDCDeposited` - When user deposits USDC
- `GlUSDRedeemed` - When user redeems GlUSD
- `TreasuryFeeReceived` - When treasury receives fee
- `YieldDistributed` - When yield is distributed
- `ReferralRewardStaked` - When referral reward is staked
- `ReferrerSet` - When referrer is set

## Security Considerations

1. **Access Control**
   - Only treasury can mint/burn GlUSD
   - Only owner can update protocol addresses
   - Referrer can only be set once per user

2. **Reentrancy**
   - SafeERC20 used for all token transfers
   - Checks-effects-interactions pattern followed

3. **Upgradeability**
   - UUPS pattern with owner-only upgrades
   - ERC7201 storage prevents collisions

## Future Enhancements

1. Implement actual Aave Pool integration
2. Implement actual Morpho Market integration
3. Add yield withdrawal from protocols
4. Add compound interest calculations
5. Add referral reward withdrawal mechanism
6. Add batch operations for efficiency

