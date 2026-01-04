// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {TeacherNft} from "../src/TeacherNFT.sol";
import {ProxyFactory} from "../src/proxies/ProxyFactory.sol";

contract TeacherNFTTest is Test {
    TeacherNft public impl;
    TeacherNft public nft;
    ProxyFactory public factory;

    address owner = makeAddr("owner");
    address teacher1 = makeAddr("teacher1");
    address teacher2 = makeAddr("teacher2");

    string constant NAME = "Teacher NFT";
    string constant SYMBOL = "TCHR";
    bytes constant DATA = "teacher data";

    function setUp() public {
        // Deploy implementation
        impl = new TeacherNft();

        // Deploy factory
        factory = new ProxyFactory();

        // Deploy proxy through factory
        address proxyAddress = factory.deployTeacherNFTProxy(address(impl), NAME, SYMBOL, owner);

        nft = TeacherNft(proxyAddress);
    }

    // ============ Proxy Deployment Tests ============

    function test_ProxyDeployment() public {
        assertEq(nft.owner(), owner);
        assertEq(nft.name(), NAME);
        assertEq(nft.symbol(), SYMBOL);
    }

    function test_ProxyImplementationSlot() public {
        bytes32 slot = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;
        address implementation = address(uint160(uint256(vm.load(address(nft), slot))));
        assertEq(implementation, address(impl));
    }

    function test_CannotInitializeTwice() public {
        vm.expectRevert();
        nft.initialize(NAME, SYMBOL, owner);
    }

    // ============ Mint Teacher NFT Tests ============

    function test_MintTeacherNFT() public {
        vm.prank(owner);
        nft.mintTeacherNFT(teacher1, "Teacher Name", DATA);

        assertEq(nft.balanceOf(teacher1), 1);
        assertEq(nft.ownerOf(0), teacher1);
        assertEq(nft.getLatestTokenId(), 1);
        assertTrue(nft.nftCreated(teacher1));
    }

    function test_MintTeacherNFT_OnlyOwner() public {
        vm.prank(teacher1);
        vm.expectRevert();
        nft.mintTeacherNFT(teacher1, "Teacher Name", DATA);
    }

    function test_MintTeacherNFT_AlreadyOwnsNFT() public {
        vm.startPrank(owner);
        nft.mintTeacherNFT(teacher1, "Teacher Name", DATA);

        vm.expectRevert(TeacherNft.accountAlreadyOwnsNFT.selector);
        nft.mintTeacherNFT(teacher1, "Teacher Name 2", DATA);
        vm.stopPrank();
    }

    function test_MintMultipleTeacherNFTs() public {
        vm.startPrank(owner);
        nft.mintTeacherNFT(teacher1, "Teacher 1", DATA);
        nft.mintTeacherNFT(teacher2, "Teacher 2", DATA);
        vm.stopPrank();

        assertEq(nft.balanceOf(teacher1), 1);
        assertEq(nft.balanceOf(teacher2), 1);
        assertEq(nft.getLatestTokenId(), 2);
        assertTrue(nft.nftCreated(teacher1));
        assertTrue(nft.nftCreated(teacher2));
    }

    // ============ Ban Teacher Tests ============

    function test_BanTeacher() public {
        vm.startPrank(owner);
        nft.mintTeacherNFT(teacher1, "Teacher Name", DATA);
        nft.banTeacher(teacher1);
        vm.stopPrank();

        assertTrue(nft.teacherBlackListed(teacher1));
    }

    function test_BanTeacher_OnlyOwner() public {
        vm.prank(teacher1);
        vm.expectRevert();
        nft.banTeacher(teacher1);
    }

    function test_BanTeacher_CannotTransfer() public {
        vm.startPrank(owner);
        nft.mintTeacherNFT(teacher1, "Teacher Name", DATA);
        nft.banTeacher(teacher1);
        vm.stopPrank();

        // Try to transfer (should fail)
        vm.prank(teacher1);
        vm.expectRevert(TeacherNft.teacherBanned.selector);
        nft.transferFrom(teacher1, teacher2, 0);
    }

    function test_BanTeacher_CannotReceive() public {
        vm.startPrank(owner);
        nft.mintTeacherNFT(teacher1, "Teacher Name", DATA);
        nft.mintTeacherNFT(teacher2, "Teacher Name 2", DATA);
        nft.banTeacher(teacher2);
        vm.stopPrank();

        // Try to transfer to banned teacher (should fail)
        vm.prank(teacher1);
        vm.expectRevert(TeacherNft.teacherBanned.selector);
        nft.transferFrom(teacher1, teacher2, 0);
    }

    // ============ View Functions Tests ============

    function test_GetLatestTokenId() public {
        assertEq(nft.getLatestTokenId(), 0);

        vm.prank(owner);
        nft.mintTeacherNFT(teacher1, "Teacher Name", DATA);

        assertEq(nft.getLatestTokenId(), 1);
    }

    function test_NftCreated() public {
        assertFalse(nft.nftCreated(teacher1));

        vm.prank(owner);
        nft.mintTeacherNFT(teacher1, "Teacher Name", DATA);

        assertTrue(nft.nftCreated(teacher1));
    }

    function test_TeacherBlackListed() public {
        assertFalse(nft.teacherBlackListed(teacher1));

        vm.prank(owner);
        nft.banTeacher(teacher1);

        assertTrue(nft.teacherBlackListed(teacher1));
    }

    // ============ Upgrade Tests ============

    function test_Upgrade_OnlyOwner() public {
        TeacherNft newImpl = new TeacherNft();

        vm.prank(owner);
        nft.upgradeToAndCall(address(newImpl), "");

        bytes32 slot = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;
        address implementation = address(uint160(uint256(vm.load(address(nft), slot))));
        assertEq(implementation, address(newImpl));
    }

    function test_Upgrade_NonOwner() public {
        TeacherNft newImpl = new TeacherNft();

        vm.prank(teacher1);
        vm.expectRevert();
        nft.upgradeToAndCall(address(newImpl), "");
    }

    function test_Upgrade_PreservesStorage() public {
        // Mint NFT
        vm.prank(owner);
        nft.mintTeacherNFT(teacher1, "Teacher Name", DATA);

        // Ban teacher
        vm.prank(owner);
        nft.banTeacher(teacher1);

        // Upgrade
        TeacherNft newImpl = new TeacherNft();
        vm.prank(owner);
        nft.upgradeToAndCall(address(newImpl), "");

        // Verify storage is preserved
        assertEq(nft.getLatestTokenId(), 1);
        assertEq(nft.balanceOf(teacher1), 1);
        assertTrue(nft.nftCreated(teacher1));
        assertTrue(nft.teacherBlackListed(teacher1));
    }
}

