# Gnosisland System Architecture

## Overview Diagram

```mermaid
graph TB
    subgraph "Users"
        Student[Student]
        Teacher[Teacher]
        Referrer[Referrer]
    end
    
    subgraph "Core Contracts"
        LessonNFT[LessonNFT<br/>Course Marketplace]
        TeacherNFT[TeacherNFT<br/>Teacher Auth]
        EscrowNFT[EscrowNFT<br/>Referral Codes]
        LessonFactory[LessonFactory<br/>Create Courses]
        CertificateFactory[CertificateFactory<br/>Create Certificates]
        CertificateNFT[CertificateNFT<br/>Per Teacher]
    end
    
    subgraph "Financial Layer"
        TreasuryContract[TreasuryContract<br/>Fund Management]
        GlUSD[GlUSD Token<br/>1:1 with USDC]
        Vault[Vault<br/>ERC4626 Staking]
    end
    
    subgraph "DeFi Protocols"
        Morpho[Morpho<br/>90% Allocation]
        Aave[Aave<br/>10% Allocation]
    end
    
    Student -->|Purchase Course| LessonNFT
    Teacher -->|Create Course| LessonFactory
    Teacher -->|Authenticate| TeacherNFT
    Referrer -->|Generate Code| EscrowNFT
    
    LessonNFT -->|Mint Certificate| CertificateFactory
    CertificateFactory -->|Get/Create| CertificateNFT
    CertificateNFT -->|Soulbound NFT| Student
    
    LessonNFT -->|Fees| TreasuryContract
    LessonNFT -->|GlUSD Payment| GlUSD
    
    Student -->|Deposit USDC| TreasuryContract
    TreasuryContract -->|Mint 1:1| GlUSD
    Student -->|Stake GlUSD| Vault
    Vault -->|Track Shares| TreasuryContract
    
    TreasuryContract -->|Stake Assets| Morpho
    TreasuryContract -->|Stake Assets| Aave
    
    TreasuryContract -->|Yield| Vault
    Vault -->|Claim Yield| Student
```

## Contract Interaction Flow

```mermaid
sequenceDiagram
    participant S as Student
    participant L as LessonNFT
    participant T as TreasuryContract
    participant G as GlUSD
    participant V as Vault
    participant M as Morpho/Aave
    
    Note over S,M: Deposit & Staking Flow
    S->>T: depositUSDC(amount)
    T->>G: mint(amount) 1:1
    T->>T: track underlyingBalanceOf
    G-->>S: GlUSD tokens
    
    S->>V: deposit(glusdAmount)
    V->>T: trackGlUSDShare(shares)
    V-->>S: vGlUSD shares
    
    Note over S,M: Lesson Purchase Flow
    S->>L: buyLesson(lessonId, coupon, referral)
    L->>T: receiveTreasuryFee(fees)
    T->>T: track protocolFunds
    T->>M: stakeAssets(yield portion)
    L->>G: handleGlUSDPayment(teacherAmount)
    G-->>Teacher: GlUSD transfer
    
    Note over S,M: Withdrawal Flow
    S->>V: withdraw(assets)
    V->>T: handleVaultWithdraw(user, shares, usdc)
    T->>G: burn(glusdShares)
    T->>M: requestFromProtocols(share%)
    T->>S: transfer USDC
    
    Note over S,M: Claim Yield Flow
    S->>T: claim(amount)
    T->>T: getClaimableAmount(share%)
    T->>M: requestFromProtocols(share%)
    T->>S: transfer USDC yield
```

## Fee Distribution Flow

```mermaid
flowchart TD
    Purchase[Lesson Purchase<br/>$100]
    
    Purchase -->|No Discount| NormalFees[Normal Purchase]
    Purchase -->|Referral Code| ReferralFees[Referral Purchase]
    Purchase -->|Coupon Code| CouponFees[Coupon Purchase]
    
    NormalFees -->|20%| Treasury20[$20 to Treasury]
    NormalFees -->|80%| Teacher80[$80 to Teacher]
    
    ReferralFees -->|10%| Referrer10[$10 to Referrer]
    ReferralFees -->|10%| Treasury10[$10 to Treasury]
    ReferralFees -->|80%| Teacher80Ref[$80 to Teacher]
    
    CouponFees -->|10%| Treasury10Coupon[$10 to Treasury]
    CouponFees -->|90%| Teacher90[$90 to Teacher]
    
    Treasury20 -->|50/50 Split| Protocol10[$10 Protocol Funds]
    Treasury20 -->|50/50 Split| Stakers10[$10 Staked for Yield]
    
    Treasury10 -->|100%| Protocol10Ref[$10 Protocol Funds]
    
    Treasury10Coupon -->|50/50 Split| Protocol5[$5 Protocol Funds]
    Treasury10Coupon -->|50/50 Split| Stakers5[$5 Staked for Yield]
    
    Referrer10 -->|100%| ReferrerStake[Staked 90% Morpho<br/>10% Aave]
    Referrer10 -->|1:1 Mint| ReferrerGlUSD[GlUSD Minted]
    
    Stakers10 -->|90% Morpho<br/>10% Aave| YieldPool[Yield Pool]
    Stakers5 -->|90% Morpho<br/>10% Aave| YieldPool
    
    YieldPool -->|Proportional| VaultUsers[Vault Stakers]
```

