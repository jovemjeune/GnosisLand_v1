// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {LibTreasuryStorage} from "../libraries/LibTreasuryStorage.sol";
import {LibDiamond} from "../libraries/LibDiamond.sol";
import {TreasuryStakingLibrary} from "../../libraries/TreasuryStakingLibrary.sol";

contract TreasuryStakingFacet {
    using SafeERC20 for IERC20;

    error invalidAmount();
    error stakeStillLocked();
    error contractPaused();

    event AssetsStaked(address indexed protocol, uint256 amount);
    event StakeWithdrawn(address indexed user, uint256 amount, bool isReferral);

    function getWithdrawableAmount(address user, bool isReferral) public view returns (uint256 withdrawable) {
        LibTreasuryStorage.TreasuryStorage storage ts = LibTreasuryStorage.treasuryStorage();
        uint256 stakes = isReferral ? ts.referrerStakes[user] : ts.userStakes[user];
        uint256 timeStampMode = isReferral ? ts.referrerTimeStamp[user] : ts.userTimeStamp[user];
        uint256 currentTime = block.timestamp;
        if (currentTime >= timeStampMode + LibTreasuryStorage.LOCK_PERIOD && (timeStampMode > uint256(0))) {
            withdrawable += stakes;
        }
    }

    function withdrawStaked(uint256 amount, bool isReferral) external {
        LibTreasuryStorage.TreasuryStorage storage ts = LibTreasuryStorage.treasuryStorage();
        if (amount == 0) revert invalidAmount();
        if (amount > getWithdrawableAmount(msg.sender, isReferral)) revert stakeStillLocked();

        if (isReferral) {
            ts.referrerStakes[msg.sender] -= amount;
            ts.referrerStakedCollateral[msg.sender] -= amount;
        } else {
            ts.userStakes[msg.sender] -= amount;
        }

        ts.totalAssetsStaked -= amount;
        ts.totalWithdrawn[msg.sender] += amount;
        ts.usdcToken.safeTransfer(msg.sender, amount);
        emit StakeWithdrawn(msg.sender, amount, isReferral);
    }

    function stakeAssets(uint256 amount, address staker, bool isReferral) external {
        LibTreasuryStorage.TreasuryStorage storage ts = LibTreasuryStorage.treasuryStorage();
        (uint256 morphoAmount, uint256 aaveAmount) = TreasuryStakingLibrary.stakeAssets(
            ts.usdcToken,
            ts.morphoMarket,
            ts.aavePool,
            ts.morphoMarketParams,
            amount,
            ts.morphoAllocationPercent
        );

        ts.morphoAssets += morphoAmount;
        ts.aaveAssets += aaveAmount;
        ts.totalAssetsStaked += amount;

        if (morphoAmount > 0) emit AssetsStaked(address(ts.morphoMarket), morphoAmount);
        if (aaveAmount > 0) emit AssetsStaked(address(ts.aavePool), aaveAmount);
        if (isReferral) {
            if (ts.referrerStakes[staker] == 0) {
                ts.referrerTimeStamp[staker] = block.timestamp;
                ts.referrerStakes[staker] = amount;
            } else {
                ts.referrerStakes[staker] += amount;
            }
        } else {
            if (ts.userStakes[staker] == 0) {
                ts.userTimeStamp[staker] = block.timestamp;
                ts.userStakes[staker] = amount;
            } else {
                ts.userStakes[staker] += amount;
            }
        }
    }

    function requestFromMorpho(uint256 amount) external returns (uint256) {
        LibTreasuryStorage.TreasuryStorage storage ts = LibTreasuryStorage.treasuryStorage();
        uint256 withdrawn = TreasuryStakingLibrary.requestFromMorpho(
            ts.morphoMarket, ts.morphoMarketParams, ts.usdcToken, amount, ts.morphoAssets
        );
        if (withdrawn > 0) {
            ts.morphoAssets -= withdrawn;
            ts.totalAssetsStaked -= withdrawn;
        }
        return withdrawn;
    }

    function requestFromAave(uint256 amount) external returns (uint256) {
        LibTreasuryStorage.TreasuryStorage storage ts = LibTreasuryStorage.treasuryStorage();
        uint256 withdrawn = TreasuryStakingLibrary.requestFromAave(ts.aavePool, ts.usdcToken, amount, ts.aaveAssets);
        if (withdrawn > 0) {
            ts.aaveAssets -= withdrawn;
            ts.totalAssetsStaked -= withdrawn;
        }
        return withdrawn;
    }

    // Getters
    function userStakes(address user) external view returns (uint256) {
        return LibTreasuryStorage.treasuryStorage().userStakes[user];
    }

    function referrerStakes(address referrer) external view returns (uint256) {
        return LibTreasuryStorage.treasuryStorage().referrerStakes[referrer];
    }

    function morphoAssets() external view returns (uint256) {
        return LibTreasuryStorage.treasuryStorage().morphoAssets;
    }

    function aaveAssets() external view returns (uint256) {
        return LibTreasuryStorage.treasuryStorage().aaveAssets;
    }

    function morphoAllocationPercent() external view returns (uint256) {
        return LibTreasuryStorage.treasuryStorage().morphoAllocationPercent;
    }

    function aaveAllocationPercent() external view returns (uint256) {
        return LibTreasuryStorage.treasuryStorage().aaveAllocationPercent;
    }
}

