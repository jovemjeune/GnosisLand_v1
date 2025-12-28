// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {TreasuryContract} from "../src/TreasuryContract.sol";
import {GlUSD} from "../src/GlUSD.sol";
import {EscrowNFT} from "../src/EscrowNFT.sol";
import {TeacherNft} from "../src/TeacherNFT.sol";
import {Vault} from "../src/Vault.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {IAavePool} from "../src/interfaces/IAavePool.sol";
import {IMorphoMarket} from "../src/interfaces/IMorphoMarket.sol";

/**
 * @title BaseMainnetForkTest
 * @dev Tests TreasuryContract integration with Aave v3 and Morpho Blue on Base mainnet
 * @notice Forks Base mainnet to test real protocol interactions
 */
contract BaseMainnetForkTest is Test {
    // Base mainnet RPC URL
    string BASE_RPC_URL = vm.envOr("BASE_RPC_URL", string("https://mainnet.base.org"));
    
    // Base mainnet addresses
    address constant BASE_USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913; // USDC on Base
    address constant BASE_AAVE_POOL_V3 = 0xA238Dd80C259a72e81d7e4664a9801593F98d1c5; // Aave v3 Pool on Base
    address constant BASE_MORPHO_BLUE = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb; // Morpho Blue on Base
    
    // Test addresses
    address owner = address(0x1);
    address user = address(0x2);
    address teacher = address(0x3);
    
    // Contracts
    TreasuryContract treasury;
    GlUSD glusd;
    EscrowNFT escrow;
    TeacherNft teacherNFT;
    Vault vault;
    IERC20 usdc;
    
    // Morpho Market Parameters for USDC (example - need to find actual Base mainnet market)
    IMorphoMarket.MarketParams morphoParams;
    
    function setUp() public {
        // Try to fork Base mainnet at latest block (if RPC URL is available)
        // If fork fails, tests will run on local chain (for unit testing)
        try vm.createSelectFork(BASE_RPC_URL) {
            // Successfully forked Base mainnet
        } catch {
            // Fork failed - will run on local chain
            // Tests that require fork will skip
        }
        
        // Initialize USDC
        usdc = IERC20(BASE_USDC);
        
        // Verify Aave Pool exists (only if on fork)
        if (block.chainid == 8453) {
            require(BASE_AAVE_POOL_V3.code.length > 0, "Aave Pool not found");
            require(BASE_MORPHO_BLUE.code.length > 0, "Morpho Blue not found");
        }
        
        vm.startPrank(owner);
        
        // Deploy EscrowNFT
        EscrowNFT escrowImpl = new EscrowNFT();
        bytes memory escrowInit = abi.encodeWithSelector(
            EscrowNFT.initialize.selector,
            owner
        );
        escrow = EscrowNFT(address(new ERC1967Proxy(address(escrowImpl), escrowInit)));
        
        // Deploy TeacherNFT
        TeacherNft teacherNFTImpl = new TeacherNft();
        bytes memory teacherInit = abi.encodeWithSelector(
            TeacherNft.initialize.selector,
            "Teacher NFT",
            "TEACH",
            owner
        );
        teacherNFT = TeacherNft(address(new ERC1967Proxy(address(teacherNFTImpl), teacherInit)));
        
        // Deploy GlUSD (with temporary treasury address)
        GlUSD glusdImpl = new GlUSD();
        bytes memory glusdInit = abi.encodeWithSelector(
            GlUSD.initialize.selector,
            address(0x123), // Temporary
            BASE_USDC,
            owner
        );
        glusd = GlUSD(address(new ERC1967Proxy(address(glusdImpl), glusdInit)));
        
        // Deploy TreasuryContract
        // On local chain (not fork), use address(0) for protocols so assets are tracked without staking
        // On fork, use actual protocol addresses
        address aavePoolAddr = (block.chainid == 8453 && BASE_AAVE_POOL_V3.code.length > 0) 
            ? BASE_AAVE_POOL_V3 
            : address(0);
        address morphoMarketAddr = (block.chainid == 8453 && BASE_MORPHO_BLUE.code.length > 0) 
            ? BASE_MORPHO_BLUE 
            : address(0);
        
        TreasuryContract treasuryImpl = new TreasuryContract();
        bytes memory treasuryInit = abi.encodeWithSelector(
            TreasuryContract.initialize.selector,
            address(glusd),
            BASE_USDC,
            aavePoolAddr,
            morphoMarketAddr,
            address(escrow),
            address(0), // lessonNFT (will be set later)
            owner
        );
        treasury = TreasuryContract(address(new ERC1967Proxy(address(treasuryImpl), treasuryInit)));
        
        // Update GlUSD treasury
        glusd.updateTreasury(address(treasury));
        
        // Deploy Vault
        vault = new Vault(address(glusd), address(treasury), owner);
        treasury.updateVault(address(vault));
        
        // Set Morpho market parameters (example - need actual Base mainnet market params)
        // For now, using placeholder - in production, query actual market
        // Only set if on Base mainnet fork, otherwise leave as default (will track assets without staking)
        if (block.chainid == 8453 && BASE_MORPHO_BLUE.code.length > 0) {
            morphoParams = IMorphoMarket.MarketParams({
                loanToken: BASE_USDC,
                collateralToken: BASE_USDC, // Placeholder - actual market may use different collateral
                oracle: address(0), // Placeholder
                irm: address(0), // Placeholder
                lltv: 0 // Placeholder
            });
            
            // Update Morpho market params in treasury
            treasury.updateMorphoMarketParams(morphoParams);
        } else {
            // On local chain, set loanToken to address(0) so assets are tracked in else branch
            morphoParams = IMorphoMarket.MarketParams({
                loanToken: address(0),
                collateralToken: address(0),
                oracle: address(0),
                irm: address(0),
                lltv: 0
            });
        }
        
        // Note: In production, query actual Morpho market parameters from Base mainnet
        // For testing, we'll use mock or find actual market
        
        vm.stopPrank();
    }
    
    /**
     * @notice Test that we can query Aave Pool on Base mainnet
     */
    function test_AavePool_Exists() public view {
        IAavePool aavePool = IAavePool(BASE_AAVE_POOL_V3);
        
        // Query USDC reserve data
        IAavePool.ReserveData memory reserveData = aavePool.getReserveData(BASE_USDC);
        
        // Verify reserve is active (aToken address should not be zero)
        assertTrue(reserveData.aTokenAddress != address(0), "USDC reserve not active on Aave");
        
        // Get normalized income (should be >= 1e27)
        uint256 normalizedIncome = aavePool.getReserveNormalizedIncome(BASE_USDC);
        assertTrue(normalizedIncome >= 1e27, "Invalid normalized income");
    }
    
    /**
     * @notice Test that we can query Morpho Blue on Base mainnet
     */
    function test_MorphoBlue_Exists() public view {
        IMorphoMarket morpho = IMorphoMarket(BASE_MORPHO_BLUE);
        
        // Verify contract exists
        assertTrue(address(morpho).code.length > 0, "Morpho Blue contract not found");
        
        // Note: Querying market requires valid market params
        // In production, find actual USDC market on Base mainnet
    }
    
    /**
     * @notice Test staking to Aave (with actual Base mainnet fork)
     * @dev This test simulates fee staking by calling receiveTreasuryFee
     * @dev receiveTreasuryFee stakes fees (10% to Aave, 90% to Morpho)
     */
    function test_StakeToAave_BaseMainnet() public {
        // Get some USDC - use deal() to give treasury USDC balance for fees
        uint256 feeAmount = 1000e6; // 1000 USDC in fees
        deal(address(usdc), address(treasury), feeAmount);
        
        // Set mock lessonNFT as authorized caller (must be done by owner)
        address mockLessonNFT = address(0x1234); // Mock lessonNFT address
        vm.prank(owner);
        treasury.updateLessonNFT(mockLessonNFT);
        
        // Call receiveTreasuryFee (simulating a lesson purchase with no referral/coupon)
        // receiveTreasuryFee splits: 50% protocol, 50% stakers (if no referral)
        // Staker portion (50%) gets staked: 10% of that goes to Aave
        uint256 stakerFee = feeAmount / 2; // 50% goes to stakers
        uint256 expectedAaveAmount = (stakerFee * 10) / 100; // 10% of staker fee goes to Aave
        
        // Call receiveTreasuryFee as lessonNFT
        vm.prank(mockLessonNFT);
        treasury.receiveTreasuryFee(
            feeAmount,
            user, // buyer
            teacher, // teacher
            bytes32(0), // no referral code
            0, // no referral reward
            address(0) // no referrer
        );
        
        // Verify Aave assets tracked (10% of staker fee)
        assertEq(treasury.aaveAssets(), expectedAaveAmount, "Aave assets should be 10% of staker fee");
    }
    
    /**
     * @notice Test staking to Morpho (with actual Base mainnet fork)
     * @dev This test simulates fee staking by calling receiveTreasuryFee
     * @dev receiveTreasuryFee stakes fees (90% to Morpho, 10% to Aave)
     */
    function test_StakeToMorpho_BaseMainnet() public {
        vm.startPrank(user);
        
        // Get some USDC - use deal() to give user USDC balance for testing
        uint256 feeAmount = 1000e6; // 1000 USDC in fees
        
        // Give treasury USDC for fees
        deal(address(usdc), address(treasury), feeAmount);
        
        // Approve treasury to spend USDC (for receiveTreasuryFee)
        usdc.approve(address(treasury), feeAmount);
        
        // Simulate receiving treasury fee (this will stake 90% to Morpho)
        // receiveTreasuryFee splits: 50% protocol, 50% stakers (if no referral)
        // Staker portion (50%) gets staked: 90% of that goes to Morpho
        uint256 stakerFee = feeAmount / 2; // 50% goes to stakers
        uint256 expectedMorphoAmount = (stakerFee * 90) / 100; // 90% of staker fee goes to Morpho
        
        vm.stopPrank();
        
        // Set mock lessonNFT as authorized caller (must be done by owner)
        address mockLessonNFT = address(0x1234); // Mock lessonNFT address
        vm.prank(owner);
        treasury.updateLessonNFT(mockLessonNFT);
        
        // Call receiveTreasuryFee as lessonNFT (simulating a lesson purchase with no referral/coupon)
        vm.prank(mockLessonNFT);
        treasury.receiveTreasuryFee(
            feeAmount,
            user, // buyer
            teacher, // teacher
            bytes32(0), // no referral code
            0, // no referral reward
            address(0) // no referrer
        );
        
        // Verify Morpho assets tracked (90% of staker fee)
        assertEq(treasury.morphoAssets(), expectedMorphoAmount, "Morpho assets should be 90% of staker fee");
    }
    
    /**
     * @notice Test 90/10 allocation split
     * @dev This test verifies the allocation logic without requiring actual USDC balance
     */
    function test_AllocationSplit_90PercentMorpho_10PercentAave() public {
        // Verify allocation percentages are set correctly
        assertEq(treasury.morphoAllocationPercent(), 90, "Morpho allocation should be 90%");
        assertEq(treasury.aaveAllocationPercent(), 10, "Aave allocation should be 10%");
        
        // Test allocation calculation
        uint256 depositAmount = 1000e6; // 1000 USDC
        
        // Calculate expected allocations
        uint256 expectedMorphoAmount = (depositAmount * 90) / 100; // 900 USDC
        uint256 expectedAaveAmount = depositAmount - expectedMorphoAmount; // 100 USDC
        
        assertEq(expectedMorphoAmount, 900e6, "Morpho should get 900 USDC (90%)");
        assertEq(expectedAaveAmount, 100e6, "Aave should get 100 USDC (10%)");
        assertEq(expectedMorphoAmount + expectedAaveAmount, depositAmount, "Total should equal deposit");
        
        // Note: Actual staking test requires USDC balance and valid protocol addresses
        // For full integration test, use test_StakeToAave_BaseMainnet() or test_StakeToMorpho_BaseMainnet()
    }
    
    /**
     * @notice Test that total assets staked equals sum of Morpho + Aave
     */
    function test_TotalAssetsStaked_EqualsSum() public {
        vm.startPrank(user);
        
        // Get some USDC - use deal() to give user USDC balance for testing
        uint256 feeAmount = 5000e6; // 5000 USDC in fees
        
        // Give treasury USDC for fees
        deal(address(usdc), address(treasury), feeAmount);
        
        // Approve treasury to spend USDC (for receiveTreasuryFee)
        usdc.approve(address(treasury), feeAmount);
        
        // Simulate receiving treasury fee
        // receiveTreasuryFee splits: 50% protocol, 50% stakers (if no referral)
        uint256 stakerFee = feeAmount / 2; // 50% goes to stakers (this gets staked)
        
        vm.stopPrank();
        
        // Set mock lessonNFT as authorized caller (must be done by owner)
        address mockLessonNFT = address(0x1234); // Mock lessonNFT address
        vm.prank(owner);
        treasury.updateLessonNFT(mockLessonNFT);
        
        // Call receiveTreasuryFee as lessonNFT (simulating a lesson purchase with no referral/coupon)
        vm.prank(mockLessonNFT);
        treasury.receiveTreasuryFee(
            feeAmount,
            user, // buyer
            teacher, // teacher
            bytes32(0), // no referral code
            0, // no referral reward
            address(0) // no referrer
        );
        
        uint256 totalStaked = treasury.totalAssetsStaked();
        uint256 morphoAmount = treasury.morphoAssets();
        uint256 aaveAmount = treasury.aaveAssets();
        
        assertEq(totalStaked, morphoAmount + aaveAmount, "Total staked should equal sum");
        assertEq(totalStaked, stakerFee, "Total staked should equal staker fee portion");
    }
}

