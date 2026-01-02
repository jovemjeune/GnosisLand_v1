// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IAavePool} from "../interfaces/IAavePool.sol";
import {IMorphoMarket} from "../interfaces/IMorphoMarket.sol";

/**
 * @title TreasuryYieldLibrary
 * @notice Library for yield calculation from DeFi protocols
 * @dev Extracted from TreasuryContract to reduce contract size
 */
library TreasuryYieldLibrary {
    /**
     * @notice Gets available yield from Morpho Blue
     * @param morphoMarket Morpho Market contract
     * @param morphoMarketParams Morpho market parameters
     * @param morphoAssets Current Morpho assets tracked
     * @return yield Available yield amount
     */
    function getAvailableYieldFromMorpho(
        IMorphoMarket morphoMarket,
        IMorphoMarket.MarketParams memory morphoMarketParams,
        uint256 morphoAssets
    ) external view returns (uint256 yield) {
        if (address(morphoMarket) == address(0) || morphoAssets == 0 || morphoMarketParams.loanToken == address(0)) {
            return 0;
        }
        try morphoMarket.market(morphoMarketParams) returns (IMorphoMarket.Market memory m) {
            if (m.totalSupplyShares == 0) return 0;
            uint256 v = (morphoAssets * m.totalSupplyAssets) / m.totalSupplyShares;
            return v > morphoAssets ? v - morphoAssets : 0;
        } catch {
            return 0;
        }
    }

    /**
     * @notice Gets available yield from Aave
     * @param aavePool Aave Pool contract
     * @param usdcToken USDC token contract
     * @param aaveAssets Current Aave assets tracked
     * @return yield Available yield amount
     */
    function getAvailableYieldFromAave(
        IAavePool aavePool,
        IERC20 usdcToken,
        uint256 aaveAssets
    ) external view returns (uint256 yield) {
        if (address(aavePool) == address(0) || aaveAssets == 0) return 0;
        try aavePool.getReserveNormalizedIncome(address(usdcToken)) returns (uint256 n) {
            if (n <= 1e27) return 0;
            return (aaveAssets * (n - 1e27)) / 1e27;
        } catch {
            return 0;
        }
    }
}