## Data Flow: User Deposit to Yield Claim

```mermaid
stateDiagram-v2
    [*] --> DepositUSDC: User deposits $100 USDC
    
    DepositUSDC --> MintGlUSD: TreasuryContract
    MintGlUSD --> UserHasGlUSD: 100 GlUSD minted 1:1
    UserHasGlUSD --> TrackBalance: underlyingBalanceOf = $100
    
    TrackBalance --> StakeToVault: User stakes 100 GlUSD
    StakeToVault --> TrackShares: GlUSD_shareOf = vault shares
    TrackShares --> EligibleForYield: User now eligible for yield
    
    EligibleForYield --> YieldAccrues: Yield accrues from Morpho/Aave
    YieldAccrues --> CheckClaimable: User checks claimable amount
    
    CheckClaimable --> CalculateShare: Calculate share percentage
    CalculateShare --> DetermineProtocol: Share > 90%: Both<br/>Share >= 10%: Morpho<br/>Share < 10%: Aave
    
    DetermineProtocol --> RequestYield: Request from protocols
    RequestYield --> ClaimYield: User claims yield
    ClaimYield --> [*]
    
    EligibleForYield --> Withdraw: User withdraws
    Withdraw --> BurnGlUSD: Burn GlUSD from Treasury
    BurnGlUSD --> RequestUSDC: Request USDC from protocols
    RequestUSDC --> SendUSDC: Send USDC to user
    SendUSDC --> [*]
```

## Referral System Flow

```mermaid
graph LR
    subgraph "Referrer"
        R[Referrer]
        R -->|Create| EscrowNFT[EscrowNFT<br/>Generate Code]
        EscrowNFT -->|NFT Minted| Code[Referral Code<br/>bytes32]
    end
    
    subgraph "New User"
        NU[New User]
        Code -->|Use Code| NU
        NU -->|Purchase| LessonNFT[LessonNFT<br/>First Purchase]
    end
    
    subgraph "Fee Distribution"
        LessonNFT -->|10% Referrer<br/>10% Protocol<br/>80% Teacher| Fees[Fee Split]
        Fees -->|$10| ReferrerReward[Referral Reward]
        Fees -->|$10| ProtocolFee[Protocol Fee]
    end
    
    subgraph "Referrer Benefits"
        ReferrerReward -->|1:1 Mint| ReferrerGlUSD[100 GlUSD Minted]
        ReferrerReward -->|Track| UnderlyingBalance[underlyingBalanceOf += $10]
        ReferrerReward -->|Stake| Staking[90% Morpho<br/>10% Aave]
        Staking -->|Lock 1 Day| Locked[Locked Stake]
        Locked -->|After 1 Day| Withdrawable[Withdrawable]
    end
    
    ReferrerGlUSD -->|Optional| VaultStake[Stake to Vault]
    VaultStake -->|Earn Yield| Yield[Yield Earnings]
```

## Protocol Funds Separation

```mermaid
graph TD
    subgraph "TreasuryContract Balance"
        TotalBalance[Total USDC Balance]
    end
    
    TotalBalance -->|Separated| ProtocolFunds[protocolFunds<br/>Never Mixed]
    TotalBalance -->|Separated| StakerFunds[Staker Funds<br/>Available for Claims]
    
    ProtocolFunds -->|Source| ReferralFees[Referral Fees<br/>10%]
    ProtocolFunds -->|Source| NormalFees[Normal Fees<br/>10%]
    ProtocolFunds -->|Source| CouponFees[Coupon Fees<br/>5%]
    
    StakerFunds -->|Source| StakerPortion[Staker Portion<br/>10% or 5%]
    StakerFunds -->|Source| UserDeposits[User Deposits]
    StakerFunds -->|Source| ReferralRewards[Referral Rewards]
    
    StakerFunds -->|Available| Claimable[Claimable by Users]
    StakerFunds -->|Staked| MorphoAave[Morpho/Aave]
    
    ProtocolFunds -->|Never Used| Protected[Protected<br/>Not for Claims]
```

