// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {DiscountBallot} from "../src/DiscountBallot.sol";
import {ProxyFactory} from "../src/proxies/ProxyFactory.sol";

contract DiscountBallotTest is Test {
    DiscountBallot public impl;
    DiscountBallot public db;
    ProxyFactory public factory;

    address owner = makeAddr("owner");
    address official1 = makeAddr("official1");
    address official2 = makeAddr("official2");
    address treasury = makeAddr("treasury");
    address user1 = makeAddr("user1");

    uint256 constant MINIMUM_DEPOSIT = 2e16; // 0.02 ETH

    function setUp() public {
        // Deploy implementation
        impl = new DiscountBallot();

        // Deploy factory
        factory = new ProxyFactory();

        // Deploy proxy through factory
        address proxyAddress = factory.deployDiscountBallotProxy(address(impl), MINIMUM_DEPOSIT, owner);

        db = DiscountBallot(proxyAddress);

        // Set treasury
        vm.prank(owner);
        db.updateTreasury(treasury);
    }

    // ============ Proxy Deployment Tests ============

    function test_ProxyDeployment() public {
        assertEq(db.owner(), owner);
        assertEq(db.minimumDepositPerVote(), MINIMUM_DEPOSIT);
        assertTrue(db.isOfficial(owner));
    }

    function test_ProxyImplementationSlot() public {
        bytes32 slot = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;
        address implementation = address(uint160(uint256(vm.load(address(db), slot))));
        assertEq(implementation, address(impl));
    }

    function test_CannotInitializeTwice() public {
        vm.expectRevert();
        db.initialize(MINIMUM_DEPOSIT, owner);
    }

    // ============ View Functions Tests ============

    function test_GetMinimumDepositAmount() public {
        assertEq(db.getMinimumDepositAmount(), MINIMUM_DEPOSIT);
    }

    function test_MinimumDepositPerVote() public {
        assertEq(db.minimumDepositPerVote(), MINIMUM_DEPOSIT);
    }

    function test_IsOfficial() public {
        assertTrue(db.isOfficial(owner));
        assertFalse(db.isOfficial(official1));
    }

    function test_Treasury() public {
        assertEq(db.treasury(), treasury);
    }

    function test_LatestBallotId() public {
        assertEq(db.latestBallotId(), 0);
    }

    function test_UserVoted() public {
        assertFalse(db.userVoted(user1));
    }

    function test_GetOptionVotes() public {
        assertEq(db.getOptionOneVotes(0), 0);
        assertEq(db.getOptionTwoVotes(0), 0);
        assertEq(db.getOptionThreeVotes(0), 0);
    }

    function test_Proposal() public {
        (
            uint256 proposalId,
            uint256 discountPrice,
            address proposalOwner,
            DiscountBallot.Discounts winnerOption,
            bool finished
        ) = db.proposal(0);
        assertEq(proposalId, 0);
        assertEq(discountPrice, 0);
        assertEq(proposalOwner, address(0));
        assertEq(uint256(winnerOption), 0); // PENDING
        assertFalse(finished);
    }

    function test_Votes() public {
        (uint256 voteAmountForOptionOne, uint256 voteAmountForOptionTwo, uint256 voteAmountForOptionThree) = db.votes(0);
        assertEq(voteAmountForOptionOne, 0);
        assertEq(voteAmountForOptionTwo, 0);
        assertEq(voteAmountForOptionThree, 0);
    }

    // ============ Treasury Update Tests ============

    function test_UpdateTreasury() public {
        address newTreasury = makeAddr("newTreasury");

        vm.prank(owner);
        db.updateTreasury(newTreasury);

        assertEq(db.treasury(), newTreasury);
    }

    function test_UpdateTreasury_ZeroAddress() public {
        vm.prank(owner);
        vm.expectRevert(DiscountBallot.zeroAddress.selector);
        db.updateTreasury(address(0));
    }

    function test_UpdateTreasury_OnlyOwner() public {
        vm.prank(user1);
        vm.expectRevert();
        db.updateTreasury(makeAddr("newTreasury"));
    }

    // ============ Withdraw Tests ============

    function test_WithdrawToTreasury() public {
        // Send ETH to contract
        vm.deal(address(db), 1 ether);

        uint256 treasuryBalanceBefore = treasury.balance;

        vm.prank(owner);
        db.withdrawToTreasury();

        uint256 treasuryBalanceAfter = treasury.balance;
        assertEq(treasuryBalanceAfter - treasuryBalanceBefore, 1 ether);
        assertEq(address(db).balance, 0);
    }

    function test_WithdrawToTreasury_OnlyOfficial() public {
        vm.deal(address(db), 1 ether);

        vm.prank(user1);
        vm.expectRevert(DiscountBallot.callerIsNotTeamMember.selector);
        db.withdrawToTreasury();
    }

    function test_EmergencyWithdraw() public {
        vm.deal(address(db), 1 ether);
        address recipient = makeAddr("recipient");

        uint256 recipientBalanceBefore = recipient.balance;

        vm.prank(owner);
        db.emergencyWithdraw(recipient);

        uint256 recipientBalanceAfter = recipient.balance;
        assertEq(recipientBalanceAfter - recipientBalanceBefore, 1 ether);
        assertEq(address(db).balance, 0);
    }

    function test_EmergencyWithdraw_ZeroAddress() public {
        vm.deal(address(db), 1 ether);

        vm.prank(owner);
        vm.expectRevert(DiscountBallot.zeroAddress.selector);
        db.emergencyWithdraw(address(0));
    }

    function test_EmergencyWithdraw_OnlyOwner() public {
        vm.deal(address(db), 1 ether);

        vm.prank(user1);
        vm.expectRevert();
        db.emergencyWithdraw(makeAddr("recipient"));
    }

    // ============ Constants Tests ============

    function test_VotingPeriod() public {
        assertEq(db.VOTING_PERIOD(), 1 days);
    }

    // ============ Upgrade Tests ============

    function test_Upgrade_OnlyOwner() public {
        DiscountBallot newImpl = new DiscountBallot();

        vm.prank(owner);
        db.upgradeToAndCall(address(newImpl), "");

        bytes32 slot = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;
        address implementation = address(uint160(uint256(vm.load(address(db), slot))));
        assertEq(implementation, address(newImpl));
    }

    function test_Upgrade_NonOwner() public {
        DiscountBallot newImpl = new DiscountBallot();

        vm.prank(user1);
        vm.expectRevert();
        db.upgradeToAndCall(address(newImpl), "");
    }

    function test_Upgrade_PreservesStorage() public {
        // Update treasury
        address newTreasury = makeAddr("newTreasury");
        vm.prank(owner);
        db.updateTreasury(newTreasury);

        // Upgrade
        DiscountBallot newImpl = new DiscountBallot();
        vm.prank(owner);
        db.upgradeToAndCall(address(newImpl), "");

        // Verify storage is preserved
        assertEq(db.minimumDepositPerVote(), MINIMUM_DEPOSIT);
        assertEq(db.treasury(), newTreasury);
        assertTrue(db.isOfficial(owner));
    }

    // ============ Vote Tests ============

    function test_CreateProposal() public {
        uint256 discountPrice = 50e6; // 50 USDC
        uint256 proposalId = db.createProposal(discountPrice, owner);

        assertEq(proposalId, 1);
        assertEq(db.latestBallotId(), 1);

        (
            uint256 propId,
            uint256 propDiscountPrice,
            address propOwner,
            DiscountBallot.Discounts propWinnerOption,
            bool propFinished
        ) = db.proposal(proposalId);
        assertEq(propId, proposalId);
        assertEq(propDiscountPrice, discountPrice);
        assertEq(propOwner, owner);
        assertEq(uint256(propWinnerOption), uint256(DiscountBallot.Discounts.PENDING));
        assertFalse(propFinished);
    }

    function test_Vote_OptionOne() public {
        uint256 discountPrice = 50e6;
        uint256 proposalId = db.createProposal(discountPrice, owner);
        uint256 voteAmount = MINIMUM_DEPOSIT;

        vm.deal(user1, 1 ether);
        vm.prank(user1);
        db.vote{value: voteAmount}(proposalId, DiscountBallot.Discounts.OPTION_ONE);

        assertTrue(db.userVoted(user1));
        assertEq(db.getOptionOneVotes(proposalId), voteAmount);
        (uint256 voteOne, uint256 voteTwo, uint256 voteThree) = db.votes(proposalId);
        assertEq(voteOne, voteAmount);
        assertEq(voteTwo, 0);
        assertEq(voteThree, 0);
        assertEq(address(db).balance, voteAmount);
    }

    function test_Vote_OptionTwo() public {
        uint256 discountPrice = 50e6;
        uint256 proposalId = db.createProposal(discountPrice, owner);
        uint256 voteAmount = MINIMUM_DEPOSIT * 2;

        vm.deal(user1, 1 ether);
        vm.prank(user1);
        db.vote{value: voteAmount}(proposalId, DiscountBallot.Discounts.OPTION_TWO);

        assertTrue(db.userVoted(user1));
        assertEq(db.getOptionTwoVotes(proposalId), voteAmount);
        (uint256 voteOne, uint256 voteTwo, uint256 voteThree) = db.votes(proposalId);
        assertEq(voteTwo, voteAmount);
    }

    function test_Vote_OptionThree() public {
        uint256 discountPrice = 50e6;
        uint256 proposalId = db.createProposal(discountPrice, owner);
        uint256 voteAmount = MINIMUM_DEPOSIT * 3;

        vm.deal(user1, 1 ether);
        vm.prank(user1);
        db.vote{value: voteAmount}(proposalId, DiscountBallot.Discounts.OPTION_THREE);

        assertTrue(db.userVoted(user1));
        assertEq(db.getOptionThreeVotes(proposalId), voteAmount);
        (uint256 voteOne, uint256 voteTwo, uint256 voteThree) = db.votes(proposalId);
        assertEq(voteThree, voteAmount);
    }

    function test_Vote_MultipleUsers() public {
        uint256 discountPrice = 50e6;
        uint256 proposalId = db.createProposal(discountPrice, owner);
        uint256 voteAmount1 = MINIMUM_DEPOSIT;
        uint256 voteAmount2 = MINIMUM_DEPOSIT * 2;

        address user2 = makeAddr("user2");

        vm.deal(user1, 1 ether);
        vm.deal(user2, 1 ether);

        vm.prank(user1);
        db.vote{value: voteAmount1}(proposalId, DiscountBallot.Discounts.OPTION_ONE);

        vm.prank(user2);
        db.vote{value: voteAmount2}(proposalId, DiscountBallot.Discounts.OPTION_TWO);

        assertEq(db.getOptionOneVotes(proposalId), voteAmount1);
        assertEq(db.getOptionTwoVotes(proposalId), voteAmount2);
        (uint256 voteOne, uint256 voteTwo, uint256 voteThree) = db.votes(proposalId);
        assertEq(voteOne, voteAmount1);
        assertEq(voteTwo, voteAmount2);
    }

    function test_Vote_NonExistentProposal() public {
        uint256 proposalId = 999;
        uint256 voteAmount = MINIMUM_DEPOSIT;

        vm.deal(user1, 1 ether);
        vm.prank(user1);
        vm.expectRevert(DiscountBallot.ballotDoesNotExistOrCompleted.selector);
        db.vote{value: voteAmount}(proposalId, DiscountBallot.Discounts.OPTION_ONE);
    }

    function test_Vote_InsufficientPayment() public {
        uint256 discountPrice = 50e6;
        uint256 proposalId = db.createProposal(discountPrice, owner);
        uint256 insufficientAmount = MINIMUM_DEPOSIT - 1;

        vm.deal(user1, 1 ether);
        vm.prank(user1);
        vm.expectRevert(DiscountBallot.paymentIsLowerThenMinimumPaymentAmount.selector);
        db.vote{value: insufficientAmount}(proposalId, DiscountBallot.Discounts.OPTION_ONE);
    }

    function test_Vote_InvalidOption() public {
        uint256 discountPrice = 50e6;
        uint256 proposalId = db.createProposal(discountPrice, owner);
        uint256 voteAmount = MINIMUM_DEPOSIT;

        vm.deal(user1, 1 ether);
        vm.prank(user1);
        vm.expectRevert(DiscountBallot.invalidDiscountOption.selector);
        db.vote{value: voteAmount}(proposalId, DiscountBallot.Discounts.PENDING);
    }

    function test_Vote_UserAlreadyVoted() public {
        uint256 discountPrice = 50e6;
        uint256 proposalId = db.createProposal(discountPrice, owner);
        uint256 voteAmount = MINIMUM_DEPOSIT;

        vm.deal(user1, 1 ether);
        vm.prank(user1);
        db.vote{value: voteAmount}(proposalId, DiscountBallot.Discounts.OPTION_ONE);

        vm.deal(user1, 1 ether);
        vm.prank(user1);
        vm.expectRevert(DiscountBallot.userAlreadyVoted.selector);
        db.vote{value: voteAmount}(proposalId, DiscountBallot.Discounts.OPTION_TWO);
    }
}
