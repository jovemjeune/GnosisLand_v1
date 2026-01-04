// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {LibTreasuryStorage} from "../libraries/LibTreasuryStorage.sol";
import {TreasuryShareLibrary} from "../../libraries/TreasuryShareLibrary.sol";
import {TreasuryYieldLibrary} from "../../libraries/TreasuryYieldLibrary.sol";

interface ITreasuryStakingFacet {
    function getWithdrawableAmount(address user, bool isReferral) external view returns (uint256);
    function requestFromMorpho(uint256 amount) external returns (uint256);
    function requestFromAave(uint256 amount) external returns (uint256);
}

contract TreasuryYieldFacet {
    using SafeERC20 for IERC20;

    error stakeStillLocked();
    error contractPaused();
    error nothingToClaim();
    error insufficientBalance();

    event FundsClaimed(address indexed user, uint256 amount);

    function getClaimableAmount(address user) external view returns (uint256 claimable) {
        LibTreasuryStorage.TreasuryStorage storage ts = LibTreasuryStorage.treasuryStorage();
        uint256 userShares = ts.userShare[user];
        if (userShares == 0) return 0;

        uint256 totalVaultShares = _getTotalVaultShares();
        if (totalVaultShares == 0) return 0;

        uint256 sharePercent = TreasuryShareLibrary.calculateSharePercent(userShares, totalVaultShares);
        (bool checkMorpho, bool checkAave, bool checkBoth) = TreasuryShareLibrary.getProtocolChecks(sharePercent);
        uint256 availableYield = 0;

        if (checkBoth) {
            availableYield += _getAvailableYieldFromMorpho();
            availableYield += _getAvailableYieldFromAave();
        } else if (checkMorpho) {
            availableYield = _getAvailableYieldFromMorpho();
        } else if (checkAave) {
            availableYield = _getAvailableYieldFromAave();
        }

        claimable = (availableYield * userShares) / totalVaultShares;

        uint256 availableUSDC = ts.usdcToken.balanceOf(address(this)) - ts.protocolFunds;
        if (claimable > availableUSDC) {
            claimable = availableUSDC;
        }
    }

    function claim(uint256 amount) external {
        LibTreasuryStorage.TreasuryStorage storage ts = LibTreasuryStorage.treasuryStorage();
        if (ts.paused) revert contractPaused();

        // Invariant 2: Check 1-day lock period
        uint256 withdrawable = ITreasuryStakingFacet(address(this)).getWithdrawableAmount(msg.sender, false);
        if (withdrawable == 0) {
            uint256 stakes = ts.userStakes[msg.sender];
            if (stakes == 0) {
                revert stakeStillLocked();
            }
            uint256 timeStamp = ts.userTimeStamp[msg.sender];
            if (timeStamp > 0 && block.timestamp < timeStamp + LibTreasuryStorage.LOCK_PERIOD) {
                revert stakeStillLocked();
            }
        }

        // Invariant 3: User must have withdrawn before claiming
        if (ts.totalWithdrawn[msg.sender] == 0) {
            revert stakeStillLocked();
        }

        uint256 claimable = this.getClaimableAmount(msg.sender);
        if (claimable == 0) revert nothingToClaim();
        if (amount > claimable) amount = claimable;

        uint256 userGlUSDBalance = ts.glusdToken.balanceOf(msg.sender);
        uint256 userUSDCBalance = ts.underlyingBalanceOf[msg.sender];

        if (userGlUSDBalance < userUSDCBalance) {
            uint256 shortfall = userUSDCBalance - userGlUSDBalance;
            if (amount > shortfall) {
                amount = amount - shortfall;
            } else {
                revert insufficientBalance();
            }
        }

        uint256 availableUSDC = ts.usdcToken.balanceOf(address(this)) - ts.protocolFunds;

        if (availableUSDC < amount) {
            uint256 userShares = ts.userShare[msg.sender];
            uint256 totalVaultShares = _getTotalVaultShares();
            uint256 sharePercent = TreasuryShareLibrary.calculateSharePercent(userShares, totalVaultShares);
            (bool checkMorpho, bool checkAave, bool checkBoth) = TreasuryShareLibrary.getProtocolChecks(sharePercent);

            if (checkBoth) {
                ITreasuryStakingFacet(address(this)).requestFromMorpho(amount / 2);
                ITreasuryStakingFacet(address(this)).requestFromAave(amount / 2);
            } else if (checkMorpho) {
                ITreasuryStakingFacet(address(this)).requestFromMorpho(amount);
            } else if (checkAave) {
                ITreasuryStakingFacet(address(this)).requestFromAave(amount);
            }
        }
        ts.usdcToken.safeTransfer(msg.sender, amount);
        emit FundsClaimed(msg.sender, amount);
    }

    function _getTotalVaultShares() internal view returns (uint256) {
        LibTreasuryStorage.TreasuryStorage storage ts = LibTreasuryStorage.treasuryStorage();
        if (ts.vault == address(0)) return 0;
        return IERC4626(ts.vault).totalSupply();
    }

    function _getAvailableYieldFromMorpho() internal view returns (uint256) {
        LibTreasuryStorage.TreasuryStorage storage ts = LibTreasuryStorage.treasuryStorage();
        return TreasuryYieldLibrary.getAvailableYieldFromMorpho(ts.morphoMarket, ts.morphoMarketParams, ts.morphoAssets);
    }

    function _getAvailableYieldFromAave() internal view returns (uint256) {
        LibTreasuryStorage.TreasuryStorage storage ts = LibTreasuryStorage.treasuryStorage();
        return TreasuryYieldLibrary.getAvailableYieldFromAave(ts.aavePool, ts.usdcToken, ts.aaveAssets);
    }

    function userShare(address user) external view returns (uint256) {
        return LibTreasuryStorage.treasuryStorage().userShare[user];
    }
}

