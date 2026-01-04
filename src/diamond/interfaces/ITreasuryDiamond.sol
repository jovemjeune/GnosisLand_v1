// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

/**
 * @title ITreasuryDiamond
 * @notice Interface for Treasury Diamond - provides all public functions
 * @dev This interface allows tests and external contracts to interact with the Diamond
 */
interface ITreasuryDiamond {
    // Core functions
    function totalAssets() external view returns (uint256);
    function convertToShares(uint256 assets) external view returns (uint256 shares);
    function convertToAssets(uint256 shares) external view returns (uint256 assets);
    function depositUSDC(uint256 amount) external;
    function redeemGlUSD(uint256 shares) external;

    // Staking functions
    function getWithdrawableAmount(address user, bool isReferral) external view returns (uint256);
    function withdrawStaked(uint256 amount, bool isReferral) external;

    // Yield functions
    function getClaimableAmount(address user) external view returns (uint256);
    function claim(uint256 amount) external;

    // Fee functions
    function receiveTreasuryFee(
        uint256 amount,
        address buyer,
        address teacher,
        bytes32 referralCode,
        uint256 referralReward,
        address referrer
    ) external;
    function validateReferralCode(bytes32 referralCode) external view returns (address referrer, uint256 tokenId);
    function handleGlUSDPayment(uint256 glusdAmount, address from, address to) external returns (bool);

    // Vault functions
    function trackGlUSDShare(address user, uint256 shares) external;
    function handleVaultWithdraw(address user, uint256 vaultShares, uint256 usdcAmount, address receiver) external;

    // Admin functions
    function pause() external;
    function unpause() external;
    function updateAavePool(address _newAavePool) external;
    function updateMorphoMarket(address _newMorphoMarket) external;
    function updateMorphoMarketParams(IMorphoMarket.MarketParams memory _marketParams) external;
    function updateEscrowNFT(address _newEscrowNft) external;
    function updateLessonNFT(address _newLessonNFT) external;
    function updateVault(address _newVault) external;

    // View functions / Getters
    function glusdToken() external view returns (address);
    function usdcToken() external view returns (address);
    function paused() external view returns (bool);
    function totalShares() external view returns (uint256);
    function totalAssetsStaked() external view returns (uint256);
    function underlyingBalanceOf(address user) external view returns (uint256);
    function totalWithdrawn(address user) external view returns (uint256);
    function userShare(address user) external view returns (uint256);
    function userStakes(address user) external view returns (uint256);
    function referrerStakes(address referrer) external view returns (uint256);
    function referrerStakedCollateral(address referrer) external view returns (uint256);
    function referrerShares(address referrer) external view returns (uint256);
    function protocolFunds() external view returns (uint256);
    function vault() external view returns (address);
    function escrowNFT() external view returns (address);
    function lessonNFT() external view returns (address);
    function morphoAssets() external view returns (uint256);
    function aaveAssets() external view returns (uint256);
    function morphoAllocationPercent() external view returns (uint256);
    function aaveAllocationPercent() external view returns (uint256);

    // Constants (via getter functions in facets)
    function LOCK_PERIOD() external view returns (uint256);
}

import {IMorphoMarket} from "../../interfaces/IMorphoMarket.sol";

