// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {LibTreasuryStorage} from "../libraries/LibTreasuryStorage.sol";
import {LibDiamond} from "../libraries/LibDiamond.sol";
import {GlUSD} from "../../GlUSD.sol";

contract TreasuryCoreFacet {
    using SafeERC20 for IERC20;
    using Math for uint256;

    // Constants are in LibTreasuryStorage - access via getter function

    error zeroAddress();
    error insufficientBalance();
    error invalidAmount();
    error stakeStillLocked();
    error contractPaused();
    error unauthorizedCaller();

    event USDCDeposited(address indexed user, uint256 assets, uint256 shares);
    event GlUSDRedeemed(address indexed user, uint256 shares, uint256 assets);

    function totalAssets() public view returns (uint256) {
        LibTreasuryStorage.TreasuryStorage storage ts = LibTreasuryStorage.treasuryStorage();
        return ts.totalAssetsStaked;
    }

    function convertToShares(uint256 assets) public view returns (uint256 shares) {
        LibTreasuryStorage.TreasuryStorage storage ts = LibTreasuryStorage.treasuryStorage();
        if (ts.totalShares == 0) return assets;
        return assets.mulDiv(ts.totalShares, totalAssets(), Math.Rounding.Floor);
    }

    function convertToAssets(uint256 shares) public view returns (uint256 assets) {
        LibTreasuryStorage.TreasuryStorage storage ts = LibTreasuryStorage.treasuryStorage();
        if (ts.totalShares == 0) return 0;
        return shares.mulDiv(totalAssets(), ts.totalShares, Math.Rounding.Floor);
    }

    function depositUSDC(uint256 amount) external {
        LibTreasuryStorage.TreasuryStorage storage ts = LibTreasuryStorage.treasuryStorage();
        if (ts.paused) revert contractPaused();
        if (amount == 0) revert invalidAmount();
        ts.usdcToken.safeTransferFrom(msg.sender, address(this), amount);
        uint256 shares = amount;
        ts.glusdToken.mint(msg.sender, shares);
        ts.underlyingBalanceOf[msg.sender] += amount;
        ts.totalShares += shares;
        emit USDCDeposited(msg.sender, amount, shares);
    }

    function redeemGlUSD(uint256 shares) external {
        LibTreasuryStorage.TreasuryStorage storage ts = LibTreasuryStorage.treasuryStorage();
        if (shares == 0) revert invalidAmount();
        if (ts.glusdToken.balanceOf(msg.sender) < shares) revert insufficientBalance();
        uint256 assets = convertToAssets(shares);
        if (assets < shares) assets = shares;
        ts.glusdToken.burn(msg.sender, shares);
        if (ts.totalShares >= shares) ts.totalShares -= shares;
        if (ts.underlyingBalanceOf[msg.sender] >= shares) {
            ts.underlyingBalanceOf[msg.sender] -= shares;
        } else {
            ts.underlyingBalanceOf[msg.sender] = 0;
        }
        ts.totalWithdrawn[msg.sender] += shares;
        if (ts.totalAssetsStaked >= assets) {
            ts.totalAssetsStaked -= assets;
        }
        ts.usdcToken.safeTransfer(msg.sender, assets);
        emit GlUSDRedeemed(msg.sender, shares, assets);
    }

    // Getters for storage variables
    function glusdToken() external view returns (address) {
        return address(LibTreasuryStorage.treasuryStorage().glusdToken);
    }

    function usdcToken() external view returns (address) {
        return address(LibTreasuryStorage.treasuryStorage().usdcToken);
    }

    function paused() external view returns (bool) {
        return LibTreasuryStorage.treasuryStorage().paused;
    }

    function totalShares() external view returns (uint256) {
        return LibTreasuryStorage.treasuryStorage().totalShares;
    }

    function totalAssetsStaked() external view returns (uint256) {
        return LibTreasuryStorage.treasuryStorage().totalAssetsStaked;
    }

    function underlyingBalanceOf(address user) external view returns (uint256) {
        return LibTreasuryStorage.treasuryStorage().underlyingBalanceOf[user];
    }

    function totalWithdrawn(address user) external view returns (uint256) {
        return LibTreasuryStorage.treasuryStorage().totalWithdrawn[user];
    }

    function LOCK_PERIOD() external pure returns (uint256) {
        return LibTreasuryStorage.LOCK_PERIOD;
    }
}

