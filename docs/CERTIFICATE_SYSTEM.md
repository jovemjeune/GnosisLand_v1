# Certificate System Architecture

## Overview

The certificate system provides verifiable on-chain credentials for course completion. Each teacher has their own CertificateNFT contract with custom metadata support.

## Architecture

```mermaid
graph TB
    subgraph "Certificate Creation"
        Teacher[Teacher]
        LF[LessonFactory]
        CF[CertificateFactory]
        CNFT[CertificateNFT<br/>Per Teacher]
    end
    
    subgraph "Certificate Minting"
        Student[Student]
        LN[LessonNFT]
        CNFT2[CertificateNFT]
    end
    
    Teacher -->|Create Lesson Contract| LF
    LF -->|Initialize with CertificateFactory| LN
    
    Student -->|Purchase Lesson| LN
    LN -->|After Purchase| CF
    CF -->|getOrCreateCertificateContract| CNFT
    CNFT -->|mintCertificate| Student
    
    Note1[Certificate Metadata:<br/>Optional per lesson<br/>If not provided,<br/>uses lesson name]
```

## Flow: Certificate Minting

```mermaid
sequenceDiagram
    autonumber
    participant S as Student
    participant L as LessonNFT
    participant CF as CertificateFactory
    participant CN as CertificateNFT
    
    Note over S,CN: Lesson Purchase Complete
    S->>L: buyLesson(lessonId, ...)
    L->>L: Process payment & fees
    L->>L: Mint Lesson NFT
    L->>L: _mintCertificate(lessonId, student)
    
    Note over S,CN: Get Teacher's Certificate Contract
    L->>CF: getOrCreateCertificateContract(teacher, "", lessonNFT)
    alt Certificate Contract Exists
        CF-->>L: Existing CertificateNFT address
    else Certificate Contract Doesn't Exist
        CF->>CF: createCertificateContract(teacher, "", lessonNFT)
        CF->>CN: Deploy new CertificateNFT
        CN-->>CF: CertificateNFT address
        CF-->>L: New CertificateNFT address
    end
    
    Note over S,CN: Mint Certificate
    L->>CN: mintCertificate(lessonId, student, metadata, lessonName)
    CN->>CN: Check !lessonFinished[lessonId]
    CN->>CN: lessonFinished[lessonId] = true
    CN->>CN: Store metadata (or lessonName if empty)
    CN->>CN: _safeMint(student, lessonId)
    CN-->>S: Certificate NFT (Soulbound)
    CN-->>L: certificateTokenId
    L->>L: Emit CertificateMinted event
```

## Certificate Metadata

### Optional Metadata per Lesson

When creating a lesson, teachers can optionally provide certificate metadata:

```solidity
// In LessonNFT.createLesson()
function createLesson(
    bytes memory lessonData,
    string memory certMetadata  // Optional: empty string if not provided
) external onlyOwner returns (uint256 lessonId)
```

### Metadata Priority

1. **Custom Metadata**: If teacher provides `certMetadata` during lesson creation, it's used
2. **Lesson Name**: If no metadata provided, certificate uses the lesson name
3. **Base URI**: Teacher can set a base metadata URI in their CertificateNFT contract

### Storage

```solidity
// In LessonNFT
mapping(uint256 => string) public certificateMetadata; // lessonId => optional metadata

// In CertificateNFT
mapping(uint256 => string) public lessonMetadata; // lessonId => stored metadata
string public baseMetadataURI; // Teacher's base URI (optional)
```

## Certificate Contract Structure

### CertificateFactory

- **Purpose**: Creates CertificateNFT contracts per teacher
- **Functions**:
  - `createCertificateContract()`: Creates new CertificateNFT for teacher
  - `getOrCreateCertificateContract()`: Gets existing or creates new
  - `getTeacherCertificate()`: View function to get teacher's contract

### CertificateNFT (Per Teacher)

- **Purpose**: Soulbound ERC721 certificates for a specific teacher
- **Features**:
  - One-time mint per lesson (prevents duplicates)
  - Custom metadata per lesson (optional)
  - Soulbound (non-transferable)
  - Only LessonNFT can mint

### Key Properties

1. **Soulbound**: Certificates cannot be transferred
2. **One-Time Mint**: Each lesson can only mint one certificate
3. **Custom Metadata**: Teachers can provide custom metadata per lesson
4. **Automatic Minting**: Certificates are minted automatically after lesson purchase

## Integration Points

### LessonNFT Integration

```solidity
// After lesson purchase, automatically mint certificate
function buyLesson(...) external {
    // ... payment processing ...
    _safeMint(msg.sender, tokenId, data);
    _mintCertificate(lessonId, msg.sender); // Automatic certificate minting
}

function _mintCertificate(uint256 lessonId, address student) internal {
    if (certificateFactory == address(0)) return; // Skip if not set
    
    address certificateContract = ICertificateFactory(certificateFactory)
        .getOrCreateCertificateContract(onBehalf, "", address(this));
    
    string memory certMetadata = certificateMetadata[lessonId];
    string memory lessonName = _name;
    
    ICertificateNFT(certificateContract).mintCertificate(
        lessonId,
        student,
        certMetadata, // Custom metadata if provided
        lessonName    // Fallback to lesson name
    );
}
```

### LessonFactory Integration

```solidity
// LessonFactory constructor includes CertificateFactory
constructor(
    address _lessonNFTImplementation,
    address _treasuryContract,
    address _paymentToken,
    address _teacherNFT,
    address _certificateFactory  // Can be address(0) if not enabled
)
```

## Certificate Creation Flow

```mermaid
flowchart TD
    Start[Teacher Creates Lesson] --> CreateLesson[createLesson<br/>lessonData, certMetadata]
    CreateLesson --> StoreMetadata{Metadata<br/>Provided?}
    StoreMetadata -->|Yes| StoreCustom[Store custom metadata]
    StoreMetadata -->|No| StoreEmpty[Store empty string]
    StoreCustom --> LessonReady[Lesson Ready]
    StoreEmpty --> LessonReady
    
    LessonReady --> Purchase[Student Purchases Lesson]
    Purchase --> CheckFactory{CertificateFactory<br/>Set?}
    CheckFactory -->|No| Skip[Skip Certificate]
    CheckFactory -->|Yes| GetContract[Get/Create Certificate Contract]
    GetContract --> MintCert[Mint Certificate]
    MintCert --> CheckMetadata{Metadata<br/>Exists?}
    CheckMetadata -->|Yes| UseCustom[Use custom metadata]
    CheckMetadata -->|No| UseName[Use lesson name]
    UseCustom --> Mint[Mint NFT to Student]
    UseName --> Mint
    Mint --> Complete[Certificate Minted]
```

## Security Features

1. **Access Control**: Only LessonNFT can mint certificates
2. **One-Time Mint**: `lessonFinished` mapping prevents duplicate mints
3. **Soulbound**: Certificates cannot be transferred or approved
4. **Teacher Ownership**: Each teacher owns their CertificateNFT contract

## Events

```solidity
event CertificateContractCreated(
    address indexed teacher,
    address indexed certificateContract,
    string baseMetadataURI
);

event CertificateMinted(
    address indexed student,
    uint256 indexed lessonId,
    uint256 indexed tokenId,
    string metadata
);
```

## Benefits

1. **Verifiable Credentials**: On-chain proof of course completion
2. **Custom Branding**: Teachers can customize certificate metadata
3. **Automatic**: Certificates mint automatically after purchase
4. **Flexible**: Optional metadata allows teachers to choose level of customization
5. **Soulbound**: Prevents certificate trading, maintains authenticity

