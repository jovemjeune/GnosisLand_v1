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

contract DiscountBallot is Ownable, Initializable, UUPSUpgradeable {
    //-----------------------Storage Variables-----------------------------------------
    uint256 public votingPeriod;
    uint256 public minimumDepositPerVote;
    address[] public officialList;
    uint256 public latestBallotId;
    address payable public treasury;
    mapping(address => bool) public userVoted;
    mapping(uint256 => uint256) public getOptionOneVotes; //10% discount;
    mapping(uint256 => uint256) public getOptionTwoVotes; //25% discount;
    mapping(uint256 => uint256) public getOptionThreeVotes; //50% discount;
    mapping(address => bool) public isOfficial;
    mapping(uint256 => Proposal) public proposal;
    mapping(uint256 => Votes) public votes;

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
        _transferOwnership(initialOwner);
        isOfficial[initialOwner] = true; //Owner is from Gnosisland team by default
        minimumDepositPerVote = _minimumDepositPerVote;
    }

    //-----------------------UUPS authorization-----------------------------------------
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    //-----------------------public view functions-----------------------------------------
    // Storage variables are already public, so getter functions are auto-generated
    // Only need custom getter for array indexing

    //-----------------------public functions-----------------------------------------

    function withdrawToTreasury() public {
        if (!isOfficial[msg.sender]) {
            revert callerIsNotTeamMember();
        }
        (bool success,) = treasury.call{value: address(this).balance}("");
        require(success, "Withdrawal call failed");
    }

    function updateTreasury(address _newTreasury) public onlyOwner {
        if (_newTreasury == address(0)) {
            revert zeroAddress();
        }
        treasury = payable(_newTreasury);
    }

    function emergencyWithdraw(address to) public onlyOwner {
        if (to == address(0)) revert zeroAddress();
        (bool success,) = payable(to).call{value: address(this).balance}("");
        require(success, "Withdrawal call failed");
    }

    //-----------------------external functions-----------------------------------------

    function createProposal(uint256 discountPrice, address proposalOwner) external returns (uint256) {
        if (proposalOwner == address(0)) {
            revert zeroAddress();
        }

        latestBallotId++;
        uint256 proposalId = latestBallotId;

        proposal[proposalId] = Proposal({
            proposalId: proposalId,
            discountPrice: discountPrice,
            proposalOwner: proposalOwner,
            winnerOption: Discounts.PENDING,
            finished: false
        });

        return proposalId;
    }

    function vote(uint256 proposalId, Discounts option) external payable {
        // Check if proposal exists and is not finished
        if (proposal[proposalId].proposalId == 0 || proposal[proposalId].finished) {
            revert ballotDoesNotExistOrCompleted();
        }

        // Check if minimum deposit is met
        if (msg.value < minimumDepositPerVote) {
            revert paymentIsLowerThenMinimumPaymentAmount();
        }

        // Check if user has already voted
        if (userVoted[msg.sender]) {
            revert userAlreadyVoted();
        }

        // Validate option is one of the three valid options
        if (option == Discounts.PENDING || uint256(option) > uint256(Discounts.OPTION_THREE)) {
            revert invalidDiscountOption();
        }

        // Mark user as voted
        userVoted[msg.sender] = true;

        // Update vote counts based on option
        if (option == Discounts.OPTION_ONE) {
            getOptionOneVotes[proposalId] += msg.value;
            votes[proposalId].voteAmountForOptionOne += msg.value;
        } else if (option == Discounts.OPTION_TWO) {
            getOptionTwoVotes[proposalId] += msg.value;
            votes[proposalId].voteAmountForOptionTwo += msg.value;
        } else {
            getOptionThreeVotes[proposalId] += msg.value;
            votes[proposalId].voteAmountForOptionThree += msg.value;
        }
    }

    //-----------------------view functions-----------------------------------------
    function getMinimumDepositAmount() external view returns (uint256) {
        return minimumDepositPerVote;
    }
}
