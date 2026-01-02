// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

/**
 * @title TreasuryShareLibrary
 * @notice Library for share percentage calculations
 * @dev Extracted from TreasuryContract to reduce contract size
 */
library TreasuryShareLibrary {
    /**
     * @notice Determines which protocols to check based on share percentage
     * @param sharePercent User's share percentage (0-100)
     * @return checkMorpho Whether to check Morpho
     * @return checkAave Whether to check Aave
     * @return checkBoth Whether to check both protocols
     */
    function getProtocolChecks(uint256 sharePercent) internal pure returns (bool checkMorpho, bool checkAave, bool checkBoth) {
        checkMorpho = sharePercent >= 10;
        checkAave = sharePercent < 90;
        checkBoth = sharePercent > 90;
    }

    /**
     * @notice Calculates share percentage
     * @param userShare User's share amount
     * @param totalShares Total shares in vault
     * @return sharePercent Share percentage (0-100)
     */
    function calculateSharePercent(uint256 userShare, uint256 totalShares) internal pure returns (uint256 sharePercent) {
        if (totalShares == 0) return 0;
        return (userShare * 100) / totalShares;
    }
}

