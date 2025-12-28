# Gnosis Land Visual System Summary

## Quick Reference: System Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                        GNOSIS LAND PLATFORM                        │
└─────────────────────────────────────────────────────────────────┘
                              │
        ┌─────────────────────┼─────────────────────┐
        │                     │                     │
        ▼                     ▼                     ▼
   ┌─────────┐          ┌──────────┐          ┌─────────┐
   │Students │          │ Teachers │          │Referrers│
   └────┬────┘          └────┬─────┘          └────┬────┘
        │                    │                     │
        │                    │                     │
        ▼                    ▼                     ▼
┌───────────────────────────────────────────────────────────┐
│              LESSON MARKETPLACE (LessonNFT)                │
│  • Course Purchase                                         │
│  • Coupon Codes (50% discount)                            │
│  • Referral Codes (10% discount)                           │
│  • USDC or GlUSD Payment                                   │
│  • Automatic Certificate Minting                            │
└───────────────────────────────────────────────────────────┘
        │                    │                     │
        │                    │                     │
        ▼                    ▼                     ▼
┌───────────────────────────────────────────────────────────┐
│         CERTIFICATE SYSTEM                                 │
│  • CertificateFactory (Creates per-teacher contracts)      │
│  • CertificateNFT (Soulbound, custom metadata)             │
│  • Optional metadata per lesson                            │
└───────────────────────────────────────────────────────────┘
        │                    │                     │
        │                    │                     │
        ▼                    ▼                     ▼
┌───────────────────────────────────────────────────────────┐
│           TREASURY CONTRACT (Fund Manager)                 │
│  • Receives fees (10-20%)                                  │
│  • Separates protocol funds                                │
│  • Mints GlUSD 1:1                                         │
│  • Tracks underlyingBalanceOf                              │
│  • Manages yield distribution                              │
└───────────────────────────────────────────────────────────┘
        │                    │
        │                    │
        ▼                    ▼
┌──────────────────┐  ┌──────────────────┐
│   GlUSD Token    │  │  Vault (ERC4626) │
│  1:1 with USDC   │  │  Staking Pool    │
│  Yield-bearing   │  │  Share Tracking  │
└──────────────────┘  └──────────────────┘
        │                    │
        │                    │
        └──────────┬─────────┘
                   │
                   ▼
        ┌──────────────────┐
        │  DeFi Protocols  │
        │  90% Morpho      │
        │  10% Aave        │
        └──────────────────┘
```

## Money Flow Diagram

```
STUDENT DEPOSIT FLOW:
┌────────┐    100 USDC    ┌──────────────┐    100 GlUSD    ┌────────┐
│Student │ ──────────────> │  Treasury    │ ──────────────> │Student │
└────────┘                 │  Contract    │                 └───┬────┘
                           └──────────────┘                     │
                                                                 │
                           ┌──────────────┐                     │
                           │    Vault     │ <───────────────────┘
                           │  (ERC4626)   │    Stake GlUSD
                           └──────┬───────┘
                                  │
                                  │ Track Shares
                                  │
                           ┌──────▼───────┐
                           │  Treasury    │
                           │  GlUSD_shareOf│
                           └──────────────┘

LESSON PURCHASE FLOW ($100 Course):
┌────────┐
│Student │
└───┬────┘
    │ $100 Payment
    ▼
┌──────────────┐
│  LessonNFT   │
└───┬──────────┘
    │
    ├─> $80 ──────> Teacher
    ├─> $10 ──────> Protocol Funds (Treasury)
    └─> $10 ──────> Stakers Pool (Morpho/Aave)

WITH REFERRAL ($100 Course, 10% discount):
┌────────┐
│Student │
└───┬────┘
    │ $90 Payment (10% off)
    ▼
┌──────────────┐
│  LessonNFT   │
└───┬──────────┘
    │
    ├─> $72 ──────> Teacher (80%)
    ├─> $9  ──────> Protocol Funds (10%)
    └─> $9  ──────> Referrer (10% → Staked)

