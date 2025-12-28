// SPDX-License-Identifier: MIT

//  ____                 _       _                    _ 
// / ___|_ __   ___  ___(_)___  | |    __ _ _ __   __| |
//| |  _| '_ \ / _ \/ __| / __| | |   / _` | '_ \ / _` |
//| |_| | | | | (_) \__ \ \__ \ | |__| (_| | | | | (_| |
// \____|_| |_|\___/|___/_|___/ |_____\__,_|_| |_|\__,_|
     
pragma solidity ^0.8.13;

import {CertificateNFT} from "./CertificateNFT.sol";

/**
 * @title CertificateFactory
 * @dev Factory contract for creating CertificateNFT contracts per teacher
 * @notice Each teacher gets their own CertificateNFT contract with custom metadata support
 * @notice Only LessonNFT can mint certificates from teacher's contract
 */
contract CertificateFactory {
    //-----------------------Storage Variables-----------------------------------------
    mapping(address => address) public teacherToCertificate; // teacher => CertificateNFT contract
    address[] public allCertificates; // Array of all certificate contracts
    
    //-----------------------custom errors-----------------------------------------
    error zeroAddress();
    error certificateAlreadyExists(); // Teacher already has a certificate contract
    
    //-----------------------events-----------------------------------------
    event CertificateContractCreated(
        address indexed teacher,
        address indexed certificateContract,
        string baseMetadataURI
    );
    
    //-----------------------public view functions-----------------------------------------
    /**
     * @notice Gets the CertificateNFT contract address for a teacher
     * @dev Returns address(0) if teacher hasn't created a certificate contract yet
     * @param teacher Address of the teacher
     * @return Address of the teacher's CertificateNFT contract (or address(0) if not created)
     */
    function getTeacherCertificate(address teacher) external view returns (address) {
        return teacherToCertificate[teacher];
    }
    
    /**
     * @notice Gets all certificate contracts
     * @dev Returns array of all CertificateNFT contract addresses
     * @return Array of all certificate contract addresses
     */
    function getAllCertificates() external view returns (address[] memory) {
        return allCertificates;
    }
    
    //-----------------------external functions-----------------------------------------
    /**
     * @notice Creates a CertificateNFT contract for a teacher
     * @dev Each teacher can create one certificate contract. Contract supports custom metadata.
     * @param teacher Address of the teacher
     * @param baseMetadataURI Optional base URI for certificate metadata (empty string if not provided)
     * @param lessonNFT Address of the LessonNFT contract that can mint certificates
     * @return certificateAddress Address of the created CertificateNFT contract
     * @custom:reverts zeroAddress If teacher or lessonNFT is address(0)
     * @custom:reverts certificateAlreadyExists If teacher already has a certificate contract
     * @custom:emits CertificateContractCreated When contract is successfully created
     */
    function createCertificateContract(
        address teacher,
        string memory baseMetadataURI,
        address lessonNFT
    ) external returns (address certificateAddress) {
        if (teacher == address(0) || lessonNFT == address(0)) {
            revert zeroAddress();
        }
        
        // Check if teacher already has a certificate contract
        if (teacherToCertificate[teacher] != address(0)) {
            revert certificateAlreadyExists();
        }
        
        // Deploy new CertificateNFT contract for teacher
        certificateAddress = address(new CertificateNFT(teacher, baseMetadataURI, lessonNFT));
        
        // Track the contract
        teacherToCertificate[teacher] = certificateAddress;
        allCertificates.push(certificateAddress);
        
        emit CertificateContractCreated(teacher, certificateAddress, baseMetadataURI);
        
        return certificateAddress;
    }
    
    /**
     * @notice Gets or creates a CertificateNFT contract for a teacher
     * @dev If teacher doesn't have a contract, creates one. Otherwise returns existing.
     * @param teacher Address of the teacher
     * @param baseMetadataURI Optional base URI for certificate metadata (empty string if not provided)
     * @param lessonNFT Address of the LessonNFT contract that can mint certificates
     * @return certificateAddress Address of the teacher's CertificateNFT contract
     * @custom:reverts zeroAddress If teacher or lessonNFT is address(0)
     */
    function getOrCreateCertificateContract(
        address teacher,
        string memory baseMetadataURI,
        address lessonNFT
    ) external returns (address certificateAddress) {
        if (teacher == address(0) || lessonNFT == address(0)) {
            revert zeroAddress();
        }
        
        // If teacher already has a certificate contract, return it
        if (teacherToCertificate[teacher] != address(0)) {
            return teacherToCertificate[teacher];
        }
        
        // Otherwise, create a new one
        return this.createCertificateContract(teacher, baseMetadataURI, lessonNFT);
    }
}

