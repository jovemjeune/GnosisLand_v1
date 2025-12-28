# Gnosisland User Flows

## Flow 1: Student Deposits and Stakes

```mermaid
sequenceDiagram
    autonumber
    participant S as Student
    participant TC as TreasuryContract
    participant G as GlUSD
    participant V as Vault
    
    Note over S,V: Step 1: Deposit USDC
    S->>TC: depositUSDC(100 USDC)
    TC->>TC: Transfer USDC from student
    TC->>G: mint(student, 100 GlUSD)
    TC->>TC: underlyingBalanceOf[student] += 100
    G-->>S: 100 GlUSD
    
    Note over S,V: Step 2: Stake GlUSD to Vault
    S->>G: approve(Vault, 100 GlUSD)
    S->>V: deposit(100 GlUSD, student)
    V->>G: transferFrom(student, Vault, 100)
    V->>V: _mint(student, vaultShares)
    V->>V: GlUSD_shareOf[student] += shares
    V->>TC: trackGlUSDShare(student, shares)
    TC->>TC: GlUSD_shareOf[student] += shares
    V-->>S: vaultShares (vGlUSD)
    
    Note over S,V: Student is now eligible for yield
```

## Flow 2: Lesson Purchase with Referral

```mermaid
sequenceDiagram
    autonumber
    participant S as Student
    participant L as LessonNFT
    participant TC as TreasuryContract
    participant E as EscrowNFT
    participant T as Teacher
    participant R as Referrer
    participant G as GlUSD
    
    Note over S,G: Step 1: Validate Referral
    S->>L: buyLesson(lessonId, coupon=0, referralCode)
    L->>TC: validateReferralCode(referralCode)
    TC->>E: validateReferralCode(referralCode)
    E-->>TC: (referrer, tokenId)
    TC-->>L: (referrer, tokenId)
    
    Note over S,G: Step 2: Calculate Fees
    L->>L: finalPrice = price * 0.9 (10% discount)
    L->>L: referralReward = finalPrice * 0.1 (10%)
    L->>L: treasuryFee = finalPrice * 0.1 (10%)
    L->>L: teacherAmount = finalPrice * 0.8 (80%)
    
    Note over S,G: Step 3: Transfer Payments
    S->>L: transferFrom(USDC, finalPrice)
    L->>TC: transfer(USDC, treasuryFee + referralReward)
    L->>T: transfer(USDC, teacherAmount)
    
    Note over S,G: Step 4: Process Fees
    L->>TC: receiveTreasuryFee(treasuryFee, ..., referralReward, referrer)
    TC->>TC: protocolFunds += treasuryFee
    TC->>TC: _processReferralReward(referralReward, referrer)
    TC->>TC: underlyingBalanceOf[referrer] += referralReward
    TC->>G: mint(referrer, referralReward)
    G-->>R: GlUSD tokens
    
    Note over S,G: Step 5: Mint Lesson NFT
    L->>L: _safeMint(student, tokenId)
    L-->>S: Lesson NFT
    
    Note over S,G: Step 6: Mint Certificate NFT
    L->>CF: getOrCreateCertificateContract(teacher)
    CF-->>L: certificateContract
    L->>CNFT: mintCertificate(lessonId, student, metadata, lessonName)
    CNFT->>CNFT: _safeMint(student, tokenId)
    CNFT-->>S: Certificate NFT (Soulbound)
```

## Flow 3: GlUSD Payment for Course

