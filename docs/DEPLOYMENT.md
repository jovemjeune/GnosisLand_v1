# Deployment Guide

This guide explains how to deploy the Gnosisland smart contracts to Base mainnet.

## Prerequisites

1. **Foundry**: Install [Foundry](https://book.getfoundry.sh/getting-started/installation)
2. **Environment Variables**: Set up your deployment keys and configuration
3. **Base RPC URL**: Access to Base mainnet RPC endpoint
4. **Base Mainnet Addresses**: Know the addresses for USDC, Aave, and Morpho

## Environment Variables

Create a `.env` file or export the following variables:

```bash
# Required
export PRIVATE_KEY=<your_deployer_private_key>
export OWNER=<owner_address>  # Will be set as owner of all contracts

# Base Mainnet Addresses (defaults provided)
export USDC_TOKEN=0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913
export AAVE_POOL=0xA238Dd80C259a72e81d7e4664a9801593F98d1c5
export MORPHO_MARKET=0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb

# Optional: Morpho Market Parameters
# These should be queried from Morpho's market registry on Base mainnet
export MORPHO_COLLATERAL=<collateral_token_address>
export MORPHO_ORACLE=<oracle_address>
export MORPHO_IRM=<irm_address>
export MORPHO_LLTV=<lltv_value>  # Loan-to-value ratio (e.g., 950000000000000000 for 95%)

# Optional: Discount Ballot Configuration
export MINIMUM_DEPOSIT_PER_VOTE=100000000  # 100 USDC (6 decimals)
```

## Deployment Steps

### 1. Simulate Deployment (Recommended)

Before deploying to mainnet, simulate the deployment:

```bash
forge script script/Deploy.s.sol:GnosislandDeploymentScript \
  --fork-url https://mainnet.base.org \
  -vvvv
```

This will show you:
- All contract addresses that will be deployed
- Gas estimates
- Any potential errors

### 2. Deploy to Base Mainnet

```bash
forge script script/Deploy.s.sol:GnosislandDeploymentScript \
  --rpc-url https://mainnet.base.org \
  --broadcast \
  --verify \
  -vvvv
```

### 3. Deploy to Base Sepolia (Testnet)

For testing on testnet:

```bash
# Update environment variables for testnet addresses
export USDC_TOKEN=<testnet_usdc_address>
export AAVE_POOL=<testnet_aave_address>
export MORPHO_MARKET=<testnet_morpho_address>

forge script script/Deploy.s.sol:GnosislandDeploymentScript \
  --rpc-url https://sepolia.base.org \
  --broadcast \
  --verify \
  -vvvv
```

## Deployment Order

The script deploys contracts in the following order:

1. **GlUSD** (with temporary treasury, updated later)
2. **EscrowNFT** (for referral codes)
3. **TeacherNFT** (for teacher authentication)
4. **TreasuryContract** (central treasury and yield management)
5. **Update GlUSD** (set correct treasury address)
6. **Vault** (ERC4626 vault for GlUSD staking)
7. **Set Morpho Market Parameters** (if provided)
8. **CertificateFactory** (for creating certificate contracts)
9. **LessonFactory** (for creating lesson contracts)
10. **Update TreasuryContract** (authorize LessonFactory)
11. **DiscountBallot** (for governance voting)

## Post-Deployment Checklist

After deployment, verify and configure:

- [ ] **Verify Contracts**: Verify all contracts on BaseScan
- [ ] **Transfer Ownership**: Transfer ownership to multisig/DAO if needed
- [ ] **Set Morpho Parameters**: If not set during deployment, configure Morpho market parameters
- [ ] **Initialize First Teacher**: Mint first TeacherNFT
- [ ] **Test Deposits**: Test USDC deposits and GlUSD minting
- [ ] **Test Staking**: Test GlUSD staking to Vault
- [ ] **Test Lesson Creation**: Create a test lesson via LessonFactory
- [ ] **Test Lesson Purchase**: Purchase a lesson and verify fee distribution
- [ ] **Monitor**: Set up monitoring for contract events

## Contract Addresses

After deployment, save the following addresses:

```
GlUSD Proxy: <address>
EscrowNFT Proxy: <address>
TeacherNFT Proxy: <address>
TreasuryContract Proxy: <address>
Vault: <address>
CertificateFactory: <address>
LessonFactory: <address>
DiscountBallot Proxy: <address>
```

## Troubleshooting

### Common Issues

1. **Insufficient Gas**: Ensure deployer has enough ETH for gas
2. **Verification Fails**: Check that Etherscan API key is set correctly
3. **Morpho Parameters**: If Morpho staking fails, verify market parameters are correct
4. **Ownership Issues**: Ensure OWNER address is correct and has proper permissions

### Getting Morpho Market Parameters

To find the correct Morpho market parameters on Base mainnet:

1. Visit [Morpho Blue Markets](https://app.morpho.org/)
2. Find the USDC market
3. Query the market parameters using Morpho's registry contract
4. Set the environment variables accordingly

## Security Considerations

⚠️ **Important Security Notes**:

1. **Private Key Security**: Never commit private keys to version control
2. **Owner Address**: Use a multisig or DAO for the owner address in production
3. **Verification**: Always verify contracts on block explorers
4. **Audit**: Complete security audit before mainnet deployment
5. **Gradual Rollout**: Consider deploying to testnet first, then mainnet with limited functionality

## Support

For issues or questions:
- Check the [README.md](README.md) for general information
- Review [SECURITY.md](SECURITY.md) for security best practices
- Open an issue on GitHub for bugs or feature requests

---

**Last Updated**: 2025


