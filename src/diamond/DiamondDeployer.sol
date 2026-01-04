// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Diamond} from "./Diamond.sol";
import {DiamondCutFacet} from "./facets/DiamondCutFacet.sol";
import {DiamondLoupeFacet} from "./facets/DiamondLoupeFacet.sol";
import {TreasuryCoreFacet} from "./facets/TreasuryCoreFacet.sol";
import {TreasuryStakingFacet} from "./facets/TreasuryStakingFacet.sol";
import {TreasuryYieldFacet} from "./facets/TreasuryYieldFacet.sol";
import {TreasuryFeeFacet} from "./facets/TreasuryFeeFacet.sol";
import {TreasuryVaultFacet} from "./facets/TreasuryVaultFacet.sol";
import {TreasuryAdminFacet} from "./facets/TreasuryAdminFacet.sol";
import {TreasuryInitFacet} from "./facets/TreasuryInitFacet.sol";
import {IDiamondCut} from "./interfaces/IDiamondCut.sol";
import {DiamondSelectors} from "./libraries/DiamondSelectors.sol";

/**
 * @title DiamondDeployer
 * @notice Helper contract to deploy Diamond with all Treasury facets
 * @dev This simplifies the deployment process
 * @dev Note: diamondCut must be called by the owner. In tests, use vm.prank(owner) before calling.
 */
contract DiamondDeployer {
    struct DeploymentParams {
        address contractOwner;
        address glusdToken;
        address usdcToken;
        address aavePool;
        address morphoMarket;
        address escrowNFT;
        address lessonNFT;
    }
    function deployTreasuryDiamond(
        address _diamondCutFacet,
        address _diamondLoupeFacet,
        address _coreFacet,
        address _stakingFacet,
        address _yieldFacet,
        address _feeFacet,
        address _vaultFacet,
        address _adminFacet,
        address _initFacet,
        DeploymentParams memory params
    ) external returns (address diamond) {
        // Deploy Diamond
        diamond = address(new Diamond(params.contractOwner, _diamondCutFacet));

        return diamond;
    }

    /**
     * @notice Gets facet cuts for diamond deployment
     * @dev Returns cuts that can be used to call diamondCut
     */
    function getFacetCuts(
        address _diamondLoupeFacet,
        address _coreFacet,
        address _stakingFacet,
        address _yieldFacet,
        address _feeFacet,
        address _vaultFacet,
        address _adminFacet,
        address _initFacet
    ) external pure returns (IDiamondCut.FacetCut[] memory cuts, bytes memory initCalldata, address initFacet) {
        // Prepare initialization calldata
        initCalldata = abi.encodeWithSelector(
            TreasuryInitFacet.init.selector,
            address(0), // Will be set by caller
            address(0),
            address(0),
            address(0),
            address(0),
            address(0)
        );
        initFacet = _initFacet;

        // Prepare facet cuts
        cuts = new IDiamondCut.FacetCut[](8);

        cuts[0] = IDiamondCut.FacetCut({
            facetAddress: _diamondLoupeFacet,
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: DiamondSelectors.getLoupeSelectors()
        });

        cuts[1] = IDiamondCut.FacetCut({
            facetAddress: _coreFacet,
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: DiamondSelectors.getCoreSelectors()
        });

        cuts[2] = IDiamondCut.FacetCut({
            facetAddress: _stakingFacet,
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: DiamondSelectors.getStakingSelectors()
        });

        cuts[3] = IDiamondCut.FacetCut({
            facetAddress: _yieldFacet,
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: DiamondSelectors.getYieldSelectors()
        });

        cuts[4] = IDiamondCut.FacetCut({
            facetAddress: _feeFacet,
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: DiamondSelectors.getFeeSelectors()
        });

        cuts[5] = IDiamondCut.FacetCut({
            facetAddress: _vaultFacet,
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: DiamondSelectors.getVaultSelectors()
        });

        cuts[6] = IDiamondCut.FacetCut({
            facetAddress: _adminFacet,
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: DiamondSelectors.getAdminSelectors()
        });

        cuts[7] = IDiamondCut.FacetCut({
            facetAddress: _initFacet,
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: DiamondSelectors.getInitSelectors()
        });
    }
}

