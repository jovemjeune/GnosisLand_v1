// SPDX-License-Identifier: MIT

//  ____                 _       _                    _ 
// / ___|_ __   ___  ___(_)___  | |    __ _ _ __   __| |
//| |  _| '_ \ / _ \/ __| / __| | |   / _` | '_ \ / _` |
//| |_| | | | | (_) \__ \ \__ \ | |__| (_| | | | | (_| |
// \____|_| |_|\___/|___/_|___/ |_____\__,_|_| |_|\__,_|
     
pragma solidity ^0.8.13;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import {StorageSlot} from "@openzeppelin/contracts/utils/StorageSlot.sol";
import {SlotDerivation} from "@openzeppelin/contracts/utils/SlotDerivation.sol";
pragma solidity ^0.8.13;

/**
 * @notice Teacher NFTs can be minted only by GnosislandFactory.
 * @author jovemjeune
 * @dev    Creates an nft in order to authenticate users during 
 */
contract TeacherNft is ERC721, Ownable, Initializable, UUPSUpgradeable {
    using StorageSlot for *;
    using SlotDerivation for *;

    //-----------------------ERC7201 Namespace Storage-----------------------------------------
    /**
     * @dev Storage of the TeacherNFT contract.
     * @custom:storage-location erc7201:gnosisland.storage.TeacherNFT
     */
    struct TeacherNFTStorage {
        string name;
        string symbol;
        uint256 latestTokenId;
        mapping(address => bool) nftCreated;
        mapping(address => bool) teacherBlackListed;
    }

    // keccak256(abi.encode(uint256(keccak256("gnosisland.storage.TeacherNFT")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant TEACHER_NFT_STORAGE_LOCATION = 0xf4327a6f48f9a32df6a39c24f65cef1060ec7e47250f7271db03107370883f00;

    function _getTeacherNFTStorage() private pure returns (TeacherNFTStorage storage $) {
        assembly ("memory-safe") {
            $.slot := TEACHER_NFT_STORAGE_LOCATION
        }
    }

    //-----------------------custom errors-----------------------------------------
    error accountAlreadyOwnsNFT();
    error teacherBanned();

    //-----------------------constructor (disabled for upgradeable)-----------------------------------------
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() ERC721("", "GNOSIS") Ownable(address(this)) {
        _disableInitializers();
    }

    //-----------------------initializer-----------------------------------------
    /**
     * @notice Initializes the TeacherNFT contract
     * @dev Called once when the proxy is deployed. Sets name, symbol, and owner.
     * @param name_ Name of the NFT collection
     * @param symbol_ Symbol of the NFT collection
     * @param initialOwner Address of the initial owner
     */
    function initialize(string memory name_, string memory symbol_, address initialOwner) external initializer {
        TeacherNFTStorage storage $ = _getTeacherNFTStorage();
        $.name = name_;
        $.symbol = symbol_;
        // Set owner
        _transferOwnership(initialOwner);
    }

    //-----------------------public view functions-----------------------------------------
    /// @dev Override ERC721 name() to read from ERC7201 storage
    function name() public view virtual override returns (string memory) {
        TeacherNFTStorage storage $ = _getTeacherNFTStorage();
        return $.name;
    }

    /// @dev Override ERC721 symbol() to read from ERC7201 storage
    function symbol() public view virtual override returns (string memory) {
        TeacherNFTStorage storage $ = _getTeacherNFTStorage();
        return $.symbol;
    }

    //-----------------------UUPS authorization-----------------------------------------
    /**
     * @notice Authorizes contract upgrades
     * @dev Only the owner can authorize upgrades. This is required by UUPS pattern.
     * @param newImplementation Address of the new implementation contract
     */
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    function getLatestTokenId() external view returns(uint256){
        TeacherNFTStorage storage $ = _getTeacherNFTStorage();
        return $.latestTokenId;
    }

    function nftCreated(address teacher) external view returns (bool) {
        TeacherNFTStorage storage $ = _getTeacherNFTStorage();
        return $.nftCreated[teacher];
    }

    function teacherBlackListed(address teacher) external view returns (bool) {
        TeacherNFTStorage storage $ = _getTeacherNFTStorage();
        return $.teacherBlackListed[teacher];
    }

    //-----------------------external functions-----------------------------------------
    /**
     * @notice Mints a TeacherNFT to a teacher
     * @dev Only owner can mint. Each teacher can only have one NFT.
     * @param teacher Address of the teacher to mint NFT to
     * @param name_ Name metadata for the NFT
     * @param data Additional metadata bytes for the NFT
     * @custom:security Only callable by owner
     * @custom:reverts accountAlreadyOwnsNFT If teacher already has an NFT
     * @custom:reverts teacherBanned If teacher is blacklisted
     */
    function mintTeacherNFT(
        address teacher, 
        string memory name_,
        bytes memory data
    ) external onlyOwner{
        TeacherNFTStorage storage $ = _getTeacherNFTStorage();
        if($.nftCreated[teacher]){
            revert accountAlreadyOwnsNFT();
        }
        $.nftCreated[teacher] = true; //ensure each teacher has only one nft 
        _safeMint(teacher, $.latestTokenId, data);
        $.latestTokenId++;
    }

    
    /**
     * @notice Bans a teacher (blocks all actions)
     * @dev Only owner can ban. Used for teachers sharing NSFW content, copyright violations, or unsafe content.
     * @param teacher Address of the teacher to ban
     * @custom:security Only callable by owner
     * @custom:notice Sharing NSFW content or copyright violations is prohibited and will result in account ban
     */
    function banTeacher(address teacher) external onlyOwner{
        TeacherNFTStorage storage $ = _getTeacherNFTStorage();
        $.teacherBlackListed[teacher] = true;
    }

    /**
     * @notice Overrides ERC721 _update to prevent blacklisted teachers from transferring
     * @dev Blocks transfers if either from or to address is blacklisted
     * @param to Address receiving the token
     * @param tokenId Token ID being transferred
     * @param auth Authorized address (unused)
     * @return Address of the previous owner
     * @custom:reverts teacherBanned If from or to address is blacklisted
     */
    function _update(address to, uint256 tokenId, address auth) internal virtual override returns (address) {
        TeacherNFTStorage storage $ = _getTeacherNFTStorage();
        address from = _ownerOf(tokenId);
        
        // Prevent blacklisted teachers from transferring their NFTs
        if($.teacherBlackListed[from] == true || $.teacherBlackListed[to] == true){
            revert teacherBanned();
        }
        
        return super._update(to, tokenId, auth);
    }
}
