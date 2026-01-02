// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IAavePool} from "../interfaces/IAavePool.sol";
import {IMorphoMarket} from "../interfaces/IMorphoMarket.sol";

/**
 * @title TreasuryStakingLibrary
 * @notice Library for DeFi staking operations (Aave and Morpho Blue)
 * @dev Extracted from TreasuryContract to reduce contract size
 */
library TreasuryStakingLibrary {
    using SafeERC20 for IERC20;

    /**
     * @notice Stakes assets to Morpho and Aave with allocation split
     * @param usdcToken USDC token contract
     * @param morphoMarket Morpho Market contract
     * @param aavePool Aave Pool contract
     * @param morphoMarketParams Morpho market parameters
     * @param amount Total amount to stake
     * @param morphoAllocationPercent Percentage for Morpho (e.g., 90)
     * @return morphoAmount Amount staked to Morpho
     * @return aaveAmount Amount staked to Aave
     */
    function stakeAssets(
        IERC20 usdcToken,
        IMorphoMarket morphoMarket,
        IAavePool aavePool,
        IMorphoMarket.MarketParams memory morphoMarketParams,
        uint256 amount,
        uint256 morphoAllocationPercent
    ) external returns (uint256 morphoAmount, uint256 aaveAmount) {
        morphoAmount = (amount * morphoAllocationPercent) / 100;
        aaveAmount = amount - morphoAmount;

        // Stake to Morpho (90% allocation)
        if (morphoAmount > 0 && address(morphoMarket) != address(0) && morphoMarketParams.loanToken != address(0)) {
            SafeERC20.forceApprove(usdcToken, address(morphoMarket), morphoAmount);
            try morphoMarket.supply(morphoMarketParams, morphoAmount, 0, address(this), "") {} catch {}
        }

        // Stake to Aave (10% allocation)
        if (aaveAmount > 0 && address(aavePool) != address(0)) {
            SafeERC20.forceApprove(usdcToken, address(aavePool), aaveAmount);
            try aavePool.supply(address(usdcToken), aaveAmount, address(this), 0) {} catch {}
        }
    }

    /**
     * @notice Requests withdrawal from Morpho
     * @param morphoMarket Morpho Market contract
     * @param morphoMarketParams Morpho market parameters
     * @param usdcToken USDC token contract
     * @param amount Amount to withdraw
     * @param morphoAssets Current Morpho assets tracked
     * @return withdrawn Amount actually withdrawn
     */
    function requestFromMorpho(
        IMorphoMarket morphoMarket,
        IMorphoMarket.MarketParams memory morphoMarketParams,
        IERC20 usdcToken,
        uint256 amount,
        uint256 morphoAssets
    ) external returns (uint256 withdrawn) {
        if (address(morphoMarket) == address(0) || morphoAssets == 0) return 0;
        uint256 w = amount > morphoAssets ? morphoAssets : amount;
        if (morphoMarketParams.loanToken == address(0)) {
            return w;
        }
        try morphoMarket.withdraw(morphoMarketParams, w, 0, address(this), address(this)) returns (
            uint256 a,
            uint256
        ) {
            if (a >= morphoAssets) {
                return morphoAssets;
            }
            return a;
        } catch {
            return w;
        }
    }

    /**
     * @notice Requests withdrawal from Aave
     * @param aavePool Aave Pool contract
     * @param usdcToken USDC token contract
     * @param amount Amount to withdraw
     * @param aaveAssets Current Aave assets tracked
     * @return withdrawn Amount actually withdrawn
     */
    function requestFromAave(
        IAavePool aavePool,
        IERC20 usdcToken,
        uint256 amount,
        uint256 aaveAssets
    ) external returns (uint256 withdrawn) {
        if (address(aavePool) == address(0) || aaveAssets == 0) return 0;
        uint256 w = amount > aaveAssets ? aaveAssets : amount;
        try aavePool.withdraw(address(usdcToken), w, address(this)) returns (uint256 a) {
            if (a >= aaveAssets) {
                return aaveAssets;
            }
            return a;
        } catch {
            return w;
        }
    }
}

