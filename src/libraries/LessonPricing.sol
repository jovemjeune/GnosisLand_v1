// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

/**
 * @title LessonPricing
 * @dev Library for calculating lesson prices, discounts, and fee distributions
 * @notice Extracted to reduce bytecode size in LessonNFT
 */
library LessonPricing {
    /**
     * @notice Calculates final price after applying discounts
     * @param basePrice Original lesson price
     * @param couponCode Coupon code (bytes32(0) if not used)
     * @param hasReferral Whether user has valid referral
     * @param hasUsedReferral Whether user has already used referral discount
     * @return finalPrice Final price after discounts
     * @return isCouponUsed Whether coupon was applied
     * @return isReferralUsed Whether referral discount was applied
     */
    function calculatePrice(uint256 basePrice, bytes32 couponCode, bool hasReferral, bool hasUsedReferral)
        internal
        pure
        returns (uint256 finalPrice, bool isCouponUsed, bool isReferralUsed)
    {
        finalPrice = basePrice;
        isCouponUsed = false;
        isReferralUsed = false;

        // Apply coupon discount (15%) if valid
        if (couponCode != bytes32(0)) {
            finalPrice = (basePrice * 85) / 100; // 15% discount
            isCouponUsed = true;
        }

        // Apply referral discount (10%) if valid and not used before (takes precedence)
        if (hasReferral && !hasUsedReferral) {
            finalPrice = (basePrice * 90) / 100; // 10% discount
            isReferralUsed = true;
            isCouponUsed = false; // Referral takes precedence
        }
    }

    /**
     * @notice Calculates fee distribution based on purchase type
     * @param finalPrice Final price after discounts
     * @param isReferralUsed Whether referral discount was used
     * @param isCouponUsed Whether coupon was used
     * @return treasuryFee Fee to treasury
     * @return teacherAmount Amount to teacher
     * @return referralReward Reward to referrer (0 if not applicable)
     */
    function calculateFees(uint256 finalPrice, bool isReferralUsed, bool isCouponUsed)
        internal
        pure
        returns (uint256 treasuryFee, uint256 teacherAmount, uint256 referralReward)
    {
        if (isReferralUsed) {
            // With referral: 10% to referrer, 10% to protocol, 80% to teacher
            referralReward = (finalPrice * 10) / 100;
            treasuryFee = (finalPrice * 10) / 100;
            teacherAmount = finalPrice - treasuryFee - referralReward;
        } else if (isCouponUsed) {
            // With coupon: 10% total (5% protocol + 5% stakers), 90% to teacher
            treasuryFee = (finalPrice * 10) / 100;
            teacherAmount = finalPrice - treasuryFee;
        } else {
            // Normal: 20% total (10% protocol + 10% stakers), 80% to teacher
            treasuryFee = (finalPrice * 20) / 100;
            teacherAmount = finalPrice - treasuryFee;
        }
    }
}

