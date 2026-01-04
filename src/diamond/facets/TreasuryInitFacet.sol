// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {LibTreasuryStorage} from "../libraries/LibTreasuryStorage.sol";
import {GlUSD} from "../../GlUSD.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IAavePool} from "../../interfaces/IAavePool.sol";
import {IMorphoMarket} from "../../interfaces/IMorphoMarket.sol";

contract TreasuryInitFacet {
    error zeroAddress();

    function init(
        address _glusdToken,
        address _usdcToken,
        address _aavePool,
        address _morphoMarket,
        address _escrowNFT,
        address _lessonNFT
    ) external {
        if (_glusdToken == address(0) || _usdcToken == address(0)) {
            revert zeroAddress();
        }

        LibTreasuryStorage.TreasuryStorage storage ts = LibTreasuryStorage.treasuryStorage();

        // Only initialize if not already initialized
        require(address(ts.glusdToken) == address(0), "Already initialized");

        ts.glusdToken = GlUSD(_glusdToken);
        ts.usdcToken = IERC20(_usdcToken);
        if (_aavePool != address(0)) {
            ts.aavePool = IAavePool(_aavePool);
        }
        if (_morphoMarket != address(0)) {
            ts.morphoMarket = IMorphoMarket(_morphoMarket);
        }
        ts.escrowNFT = _escrowNFT;
        ts.lessonNFT = _lessonNFT;
        ts.morphoAllocationPercent = 90;
        ts.aaveAllocationPercent = 10;
        ts.paused = false;
    }
}

