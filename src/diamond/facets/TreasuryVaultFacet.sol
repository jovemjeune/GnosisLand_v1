// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {LibTreasuryStorage} from "../libraries/LibTreasuryStorage.sol";
import {TreasuryShareLibrary} from "../../libraries/TreasuryShareLibrary.sol";

interface ITreasuryStakingFacet {
    function requestFromMorpho(uint256 amount) external returns (uint256);
    function requestFromAave(uint256 amount) external returns (uint256);
}

contract TreasuryVaultFacet {
    using SafeERC20 for IERC20;

    error unauthorizedCaller();
    error contractPaused();
    error zeroAddress();

    event VaultWithdrawProcessed(address indexed user, uint256 glusdBurned, uint256 usdcSent);
    event GlUSDShareTracked(address indexed user, uint256 shares);

    function trackGlUSDShare(address user, uint256 shares) external {
        LibTreasuryStorage.TreasuryStorage storage ts = LibTreasuryStorage.treasuryStorage();
        if (msg.sender != ts.vault) revert unauthorizedCaller();
        ts.userShare[user] += shares;
        emit GlUSDShareTracked(user, shares);
    }

    function handleVaultWithdraw(address user, uint256 vaultShares, uint256 usdcAmount, address receiver) external {
        LibTreasuryStorage.TreasuryStorage storage ts = LibTreasuryStorage.treasuryStorage();
        if (msg.sender != ts.vault || ts.paused) {
            if (msg.sender != ts.vault) revert unauthorizedCaller();
            revert contractPaused();
        }

        if (ts.userShare[user] >= vaultShares) {
            ts.userShare[user] -= vaultShares;
        } else {
            ts.userShare[user] = 0;
        }

        uint256 userUnderlyingBalance = ts.underlyingBalanceOf[user];
        uint256 actualWithdrawAmount = usdcAmount < userUnderlyingBalance ? usdcAmount : userUnderlyingBalance;

        if (actualWithdrawAmount > 0) {
            ts.glusdToken.burn(address(ts.vault), actualWithdrawAmount);
        }

        if (ts.underlyingBalanceOf[user] >= actualWithdrawAmount) {
            ts.underlyingBalanceOf[user] -= actualWithdrawAmount;
        } else {
            ts.underlyingBalanceOf[user] = 0;
        }
        ts.totalWithdrawn[user] += actualWithdrawAmount;

        usdcAmount = actualWithdrawAmount;

        uint256 userShares = ts.userShare[user];
        uint256 totalVaultShares = _getTotalVaultShares();

        uint256 availableUSDC = ts.usdcToken.balanceOf(address(this)) - ts.protocolFunds;
        uint256 requested = 0;

        if (userShares > 0 && totalVaultShares > 0) {
            uint256 sharePercent = TreasuryShareLibrary.calculateSharePercent(userShares, totalVaultShares);
            (bool checkMorpho, bool checkAave, bool checkBoth) = TreasuryShareLibrary.getProtocolChecks(sharePercent);

            if (availableUSDC < usdcAmount) {
                if (checkBoth) {
                    requested += ITreasuryStakingFacet(address(this)).requestFromMorpho(usdcAmount / 2);
                    requested += ITreasuryStakingFacet(address(this)).requestFromAave(usdcAmount / 2);
                } else if (checkMorpho) {
                    requested = ITreasuryStakingFacet(address(this)).requestFromMorpho(usdcAmount);
                } else if (checkAave) {
                    requested = ITreasuryStakingFacet(address(this)).requestFromAave(usdcAmount);
                }
            }
        }

        uint256 toSend = availableUSDC + requested;
        if (toSend > usdcAmount) toSend = usdcAmount;
        if (toSend > 0) {
            ts.usdcToken.safeTransfer(receiver, toSend);
        }

        emit VaultWithdrawProcessed(user, vaultShares, toSend);
    }

    function _getTotalVaultShares() internal view returns (uint256) {
        LibTreasuryStorage.TreasuryStorage storage ts = LibTreasuryStorage.treasuryStorage();
        if (ts.vault == address(0)) return 0;
        return IERC4626(ts.vault).totalSupply();
    }

    function vault() external view returns (address) {
        return LibTreasuryStorage.treasuryStorage().vault;
    }
}

