// SPDX-License-Identifier: MIT

//  ____                 _       _                    _ 
// / ___|_ __   ___  ___(_)___  | |    __ _ _ __   __| |
//| |  _| '_ \ / _ \/ __| / __| | |   / _` | '_ \ / _` |
//| |_| | | | | (_) \__ \ \__ \ | |__| (_| | | | | (_| |
// \____|_| |_|\___/|___/_|___/ |_____\__,_|_| |_|\__,_|
     
pragma solidity ^0.8.13;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title CertificateNFT
 * @dev Soulbound ERC721 NFT for course completion certificates
 * @notice Each teacher has their own CertificateNFT contract with custom metadata
 * @notice Certificates are one-time mintable per lesson, only by LessonNFT
 */
contract CertificateNFT is ERC721, Ownable {
    //-----------------------Storage Variables-----------------------------------------
    address public lessonNFT; // Only LessonNFT can mint certificates
    address public teacher; // Teacher who owns this certificate contract
    string public baseMetadataURI; // Base URI for certificate metadata (optional)
    
    // One-time mint tracking per lesson
    mapping(uint256 => bool) public lessonFinished; // lessonId => already minted
    mapping(uint256 => address) public lessonToStudent; // lessonId => student address
    mapping(uint256 => string) public lessonMetadata; // lessonId => custom metadata (if provided)
    
    uint256 private _tokenIdCounter; // Internal counter for token IDs
    
    //-----------------------custom errors-----------------------------------------
    error onlyLessonNFT(); // Only LessonNFT can mint
    error alreadyMinted(); // Certificate already minted for this lesson
    error zeroAddress();
    
    //-----------------------events-----------------------------------------
    event CertificateMinted(
        address indexed student,
        uint256 indexed lessonId,
        uint256 indexed tokenId,
        string metadata
    );
    
    //-----------------------constructor-----------------------------------------
    /**
     * @notice Initializes the CertificateNFT contract
     * @dev Sets up the certificate contract for a specific teacher
     * @param _teacher Address of the teacher who owns this certificate contract
     * @param _baseMetadataURI Optional base URI for certificate metadata (empty string if not provided)
     * @param _lessonNFT Address of the LessonNFT contract that can mint certificates
     * @custom:reverts zeroAddress If teacher or lessonNFT is address(0)
     */
    constructor(
        address _teacher,
        string memory _baseMetadataURI,
        address _lessonNFT
    ) ERC721("Gnosisland Certificate", "GNOSIS-CERT") Ownable(_teacher) {
        if (_teacher == address(0) || _lessonNFT == address(0)) {
            revert zeroAddress();
        }
        teacher = _teacher;
        baseMetadataURI = _baseMetadataURI;
        lessonNFT = _lessonNFT;
    }
    
    //-----------------------public view functions-----------------------------------------
    /**
     * @notice Returns the token URI for a certificate
     * @dev Returns custom metadata if provided, otherwise returns base URI + token ID
     * @param tokenId The token ID of the certificate
     * @return The token URI (metadata)
     */
    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        _requireOwned(tokenId);
        
        // If custom metadata exists for this lesson, return it
        string memory customMetadata = lessonMetadata[tokenId];
        if (bytes(customMetadata).length > 0) {
            return customMetadata;
        }
        
        // Otherwise, return base URI + token ID (or just base URI if it's a full URL)
        if (bytes(baseMetadataURI).length > 0) {
            return string(abi.encodePacked(baseMetadataURI, "/", _toString(tokenId)));
        }
        
        // If no metadata at all, return empty (frontend can use lesson name)
        return "";
    }
    
    //-----------------------external functions-----------------------------------------
    /**
     * @notice Mints a certificate NFT to a student after lesson completion
     * @dev Only LessonNFT can call this. Each lesson can only mint one certificate per student.
     * @param lessonId The ID of the completed lesson
     * @param student Address of the student receiving the certificate
     * @param metadata Optional custom metadata for the certificate (empty string if not provided)
     * @param lessonName Name of the lesson (used if metadata is not provided)
     * @return tokenId The token ID of the minted certificate
     * @custom:security Only callable by LessonNFT
     * @custom:reverts onlyLessonNFT If caller is not LessonNFT
     * @custom:reverts alreadyMinted If certificate already minted for this lesson
     * @custom:emits CertificateMinted When certificate is successfully minted
     */
    function mintCertificate(
        uint256 lessonId,
        address student,
        string memory metadata,
        string memory lessonName
    ) external returns (uint256 tokenId) {
        // Only LessonNFT can mint
        if (msg.sender != lessonNFT) {
            revert onlyLessonNFT();
        }
        
        // Check if certificate already minted for this lesson
        if (lessonFinished[lessonId] || lessonToStudent[lessonId] != address(0)) {
            revert alreadyMinted();
        }
        
        // Mark lesson as finished and track student
        lessonFinished[lessonId] = true;
        lessonToStudent[lessonId] = student;
        
        // Generate token ID (use lessonId as tokenId for simplicity, or use counter)
        tokenId = lessonId; // Using lessonId as tokenId ensures uniqueness
        
        // Store metadata if provided, otherwise store lesson name
        if (bytes(metadata).length > 0) {
            lessonMetadata[tokenId] = metadata;
        } else {
            // If no metadata provided, use lesson name
            lessonMetadata[tokenId] = lessonName;
        }
        
        // Mint soulbound NFT to student
        _safeMint(student, tokenId);
        
        emit CertificateMinted(student, lessonId, tokenId, lessonMetadata[tokenId]);
        
        return tokenId;
    }
    
    /**
     * @notice Updates the base metadata URI
     * @dev Only owner (teacher) can update
     * @param _newBaseMetadataURI New base metadata URI
     * @custom:security Only callable by owner (teacher)
     */
    function updateBaseMetadataURI(string memory _newBaseMetadataURI) external onlyOwner {
        baseMetadataURI = _newBaseMetadataURI;
    }
    
    /**
     * @notice Updates the LessonNFT address (for upgrades)
     * @dev Only owner can update
     * @param _newLessonNFT Address of the new LessonNFT contract
     * @custom:security Only callable by owner
     * @custom:reverts zeroAddress If new LessonNFT address is address(0)
     */
    function updateLessonNFT(address _newLessonNFT) external onlyOwner {
        if (_newLessonNFT == address(0)) {
            revert zeroAddress();
        }
        lessonNFT = _newLessonNFT;
    }
    
    //-----------------------internal functions-----------------------------------------
    /**
     * @notice Prevents transfer of soulbound certificates
     * @dev Overrides ERC721 transferFrom to implement soulbound functionality
     * @param from Address to transfer from
     * @param to Address to transfer to
     * @param tokenId Token ID to transfer
     * @custom:reverts soulboundToken Always reverts as certificates are soulbound
     */
    function transferFrom(address from, address to, uint256 tokenId) public virtual override {
        revert("Soulbound: Cannot transfer certificates");
    }
    
    /**
     * @notice Prevents approval of soulbound certificates
     * @dev Overrides ERC721 approve to prevent transfers
     * @param to Address to approve
     * @param tokenId Token ID to approve
     */
    function approve(address to, uint256 tokenId) public virtual override {
        revert("Soulbound: Cannot approve certificates");
    }
    
    /**
     * @notice Prevents setting approval for all
     * @dev Overrides ERC721 setApprovalForAll to prevent transfers
     * @param operator Address to approve
     * @param approved Whether to approve
     */
    function setApprovalForAll(address operator, bool approved) public virtual override {
        revert("Soulbound: Cannot approve certificates");
    }
    
    /**
     * @notice Converts uint256 to string
     * @dev Internal helper function
     * @param value The uint256 value to convert
     * @return The string representation
     */
    function _toString(uint256 value) internal pure returns (string memory) {
        if (value == 0) {
            return "0";
        }
        uint256 temp = value;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));
            value /= 10;
        }
        return string(buffer);
    }
}

