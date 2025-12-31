# Coupon Code System

## Overview

Gnosisland implements a coupon code system that allows teachers to offer 50% discounts on their courses. Each coupon code is unique, can only be used once, and is tied to the teacher who created it.

## Key Features

- **50% Discount**: Coupon codes provide a 50% discount on course prices
- **One-Time Use**: Each coupon code can only be used once
- **Teacher-Specific**: Coupon codes are created by teachers for their own courses
- **Minimum Price Protection**: Final price after discount must be at least 25 USDC
- **Fee Adjustment**: Protocol and staker fees are halved when coupon is used

## How It Works

### Creating Coupon Codes

Teachers create coupon codes by calling:
```solidity
function createCouponCode(uint256 teacherTokenId) external returns (bytes32 couponCode)
```

**Process**:
1. Teacher must own a TeacherNFT (verified by `teacherTokenId`)
2. Teacher must be the owner of the LessonNFT contract
3. A unique `bytes32` coupon code is generated
4. Coupon code is stored with creator address
5. Coupon code is returned to the teacher

**Storage**:
- `mapping(bytes32 => bool) public couponCodesUsed`: Tracks if coupon has been used
- `mapping(bytes32 => address) public couponCodeCreator`: Maps coupon to creator

### Using Coupon Codes

Students use coupon codes when purchasing courses:
```solidity
function buyLesson(
    uint256 lessonId,
    bytes32 couponCode,
    uint256 paymentAmount,
    bytes32 referralCode
) external
```

**Validation**:
1. Coupon code must exist (creator address is non-zero)
2. Coupon code must not have been used before
3. Coupon code creator must be the teacher of the course
4. Final price after discount must be ≥ 25 USDC

**Discount Calculation**:
```solidity
uint256 finalPrice = (price * 50) / 100; // 50% discount
require(finalPrice >= MINIMUM_PRICE, "priceTooLowForDiscounts");
```

## Fee Structure with Coupons

When a coupon code is used, the fee structure changes:

| Component | Normal Purchase | With Coupon (50% off) |
|-----------|-----------------|----------------------|
| **Original Price** | 100 USDC | 100 USDC |
| **Final Price** | 100 USDC | 50 USDC |
| **Protocol Fee** | 10 USDC (10%) | 2.5 USDC (5%) |
| **Staker Fee** | 10 USDC (10%) | 2.5 USDC (5%) |
| **Teacher Fee** | 80 USDC (80%) | 45 USDC (90%) |

**Note**: Fees are calculated on the **final discounted price**, not the original price.

## Minimum Price Protection

To maintain protocol sustainability, the final price after discount must be at least 25 USDC:

```solidity
uint256 public constant MINIMUM_PRICE = 25e6; // 25 USDC (6 decimals)

function _processDiscounts(uint256 price, bytes32 couponCode) internal view returns (uint256) {
    uint256 finalPrice = price;
    
    if (couponCode != bytes32(0)) {
        // Validate coupon code
        require(couponCodeCreator[couponCode] == onBehalf, "invalidCouponCode");
        require(!couponCodesUsed[couponCode], "couponCodeAlreadyUsed");
        
        // Apply 50% discount
        finalPrice = (price * 50) / 100;
        
        // Ensure minimum price
        require(finalPrice >= MINIMUM_PRICE, "priceTooLowForDiscounts");
    }
    
    return finalPrice;
}
```

**Examples**:
- Course priced at 50 USDC → With coupon: 25 USDC ✅
- Course priced at 100 USDC → With coupon: 50 USDC ✅
- Course priced at 30 USDC → With coupon: 15 USDC ❌ (below minimum)

## Security Features

### One-Time Use Protection
```solidity
require(!couponCodesUsed[couponCode], "couponCodeAlreadyUsed");
// ... use coupon ...
couponCodesUsed[couponCode] = true; // Mark as used
```

### Teacher Verification
```solidity
require(couponCodeCreator[couponCode] == onBehalf, "invalidCouponCode");
```

This ensures:
- Only the course teacher's coupon codes can be used
- Prevents cross-course coupon usage
- Prevents unauthorized coupon creation

