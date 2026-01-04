// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {LibTreasuryStorage} from "../libraries/LibTreasuryStorage.sol";
import {LibDiamond} from "../libraries/LibDiamond.sol";
import {IAavePool} from "../../interfaces/IAavePool.sol";
import {IMorphoMarket} from "../../interfaces/IMorphoMarket.sol";

contract TreasuryAdminFacet {
    error zeroAddress();

    event ContractPaused();
    event ContractUnpaused();

    function pause() external {
        LibDiamond.enforceIsContractOwner();
        LibTreasuryStorage.TreasuryStorage storage ts = LibTreasuryStorage.treasuryStorage();
        ts.paused = true;
        emit ContractPaused();
    }

    function unpause() external {
        LibDiamond.enforceIsContractOwner();
        LibTreasuryStorage.TreasuryStorage storage ts = LibTreasuryStorage.treasuryStorage();
        ts.paused = false;
        emit ContractUnpaused();
    }

    function updateAavePool(address _newAavePool) external {
        LibDiamond.enforceIsContractOwner();
        LibTreasuryStorage.TreasuryStorage storage ts = LibTreasuryStorage.treasuryStorage();
        ts.aavePool = IAavePool(_newAavePool);
    }

    function updateMorphoMarket(address _newMorphoMarket) external {
        LibDiamond.enforceIsContractOwner();
        LibTreasuryStorage.TreasuryStorage storage ts = LibTreasuryStorage.treasuryStorage();
        ts.morphoMarket = IMorphoMarket(_newMorphoMarket);
    }

    function updateMorphoMarketParams(IMorphoMarket.MarketParams memory _marketParams) external {
        LibDiamond.enforceIsContractOwner();
        LibTreasuryStorage.TreasuryStorage storage ts = LibTreasuryStorage.treasuryStorage();
        ts.morphoMarketParams = _marketParams;
    }

    function updateEscrowNFT(address _newEscrowNft) external {
        LibDiamond.enforceIsContractOwner();
        LibTreasuryStorage.TreasuryStorage storage ts = LibTreasuryStorage.treasuryStorage();
        ts.escrowNFT = _newEscrowNft;
    }

    function updateLessonNFT(address _newLessonNFT) external {
        LibDiamond.enforceIsContractOwner();
        if (_newLessonNFT == address(0)) revert zeroAddress();
        LibTreasuryStorage.TreasuryStorage storage ts = LibTreasuryStorage.treasuryStorage();
        ts.lessonNFT = _newLessonNFT;
    }

    function updateVault(address _newVault) external {
        LibDiamond.enforceIsContractOwner();
        if (_newVault == address(0)) revert zeroAddress();
        LibTreasuryStorage.TreasuryStorage storage ts = LibTreasuryStorage.treasuryStorage();
        ts.vault = _newVault;
    }

    // Getters
    function escrowNFT() external view returns (address) {
        return LibTreasuryStorage.treasuryStorage().escrowNFT;
    }

    function lessonNFT() external view returns (address) {
        return LibTreasuryStorage.treasuryStorage().lessonNFT;
    }

    function aavePool() external view returns (address) {
        return address(LibTreasuryStorage.treasuryStorage().aavePool);
    }

    function morphoMarket() external view returns (address) {
        return address(LibTreasuryStorage.treasuryStorage().morphoMarket);
    }
}

