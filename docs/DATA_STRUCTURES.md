# Data Structures

This document describes the storage layouts and data organization in Gnosisland contracts.

## Storage Layout Overview

All upgradeable contracts use **ERC7201 namespaced storage** to prevent storage collisions during upgrades. Each contract has a unique storage namespace.

## TreasuryContract Storage

**Namespace**: `gnosisland.storage.TreasuryContract`

### Core State Variables
```solidity
struct TreasuryContractStorage {
    GlUSD glusdToken;                    // GlUSD token contract
    IERC20 usdcToken;                    // USDC token contract
    IAavePool aavePool;                  // Aave Pool interface
    IMorphoMarket morphoMarket;          // Morpho Market interface
    IMorphoMarket.MarketParams morphoMarketParams; // Morpho market parameters
    address escrowNFT;                   // EscrowNFT contract
    address lessonNFT;                   // LessonNFT contract (authorized)
    address vault;                       // Vault contract (ERC4626)
    bool paused;                         // Emergency pause flag
}
```

### Vault Tracking
```solidity
uint256 totalAssetsStaked;               // Total USDC in Morpho + Aave
uint256 totalShares;                     // Total GlUSD shares minted
uint256 morphoAssets;                    // USDC staked in Morpho (90%)
uint256 aaveAssets;                      // USDC staked in Aave (10%)
uint256 protocolFunds;                   // Protocol revenue (separate)
```

### Allocation Percentages
```solidity
uint256 morphoAllocationPercent;         // 90%
uint256 aaveAllocationPercent;          // 10%
```

### User Tracking
```solidity
mapping(address => uint256) underlyingBalanceOf;  // User => USDC deposited
mapping(address => uint256) GlUSD_shareOf;       // User => GlUSD shares (from Vault)
mapping(address => uint256) totalWithdrawn;     // User => Total USDC withdrawn
mapping(address => uint256) userDeposits;        // Legacy: User => USDC deposited
mapping(address => uint256) userShares;          // Legacy: User => GlUSD shares
```

### Referral Tracking
```solidity
mapping(address => uint256) referrerStakedCollateral;  // Referrer => Total USDC staked
mapping(address => uint256) referrerShares;            // Referrer => GlUSD shares
mapping(address => uint256) referrerTotalRewards;      // Referrer => Total rewards
```

### Stake Lock Tracking
```solidity
struct Stake {
    uint256 amount;                      // Amount staked
    uint256 timestamp;                   // When stake was made
    bool isReferral;                     // true if from referral reward
}

mapping(address => Stake[]) userStakes;        // User => Array of stakes
mapping(address => Stake[]) referrerStakes;    // Referrer => Array of referral stakes
uint256 constant LOCK_PERIOD = 1 days;        // 1 day lock period
```

### Constants
```solidity
uint256 constant TREASURY_FEE_PERCENT = 10;      // 10% of sales
uint256 constant USER_YIELD_PERCENT = 3;        // 3% to users/teachers
uint256 constant REFERRAL_REWARD_PERCENT = 3;   // 3% of purchase price
uint256 constant MORPHO_ALLOCATION = 90;        // 90% to Morpho
uint256 constant AAVE_ALLOCATION = 10;           // 10% to Aave
```

## LessonNFT Storage

**Namespace**: Standard ERC721 storage + custom variables

### Core Variables
```solidity
string private _name;                    // Contract name
string private _symbol;                   // Contract symbol
uint256 public price;                     // Current course price
uint256 public originalPrice;             // Original price (immutable)
uint256 public latestNFTId;               // Latest NFT token ID
address public onBehalf;                  // Teacher's address
address public treasuryContract;          // Treasury contract
bool public lessonsPaused;                // Pause flag
bytes public data;                        // Course data
address public paymentToken;              // USDC address
address public teacherNFT;                // TeacherNFT contract
address public certificateFactory;        // CertificateFactory contract
```

### Mappings
```solidity
mapping(uint256 => bytes) public nftData;                    // lessonId => lesson data
mapping(uint256 => string) public certificateMetadata;      // lessonId => certificate metadata
mapping(uint256 => uint256) public tokenToLesson;           // tokenId => lessonId
mapping(address => uint256) public userBalance;             // User => balance
mapping(address => address) public referrers;              // User => Referrer
mapping(address => bool) public hasUsedReferralDiscount;    // User => Used referral?
mapping(bytes32 => bool) public couponCodesUsed;           // Coupon => Used?
mapping(bytes32 => address) public couponCodeCreator;      // Coupon => Creator
```

### Constants
```solidity
uint256 public constant MINIMUM_PRICE = 25e6;  // 25 USDC (6 decimals)
```

## Vault Storage

**Namespace**: Standard ERC4626 storage + custom variables

