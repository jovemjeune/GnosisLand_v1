# User Flows

This document describes the step-by-step user interaction flows in Gnosisland.

## Teacher Flow

### 1. Become a Teacher
1. Connect wallet to Gnosisland
2. Call `TeacherNFT.mintTeacherNFT(teacherAddress, name, data)`
3. Receive TeacherNFT token
4. Teacher is now verified and can create courses

### 2. Create a Course
1. Call `LessonFactory.createLessonNFT(teacherTokenId, price, name, data)`
   - `price` must be at least 25 USDC
   - Factory validates teacher has TeacherNFT
2. New LessonNFT contract is deployed
3. Course is now available in marketplace

### 3. Create Coupon Code
1. Call `LessonNFT.createCouponCode(teacherTokenId)`
2. Receive a unique coupon code (bytes32)
3. Share coupon code with students for 50% discount

### 4. Receive Payment
1. Student purchases course
2. Teacher receives 80-90% of purchase price (depending on discounts)
3. If student pays with GlUSD, teacher earns yield on payment

### 5. View Earnings
1. Check balance in TreasuryContract
2. Withdraw earnings (if any withdrawal mechanism exists)

## Student Flow

### 1. Deposit USDC
1. Approve USDC to TreasuryContract
2. Call `TreasuryContract.depositUSDC(amount)`
3. Receive GlUSD 1:1 with USDC deposited
4. GlUSD represents shares in the vault

### 2. Stake GlUSD (Optional)
1. Approve GlUSD to Vault
2. Call `Vault.deposit(glusdAmount, receiver)`
3. Start earning yield on staked GlUSD
4. Yield accrues over time (~6.25% APY)

### 3. Purchase Course
1. Browse available courses
2. Select course (LessonNFT contract)
3. Call `LessonNFT.buyLesson(lessonId, couponCode, paymentAmount, referralCode)`
   - `paymentAmount` must be at least the final price (after discounts)
   - Can pay with USDC or GlUSD
4. If using coupon code: 50% discount applied
5. If using referral code: 10% discount applied
6. Receive soulbound NFT representing course completion
7. Certificate automatically minted

### 4. Claim Yield
1. Check available yield in Vault
2. Call `Vault.redeem(shares, receiver, owner)` to withdraw
3. Or call `TreasuryContract.claim(amount)` if using direct staking
4. Receive USDC (value may have increased due to yield)

### 5. Withdraw Staked Funds
1. Wait for 1-day lock period to expire
2. Call `TreasuryContract.withdrawStaked(amount, isReferral)`
3. Receive USDC back (may include yield)

## Referrer Flow

### 1. Create Referral Code
1. Call `EscrowNFT.createReferralCode(referrerAddress)`
2. Receive referral code NFT
3. Get referral code as `bytes32` hash
4. Share referral code with potential students

### 2. Earn Referral Rewards
1. Student uses referral code when purchasing
2. Referrer automatically receives 3% of purchase price
3. Reward is automatically staked in TreasuryContract
4. Referrer earns yield on staked rewards
5. Can withdraw after 1-day lock period

### 3. Track Referrals
1. Check `TreasuryContract.referrerStakedCollateral(referrer)`
2. Check `TreasuryContract.referrerTotalRewards(referrer)`
3. View all referral rewards and yield earned

## Discount Flow

### Coupon Code Discount
1. Teacher creates coupon code (50% discount)
2. Student uses coupon code when purchasing
3. Final price = original price × 50%
4. Minimum price validation: final price must be ≥ 25 USDC
5. Fee structure adjusted:
   - Protocol fee: 5% (half of normal)
   - Staker fee: 5% (half of normal)
   - Teacher fee: 90%

### Referral Discount
1. Student uses referral code
2. 10% discount applied to purchase price
3. Referrer receives 3% of original price (not discounted)
4. Fee structure:
   - Protocol fee: 10%
   - Referrer fee: 10% (3% reward + 7% discount)
   - Teacher fee: 80%

## Payment Methods

### Pay with USDC
1. Approve USDC to LessonNFT
2. Call `buyLesson()` with USDC
3. USDC transferred directly to TreasuryContract
4. Fees distributed immediately

### Pay with GlUSD
1. Deposit USDC to get GlUSD
2. Approve GlUSD to LessonNFT
3. Call `buyLesson()` with GlUSD
4. TreasuryContract handles GlUSD payment
5. Teacher receives GlUSD (can earn yield)

## Certificate Flow

### Automatic Certificate Minting
1. Student purchases course
2. `LessonNFT.buyLesson()` automatically calls CertificateFactory
3. CertificateFactory gets or creates CertificateNFT for teacher
4. CertificateNFT mints soulbound certificate to student
5. Certificate includes:
   - Lesson ID
   - Student address
   - Course metadata
   - Lesson name

### View Certificate
1. Student can view certificate NFT in wallet
2. Certificate is soulbound (non-transferable)
3. Metadata stored on-chain or via URI

## Error Scenarios

### Insufficient Payment
- Error: `unsufficientPayment()`
- Solution: Send correct payment amount (including discounts)

### Price Too Low
- Error: `priceTooLowForDiscounts()`
- Solution: Final price after discount must be ≥ 25 USDC

### Coupon Already Used
- Error: `couponCodeAlreadyUsed()`
- Solution: Each coupon code can only be used once

### Invalid Coupon Code
- Error: `invalidCouponCode()`
- Solution: Use valid coupon code from teacher

### Stake Still Locked
- Error: `stakeStillLocked()`
- Solution: Wait for 1-day lock period to expire

### Not a Teacher
- Error: `notATeacher()`
- Solution: Mint TeacherNFT first

## Gas Optimization Tips

1. **Batch Operations**: If available, batch multiple operations
2. **Approve Once**: Approve maximum amount to avoid repeated approvals
3. **Stake for Longer**: Longer staking periods may have better yield
4. **Use Referral Codes**: Earn rewards while helping others

## Security Best Practices

1. **Verify Contract Addresses**: Always verify contract addresses before interacting
2. **Check Prices**: Verify course prices before purchasing
3. **Validate Coupon Codes**: Ensure coupon codes are from trusted teachers
4. **Monitor Transactions**: Check transaction status on Base explorer
5. **Keep Private Keys Safe**: Never share private keys or seed phrases

