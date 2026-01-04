// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

/**
 * @title ITreasuryErrors
 * @notice Common errors used across Treasury facets
 * @dev This interface allows tests to reference errors
 */
interface ITreasuryErrors {
    error zeroAddress();
    error insufficientBalance();
    error invalidAmount();
    error stakeStillLocked();
    error contractPaused();
    error unauthorizedCaller();
    error nothingToClaim();
}

