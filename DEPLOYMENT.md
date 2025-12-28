# Deployment Guide

Complete guide for deploying Gnosisland contracts to Base mainnet.

## Prerequisites

### Required Tools
- [Foundry](https://book.getfoundry.sh/getting-started/installation) (latest version)
- [cast](https://book.getfoundry.sh/reference/cast/) (included with Foundry)
- Node.js (for development tools)
- Git

### Required Accounts
- Deployer account with ETH for gas
- Owner account (can be same as deployer)

### Required Information
- Base mainnet RPC URL
- Contract addresses (USDC, Aave, Morpho)
- Deployer private key (keep secure!)

## Environment Setup

### 1. Clone Repository
```bash
git clone https://github.com/jovemjeune/GnosisLand_v1.git
cd GnosisLand_v1
```

### 2. Install Dependencies
```bash
forge install
```

### 3. Build Contracts
```bash
forge build
```

### 4. Set Environment Variables

Create a `.env` file:
```bash
# Wallet Setup (use cast wallet import for security)
# cast wallet import PRIVATE_KEY --interactive

# Owner Address
OWNER=0xYourOwnerAddress

# Base Mainnet Addresses
USDC_TOKEN=0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913
AAVE_POOL=0xA238Dd80C259a72e81d7e4664a9801593F98d1c5
MORPHO_MARKET=0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb

# Base Mainnet RPC
BASE_RPC_URL=https://mainnet.base.org

# Etherscan API Key (for verification)
ETHERSCAN_API_KEY=YourEtherscanAPIKey
```

### 5. Import Wallet Securely

**⚠️ IMPORTANT**: Never commit your private key to git!

Use cast to import wallet interactively:
```bash
cast wallet import PRIVATE_KEY --interactive
```

This will prompt you for your private key securely without exposing it in command history.

## Deployment Steps

### Step 1: Verify Prerequisites

```bash
# Check Foundry version
forge --version

# Verify you're on correct network
cast chain-id --rpc-url $BASE_RPC_URL
# Should output: 8453

# Check deployer balance
cast balance $OWNER --rpc-url $BASE_RPC_URL
```

### Step 2: Run Deployment Script

```bash
forge script script/Deploy.s.sol:GnosislandDeploymentScript \
  --rpc-url $BASE_RPC_URL \
  --broadcast \
  --verify \
  -vvvv
```

### Step 3: Verify Deployment

The deployment script will output all contract addresses. Verify each contract:

```bash
# Verify GlUSD
cast code <GLUSD_ADDRESS> --rpc-url $BASE_RPC_URL

# Verify TreasuryContract
cast code <TREASURY_ADDRESS> --rpc-url $BASE_RPC_URL

# Verify Vault
cast code <VAULT_ADDRESS> --rpc-url $BASE_RPC_URL
```

## Deployment Order

The deployment script handles this automatically, but here's the order:

1. **GlUSD Token** (non-upgradeable)
2. **TreasuryContract Implementation** (logic contract)
3. **TreasuryContract Proxy** (UUPS proxy)
4. **TeacherNFT Implementation** (logic contract)
5. **TeacherNFT Proxy** (UUPS proxy)
6. **EscrowNFT Implementation** (logic contract)
7. **EscrowNFT Proxy** (UUPS proxy)
8. **CertificateFactory Implementation** (logic contract)
9. **CertificateFactory Proxy** (UUPS proxy)
10. **Vault** (non-upgradeable, ERC4626)
11. **LessonNFT Implementation** (for factory)
12. **LessonFactory** (non-upgradeable, uses constructor)

## Post-Deployment Setup

### 1. Update TreasuryContract References

After deployment, update TreasuryContract with all dependencies:

```bash
# Update Vault reference
cast send <TREASURY_PROXY> "updateVault(address)" <VAULT_ADDRESS> \
  --rpc-url $BASE_RPC_URL \
  --private-key $PRIVATE_KEY

# Update LessonNFT reference (after LessonFactory is deployed)
cast send <TREASURY_PROXY> "updateLessonNFT(address)" <LESSON_FACTORY_ADDRESS> \
  --rpc-url $BASE_RPC_URL \
  --private-key $PRIVATE_KEY
```

### 2. Configure Morpho Market Parameters

```bash
# Set Morpho market parameters
cast send <TREASURY_PROXY> "updateMorphoMarketParams((address,address,address,address,uint256))" \
  "<USDC_ADDRESS>,<USDC_ADDRESS>,<ORACLE_ADDRESS>,<IRM_ADDRESS>,<LLTV>" \
  --rpc-url $BASE_RPC_URL \
  --private-key $PRIVATE_KEY
```

**Note**: Get actual Morpho market parameters from Morpho Blue documentation.

### 3. Verify All Contracts

Verify all contracts on Base explorer:
- GlUSD
- TreasuryContract (proxy and implementation)
- TeacherNFT (proxy and implementation)
- EscrowNFT (proxy and implementation)
- CertificateFactory (proxy and implementation)
- Vault
- LessonFactory

### 4. Test Basic Functionality

```bash
# Test GlUSD minting
cast send <TREASURY_PROXY> "depositUSDC(uint256)" 1000000 \
  --rpc-url $BASE_RPC_URL \
  --private-key $PRIVATE_KEY

# Check GlUSD balance
cast call <GLUSD_ADDRESS> "balanceOf(address)" <YOUR_ADDRESS> \
  --rpc-url $BASE_RPC_URL
```

## Gas Estimation

Approximate gas costs for deployment:

| Contract | Estimated Gas |
|----------|--------------|
| GlUSD | ~2,000,000 |
| TreasuryContract (impl) | ~3,500,000 |
| TreasuryContract (proxy) | ~1,500,000 |
| TeacherNFT (impl) | ~2,000,000 |
| TeacherNFT (proxy) | ~1,500,000 |
| EscrowNFT (impl) | ~2,000,000 |
| EscrowNFT (proxy) | ~1,500,000 |
| CertificateFactory (impl) | ~2,000,000 |
| CertificateFactory (proxy) | ~1,500,000 |
| Vault | ~2,500,000 |
| LessonNFT (impl) | ~2,500,000 |
| LessonFactory | ~2,000,000 |

**Total**: ~25,000,000 gas (~0.025 ETH at 1 gwei)

## Verification

### Automatic Verification

The deployment script includes `--verify` flag which automatically verifies contracts on Base explorer.

### Manual Verification

If automatic verification fails:

```bash
forge verify-contract <CONTRACT_ADDRESS> \
  src/ContractName.sol:ContractName \
  --chain-id 8453 \
  --etherscan-api-key $ETHERSCAN_API_KEY \
  --constructor-args $(cast abi-encode "constructor(...)" <ARGS>)
```

## Troubleshooting

### Common Issues

1. **Insufficient Gas**
   - Increase gas limit
   - Check gas price
   - Ensure sufficient ETH balance

2. **Verification Fails**
   - Check Etherscan API key
   - Verify constructor arguments
   - Wait a few blocks after deployment

3. **Initialization Fails**
   - Check all addresses are correct
   - Verify contract dependencies
   - Check access control

4. **RPC Errors**
   - Verify RPC URL is correct
   - Check network connectivity
   - Try different RPC endpoint

## Security Checklist

Before deploying:

- [ ] All tests pass locally
- [ ] Contracts verified on testnet first
- [ ] Private keys secured (not in git)
- [ ] Environment variables set correctly
- [ ] Contract addresses verified
- [ ] Gas estimation checked
- [ ] Emergency pause tested
- [ ] Access control verified
- [ ] Upgrade authorization set
- [ ] Documentation reviewed

## Post-Deployment

### 1. Monitor Contracts

- Set up monitoring for contract events
- Track gas usage
- Monitor for unusual activity

### 2. Update Documentation

- Update README with deployed addresses
- Document any deployment-specific notes
- Update frontend with contract addresses

### 3. Community Announcement

- Announce deployment on social media
- Share contract addresses
- Provide usage instructions

## Rollback Plan

If issues are discovered:

1. **Pause Contracts**: Use emergency pause if available
2. **Upgrade Contracts**: Deploy fixes via UUPS upgrade
3. **Communicate**: Notify users of issues and fixes

## Support

For deployment issues:
- Check [GitHub Issues](https://github.com/jovemjeune/GnosisLand_v1/issues)
- Review deployment script logs
- Verify all prerequisites

---

**Last Updated**: 2024-12-28

