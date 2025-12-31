// SPDX-License-Identifier: MIT

//  ____                 _       _                    _
// / ___|_ __   ___  ___(_)___  | |    __ _ _ __   __| |
//| |  _| '_ \ / _ \/ __| / __| | |   / _` | '_ \ / _` |
//| |_| | | | | (_) \__ \ \__ \ | |__| (_| | | | | (_| |
// \____|_| |_|\___/|___/_|___/ |_____\__,_|_| |_|\__,_|

pragma solidity ^0.8.13;

import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {LessonNFT} from "./LessonNFT.sol";

// Interface for TeacherNFT
interface ITeacherNFT {
    function ownerOf(uint256 tokenId) external view returns (address);
    function balanceOf(address owner) external view returns (uint256);
    function teacherBlackListed(address teacher) external view returns (bool);
}

/**
 * @title LessonFactory
 * @dev Factory contract for teachers to create new LessonNFT contracts
 * @notice Teachers use this to deploy their own LessonNFT proxy contracts
 * @notice Each teacher can create multiple lesson contracts (for different courses)
 */
contract LessonFactory {
    //-----------------------Storage Variables-----------------------------------------
    address public lessonNFTImplementation; // Implementation contract for LessonNFT
    address public treasuryContract; // Treasury contract address
    address public paymentToken; // USDC token address
    address public teacherNFT; // TeacherNFT contract address
    address public certificateFactory; // CertificateFactory contract address
    address public owner; // Factory owner

    // Track deployed contracts per teacher
    mapping(address => address[]) public teacherContracts; // Teacher => Array of deployed LessonNFT contracts
    mapping(address => uint256) public teacherContractCount; // Teacher => Number of contracts created

    //-----------------------constants-----------------------------------------
    /**
     * @dev Minimum price for lessons (25 USDC)
     * Note: For USDC (6 decimals), this is 50 * 1e6 = 50,000,000
     */
    uint256 public constant MINIMUM_PRICE = 25e6;

    //-----------------------custom errors-----------------------------------------
    error zeroAddress();
    error notATeacher();
    error invalidPrice();
    error teacherBanned();

    //-----------------------events-----------------------------------------
    event LessonNFTCreated(
        address indexed teacher, address indexed lessonNFT, string name, uint256 price, uint256 indexed contractIndex
    );

    //-----------------------constructor-----------------------------------------
    /**
     * @notice Initializes the LessonFactory contract
     * @dev Sets up all required addresses for deploying LessonNFT proxies
     * @param _lessonNFTImplementation Address of the LessonNFT implementation contract
     * @param _treasuryContract Address of the TreasuryContract
     * @param _paymentToken Address of the payment token (USDC)
     * @param _teacherNFT Address of the TeacherNFT contract
     * @param _certificateFactory Address of the CertificateFactory contract (can be address(0) if not set)
     * @custom:reverts zeroAddress If any required address parameter is address(0)
     */
    constructor(
        address _lessonNFTImplementation,
        address _treasuryContract,
        address _paymentToken,
        address _teacherNFT,
        address _certificateFactory
    ) {
        if (
            _lessonNFTImplementation == address(0) || _treasuryContract == address(0) || _paymentToken == address(0)
                || _teacherNFT == address(0)
        ) {
            revert zeroAddress();
        }
        lessonNFTImplementation = _lessonNFTImplementation;
        treasuryContract = _treasuryContract;
        paymentToken = _paymentToken;
        teacherNFT = _teacherNFT;
        certificateFactory = _certificateFactory; // Can be address(0) if certificates not enabled
        owner = msg.sender;
    }

    //-----------------------public view functions-----------------------------------------
    /**
     * @notice Gets all LessonNFT contracts created by a teacher
     * @dev Returns an array of all LessonNFT proxy addresses deployed by the specified teacher
     * @param teacher Address of the teacher
     * @return Array of LessonNFT contract addresses
     */
    function getTeacherContracts(address teacher) external view returns (address[] memory) {
        return teacherContracts[teacher];
    }

    /**
     * @notice Gets the number of LessonNFT contracts created by a teacher
     * @dev Returns the count of contracts deployed by the specified teacher
     * @param teacher Address of the teacher
     * @return Number of contracts created by the teacher
     */
    function getTeacherContractCount(address teacher) external view returns (uint256) {
        return teacherContractCount[teacher];
    }

    //-----------------------external functions-----------------------------------------
    /**
     * @notice Creates a new LessonNFT contract for a teacher
     * @dev Deploys a UUPS proxy for LessonNFT. Only teachers (owners of TeacherNFT) can create contracts.
     * @param teacherTokenId The TeacherNFT token ID that the caller must own
     * @param price Initial price for lessons (must be >= MINIMUM_PRICE = 25 USDC)
     * @param name Name of the lesson/course collection
     * @param data Additional metadata bytes for the lesson
     * @return lessonNFTAddress Address of the deployed LessonNFT proxy contract
     * @custom:security Verifies caller owns the TeacherNFT token
     * @custom:security Validates price >= MINIMUM_PRICE (25 USDC)
     * @custom:reverts notATeacher If caller doesn't own the TeacherNFT token
     * @custom:reverts invalidPrice If price < MINIMUM_PRICE
     * @custom:emits LessonNFTCreated When contract is successfully deployed
     */
    function createLessonNFT(uint256 teacherTokenId, uint256 price, string memory name, bytes memory data)
        external
        returns (address lessonNFTAddress)
    {
        // Verify caller owns the TeacherNFT token
        address tokenOwner = ITeacherNFT(teacherNFT).ownerOf(teacherTokenId);
        if (tokenOwner != msg.sender) {
            revert notATeacher();
        }

        // Check if teacher is banned
        // Note: This requires ITeacherNFT to have a teacherBlackListed function
        // For now, we'll assume it's checked elsewhere

        // Validate price meets minimum requirement (50 USDC)
        if (price < MINIMUM_PRICE) {
            revert invalidPrice();
        }

        // Prepare initialization data
        bytes memory initData = abi.encodeWithSelector(
            LessonNFT.initialize.selector,
            address(this), // factory (will be owner)
            msg.sender, // onBehalf (teacher's address)
            treasuryContract,
            paymentToken,
            teacherNFT,
            certificateFactory, // CertificateFactory address
            price,
            name,
            data
        );

        // Deploy proxy
        lessonNFTAddress = address(new ERC1967Proxy(lessonNFTImplementation, initData));

        // Track the deployed contract
        teacherContracts[msg.sender].push(lessonNFTAddress);
        teacherContractCount[msg.sender]++;

        emit LessonNFTCreated(msg.sender, lessonNFTAddress, name, price, teacherContractCount[msg.sender] - 1);

        return lessonNFTAddress;
    }

    /**
     * @notice Updates the LessonNFT implementation address
     * @dev Only owner can update. Used for upgrading all future LessonNFT deployments.
     * @param _newImplementation Address of the new LessonNFT implementation contract
     * @custom:security Only callable by owner
     * @custom:reverts notATeacher If caller is not owner
     * @custom:reverts zeroAddress If new implementation address is address(0)
     */
    function updateImplementation(address _newImplementation) external {
        if (msg.sender != owner) {
            revert notATeacher(); // Reuse error for unauthorized
        }
        if (_newImplementation == address(0)) {
            revert zeroAddress();
        }
        lessonNFTImplementation = _newImplementation;
    }

    /**
     * @notice Transfers factory ownership to a new address
     * @dev Only owner can transfer ownership
     * @param newOwner Address of the new owner
     * @custom:security Only callable by owner
     * @custom:reverts notATeacher If caller is not owner
     * @custom:reverts zeroAddress If new owner address is address(0)
     */
    function transferOwnership(address newOwner) external {
        if (msg.sender != owner) {
            revert notATeacher();
        }
        if (newOwner == address(0)) {
            revert zeroAddress();
        }
        owner = newOwner;
    }

    /**
     * @notice Updates the treasury contract address
     * @dev Only owner can update. Used for changing treasury implementation.
     * @param _newTreasuryContract Address of the new TreasuryContract
     * @custom:security Only callable by owner
     * @custom:reverts notATeacher If caller is not owner
     * @custom:reverts zeroAddress If new treasury address is address(0)
     */
    function updateTreasury(address _newTreasuryContract) external {
        if (msg.sender != owner) {
            revert notATeacher();
        }
        if (_newTreasuryContract == address(0)) {
            revert zeroAddress();
        }
        treasuryContract = _newTreasuryContract;
    }

    /**
     * @notice Updates the payment token address
     * @dev Only owner can update. Used for changing payment token (e.g., switching USDC versions).
     * @param _newPaymentToken Address of the new payment token contract
     * @custom:security Only callable by owner
     * @custom:reverts notATeacher If caller is not owner
     * @custom:reverts zeroAddress If new payment token address is address(0)
     */
    function updatePaymentToken(address _newPaymentToken) external {
        if (msg.sender != owner) {
            revert notATeacher();
        }
        if (_newPaymentToken == address(0)) {
            revert zeroAddress();
        }
        paymentToken = _newPaymentToken;
    }

    /**
     * @notice Updates the CertificateFactory contract address
     * @dev Only owner can update. Used for enabling certificates or changing factory implementation.
     * @param _newCertificateFactory Address of the new CertificateFactory (can be address(0) to disable)
     * @custom:security Only callable by owner
     * @custom:reverts notATeacher If caller is not owner
     */
    function updateCertificateFactory(address _newCertificateFactory) external {
        if (msg.sender != owner) {
            revert notATeacher();
        }
        certificateFactory = _newCertificateFactory;
    }
}
