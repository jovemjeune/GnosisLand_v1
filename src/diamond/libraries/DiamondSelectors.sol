// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {IDiamondCut} from "../interfaces/IDiamondCut.sol";
import {IDiamondLoupe} from "../interfaces/IDiamondLoupe.sol";
import {IERC165} from "../interfaces/IERC165.sol";

/**
 * @title DiamondSelectors
 * @notice Library for Diamond function selector arrays
 * @dev Uses pre-computed selectors to avoid large keccak256 bytecode
 */
library DiamondSelectors {
    function getLoupeSelectors() internal pure returns (bytes4[] memory) {
        bytes4[] memory selectors = new bytes4[](5);
        selectors[0] = IDiamondLoupe.facets.selector;
        selectors[1] = IDiamondLoupe.facetFunctionSelectors.selector;
        selectors[2] = IDiamondLoupe.facetAddresses.selector;
        selectors[3] = IDiamondLoupe.facetAddress.selector;
        selectors[4] = IERC165.supportsInterface.selector;
        return selectors;
    }

    function getCoreSelectors() internal pure returns (bytes4[] memory) {
        bytes4[] memory selectors = new bytes4[](12);
        selectors[0] = 0x01e1d114; // totalAssets()
        selectors[1] = 0xc6e6f592; // convertToShares(uint256)
        selectors[2] = 0x07a2d13a; // convertToAssets(uint256)
        selectors[3] = 0xf688bcfb; // depositUSDC(uint256)
        selectors[4] = 0xf0d9418e; // redeemGlUSD(uint256)
        selectors[5] = 0x4fdc3a82; // glusdToken()
        selectors[6] = 0x11eac855; // usdcToken()
        selectors[7] = 0x5c975abb; // paused()
        selectors[8] = 0x3a98ef39; // totalShares()
        selectors[9] = 0x8dd78ca4; // totalAssetsStaked()
        selectors[10] = 0x1820cabb; // LOCK_PERIOD()
        selectors[11] = 0x935a8b84; // underlyingBalanceOf(address)
        return selectors;
    }

    function getStakingSelectors() internal pure returns (bytes4[] memory) {
        bytes4[] memory selectors = new bytes4[](10);
        selectors[0] = 0x02f08bc9; // getWithdrawableAmount(address,bool)
        selectors[1] = 0x0670a9fb; // withdrawStaked(uint256,bool)
        selectors[2] = 0xbc301fb9; // stakeAssets(uint256,address,bool)
        selectors[3] = 0xfff0d849; // requestFromMorpho(uint256)
        selectors[4] = 0x4d9c365e; // requestFromAave(uint256)
        selectors[5] = 0x8da7ad23; // userStakes(address)
        selectors[6] = 0x4033eeb7; // morphoAllocationPercent()
        selectors[7] = 0x371efdf6; // aaveAllocationPercent()
        selectors[8] = 0xae0fab7c; // morphoAssets()
        selectors[9] = 0x085e6bb7; // aaveAssets()
        return selectors;
    }

    function getYieldSelectors() internal pure returns (bytes4[] memory) {
        bytes4[] memory selectors = new bytes4[](3);
        selectors[0] = 0xe12f3a61; // getClaimableAmount(address)
        selectors[1] = 0x379607f5; // claim(uint256)
        selectors[2] = 0x789ef0e0; // userShare(address)
        return selectors;
    }

    function getFeeSelectors() internal pure returns (bytes4[] memory) {
        bytes4[] memory selectors = new bytes4[](6);
        selectors[0] = 0x0a5aac5b; // receiveTreasuryFee(uint256,address,address,bytes32,uint256,address)
        selectors[1] = 0xfd0ad565; // validateReferralCode(bytes32)
        selectors[2] = 0xe9d9451d; // handleGlUSDPayment(uint256,address,address)
        selectors[3] = 0x318bd6ec; // referrerStakedCollateral(address)
        selectors[4] = 0x78a0a114; // referrerShares(address)
        selectors[5] = 0xbb96fe73; // protocolFunds()
        return selectors;
    }

    function getVaultSelectors() internal pure returns (bytes4[] memory) {
        bytes4[] memory selectors = new bytes4[](3);
        selectors[0] = 0x3e136c24; // trackGlUSDShare(address,uint256)
        selectors[1] = 0xb6735f2d; // handleVaultWithdraw(address,uint256,uint256,address)
        selectors[2] = 0xfbfa77cf; // vault()
        return selectors;
    }

    function getAdminSelectors() internal pure returns (bytes4[] memory) {
        bytes4[] memory selectors = new bytes4[](10);
        selectors[0] = 0x8456cb59; // pause()
        selectors[1] = 0x3f4ba83a; // unpause()
        selectors[2] = 0xf71a2a0a; // updateAavePool(address)
        selectors[3] = 0x3297d39c; // updateMorphoMarket(address)
        selectors[4] = 0x9f588771; // updateMorphoMarketParams((address,address,address,address,uint256))
        selectors[5] = 0x20d39a89; // updateEscrowNFT(address)
        selectors[6] = 0xe178e419; // updateLessonNFT(address)
        selectors[7] = 0xe7563f3f; // updateVault(address)
        selectors[8] = 0x6dea48bb; // escrowNFT()
        selectors[9] = 0x672e1f6f; // lessonNFT()
        return selectors;
    }

    function getInitSelectors() internal pure returns (bytes4[] memory) {
        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = 0x99e133f9; // init(address,address,address,address,address,address)
        return selectors;
    }
}