WITH COUPON ($100 Course, 50% discount):
┌────────┐
│Student │
└───┬────┘
    │ $85 Payment (15% off)
    ▼
┌──────────────┐
│  LessonNFT   │
└───┬───────────┘
    │
    ├─> $76.50 ───> Teacher (90%)
    ├─> $4.25 ────> Protocol Funds (5%)
    └─> $4.25 ────> Stakers Pool (5%)
```

## State Machine: User Journey

```
                    START
                      │
                      ▼
            ┌─────────────────┐
            │  No GlUSD       │
            │  No Vault Shares│
            └────────┬────────┘
                     │
         depositUSDC(100 USDC)
                     │
                     ▼
            ┌─────────────────┐
            │  100 GlUSD      │
            │  underlyingBalanceOf = 100│
            └────────┬────────┘
                     │
         deposit(100 GlUSD to Vault)
                     │
                     ▼
            ┌─────────────────┐
            │  Vault Shares   │
            │  GlUSD_shareOf > 0│
            │  Eligible for Yield│
            └────────┬────────┘
                     │
         ┌───────────┼───────────┐
         │           │           │
         ▼           ▼           ▼
    Purchase    Claim Yield   Withdraw
    Course       (USDC)       (USDC)
         │           │           │
         │           │           │
         ▼           ▼           ▼
    Lesson NFT   Yield      GlUSD Burned
    Minted       Claimed    USDC Received
```

## Contract Interaction Map

```
                    ┌──────────────┐
                    │  LessonNFT   │
                    └──────┬───────┘
                           │
        ┌──────────────────┼──────────────────┐
        │                  │                  │
        ▼                  ▼                  ▼
┌──────────────┐  ┌──────────────┐  ┌──────────────┐
│TreasuryContract│ │  GlUSD      │  │  TeacherNFT  │
│                │ │             │  │              │
│• receiveTreasuryFee│ │• mint()    │  │• ownerOf()  │
│• handleGlUSDPayment│ │• burn()    │  │• balanceOf()│
│• trackGlUSDShare   │ │• transfer()│  │              │
│• handleVaultWithdraw│ └──────────────┘  └──────────────┘
│• getClaimableAmount│
│• claim()           │
└────────┬───────────┘
         │
    ┌────┴────┐
    │         │
    ▼         ▼
┌────────┐ ┌──────────┐
│ Vault  │ │ EscrowNFT│
│        │ │          │
│• deposit│ │• validateReferralCode│
│• withdraw│ └──────────┘
│• redeem │
└───┬────┘
    │
    │ trackGlUSDShare()
    │
    ▼
┌──────────────┐
│TreasuryContract│
│GlUSD_shareOf │
└──────────────┘
```

## Fee Distribution Visual

```
                    $100 Lesson Purchase
                            │
        ┌───────────────────┼───────────────────┐
        │                   │                   │
   NO DISCOUNT          REFERRAL            COUPON
        │                   │                   │
        ▼                   ▼                   ▼
   ┌────────┐         ┌────────┐         ┌────────┐
   │$100    │         │$90    │         │$85    │
   │(0% off)│         │(10% off)│       │(15% off)│
   └───┬────┘         └───┬────┘         └───┬────┘
       │                 │                 │
       │                 │                 │
   ┌───┴───┐         ┌───┴───┐         ┌───┴───┐
   │       │         │       │         │       │
   ▼       ▼         ▼       ▼         ▼       ▼
$80    $20      $72    $18      $76.50  $8.50
Teacher Treasury  Teacher Treasury   Teacher Treasury
       │                 │                 │
       │                 │                 │
   ┌───┴───┐         ┌───┴───┐         ┌───┴───┐
   │       │         │       │         │       │
   ▼       ▼         ▼       ▼         ▼       ▼