```mermaid
sequenceDiagram
    autonumber
    participant S as Student
    participant L as LessonNFT
    participant TC as TreasuryContract
    participant G as GlUSD
    participant T as Teacher
    
    Note over S,T: Student pays with GlUSD
    S->>G: approve(LessonNFT, glusdAmount)
    S->>L: buyLessonWithGlUSD(lessonId, coupon, glusdAmount, referral)
    
    Note over S,T: Calculate fees
    L->>L: Calculate finalPrice, fees, teacherAmount
    
    Note over S,T: Transfer GlUSD to teacher
    L->>TC: handleGlUSDPayment(teacherAmount, student, teacher)
    TC->>G: transferFrom(student, teacher, teacherAmount)
    G-->>T: GlUSD (yield-bearing)
    
    Note over S,T: Handle fees
    L->>TC: handleGlUSDPayment(treasuryFee, student, treasury)
    TC->>G: transferFrom(student, treasury, treasuryFee)
    
    Note over S,T: Process referral if applicable
    alt Has Referral
        L->>TC: handleGlUSDPayment(referralReward, student, treasury)
        TC->>G: transferFrom(student, treasury, referralReward)
    end
    
    Note over S,T: Mint NFT
    L->>L: _safeMint(student, tokenId)
    L-->>S: Lesson NFT
```

## Flow 4: Yield Claim Process

```mermaid
sequenceDiagram
    autonumber
    participant S as Student
    participant TC as TreasuryContract
    participant V as Vault
    participant M as Morpho/Aave
    
    Note over S,M: Step 1: Check Claimable
    S->>TC: getClaimableAmount(student)
    TC->>TC: userShare = GlUSD_shareOf[student]
    TC->>V: totalSupply()
    V-->>TC: totalShares
    TC->>TC: sharePercent = (userShare * 100) / totalShares
    
    Note over S,M: Step 2: Determine Protocol
    alt sharePercent > 90%
        TC->>TC: checkBoth = true
    else sharePercent >= 10%
        TC->>TC: checkMorpho = true
    else sharePercent < 10%
        TC->>TC: checkAave = true
    end
    
    Note over S,M: Step 3: Calculate Available
    TC->>TC: availableYield = getYieldFromProtocols()
    TC->>TC: claimable = (availableYield * userShare) / totalShares
    TC->>TC: availableUSDC = balance - protocolFunds
    TC->>TC: claimable = min(claimable, availableUSDC)
    TC-->>S: claimable amount
    
    Note over S,M: Step 4: Claim Yield
    S->>TC: claim(amount)
    alt availableUSDC < amount
        TC->>M: requestFromProtocols(amount, sharePercent)
        M-->>TC: USDC
    end
    TC->>TC: availableUSDC -= amount
    TC->>S: transfer(USDC, amount)
    TC-->>S: Yield claimed
```

## Flow 5: Withdrawal Process

```mermaid
sequenceDiagram
    autonumber
    participant S as Student
    participant V as Vault
    participant TC as TreasuryContract
    participant G as GlUSD
    participant M as Morpho/Aave
    
    Note over S,M: Step 1: Request Withdrawal
    S->>V: withdraw(assets, receiver, student)
    V->>V: shares = previewWithdraw(assets)
    V->>V: _burn(student, shares)
    V->>V: GlUSD_shareOf[student] -= shares
    
    Note over S,M: Step 2: Handle Withdrawal
    V->>TC: handleVaultWithdraw(student, shares, assets, receiver)
    TC->>G: burn(student, shares)
    TC->>TC: underlyingBalanceOf[student] -= assets
    TC->>TC: GlUSD_shareOf[student] -= shares
    
    Note over S,M: Step 3: Check Share Percentage
    TC->>TC: userShare = GlUSD_shareOf[student]
    TC->>V: totalSupply()
    V-->>TC: totalShares
    TC->>TC: sharePercent = (userShare * 100) / totalShares
    
    Note over S,M: Step 4: Request from Protocols
    alt sharePercent > 90%
        TC->>M: requestFromMorpho(assets / 2)
        TC->>M: requestFromAave(assets / 2)
    else sharePercent >= 10%
        TC->>M: requestFromMorpho(assets)
    else sharePercent < 10%
        TC->>M: requestFromAave(assets)
    end
    
    Note over S,M: Step 5: Send USDC
    alt Treasury has enough
        TC->>TC: availableUSDC = balance - protocolFunds
        TC->>S: transfer(USDC, assets)
    else Need from protocols
        TC->>M: Request and wait
        M-->>TC: USDC
        TC->>S: transfer(USDC, assets)
    end
    TC-->>S: USDC received
```

