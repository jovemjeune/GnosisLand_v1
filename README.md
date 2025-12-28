<div align="center">

# 🎓 Gnosisland

### **Decentralized Learning Platform with DeFi-Powered Yield Generation**

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Solidity](https://img.shields.io/badge/Solidity-0.8.13-blue.svg)](https://soliditylang.org/)
[![Foundry](https://img.shields.io/badge/Built%20with-Foundry-000000.svg)](https://book.getfoundry.sh/)
[![Base](https://img.shields.io/badge/Target%20Network-Base-0052FF.svg)](https://base.org/)

**Empowering teachers in Argentina and Turkey while making education accessible through DeFi innovation**

[Features](#-key-features) • [Architecture](#-system-architecture) • [Getting Started](#-getting-started) • [Documentation](#-documentation) • [Security](#-security)

---

</div>

## 🌟 Overview

**Gnosisland** is a revolutionary decentralized learning platform that combines online education with DeFi yield generation. Designed for deployment on **Base** (Ethereum L2), Gnosisland addresses teacher unemployment and low salaries in underserved markets like Argentina and Turkey, while making quality education accessible to students through innovative financial mechanisms.

### 🎯 Mission

- **For Teachers**: Earn sustainable income by creating and selling online courses from home
- **For Students**: Access affordable education with discounts and earn yield on course payments
- **For the Ecosystem**: Generate sustainable yield through DeFi integrations (Aave & Morpho)

---

## ✨ Key Features

### 🎓 **Core Learning Platform**
- **Video Courses**: Teachers create and sell online video courses
- **Soulbound NFTs**: Students receive non-transferable NFTs upon course completion
- **On-Chain Certificates**: Verifiable, tamper-proof certificates stored on-chain
- **Minimum Price**: Courses start at 25 USDC (accessible pricing for Turkey/Argentina)

### 💰 **DeFi Integration**
- **GlUSD Stablecoin**: 1:1 pegged with USDC, representing yield-bearing shares
- **Yield Generation**: Automatic staking to Aave (10%) and Morpho (90%) for ~6.25% APY
- **Dual Payment**: Pay with USDC or GlUSD (teachers earn yield on GlUSD payments)
- **Vault System**: ERC4626-compatible vault for GlUSD staking and yield distribution

### 🎁 **Discount System**
- **Coupon Codes**: Teachers can create 50% discount codes
- **Referral Program**: 10% discount for referred students, 10% reward for referrers
- **Governance Voting**: DiscountBallot allows community to vote on discount rates

### 🔐 **Security & Trust**
- **Teacher Authentication**: TeacherNFT system for verified educators
- **Upgradeable Contracts**: UUPS pattern for future improvements
- **Reentrancy Protection**: Comprehensive security measures
- **Access Control**: Role-based permissions throughout

---

## 🏗️ System Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    GNOSISLAND ECOSYSTEM                          │
└─────────────────────────────────────────────────────────────────┘
                              │
        ┌─────────────────────┼─────────────────────┐
        │                     │                     │
        ▼                     ▼                     ▼
   ┌─────────┐          ┌──────────┐          ┌─────────┐
   │Students │          │ Teachers │          │Referrers│
   └────┬────┘          └────┬─────┘          └────┬────┘
        │                    │                     │
        │ 1. Deposit USDC    │ 2. Create Course   │ 3. Share Code
        │ 2. Get GlUSD       │ 3. Set Price       │
        │ 3. Stake to Vault  │ 4. Earn Yield       │
        │ 4. Earn Yield      │                     │
        │                    │                     │
        ▼                    ▼                     ▼
┌───────────────────────────────────────────────────────────┐
│              LESSON MARKETPLACE (LessonNFT)                │
│  • Purchase with USDC or GlUSD                             │
│  • 50% Coupon Discounts                                   │
│  • 10% Referral Discounts                                 │
│  • Automatic Certificate Minting                          │
└───────────────────────────────────────────────────────────┘
        │                    │                     │
        │                    │                     │
        ▼                    ▼                     ▼
┌───────────────────────────────────────────────────────────┐
│         TREASURY CONTRACT (Central Fund Manager)            │
│  • Receives 10-20% fees from purchases                    │
│  • Mints GlUSD 1:1 with USDC deposits                      │
│  • Stakes 90% to Morpho, 10% to Aave                       │
│  • Distributes yield to GlUSD holders                      │
│  • Manages protocol vs staker fund separation              │
└───────────────────────────────────────────────────────────┘
        │                    │
        │                    │
        ▼                    ▼
┌──────────────────┐  ┌──────────────────┐
│  VAULT (ERC4626) │  │  CERTIFICATE NFT  │
│  • GlUSD Staking │  │  • Soulbound     │
│  • Share Tracking│  │  • Per-Teacher   │
│  • Yield Claims  │  │  • Custom Meta   │
└──────────────────┘  └──────────────────┘
```

### 📊 **Fee Structure**

| Scenario | Protocol Fee | Staker Fee | Teacher Fee | Referrer Fee |
|----------|-------------|------------|-------------|--------------|
| **Normal Purchase** | 10% | 10% | 80% | - |
| **With Referral** | 10% | - | 80% | 10% |
| **With Coupon (50% off)** | 5% | 5% | 90% | - |

---

## 🚀 Getting Started

### Prerequisites

- [Foundry](https://book.getfoundry.sh/getting-started/installation) (latest version)
- Node.js (for development tools)
- Git

### Installation

```bash
# Clone the repository
git clone https://github.com/yourusername/gnosisland.git
cd gnosisland

# Install dependencies
forge install

# Build contracts
forge build

# Run tests
forge test
```

### Quick Start

```bash
# Format code
forge fmt

# Run tests with coverage
forge test -vvv

# Generate gas report
forge snapshot
```

---

## 📖 Documentation

### 📚 **Comprehensive Guides**

- **[README](README.md)** - Project overview and getting started guide
- **[System Architecture](docs/SYSTEM_ARCHITECTURE.md)** - Detailed system design and component interactions
- **[User Flows](docs/USER_FLOWS.md)** - Step-by-step user interaction flows
- **[Deployment Guide](DEPLOYMENT.md)** - Complete deployment instructions
- **[Security Policy](SECURITY.md)** - Security best practices and reporting

### 🎯 **Feature Documentation**

- **[Certificate System](docs/CERTIFICATE_SYSTEM.md)** - On-chain certificate implementation
- **[Coupon Codes](docs/COUPON_CODE_SYSTEM.md)** - Discount system documentation
- **[Referral System](docs/REFERRAL_SYSTEM_EXPLANATION.md)** - Referral program details
- **[Treasury System](docs/TREASURY_SYSTEM.md)** - DeFi integration and yield management

### 📊 **Technical Documentation**

- **[Data Structures](docs/DATA_STRUCTURES.md)** - Storage layouts and data organization
- **[Visual Summary](docs/VISUAL_SUMMARY.md)** - High-level system overview
- **[Complete Implementation](docs/COMPLETE_IMPLEMENTATION_SUMMARY.md)** - Full feature list

---

## 🔧 Development

### Project Structure

```
gnosisland/
├── src/                    # Smart contracts
│   ├── LessonNFT.sol      # Course marketplace
│   ├── TreasuryContract.sol # Central treasury & yield
│   ├── Vault.sol          # ERC4626 vault
│   ├── GlUSD.sol          # Yield-bearing stablecoin
│   ├── TeacherNFT.sol     # Teacher authentication
│   ├── CertificateNFT.sol # On-chain certificates
│   └── ...
├── test/                   # Test files
├── script/                 # Deployment scripts
│   ├── Deploy.s.sol       # Main deployment script
│   └── check-dependencies.sh
├── docs/                   # Documentation
└── .github/               # CI/CD workflows
```

### Testing

```bash
# Run all tests
forge test

# Run specific test file
forge test --match-path test/Invariants.t.sol

# Run with gas reporting
forge test --gas-report

# Run Base mainnet fork tests
forge test --match-contract BaseMainnetForkTest
```

### Code Quality

```bash
# Format code
forge fmt

# Lint (if configured)
forge lint

# Check dependencies
./script/check-dependencies.sh
```

---

## 🚢 Deployment

### Base Mainnet Deployment

```bash
# Import wallet using cast (interactive mode)
cast wallet import PRIVATE_KEY --interactive

# Set environment variables
export OWNER=<owner_address>
export USDC_TOKEN=0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913
export AAVE_POOL=0xA238Dd80C259a72e81d7e4664a9801593F98d1c5
export MORPHO_MARKET=0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb

# Deploy
forge script script/Deploy.s.sol:GnosislandDeploymentScript \
  --rpc-url https://mainnet.base.org \
  --broadcast \
  --verify \
  -vvvv
```

See [DEPLOYMENT.md](DEPLOYMENT.md) for complete deployment instructions.

---

## 🔒 Security

### Security Features

- ✅ **Reentrancy Guards**: All critical functions protected
- ✅ **Access Control**: Role-based permissions (Ownable pattern)
- ✅ **Upgradeable Contracts**: UUPS pattern for safe upgrades
- ✅ **Input Validation**: Comprehensive parameter checks
- ✅ **Invariant Testing**: 8 critical invariants tested
- ✅ **Donation Attack Protection**: Vault protected against manipulation

### Security Tools

- **Forge Audit**: Dependency vulnerability scanning
- **GitHub Actions**: Automated security checks in CI/CD
- **Dependabot**: Automated dependency updates
- **Comprehensive Tests**: 110+ tests covering edge cases

### Reporting Vulnerabilities

See [SECURITY.md](SECURITY.md) for our security policy and how to report vulnerabilities.

---

## 📈 Business Model

### Target Markets

- **Primary**: Argentina & Turkey (teacher unemployment focus)
- **Secondary**: Global expansion

### Revenue Streams

1. **Protocol Fees**: 5-10% of course sales
2. **Yield on Staked Funds**: Protocol earns yield on staker fees
3. **Future**: Premium features, enterprise partnerships

### Value Propositions

- **For Teachers**: 
  - Earn from home
  - Keep 80-90% of course revenue
  - Receive yield on GlUSD payments
  
- **For Students**:
  - Affordable courses (25 USDC minimum)
  - Up to 50% discounts available
  - Earn yield on deposits
  
- **For Ecosystem**:
  - Sustainable yield generation
  - Transparent fee structure
  - Community governance

---

## 🧪 Testing

### Test Coverage

- ✅ **110+ Tests**: Comprehensive test suite
- ✅ **Invariant Testing**: 8 critical business logic invariants
- ✅ **Security Tests**: Reentrancy, donation attacks, access control
- ✅ **Integration Tests**: Base mainnet fork tests
- ✅ **Gas Optimization**: Gas snapshots tracked

### Running Tests

```bash
# All tests
forge test

# Invariant tests
forge test --match-path test/Invariants.t.sol

# Security tests
forge test --match-path test/SecurityTests.t.sol

# Base mainnet fork tests
forge test --match-contract BaseMainnetForkTest
```

---

## 🤝 Contributing

We welcome contributions! Please see our contributing guidelines:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

### Development Guidelines

- Follow Solidity style guide
- Write comprehensive tests
- Update documentation
- Ensure all tests pass
- Run `forge fmt` before committing

---

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

**Important**: This software is provided "as is" without warranty. See LICENSE for full disclaimer.

---

## 🌐 Links & Resources

- **Base Network**: [base.org](https://base.org)
- **Aave v3**: [aave.com](https://aave.com)
- **Morpho Blue**: [morpho.org](https://morpho.org)
- **OpenZeppelin**: [openzeppelin.com](https://openzeppelin.com)
- **Foundry Book**: [book.getfoundry.sh](https://book.getfoundry.sh)

---

## 📞 Contact & Support

- **Issues**: [GitHub Issues](https://github.com/yourusername/gnosisland/issues)
---

<div align="center">

### ⭐ Star us on GitHub if you find this project useful!

**Built with ❤️ for the decentralized education revolution**

[⬆ Back to Top](#-gnosisland)

</div>