$10    $10      $9     $9       $4.25  $4.25
Protocol Stakers  Protocol Referrer  Protocol Stakers
Funds    Pool     Funds    Reward    Funds    Pool
```

## Yield Claim Logic Flowchart

```
                    User Calls claim()
                           │
                           ▼
              ┌────────────────────┐
              │ getClaimableAmount │
              └──────────┬──────────┘
                         │
                         ▼
              ┌────────────────────┐
              │ Get userShare      │
              │ Get totalShares    │
              └──────────┬──────────┘
                         │
                         ▼
              ┌────────────────────┐
              │ Calculate sharePercent│
              │ = (userShare*100)/total│
              └──────────┬──────────┘
                         │
        ┌────────────────┼────────────────┐
        │                │                │
        ▼                ▼                ▼
   sharePercent    sharePercent    sharePercent
      > 90%          >= 10%          < 10%
        │                │                │
        ▼                ▼                ▼
   Check Both      Check Morpho      Check Aave
   (50/50 split)   (100%)           (100%)
        │                │                │
        └────────────────┼────────────────┘
                         │
                         ▼
              ┌────────────────────┐
              │ Calculate yield   │
              │ userClaimable =   │
              │ (yield*userShare)/total│
              └──────────┬──────────┘
                         │
                         ▼
              ┌────────────────────┐
              │ Check availableUSDC│
              │ = balance - protocolFunds│
              └──────────┬──────────┘
                         │
                         ▼
              ┌────────────────────┐
              │ Transfer USDC       │
              │ to user             │
              └────────────────────┘
```

## Security Layers

```
┌─────────────────────────────────────────┐
│         SECURITY LAYERS                 │
├─────────────────────────────────────────┤
│                                         │
│  Layer 1: Reentrancy Protection        │
│  ┌───────────────────────────────────┐ │
│  │ ReentrancyGuard on all critical   │ │
│  │ functions in Vault & Treasury      │ │
│  └───────────────────────────────────┘ │
│                                         │
│  Layer 2: Access Control                │
│  ┌───────────────────────────────────┐ │
│  │ onlyOwner: Critical functions      │ │
│  │ onlyVault: trackGlUSDShare()       │ │
│  │ onlyLessonNFT: receiveTreasuryFee()│ │
│  └───────────────────────────────────┘ │
│                                         │
│  Layer 3: Donation Attack Protection    │
│  ┌───────────────────────────────────┐ │
│  │ Virtual Shares: 1e18               │ │
│  │ Virtual Assets: 1e18               │ │
│  │ Prevents price manipulation        │ │
│  └───────────────────────────────────┘ │
│                                         │
│  Layer 4: Fund Separation               │
│  ┌───────────────────────────────────┐ │
│  │ protocolFunds tracked separately   │ │
│  │ Never mixed with staker funds     │ │
│  │ Protected from claims/withdrawals  │ │
│  └───────────────────────────────────┘ │
│                                         │
│  Layer 5: Pause Mechanism               │
│  ┌───────────────────────────────────┐ │
│  │ Emergency stop functionality      │ │
│  │ Only owner can pause/unpause      │ │
│  └───────────────────────────────────┘ │
│                                         │
└─────────────────────────────────────────┘
```

## Key Metrics Tracking

```
USER METRICS:
┌─────────────────────────────────────┐
│ underlyingBalanceOf[user]           │
│   = USDC deposited/referral rewards │
│   = 1:1 with GlUSD minted           │
└─────────────────────────────────────┘

┌─────────────────────────────────────┐
│ GlUSD_shareOf[user]                 │
│   = Shares in Vault                 │
│   = Only if user staked to Vault    │
│   = Determines yield eligibility    │
└─────────────────────────────────────┘

PROTOCOL METRICS:
┌─────────────────────────────────────┐
│ protocolFunds                       │
│   = Fees collected                 │
│   = Never used for staker operations │
│   = Separated tracking              │
└─────────────────────────────────────┘

┌─────────────────────────────────────┐
│ totalAssetsStaked                   │
│   = morphoAssets + aaveAssets       │
│   = Total in DeFi protocols         │
└─────────────────────────────────────┘
```

