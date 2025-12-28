// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

/**
 * @title IMorphoMarket
 * @dev Interface for Morpho Blue market contract
 * @notice Based on Morpho Blue interface for supplying assets
 */
interface IMorphoMarket {
    /**
     * @notice Supplies assets to the market
     * @param marketParams The market parameters (loanToken, collateralToken, oracle, irm, lltv)
     * @param assets The amount of assets to supply
     * @param shares The amount of shares to mint (can be 0 for automatic calculation)
     * @param onBehalfOf The address that will receive the shares
     * @param data Additional data for the supply operation
     * @return assetsSupplied The actual amount of assets supplied
     * @return sharesSupplied The actual amount of shares minted
     */
    function supply(
        MarketParams memory marketParams,
        uint256 assets,
        uint256 shares,
        address onBehalfOf,
        bytes calldata data
    ) external returns (uint256 assetsSupplied, uint256 sharesSupplied);

    /**
     * @notice Withdraws assets from the market
     * @param marketParams The market parameters
     * @param assets The amount of assets to withdraw
     * @param shares The amount of shares to burn (can be 0 for automatic calculation)
     * @param onBehalfOf The address that owns the shares
     * @param receiver The address that will receive the assets
     * @return assetsWithdrawn The actual amount of assets withdrawn
     * @return sharesWithdrawn The actual amount of shares burned
     */
    function withdraw(
        MarketParams memory marketParams,
        uint256 assets,
        uint256 shares,
        address onBehalfOf,
        address receiver
    ) external returns (uint256 assetsWithdrawn, uint256 sharesWithdrawn);

    /**
     * @notice Gets the market's total assets
     * @param marketParams The market parameters
     * @return The total assets in the market
     */
    function market(MarketParams memory marketParams) external view returns (Market memory);

    struct MarketParams {
        address loanToken;
        address collateralToken;
        address oracle;
        address irm;
        uint256 lltv;
    }

    struct Market {
        uint128 totalSupplyAssets;
        uint128 totalSupplyShares;
        uint128 totalBorrowAssets;
        uint128 totalBorrowShares;
        uint128 lastUpdate;
        uint128 fee;
    }
}


