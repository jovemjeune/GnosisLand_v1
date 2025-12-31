// SPDX-License-Identifier: MIT

//  ____                 _       _                    _
// / ___|_ __   ___  ___(_)___  | |    __ _ _ __   __| |
//| |  _| '_ \ / _ \/ __| / __| | |   / _` | '_ \ / _` |
//| |_| | | | | (_) \__ \ \__ \ | |__| (_| | | | | (_| |
// \____|_| |_|\___/|___/_|___/ |_____\__,_|_| |_|\__,_|

pragma solidity ^0.8.13;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import {StorageSlot} from "@openzeppelin/contracts/utils/StorageSlot.sol";
import {SlotDerivation} from "@openzeppelin/contracts/utils/SlotDerivation.sol";

pragma solidity ^0.8.13;

contract DiscountBallot is Ownable, Initializable, UUPSUpgradeable {
    using StorageSlot for *;
    using SlotDerivation for *;

    //-----------------------ERC7201 Namespace Storage-----------------------------------------
    /**
     * @dev Storage of the DiscountBallot contract.
     * @custom:storage-location erc7201:gnosisland.storage.DiscountBallot
     */
    struct DiscountBallotStorage {
        uint256 votingPeriod;
        uint256 minimumDepositPerVote;
        address[] officialList;
        uint256 latestBallotId;
        address payable treasury;
        mapping(address => bool) userVoted;
        mapping(uint256 => uint256) getOptionOneVotes; //10% discount;
        mapping(uint256 => uint256) getOptionTwoVotes; //25% discount;
        mapping(uint256 => uint256) getOptionThreeVotes; //50% discount;
        mapping(address => bool) isOfficial;
        mapping(uint256 => Proposal) proposal;
        mapping(uint256 => Votes) votes;
    }

    // keccak256(abi.encode(uint256(keccak256("gnosisland.storage.DiscountBallot")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant DISCOUNT_BALLOT_STORAGE_LOCATION =
        0x128c14ba4f23205bdb10400203da2c18c7dcd45b0d972dbf23202bb2496a5200;

    function _getDiscountBallotStorage() private pure returns (DiscountBallotStorage storage $) {
        assembly ("memory-safe") {
            $.slot := DISCOUNT_BALLOT_STORAGE_LOCATION
        }
    }

    //-----------------------constants-----------------------------------------
    uint256 public constant VOTING_PERIOD = 1 days;

    //-----------------------custom errors-----------------------------------------
    error numberIsTooBig();
    error zeroAddress();
    error ballotDoesNotExistOrCompleted();
    error callerIsNotTeamMember();
    error paymentIsLowerThenMinimumPaymentAmount();
    error userAlreadyVoted();
    error invalidDiscountOption();

    //-----------------------enum-----------------------------------------
    enum Discounts {
        PENDING, //Default Option to use in proposal creation
        OPTION_ONE, //10% discount;
        OPTION_TWO, //25% discount;
        OPTION_THREE //50% discount;
    }

    //-----------------------structs-----------------------------------------
    struct Proposal {
        uint256 proposalId;
        uint256 discountPrice;
        address proposalOwner;
        Discounts winnerOption;
        bool finished;
    }

    struct Votes {
        uint256 voteAmountForOptionOne;
        uint256 voteAmountForOptionTwo;
        uint256 voteAmountForOptionThree;
    }

    //-----------------------constructor (disabled for upgradeable)-----------------------------------------
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() Ownable(address(this)) {
        _disableInitializers();
    }

    //-----------------------initializer-----------------------------------------
    function initialize(uint256 _minimumDepositPerVote, address initialOwner) external initializer {
        DiscountBallotStorage storage $ = _getDiscountBallotStorage();
        _transferOwnership(initialOwner);
        $.isOfficial[initialOwner] = true; //Owner is from Gnosisland team by default
        $.minimumDepositPerVote = _minimumDepositPerVote;
    }

    //-----------------------UUPS authorization-----------------------------------------
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    //-----------------------public view functions-----------------------------------------
    function minimumDepositPerVote() public view returns (uint256) {
        DiscountBallotStorage storage $ = _getDiscountBallotStorage();
        return $.minimumDepositPerVote;
    }

    function officialList(uint256 index) public view returns (address) {
        DiscountBallotStorage storage $ = _getDiscountBallotStorage();
        return $.officialList[index];
    }

    function latestBallotId() public view returns (uint256) {
        DiscountBallotStorage storage $ = _getDiscountBallotStorage();
        return $.latestBallotId;
    }

    function treasury() public view returns (address payable) {
        DiscountBallotStorage storage $ = _getDiscountBallotStorage();
        return $.treasury;
    }

    function userVoted(address user) public view returns (bool) {
        DiscountBallotStorage storage $ = _getDiscountBallotStorage();
        return $.userVoted[user];
    }

    function getOptionOneVotes(uint256 ballotId) public view returns (uint256) {
        DiscountBallotStorage storage $ = _getDiscountBallotStorage();
        return $.getOptionOneVotes[ballotId];
    }

    function getOptionTwoVotes(uint256 ballotId) public view returns (uint256) {
        DiscountBallotStorage storage $ = _getDiscountBallotStorage();
        return $.getOptionTwoVotes[ballotId];
    }

    function getOptionThreeVotes(uint256 ballotId) public view returns (uint256) {
        DiscountBallotStorage storage $ = _getDiscountBallotStorage();
        return $.getOptionThreeVotes[ballotId];
    }

    function isOfficial(address official) public view returns (bool) {
        DiscountBallotStorage storage $ = _getDiscountBallotStorage();
        return $.isOfficial[official];
    }

    function proposal(uint256 proposalId) public view returns (Proposal memory) {
        DiscountBallotStorage storage $ = _getDiscountBallotStorage();
        return $.proposal[proposalId];
    }

    function votes(uint256 ballotId) public view returns (Votes memory) {
        DiscountBallotStorage storage $ = _getDiscountBallotStorage();
        return $.votes[ballotId];
    }

    //-----------------------public functions-----------------------------------------

    function withdrawToTreasury() public {
        DiscountBallotStorage storage $ = _getDiscountBallotStorage();
        if (!$.isOfficial[msg.sender]) {
            revert callerIsNotTeamMember();
        }
        (bool success,) = $.treasury.call{value: address(this).balance}("");
        require(success, "Withdrawal call failed");
    }

    function updateTreasury(address _newTreasury) public onlyOwner {
        DiscountBallotStorage storage $ = _getDiscountBallotStorage();
        if (_newTreasury == address(0)) {
            revert zeroAddress();
        }
        $.treasury = payable(_newTreasury);
    }

    function emergencyWithdraw(address to) public onlyOwner {
        if (to == address(0)) revert zeroAddress();
        (bool success,) = payable(to).call{value: address(this).balance}("");
        require(success, "Withdrawal call failed");
    }

    //-----------------------external functions-----------------------------------------

    function createProposal(uint256 discountPrice, address proposalOwner) external returns (uint256) {
        DiscountBallotStorage storage $ = _getDiscountBallotStorage();

        if (proposalOwner == address(0)) {
            revert zeroAddress();
        }

        $.latestBallotId++;
        uint256 proposalId = $.latestBallotId;

        $.proposal[proposalId] = Proposal({
            proposalId: proposalId,
            discountPrice: discountPrice,
            proposalOwner: proposalOwner,
            winnerOption: Discounts.PENDING,
            finished: false
        });

        return proposalId;
    }

    function vote(uint256 proposalId, Discounts option) external payable {
        DiscountBallotStorage storage $ = _getDiscountBallotStorage();

        // Check if proposal exists and is not finished
        if ($.proposal[proposalId].proposalId == 0 || $.proposal[proposalId].finished) {
            revert ballotDoesNotExistOrCompleted();
        }

        // Check if minimum deposit is met
        if (msg.value < $.minimumDepositPerVote) {
            revert paymentIsLowerThenMinimumPaymentAmount();
        }

        // Check if user has already voted
        if ($.userVoted[msg.sender]) {
            revert userAlreadyVoted();
        }

        // Validate option is one of the three valid options
        if (option == Discounts.PENDING || uint256(option) > uint256(Discounts.OPTION_THREE)) {
            revert invalidDiscountOption();
        }

        // Mark user as voted
        $.userVoted[msg.sender] = true;

        // Update vote counts based on option
        if (option == Discounts.OPTION_ONE) {
            $.getOptionOneVotes[proposalId] += msg.value;
            $.votes[proposalId].voteAmountForOptionOne += msg.value;
        } else if (option == Discounts.OPTION_TWO) {
            $.getOptionTwoVotes[proposalId] += msg.value;
            $.votes[proposalId].voteAmountForOptionTwo += msg.value;
        } else {
            $.getOptionThreeVotes[proposalId] += msg.value;
            $.votes[proposalId].voteAmountForOptionThree += msg.value;
        }
    }

    //-----------------------view functions-----------------------------------------
    function getMinimumDepositAmount() external view returns (uint256) {
        DiscountBallotStorage storage $ = _getDiscountBallotStorage();
        return $.minimumDepositPerVote;
    }
}
