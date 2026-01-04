// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {GlUSD} from "../../GlUSD.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IAavePool} from "../../interfaces/IAavePool.sol";
import {IMorphoMarket} from "../../interfaces/IMorphoMarket.sol";

library LibTreasuryStorage {
    bytes32 constant TREASURY_STORAGE_POSITION = keccak256("gnosisland.treasury.storage");

    struct TreasuryStorage {
        GlUSD glusdToken;
        IERC20 usdcToken;
        IAavePool aavePool;
        IMorphoMarket morphoMarket;
        IMorphoMarket.MarketParams morphoMarketParams;
        address escrowNFT;
        address lessonNFT;
        address vault;
        bool paused;
        uint256 totalAssetsStaked;
        uint256 totalShares;
        uint256 morphoAssets;
        uint256 aaveAssets;
        uint256 protocolFunds;
        uint256 morphoAllocationPercent;
        uint256 aaveAllocationPercent;
        mapping(address => uint256) underlyingBalanceOf;
        mapping(address => uint256) userShare;
        mapping(address => uint256) totalWithdrawn;
        mapping(address => uint256) referrerStakedCollateral;
        mapping(address => uint256) referrerShares;
        mapping(address => uint256) referrerTotalRewards;
        mapping(address => uint256) referrerStakes;
        mapping(address => uint256) userStakes;
        mapping(address => uint256) referrerTimeStamp;
        mapping(address => uint256) userTimeStamp;
    }

    uint256 constant LOCK_PERIOD = 1 days;
    uint256 constant MORPHO_ALLOCATION = 90;
    uint256 constant AAVE_ALLOCATION = 10;

    function treasuryStorage() internal pure returns (TreasuryStorage storage ts) {
        bytes32 position = TREASURY_STORAGE_POSITION;
        assembly {
            ts.slot := position
        }
    }
}