## Flow 6: Teacher Creates Course

```mermaid
sequenceDiagram
    autonumber
    participant T as Teacher
    participant TN as TeacherNFT
    participant LF as LessonFactory
    participant LN as LessonNFT
    participant TC as TreasuryContract
    
    Note over T,TC: Step 1: Verify Teacher
    T->>TN: balanceOf(teacher)
    TN-->>T: tokenId (if teacher)
    
    Note over T,TC: Step 2: Create Lesson Contract
    T->>LF: createLessonNFT(teacherTokenId, price, name, data)
    LF->>TN: ownerOf(teacherTokenId)
    TN-->>LF: teacher address
    LF->>LF: Validate price >= 25 USDC
    LF->>LN: Deploy ERC1967Proxy
    LN->>LN: initialize(factory, teacher, treasury, ...)
    LN-->>LF: lessonNFT address
    LF-->>T: lessonNFT address
    
    Note over T,TC: Step 3: Create Lesson
    T->>LN: createLesson(lessonData)
    LN->>LN: lessonId = latestNFTId
    LN->>LN: nftData[lessonId] = lessonData
    LN->>LN: latestNFTId++
    LN-->>T: lessonId
```

## Flow 7: Coupon Code Creation and Usage

```mermaid
sequenceDiagram
    autonumber
    participant T as Teacher
    participant TN as TeacherNFT
    participant LN as LessonNFT
    participant S as Student
    
    Note over T,S: Step 1: Create Coupon
    T->>LN: createCouponCode(teacherTokenId)
    LN->>TN: ownerOf(teacherTokenId)
    TN-->>LN: teacher address
    LN->>LN: couponCode = keccak256(teacher, tokenId, timestamp, ...)
    LN->>LN: couponCodeCreator[couponCode] = teacher
    LN-->>T: couponCode
    
    Note over T,S: Step 2: Use Coupon
    S->>LN: buyLesson(lessonId, couponCode, payment, referral=0)
    LN->>LN: Validate couponCode
    LN->>LN: Check !couponCodesUsed[couponCode]
    LN->>LN: finalPrice = price * 0.50 (50% discount)
    LN->>LN: couponCodesUsed[couponCode] = true
    LN->>LN: treasuryFee = finalPrice * 0.1 (10% total: 5% protocol + 5% stakers)
    LN->>LN: teacherAmount = finalPrice * 0.9 (90%)
    LN->>LN: Process payment and mint NFT
    LN-->>S: Lesson NFT + 50% discount applied
```

## Flow 8: Referral Reward Staking

```mermaid
sequenceDiagram
    autonumber
    participant R as Referrer
    participant TC as TreasuryContract
    participant G as GlUSD
    participant V as Vault
    participant M as Morpho/Aave
    
    Note over R,M: Referrer receives reward
    TC->>TC: _processReferralReward(reward, referrer)
    TC->>TC: underlyingBalanceOf[referrer] += reward
    TC->>G: mint(referrer, reward)
    G-->>R: GlUSD (1:1)
    
    Note over R,M: Optional: Stake to Vault
    R->>G: approve(Vault, glusdAmount)
    R->>V: deposit(glusdAmount, referrer)
    V->>TC: trackGlUSDShare(referrer, shares)
    TC->>TC: GlUSD_shareOf[referrer] += shares
    V-->>R: Vault shares
    
    Note over R,M: Yield accrues
    M->>TC: Yield from staked assets
    TC->>TC: Yield distributed proportionally
    TC->>V: Yield increases share value
    V->>R: Share value appreciates
    
    Note over R,M: Claim yield
    R->>TC: claim(amount)
    TC->>TC: Calculate based on share percentage
    TC->>M: Request yield from protocols
    TC->>R: transfer(USDC, yield)
```

