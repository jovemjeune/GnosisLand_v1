# Certificate System

## Overview

Gnosisland implements an on-chain certificate system using soulbound NFTs (non-transferable ERC721 tokens). Each teacher has their own CertificateNFT contract, and certificates are automatically minted when students complete course purchases.

## Architecture

### CertificateFactory
**Purpose**: Factory contract that creates and manages CertificateNFT contracts per teacher

**Key Functions**:
- `getOrCreateCertificateContract(teacher, baseMetadataURI, lessonNFT)`: Creates or returns existing CertificateNFT for a teacher
- `getTeacherCertificate(teacher)`: Returns the CertificateNFT address for a teacher

**Storage**:
- `mapping(address => address) teacherToCertificate`: Maps teacher address to their CertificateNFT contract

### CertificateNFT
**Purpose**: Individual certificate contract for each teacher

**Key Features**:
- One contract per teacher
- Soulbound NFTs (non-transferable)
- Automatic minting on course purchase
- Custom metadata per certificate

**Key Functions**:
- `mintCertificate(lessonId, student, metadata, lessonName)`: Mints a certificate to a student
- `ownerOf(tokenId)`: Returns student address (soulbound, cannot transfer)

**Storage**:
- `address public teacher`: Teacher's address
- `address public lessonNFT`: LessonNFT contract reference
- `string public baseMetadataURI`: Base URI for metadata
- `uint256 public latestTokenId`: Latest certificate ID
- `mapping(uint256 => uint256) certificateToLesson`: Certificate ID → Lesson ID
- `mapping(uint256 => address) certificateToStudent`: Certificate ID → Student address

## Certificate Minting Flow

### Automatic Minting
1. Student purchases course via `LessonNFT.buyLesson()`
2. `LessonNFT` calls `CertificateFactory.getOrCreateCertificateContract()`
3. Factory returns or creates CertificateNFT for teacher
4. `LessonNFT` calls `CertificateNFT.mintCertificate()`
5. Certificate NFT minted to student address
6. Certificate is soulbound (cannot be transferred)

### Manual Minting (if needed)
Teachers or authorized contracts can manually mint certificates:
```solidity
certificateNFT.mintCertificate(
    lessonId,
    studentAddress,
    metadataURI,
    lessonName
);
```

## Certificate Properties

### Soulbound (Non-Transferable)
- Certificates cannot be transferred to other addresses
- `transferFrom()` and `safeTransferFrom()` will revert
- This ensures certificates represent genuine course completion
- Prevents certificate trading or selling

### Metadata
Each certificate includes:
- **Lesson ID**: Links certificate to specific course
- **Student Address**: Owner of the certificate
- **Metadata URI**: JSON metadata (can include course details, completion date, etc.)
- **Lesson Name**: Name of the completed course

### Uniqueness
- Each certificate has a unique token ID
- One certificate per student per course
- Certificate ID increments per mint

## Integration with LessonNFT

### Certificate Creation Trigger
When a student purchases a course:
```solidity
// In LessonNFT.buyLesson()
address certificateContract = certificateFactory.getOrCreateCertificateContract(
    onBehalf, // teacher address
    baseMetadataURI,
    address(this) // lessonNFT address
);

ICertificateNFT(certificateContract).mintCertificate(
    lessonId,
    student,
    certificateMetadata[lessonId],
    lessonName
);
```

### Certificate Metadata
Teachers can set certificate metadata when creating courses:
- `certificateMetadata[lessonId]`: Custom metadata URI for the certificate
- Can include course description, completion criteria, etc.

## Certificate Verification

### On-Chain Verification
Anyone can verify a certificate by:
1. Checking `CertificateNFT.ownerOf(tokenId)` to verify student ownership
2. Checking `CertificateNFT.certificateToLesson(tokenId)` to get lesson ID
3. Checking `CertificateNFT.certificateToStudent(tokenId)` to verify student address
4. Verifying certificate contract address via `CertificateFactory.getTeacherCertificate(teacher)`

### Off-Chain Verification
- Metadata can be stored off-chain (IPFS, Arweave, etc.)
- Metadata URI points to JSON with certificate details
- JSON can include:
  - Course name
  - Completion date
  - Teacher information
  - Course description
  - Skills learned

## Use Cases

### 1. Proof of Completion
- Students receive verifiable proof of course completion
- Certificates are tamper-proof (on-chain)
- Can be used for resumes, portfolios, LinkedIn, etc.

### 2. Teacher Reputation
- Teachers can showcase student certificates
- Builds trust and credibility
- Demonstrates course completion rates

### 3. Skill Verification
- Employers can verify skills on-chain
- Prevents fake certificates
- Transparent verification process

### 4. Achievement System
- Students can collect certificates as achievements
- Build a portfolio of completed courses
- Track learning progress

## Security Considerations

### Soulbound Protection
- Certificates cannot be transferred
- Prevents certificate trading
- Ensures authenticity

### Access Control
- Only authorized contracts can mint certificates
- `mintCertificate()` should have access control
- Prevents unauthorized certificate creation

### Metadata Integrity
- Metadata URIs should be immutable
- Consider using IPFS for decentralized storage
- Verify metadata before minting

## Future Enhancements

### Potential Features
1. **Certificate Levels**: Bronze, Silver, Gold based on performance
2. **Expiration Dates**: Time-limited certificates for continuing education
3. **Verification Badges**: Visual badges for verified certificates
4. **Batch Minting**: Mint multiple certificates at once
5. **Certificate Revocation**: Ability to revoke fraudulent certificates

### Integration Ideas
- Integration with job platforms
- LinkedIn verification
- Resume builders
- Portfolio websites
- Educational institutions

## Example Certificate Metadata

```json
{
  "name": "Complete Solidity Developer Course",
  "description": "Certificate of completion for Solidity Developer Course",
  "image": "ipfs://Qm...",
  "attributes": [
    {
      "trait_type": "Course",
      "value": "Solidity Developer"
    },
    {
      "trait_type": "Teacher",
      "value": "0x..."
    },
    {
      "trait_type": "Completion Date",
      "value": "2024-01-15"
    },
    {
      "trait_type": "Lesson ID",
      "value": "1"
    }
  ]
}
```

## Gas Costs

### Certificate Minting
- Approximate gas: ~80,000 - 100,000 gas
- Depends on metadata size
- One-time cost per certificate

### Certificate Verification
- View functions (no gas cost)
- Can be called by anyone
- Efficient on-chain lookups

## Best Practices

1. **Set Metadata Early**: Set certificate metadata when creating courses
2. **Use IPFS**: Store metadata on IPFS for decentralization
3. **Verify Before Minting**: Ensure student completed course requirements
4. **Document Metadata Format**: Standardize metadata structure
5. **Monitor Gas Costs**: Optimize metadata to reduce gas costs