## Share Percentage Logic

```mermaid
flowchart TD
    UserShare[User's GlUSD_shareOf]
    TotalShares[Total Vault Shares]
    
    UserShare --> Calculate[Calculate Share %<br/>sharePercent = userShare * 100 / totalShares]
    
    Calculate --> Check90{Share > 90%?}
    Check90 -->|Yes| BothProtocols[Check Both<br/>Morpho + Aave]
    Check90 -->|No| Check10{Share >= 10%?}
    
    Check10 -->|Yes| MorphoOnly[Check Morpho Only]
    Check10 -->|No| AaveOnly[Check Aave Only]
    
    BothProtocols --> RequestBoth[Request from Both<br/>50% Morpho<br/>50% Aave]
    MorphoOnly --> RequestMorpho[Request from Morpho<br/>100%]
    AaveOnly --> RequestAave[Request from Aave<br/>100%]
    
    RequestBoth --> Claim[User Claims Yield]
    RequestMorpho --> Claim
    RequestAave --> Claim
```

## Complete User Journey

```mermaid
journey
    title Student Journey: From Deposit to Course Purchase
    section Deposit
      Deposit USDC: 5: Student
      Receive GlUSD: 5: Student
      Track Balance: 4: TreasuryContract
    section Staking
      Stake to Vault: 5: Student
      Track Shares: 4: Vault
      Eligible for Yield: 5: Student
    section Course Purchase
      Browse Courses: 4: Student
      Use Referral Code: 5: Student
      Purchase Course: 5: Student
      Receive NFT: 5: Student
    section Yield
      Yield Accrues: 4: Protocols
      Check Claimable: 4: Student
      Claim Yield: 5: Student
    section Withdrawal
      Request Withdraw: 4: Student
      Burn GlUSD: 3: TreasuryContract
      Receive USDC: 5: Student
```

## Contract State Tracking

```mermaid
graph TB
    subgraph "TreasuryContract State"
        UB[underlyingBalanceOf<br/>User => USDC Amount<br/>1:1 with GlUSD]
        GS[GlUSD_shareOf<br/>User => Vault Shares<br/>Only if staked]
        PF[protocolFunds<br/>Separated Protocol Funds<br/>Never Mixed]
    end
    
    subgraph "Vault State"
        VS[GlUSD_shareOf<br/>User => Shares in Vault<br/>Tracked by Treasury]
        TS[Total Supply<br/>Including Virtual Shares<br/>Donation Protection]
    end
    
    subgraph "User Flow"
        Deposit[Deposit USDC] --> UB
        Mint[Mint GlUSD 1:1] --> UB
        Stake[Stake to Vault] --> GS
        Stake --> VS
        Withdraw[Withdraw] --> UB
        Withdraw --> GS
        Claim[Claim Yield] --> GS
    end
    
    UB -.->|1:1 Ratio| GlUSDBalance[GlUSD Balance]
    GS -.->|Proportional| YieldAmount[Yield Amount]
```

## Security Features Diagram

```mermaid
graph TB
    subgraph "Reentrancy Protection"
        RG1[ReentrancyGuard<br/>Vault]
        RG2[ReentrancyGuard<br/>TreasuryContract]
    end
    
    subgraph "Donation Attack Protection"
        VS[Virtual Shares<br/>1e18]
        VA[Virtual Assets<br/>1e18]
        VS --> Protection[Price Manipulation<br/>Prevention]
        VA --> Protection
    end
    
    subgraph "Access Control"
        OnlyOwner[onlyOwner<br/>Critical Functions]
        OnlyVault[Only Vault<br/>trackGlUSDShare]
        OnlyLessonNFT[Only LessonNFT<br/>receiveTreasuryFee]
    end
    
    subgraph "Fund Separation"
        ProtocolFunds[protocolFunds<br/>Tracked Separately]
        StakerFunds[Staker Funds<br/>Available Balance]
        ProtocolFunds -.->|Never Mixed| Separation[Complete Separation]
        StakerFunds -.->|Never Mixed| Separation
    end
    
    subgraph "Pause Mechanism"
        Pause[Pause Function<br/>Emergency Stop]
        Unpause[Unpause Function<br/>Resume Operations]
    end
```

