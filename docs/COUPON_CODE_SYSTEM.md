# Coupon Code System Implementation

## Overview

The coupon code system allows **teachers** to create **one-time usable 50% discount** coupons for their lessons. Only teachers who own a TeacherNFT can create coupon codes.

## How It Works

### Creating Coupon Codes

1. **Teacher calls `createCouponCode(teacherTokenId)`**:
   - Must own the TeacherNFT token with the specified `teacherTokenId`
   - System verifies ownership via `ITeacherNFT.ownerOf(teacherTokenId)`
   - Generates unique `bytes32` coupon code
   - Stores creator address for validation

2. **Coupon Code Generation**:
   - Uses `keccak256` hash of:
     - Teacher address
     - Teacher token ID
     - Block timestamp
     - Block prevrandao
     - Latest NFT ID
   - Ensures uniqueness and prevents collisions

### Using Coupon Codes

1. **User provides coupon code** when buying a lesson
2. **System validates**:
   - Coupon code exists (creator is not zero address)
   - Coupon code hasn't been used before
3. **Applies 50% discount**:
   - Final price = Original price × 50%
   - Fee structure: 10% to protocol (5% protocol + 5% stakers), 90% to teacher
4. **Marks coupon as used** (one-time use only)

## Discount Priority

When multiple discounts are available:

1. **Referral Discount (10%)** - Takes precedence if:
   - Valid referral code provided
   - User hasn't used referral discount before
   - This is user's first purchase

2. **Coupon Code (50%)** - Applied if:
   - Valid coupon code provided
   - No referral discount applies
   - Coupon hasn't been used

3. **Normal Price** - If no discounts apply

**Note**: Referral discount (10%) takes precedence over coupon (50%) if both are provided, but they cannot be combined.

## Fee Distribution

### With Coupon Code (50% discount):
```
Original Price: $200
Discount: 50% = $100
Final Price: $100

Protocol Fee: $100 × 5% = $5.00 (protocol)
Staker Fee: $100 × 5% = $5.00 (stakers)
Teacher Amount: $100 × 90% = $90.00

Total: $5.00 + $5.00 + $90.00 = $100 ✓
```

### With Referral (10% discount):
```
Original Price: $200
Discount: 10% = $20
Final Price: $180

Referrer Reward: $180 × 3% = $5.40
Protocol Fee: $180 × 7% = $12.60
Teacher Amount: $180 × 90% = $162

Total: $5.40 + $12.60 + $162 = $180 ✓
```

### Normal Purchase:
```
Price: $200

Protocol Fee: $200 × 10% = $20
Teacher Amount: $200 × 90% = $180

Total: $20 + $180 = $200 ✓
```

## Implementation Details

### Storage Variables

```solidity
address teacherNFT; // TeacherNFT contract address
mapping(bytes32 => bool) couponCodesUsed; // Coupon code => Whether it's been used
mapping(bytes32 => address) couponCodeCreator; // Coupon code => Address of teacher who created it
```

### Key Functions

1. **`createCouponCode(uint256 teacherTokenId)`**:
   - Verifies caller owns TeacherNFT token
   - Generates unique coupon code
   - Stores creator address
   - Emits `CouponCodeCreated` event

2. **`buyLesson(uint256 lessonId, bytes32 couponCode, uint256 paymentAmount, bytes32 referralCode)`**:
   - Validates coupon code if provided
   - Applies 50% discount if valid
   - Marks coupon as used
   - Emits `CouponCodeUsed` event

3. **View Functions**:
   - `isCouponCodeUsed(bytes32 couponCode)` - Check if coupon is used
   - `getCouponCodeCreator(bytes32 couponCode)` - Get creator address
   - `teacherNFT()` - Get TeacherNFT contract address

## Security Features

1. **Teacher Verification**:
   - Only teachers with TeacherNFT can create coupons
   - Verifies ownership via `ownerOf()` call

2. **One-Time Use**:
   - Coupon codes are marked as used after first purchase
   - Cannot be reused even if purchase fails

3. **Unique Generation**:
   - Uses multiple entropy sources for uniqueness
   - Checks for collisions (extremely unlikely)

4. **Validation**:
   - Coupon must exist (creator not zero)
   - Coupon must not be used
   - Invalid coupons revert transaction

## Events

```solidity
event CouponCodeCreated(
    address indexed teacher,
    uint256 indexed teacherTokenId,
    bytes32 indexed couponCode
);

event CouponCodeUsed(
    address indexed buyer,
    bytes32 indexed couponCode,
    uint256 discountAmount
);
```

## Example Usage

### Teacher Creates Coupon:
```solidity
// Teacher with token ID 5 creates a coupon
bytes32 couponCode = lessonNFT.createCouponCode(5);
// Returns: 0x1234...abcd (unique bytes32)
```

### User Uses Coupon:
```solidity
// User buys lesson with coupon
lessonNFT.buyLesson(
    0,           // lessonId
    couponCode,  // coupon code
    170 * 1e6,   // payment amount (15% off $200)
    bytes32(0)   // no referral code
);
// User pays $170 instead of $200
```

### Check Coupon Status:
```solidity
bool used = lessonNFT.isCouponCodeUsed(couponCode);
address creator = lessonNFT.getCouponCodeCreator(couponCode);
```

## Benefits

### For Teachers:
- **Marketing Tool**: Create discount codes to attract students
- **Flexible Pricing**: Offer discounts without changing lesson price
- **One-Time Use**: Prevents abuse of discount codes

### For Students:
- **50% Discount**: Significant savings on lesson purchases (especially for Turkish market)
- **Easy to Use**: Just provide coupon code when buying
- **Transparent**: Can verify coupon validity before purchase

### For Protocol:
- **5% Fee**: Still receives fee on discounted purchases
- **User Acquisition**: Coupons help teachers attract students
- **Network Growth**: More students = more revenue

## Migration Notes

- New storage variables added to `LessonNFTStorage`
- `initialize()` function now requires `teacherNFT` parameter
- `buyLesson()` signature changed: `bool _hasCouponCode` → `bytes32 couponCode`
- Existing deployments need to be upgraded to include teacherNFT address

## Testing Recommendations

1. **Teacher Verification**:
   - Test creating coupon without TeacherNFT (should fail)
   - Test creating coupon with wrong token ID (should fail)
   - Test creating coupon with valid token ID (should succeed)

2. **Coupon Usage**:
   - Test using valid coupon (should apply 50% discount)
   - Test using same coupon twice (should fail second time)
   - Test using invalid coupon (should fail)
   - Test using coupon with referral (referral should take precedence)

3. **Fee Distribution**:
   - Verify 5% to protocol, 95% to teacher with coupon
   - Verify correct amounts transferred

4. **Edge Cases**:
   - Test coupon code collision (extremely unlikely)
   - Test coupon with zero address teacherNFT
   - Test multiple coupons from same teacher

## Conclusion

The coupon code system provides teachers with a powerful marketing tool while maintaining protocol revenue. The one-time use restriction prevents abuse, and the teacher verification ensures only authorized users can create coupons.

