// SPDX-License-Identifier: MIT

//  ____                 _       _                    _
// / ___|_ __   ___  ___(_)___  | |    __ _ _ __   __| |
//| |  _| '_ \ / _ \/ __| / __| | |   / _` | '_ \ / _` |
//| |_| | | | | (_) \__ \ \__ \ | |__| (_| | | | | (_| |
// \____|_| |_|\___/|___/_|___/ |_____\__,_|_| |_|\__,_|

pragma solidity ^0.8.13;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";

/**
 * @title EscrowNFT
 * @dev NFT contract for referral codes
 * @notice Each NFT represents a referral code containing the referrer's address
 */
contract EscrowNFT is ERC721, Ownable, Initializable, UUPSUpgradeable {
    //-----------------------Storage Variables-----------------------------------------
    uint256 private _nextTokenId;
    mapping(uint256 => address) private _referrerAddress; // tokenId => referrer address
    mapping(address => uint256) private _userReferralCode; // user => tokenId (their referral code)
    mapping(bytes32 => uint256) private _codeToTokenId; // referral code hash => tokenId

    //-----------------------custom errors-----------------------------------------
    error referralCodeAlreadyExists();
    error invalidReferralCode();
    error zeroAddress();

    //-----------------------events-----------------------------------------
    event ReferralCodeCreated(address indexed creator, uint256 indexed tokenId, bytes32 referralCode);
    event ReferralCodeUsed(address indexed referrer, address indexed referred, uint256 indexed tokenId);

    //-----------------------constructor (disabled for upgradeable)-----------------------------------------
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() ERC721("Escrow Referral", "EREF") Ownable(address(this)) {
        _disableInitializers();
    }

    //-----------------------initializer-----------------------------------------
    /**
     * @notice Initializes the EscrowNFT contract
     * @dev Called once when the proxy is deployed. Sets the initial owner.
     * @param initialOwner Address of the initial owner
     */
    function initialize(address initialOwner) external initializer {
        _transferOwnership(initialOwner);
        // Start tokenId at 1 to avoid conflict with sentinel value 0 in validateReferralCode
        _nextTokenId = 1;
    }

    //-----------------------UUPS authorization-----------------------------------------
    /**
     * @notice Authorizes contract upgrades
     * @dev Only the owner can authorize upgrades. This is required by UUPS pattern.
     * @param newImplementation Address of the new implementation contract
     */
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    //-----------------------public view functions-----------------------------------------
    function nextTokenId() public view returns (uint256) {
        return _nextTokenId;
    }

    function referrerAddress(uint256 tokenId) public view returns (address) {
        return _referrerAddress[tokenId];
    }

    function userReferralCode(address user) public view returns (uint256) {
        return _userReferralCode[user];
    }

    /**
     * @notice Gets the referral code for a token ID
     * @dev Returns the referral code hash for a given NFT token ID
     * @param tokenId The NFT token ID
     * @return referralCode The referral code (bytes32 hash of tokenId and referrer address)
     * @custom:reverts invalidReferralCode If tokenId doesn't exist or referrer is address(0)
     */
    function getReferralCode(uint256 tokenId) public view returns (bytes32) {
        address referrer = _referrerAddress[tokenId];
        if (referrer == address(0)) {
            revert invalidReferralCode();
        }
        // Referral code is keccak256 of tokenId and referrer address
        return keccak256(abi.encodePacked(tokenId, referrer));
    }

    /**
     * @notice Validates referral code and returns referrer
     * @dev Looks up referral code and returns the referrer address and token ID
     * @param referralCode The referral code to validate (bytes32 hash)
     * @return referrer Address of the referrer (address(0) if invalid)
     * @return tokenId Token ID of the referral NFT (0 if invalid)
     * @custom:reverts invalidReferralCode If referral code doesn't exist or referrer is address(0)
     */
    function validateReferralCode(bytes32 referralCode) public view returns (address referrer, uint256 tokenId) {
        tokenId = _codeToTokenId[referralCode];
        if (tokenId == 0) {
            revert invalidReferralCode();
        }
        referrer = _referrerAddress[tokenId];
        if (referrer == address(0)) {
            revert invalidReferralCode();
        }
    }

    //-----------------------external functions-----------------------------------------
    /**
     * @notice Creates a referral code NFT
     * @dev Mints an NFT to the caller and generates a unique referral code. Each user can only have one referral code.
     * @param referrer Address that will receive referral rewards (can be caller or different address)
     * @return tokenId The created NFT token ID
     * @return referralCode The generated referral code (bytes32 hash)
     * @custom:reverts zeroAddress If referrer is address(0)
     * @custom:reverts referralCodeAlreadyExists If caller already has a referral code
     * @custom:emits ReferralCodeCreated When referral code is created
     */
    function createReferralCode(address referrer) external returns (uint256 tokenId, bytes32 referralCode) {
        if (referrer == address(0)) {
            revert zeroAddress();
        }

        // Check if user already has a referral code
        if (_userReferralCode[msg.sender] != 0) {
            revert referralCodeAlreadyExists();
        }

        // Mint NFT to creator
        tokenId = _nextTokenId;
        _nextTokenId++;
        _safeMint(msg.sender, tokenId);

        // Store referrer address
        _referrerAddress[tokenId] = referrer;
        _userReferralCode[msg.sender] = tokenId;

        // Generate and store referral code
        referralCode = keccak256(abi.encodePacked(tokenId, referrer));
        _codeToTokenId[referralCode] = tokenId;

        emit ReferralCodeCreated(msg.sender, tokenId, referralCode);
    }

    /**
     * @notice Uses a referral code (called when someone purchases with referral)
     * @dev Validates referral code and emits event. Should be called by LessonNFT.
     * @param referralCode The referral code to use
     * @param referred Address of the person being referred (buyer)
     * @custom:reverts invalidReferralCode If referral code is invalid
     * @custom:emits ReferralCodeUsed When referral code is used
     */
    function useReferralCode(bytes32 referralCode, address referred) external {
        // Verify caller is authorized (should be LessonNFT)
        // In production, add access control

        (address referrer, uint256 tokenId) = validateReferralCode(referralCode);

        emit ReferralCodeUsed(referrer, referred, tokenId);
    }
}