### Core Variables
```solidity
address public treasuryContract;         // Treasury contract reference
uint256 private _virtualShares;          // Virtual shares (donation attack protection)
uint256 private _virtualAssets;          // Virtual assets (donation attack protection)
```

### User Tracking
```solidity
mapping(address => uint256) public GlUSD_shareOf;  // User => GlUSD shares in vault
```

### Constants
```solidity
uint256 private constant INITIAL_VIRTUAL_SHARES = 1e18;  // 1 share
uint256 private constant INITIAL_VIRTUAL_ASSETS = 1e18;  // 1 asset
```

## TeacherNFT Storage

**Namespace**: `gnosisland.storage.TeacherNFT`

### Storage Structure
```solidity
struct TeacherNFTStorage {
    string name;                          // Token name
    string symbol;                        // Token symbol
    uint256 latestTokenId;                // Latest token ID
    mapping(address => bool) nftCreated;  // Address => Has NFT?
    mapping(address => bool) teacherBlackListed; // Address => Blacklisted?
}
```

## EscrowNFT Storage

**Namespace**: `gnosisland.storage.EscrowNFT`

### Storage Structure
```solidity
struct EscrowNFTStorage {
    string name;                          // Token name
    string symbol;                        // Token symbol
    uint256 latestTokenId;                // Latest token ID
    mapping(bytes32 => address) referralCodeToReferrer; // Code => Referrer
    mapping(address => bytes32[]) referrerToCodes;      // Referrer => Codes[]
    mapping(uint256 => address) tokenIdToReferrer;     // TokenId => Referrer
}
```

## CertificateNFT Storage

**Namespace**: Standard ERC721 storage + custom variables

### Core Variables
```solidity
address public teacher;                  // Teacher's address
address public lessonNFT;                 // LessonNFT contract
string public baseMetadataURI;           // Base URI for metadata
uint256 public latestTokenId;            // Latest certificate ID
```

### Mappings
```solidity
mapping(uint256 => uint256) public certificateToLesson;  // CertificateId => LessonId
mapping(uint256 => address) public certificateToStudent; // CertificateId => Student
```

## DiscountBallot Storage

**Namespace**: `gnosisland.storage.DiscountBallot`

### Storage Structure
```solidity
struct DiscountBallotStorage {
    uint256 votingPeriod;                 // Voting period duration
    uint256 minimumDepositPerVote;        // Minimum deposit per vote
    address[] officialList;                // Official voters list
    uint256 latestBallotId;               // Latest ballot ID
    address payable treasury;              // Treasury address
    mapping(address => bool) userVoted;   // User => Voted?
    mapping(uint256 => uint256) getOptionOneVotes;   // 10% discount votes
    mapping(uint256 => uint256) getOptionTwoVotes;   // 25% discount votes
    mapping(uint256 => uint256) getOptionThreeVotes; // 50% discount votes
    mapping(address => bool) isOfficial;  // Address => Is official?
    mapping(uint256 => Proposal) proposal; // BallotId => Proposal
    mapping(uint256 => Votes) votes;      // BallotId => Votes
}
```

## Storage Slot Calculation

### ERC7201 Namespace
Each contract uses a unique storage location calculated as:
```solidity
keccak256(abi.encode(uint256(keccak256("gnosisland.storage.ContractName")) - 1)) & ~bytes32(uint256(0xff))
```

### Example Storage Locations
- TreasuryContract: `0x...` (calculated from namespace)
- TeacherNFT: `0xf4327a6f48f9a32df6a39c24f65cef1060ec7e47250f7271db03107370883f00`
- DiscountBallot: `0x128c14ba4f23205bdb10400203da2c18c7dcd45b0d972dbf23202bb2496a5200`

## Storage Optimization

### Packed Storage
- Boolean values are packed with other variables when possible
- Timestamps use `uint256` (no packing needed for gas efficiency)
- Addresses are 20 bytes (packed when possible)

### Mapping Efficiency
- Mappings are used for O(1) lookups
- Nested mappings avoided where possible
- Array mappings used for iterable data (e.g., `userStakes[]`)

## Storage Collision Prevention

1. **ERC7201 Namespaces**: Each upgradeable contract uses unique namespace
2. **Private Storage**: Non-upgradeable contracts use standard storage
3. **Storage Gaps**: Upgradeable contracts reserve storage slots for future use
4. **Documentation**: All storage layouts documented in NatSpec comments

## Data Access Patterns

### Read Operations
- Direct storage reads (gas efficient)
- View functions for computed values
- Public variables for simple data

### Write Operations
- State-changing functions with access control
- Events emitted for all state changes
- Reentrancy guards on critical functions

## Storage Migration

When upgrading contracts:
1. New storage variables added to end of struct
2. Old variables never removed (for compatibility)
3. Migration functions handle data transformation if needed
4. Storage slots verified before and after upgrade