### Minimum Price Enforcement
```solidity
require(finalPrice >= MINIMUM_PRICE, "priceTooLowForDiscounts");
```

This ensures:
- Protocol sustainability
- Teachers cannot offer courses below minimum price
- Fee structure remains viable

## Coupon Code Generation

Coupon codes are generated as `bytes32` values. The exact generation method depends on the implementation, but typically involves:
- Teacher address
- Lesson ID or timestamp
- Random component or hash

**Example**:
```solidity
bytes32 couponCode = keccak256(abi.encodePacked(
    teacherAddress,
    lessonId,
    block.timestamp,
    blockhash(block.number - 1)
));
```

## Usage Flow

### Teacher Creates Coupon
1. Teacher calls `createCouponCode(teacherTokenId)`
2. Receives `bytes32` coupon code
3. Shares coupon code with students (off-chain)

### Student Uses Coupon
1. Student calls `buyLesson(lessonId, couponCode, paymentAmount, bytes32(0))`
2. System validates coupon code
3. Applies 50% discount
4. Validates minimum price
5. Processes payment with adjusted fees
6. Marks coupon as used
7. Mints NFT to student

## Error Handling

### Invalid Coupon Code
- **Error**: `invalidCouponCode()`
- **Cause**: Coupon code doesn't exist or creator doesn't match teacher
- **Solution**: Use valid coupon code from the course teacher

### Coupon Already Used
- **Error**: `couponCodeAlreadyUsed()`
- **Cause**: Coupon code has already been used
- **Solution**: Each coupon can only be used once

### Price Too Low
- **Error**: `priceTooLowForDiscounts()`
- **Cause**: Final price after discount is below 25 USDC
- **Solution**: Teacher must set higher original price

## Best Practices

### For Teachers
1. **Create Limited Coupons**: Don't create unlimited coupons
2. **Set Appropriate Prices**: Ensure price × 50% ≥ 25 USDC
3. **Share Securely**: Share coupon codes through secure channels
4. **Track Usage**: Monitor which coupons have been used
5. **Time-Limited**: Consider creating time-limited coupons (future feature)

### For Students
1. **Verify Source**: Only use coupon codes from trusted teachers
2. **Check Price**: Verify final price before purchasing
3. **Use Quickly**: Coupon codes are first-come-first-served
4. **Don't Share**: Don't share your coupon codes (they're one-time use)

## Future Enhancements

### Potential Features
1. **Time-Limited Coupons**: Expiration dates for coupons
2. **Usage Limits**: Maximum number of uses per coupon
3. **Percentage Discounts**: Custom discount percentages (not just 50%)
4. **Bulk Coupons**: Generate multiple coupons at once
5. **Coupon Analytics**: Track coupon usage and effectiveness
6. **Student-Specific Coupons**: Coupons tied to specific student addresses

## Gas Costs

- **Creating Coupon**: ~50,000 - 70,000 gas
- **Using Coupon**: Included in `buyLesson()` gas cost (~150,000 - 200,000 gas total)

## Integration with Other Systems

### Coupon + Referral
Coupons and referral codes can be used together, but discounts don't stack:
- If both are provided, coupon discount (50%) takes precedence
- Referral code is still validated but discount may not apply
- Fee structure follows coupon rules (5% protocol, 5% staker, 90% teacher)

### Coupon + GlUSD Payment
- Coupons work with both USDC and GlUSD payments
- Discount is applied to the payment amount
- Teacher receives GlUSD if student pays with GlUSD

## Example Scenarios

### Scenario 1: Successful Coupon Use
- **Original Price**: 100 USDC
- **Coupon Applied**: 50% off
- **Final Price**: 50 USDC
- **Fees**: 2.5 USDC protocol, 2.5 USDC staker, 45 USDC teacher
- **Result**: ✅ Purchase successful

### Scenario 2: Price Too Low
- **Original Price**: 40 USDC
- **Coupon Applied**: 50% off
- **Final Price**: 20 USDC
- **Result**: ❌ Reverts with `priceTooLowForDiscounts()`

### Scenario 3: Coupon Already Used
- **Coupon Code**: `0x1234...`
- **Status**: Already used
- **Result**: ❌ Reverts with `couponCodeAlreadyUsed()`

