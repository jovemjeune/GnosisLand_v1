# Visual Summary

A high-level visual overview of the Gnosisland ecosystem.

## System Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                    GNOSISLAND ECOSYSTEM                          │
│              Decentralized Learning + DeFi Platform              │
└─────────────────────────────────────────────────────────────────┘
                              │
        ┌─────────────────────┼─────────────────────┐
        │                     │                     │
        ▼                     ▼                     ▼
   ┌─────────┐          ┌──────────┐          ┌─────────┐
   │Students │          │ Teachers │          │Referrers│
   │         │          │          │          │         │
   │ • Buy   │          │ • Create │          │ • Share │
   │   Courses│          │   Courses│          │   Codes │
   │ • Earn  │          │ • Earn   │          │ • Earn  │
   │   Yield │          │   Revenue│          │   Rewards│
   └────┬────┘          └────┬─────┘          └────┬────┘
        │                    │                     │
        │ 1. Deposit USDC    │ 2. Create Course   │ 3. Share Code
        │ 2. Get GlUSD       │ 3. Set Price       │
        │ 3. Stake to Vault  │ 4. Earn Yield       │
        │ 4. Earn Yield      │                     │
        │                    │                     │
        ▼                    ▼                     ▼
┌───────────────────────────────────────────────────────────┐
│              LESSON MARKETPLACE (LessonNFT)                 │
│                                                             │
│  Features:                                                  │
│  • Purchase with USDC or GlUSD                             │
│  • 50% Coupon Discounts                                   │
│  • 10% Referral Discounts                                 │
│  • Automatic Certificate Minting                          │
│  • Minimum Price: 25 USDC                                 │
│                                                             │
│  Fee Distribution:                                         │
│  • Protocol: 10%                                          │
│  • Staker: 10% (or Referrer: 10%)                        │
│  • Teacher: 80%                                           │
└───────────────────────────────────────────────────────────┘
        │                    │                     │
        │                    │                     │
        ▼                    ▼                     ▼
┌───────────────────────────────────────────────────────────┐
│         TREASURY CONTRACT (Central Fund Manager)            │
│                                                             │
│  Functions:                                                 │
│  • Receives 10% fees from purchases                       │
│  • Mints GlUSD 1:1 with USDC deposits                      │
│  • Stakes 90% to Morpho, 10% to Aave                      │
│  • Distributes yield to GlUSD holders                      │
│  • Manages protocol vs staker fund separation              │
│                                                             │
│  DeFi Integration:                                         │
│  • Morpho Blue: 90% allocation                            │
│  • Aave v3: 10% allocation                                 │
│  • Average APY: ~6.25%                                     │
└───────────────────────────────────────────────────────────┘
        │                    │
        │                    │
        ▼                    ▼
┌──────────────────┐  ┌──────────────────┐
│  VAULT (ERC4626) │  │  CERTIFICATE NFT  │
│                  │  │                  │
│  • GlUSD Staking │  │  • Soulbound     │
│  • Share Tracking│  │  • Per-Teacher   │
│  • Yield Claims  │  │  • Custom Meta   │
│  • Donation      │  │  • Auto-Minted   │
│    Protection    │  │                  │
└──────────────────┘  └──────────────────┘
```

## Token Flow

```
USDC Deposit
    │
    ▼
TreasuryContract
    │
    ├─── Mint GlUSD (1:1)
    │
    ├─── Stake 90% → Morpho Blue
    │
    └─── Stake 10% → Aave v3
            │
            ▼
        Yield Accrues (~6.25% APY)
            │
            ▼
        GlUSD Value Increases
            │
            ▼
        Users Claim Yield
```

## Purchase Flow

```
Student Wants Course
    │
    ▼
Check Discounts
    ├─── Coupon Code? → 50% off
    └─── Referral Code? → 10% off
    │
    ▼
Calculate Final Price
    │
    ├─── Minimum: 25 USDC
    │
    ▼
Pay with USDC or GlUSD
    │
    ▼
Fee Distribution
    ├─── 10% → Protocol (TreasuryContract)
    ├─── 10% → Staker Fund (or Referrer)
    └─── 80% → Teacher
    │
    ▼
Mint Soulbound NFT to Student
    │
    ▼
Mint Certificate NFT
    │
    ▼
Course Access Granted
```

## Referral Flow

```
Referrer Creates Code
    │
    ▼
Share Code with Students
    │
    ▼
Student Uses Code
    │
    ▼
Purchase Made
    │
    ├─── Student: 10% discount
    ├─── Referrer: 3% reward
    └─── Reward Auto-Staked
    │
    ▼
Referrer Earns Yield
    │
    ▼
Can Withdraw After 1 Day
```

## DeFi Integration

```
TreasuryContract Receives Fees
    │
    ▼
Split Funds
    ├─── 90% → Morpho Blue
    │    │
    │    └─── USDC Market
    │         │
    │         └─── Yield: ~6.5% APY
    │
    └─── 10% → Aave v3
         │
         └─── USDC Pool
              │
              └─── Yield: ~5% APY
    │
    ▼
Average Yield: ~6.25% APY
    │
    ▼
Distributed to GlUSD Holders
```

## Security Architecture

```
┌─────────────────────────────────────┐
│         Security Layers              │
├─────────────────────────────────────┤
│ 1. Reentrancy Guards                 │
│ 2. Access Control (Ownable)          │
│ 3. Input Validation                  │
│ 4. Upgrade Safety (UUPS)             │
│ 5. Donation Attack Protection        │
│ 6. Fund Separation                   │
│ 7. Lock Periods                      │
│ 8. Emergency Pause                   │
└─────────────────────────────────────┘
```

## Contract Relationships

```
LessonFactory
    │
    └─── Creates → LessonNFT
            │
            ├─── Uses → TreasuryContract
            ├─── Uses → TeacherNFT
            ├─── Uses → CertificateFactory
            └─── Uses → EscrowNFT (referrals)

TreasuryContract
    │
    ├─── Mints → GlUSD
    ├─── Integrates → Aave Pool
    ├─── Integrates → Morpho Market
    └─── Manages → Vault

Vault
    │
    └─── Uses → GlUSD (as asset)
        └─── Tracks → TreasuryContract

CertificateFactory
    │
    └─── Creates → CertificateNFT (per teacher)
```

## Key Metrics

- **Minimum Course Price**: 25 USDC
- **Coupon Discount**: 50%
- **Referral Discount**: 10%
- **Protocol Fee**: 10%
- **Referral Reward**: 3% of purchase
- **Yield APY**: ~6.25% (average)
- **Stake Lock Period**: 1 day
- **DeFi Allocation**: 90% Morpho, 10% Aave

## Network Information

- **Target Network**: Base Mainnet
- **Chain ID**: 8453
- **RPC URL**: `https://mainnet.base.org`
- **USDC Address**: `0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913`
- **Aave Pool**: `0xA238Dd80C259a72e81d7e4664a9801593F98d1c5`
- **Morpho Blue**: `0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb`

