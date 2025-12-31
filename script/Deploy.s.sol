// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {GlUSD} from "../src/GlUSD.sol";
import {EscrowNFT} from "../src/EscrowNFT.sol";
import {TeacherNft} from "../src/TeacherNFT.sol";
import {TreasuryContract} from "../src/TreasuryContract.sol";
import {Vault} from "../src/Vault.sol";
import {CertificateFactory} from "../src/CertificateFactory.sol";
import {LessonNFT} from "../src/LessonNFT.sol";
import {LessonFactory} from "../src/LessonFactory.sol";
import {DiscountBallot} from "../src/DiscountBallot.sol";
import {IAavePool} from "../src/interfaces/IAavePool.sol";
import {IMorphoMarket} from "../src/interfaces/IMorphoMarket.sol";

/**
 * @title GnosislandDeploymentScript
 * @dev Comprehensive deployment script for all Gnosisland contracts
 * @notice Deploys all contracts in the correct order with proper initialization
 */
contract GnosislandDeploymentScript is Script {
    // Deployment addresses (will be set during deployment)
    address public glusdImplementation;
    address public glusdProxy;
    address public escrowNFTImplementation;
    address public escrowNFTProxy;
    address public teacherNFTImplementation;
    address public teacherNFTProxy;
    address public treasuryImplementation;
    address public treasuryProxy;
    address public vault;
    address public certificateFactoryImplementation;
    address public certificateFactoryProxy;
    address public lessonFactoryImplementation;
    address public lessonFactoryProxy;
    address public discountBallotImplementation;
    address public discountBallotProxy;

    // Configuration (set via environment variables or constructor)
    address public owner;
    address public usdcToken;
    address public aavePool;
    address public morphoMarket;
    IMorphoMarket.MarketParams public morphoMarketParams;
    uint256 public minimumDepositPerVote;

    function setUp() public {
        // Load configuration from environment variables
        owner = vm.envOr("OWNER", address(0x1234567890123456789012345678901234567890));
        usdcToken = vm.envOr("USDC_TOKEN", address(0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913)); // Base mainnet USDC
        aavePool = vm.envOr("AAVE_POOL", address(0xA238Dd80C259a72e81d7e4664a9801593F98d1c5)); // Base mainnet Aave v3
        morphoMarket = vm.envOr("MORPHO_MARKET", address(0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb)); // Base mainnet Morpho Blue
        minimumDepositPerVote = vm.envOr("MINIMUM_DEPOSIT_PER_VOTE", uint256(100e6)); // 100 USDC default

        // Morpho market parameters (set via environment or use defaults)
        // Note: These should be queried from Morpho's market registry on Base mainnet
        morphoMarketParams = IMorphoMarket.MarketParams({
            loanToken: usdcToken,
            collateralToken: vm.envOr("MORPHO_COLLATERAL", usdcToken),
            oracle: vm.envOr("MORPHO_ORACLE", address(0)),
            irm: vm.envOr("MORPHO_IRM", address(0)),
            lltv: vm.envOr("MORPHO_LLTV", uint256(0))
        });

        require(owner != address(0), "OWNER must be set");
        require(usdcToken != address(0), "USDC_TOKEN must be set");
    }

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        console.log("==========================================");
        console.log("Gnosisland Deployment Script");
        console.log("==========================================");
        console.log("Owner:", owner);
        console.log("USDC Token:", usdcToken);
        console.log("Aave Pool:", aavePool);
        console.log("Morpho Market:", morphoMarket);
        console.log("==========================================");

        // Step 1: Deploy GlUSD (with temporary treasury address)
        console.log("\n[1/9] Deploying GlUSD...");
        glusdImplementation = address(new GlUSD());
        bytes memory glusdInit = abi.encodeWithSelector(
            GlUSD.initialize.selector,
            address(0x123), // Temporary treasury (will be updated)
            usdcToken,
            owner
        );
        glusdProxy = address(new ERC1967Proxy(glusdImplementation, glusdInit));
        console.log("GlUSD Implementation:", glusdImplementation);
        console.log("GlUSD Proxy:", glusdProxy);

        // Step 2: Deploy EscrowNFT
        console.log("\n[2/9] Deploying EscrowNFT...");
        escrowNFTImplementation = address(new EscrowNFT());
        bytes memory escrowInit = abi.encodeWithSelector(EscrowNFT.initialize.selector, owner);
        escrowNFTProxy = address(new ERC1967Proxy(escrowNFTImplementation, escrowInit));
        console.log("EscrowNFT Implementation:", escrowNFTImplementation);
        console.log("EscrowNFT Proxy:", escrowNFTProxy);

        // Step 3: Deploy TeacherNFT
        console.log("\n[3/9] Deploying TeacherNFT...");
        teacherNFTImplementation = address(new TeacherNft());
        bytes memory teacherInit =
            abi.encodeWithSelector(TeacherNft.initialize.selector, "Gnosisland Teacher NFT", "GTEACH", owner);
        teacherNFTProxy = address(new ERC1967Proxy(teacherNFTImplementation, teacherInit));
        console.log("TeacherNFT Implementation:", teacherNFTImplementation);
        console.log("TeacherNFT Proxy:", teacherNFTProxy);

        // Step 4: Deploy TreasuryContract
        console.log("\n[4/9] Deploying TreasuryContract...");
        treasuryImplementation = address(new TreasuryContract());
        bytes memory treasuryInit = abi.encodeWithSelector(
            TreasuryContract.initialize.selector,
            glusdProxy,
            usdcToken,
            aavePool,
            morphoMarket,
            escrowNFTProxy,
            address(0), // lessonNFT (will be set later)
            owner
        );
        treasuryProxy = address(new ERC1967Proxy(treasuryImplementation, treasuryInit));
        console.log("TreasuryContract Implementation:", treasuryImplementation);
        console.log("TreasuryContract Proxy:", treasuryProxy);

        // Step 5: Update GlUSD with TreasuryContract
        console.log("\n[5/9] Updating GlUSD treasury...");
        GlUSD(glusdProxy).updateTreasury(treasuryProxy);
        console.log("GlUSD treasury updated");

        // Step 6: Deploy Vault (non-upgradeable)
        console.log("\n[6/9] Deploying Vault...");
        vault = address(new Vault(glusdProxy, treasuryProxy, owner));
        TreasuryContract(treasuryProxy).updateVault(vault);
        console.log("Vault:", vault);

        // Step 7: Update TreasuryContract with Morpho market params (if provided)
        if (morphoMarketParams.oracle != address(0)) {
            console.log("\n[6.5/9] Setting Morpho market parameters...");
            TreasuryContract(treasuryProxy).updateMorphoMarketParams(morphoMarketParams);
            console.log("Morpho market params set");
        }

        // Step 8: Deploy CertificateFactory (non-upgradeable)
        console.log("\n[7/9] Deploying CertificateFactory...");
        certificateFactoryProxy = address(new CertificateFactory());
        certificateFactoryImplementation = certificateFactoryProxy; // Same address for non-upgradeable
        console.log("CertificateFactory Implementation:", certificateFactoryImplementation);
        console.log("CertificateFactory Proxy:", certificateFactoryProxy);

        // Step 9: Deploy LessonFactory (non-upgradeable, uses constructor)
        console.log("\n[8/9] Deploying LessonFactory...");
        // First deploy LessonNFT implementation (needed for LessonFactory constructor)
        // LessonNFT constructor disables initializers, so we can deploy it directly
        address lessonNFTImplementation = address(new LessonNFT());
        console.log("LessonNFT Implementation:", lessonNFTImplementation);

        // Deploy LessonFactory with constructor parameters
        lessonFactoryProxy = address(
            new LessonFactory(
                lessonNFTImplementation, // _lessonNFTImplementation
                treasuryProxy, // _treasuryContract
                usdcToken, // _paymentToken
                teacherNFTProxy, // _teacherNFT
                certificateFactoryProxy // _certificateFactory
            )
        );
        lessonFactoryImplementation = lessonFactoryProxy; // Same address for non-upgradeable
        console.log("LessonFactory Implementation:", lessonFactoryImplementation);
        console.log("LessonFactory Proxy:", lessonFactoryProxy);

        // Step 10: Update TreasuryContract with LessonFactory (for receiveTreasuryFee authorization)
        console.log("\n[8.5/9] Updating TreasuryContract lessonNFT...");
        TreasuryContract(treasuryProxy).updateLessonNFT(lessonFactoryProxy);
        console.log("TreasuryContract lessonNFT updated");

        // Step 11: Deploy DiscountBallot
        console.log("\n[9/9] Deploying DiscountBallot...");
        discountBallotImplementation = address(new DiscountBallot());
        bytes memory ballotInit =
            abi.encodeWithSelector(DiscountBallot.initialize.selector, minimumDepositPerVote, owner);
        discountBallotProxy = address(new ERC1967Proxy(discountBallotImplementation, ballotInit));
        console.log("DiscountBallot Implementation:", discountBallotImplementation);
        console.log("DiscountBallot Proxy:", discountBallotProxy);

        vm.stopBroadcast();

        // Print deployment summary
        console.log("\n==========================================");
        console.log("Deployment Summary");
        console.log("==========================================");
        console.log("GlUSD Proxy:", glusdProxy);
        console.log("EscrowNFT Proxy:", escrowNFTProxy);
        console.log("TeacherNFT Proxy:", teacherNFTProxy);
        console.log("TreasuryContract Proxy:", treasuryProxy);
        console.log("Vault:", vault);
        console.log("CertificateFactory Proxy:", certificateFactoryProxy);
        console.log("LessonFactory Proxy:", lessonFactoryProxy);
        console.log("DiscountBallot Proxy:", discountBallotProxy);
        console.log("==========================================");
        console.log("\nDeployment completed successfully!");
        console.log("\nNext steps:");
        console.log("1. Verify all contracts on block explorer");
        console.log("2. Transfer ownership to multisig/DAO if needed");
        console.log("3. Set Morpho market parameters if not set during deployment");
        console.log("4. Initialize first teacher via TeacherNFT");
    }
}

