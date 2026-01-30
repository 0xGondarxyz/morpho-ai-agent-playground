# Usage Flows

## Overview

| Operation | Function | Actors | Callback | Authorization Required |
|-----------|----------|--------|----------|------------------------|
| Supply | supply() | Any User | Optional (IMorphoSupplyCallback) | No |
| Withdraw | withdraw() | Position Owner / Authorized | No | Yes |
| Borrow | borrow() | Position Owner / Authorized | No | Yes |
| Repay | repay() | Any User | Optional (IMorphoRepayCallback) | No |
| Supply Collateral | supplyCollateral() | Any User | Optional (IMorphoSupplyCollateralCallback) | No |
| Withdraw Collateral | withdrawCollateral() | Position Owner / Authorized | No | Yes |
| Liquidate | liquidate() | Any User (Liquidator) | Optional (IMorphoLiquidateCallback) | No |
| Flash Loan | flashLoan() | Any User | Required (IMorphoFlashLoanCallback) | No |

---

## Supply Flow

Deposits loan tokens into a market and credits supply shares to the recipient.

```mermaid
sequenceDiagram
    participant User
    participant Morpho
    participant IRM
    participant Token as LoanToken

    User->>Morpho: supply(marketParams, assets, shares, onBehalf, data)

    Note over Morpho: Validations
    Morpho->>Morpho: require(market.lastUpdate != 0)
    Morpho->>Morpho: require(exactlyOneZero(assets, shares))
    Morpho->>Morpho: require(onBehalf != address(0))

    Note over Morpho: Interest Accrual
    Morpho->>IRM: borrowRate(marketParams, market)
    IRM-->>Morpho: rate
    Morpho->>Morpho: Calculate interest
    Morpho->>Morpho: Update totalBorrowAssets += interest
    Morpho->>Morpho: Update totalSupplyAssets += interest
    Morpho->>Morpho: Mint fee shares to feeRecipient

    Note over Morpho: Share Calculation
    alt assets provided (shares == 0)
        Morpho->>Morpho: shares = toSharesDown(assets)
    else shares provided (assets == 0)
        Morpho->>Morpho: assets = toAssetsUp(shares)
    end

    Note over Morpho: State Changes
    Morpho->>Morpho: position[onBehalf].supplyShares += shares
    Morpho->>Morpho: market.totalSupplyShares += shares
    Morpho->>Morpho: market.totalSupplyAssets += assets

    Morpho-->>Morpho: emit Supply(id, msg.sender, onBehalf, assets, shares)

    alt data.length > 0
        Note over Morpho,User: Callback (CEI - state already updated)
        Morpho->>User: onMorphoSupply(assets, data)
        User-->>Morpho: (user sources funds)
    end

    Note over Morpho: Token Transfer
    Morpho->>Token: safeTransferFrom(msg.sender, Morpho, assets)
    Token-->>Morpho: success

    Morpho-->>User: return (assets, shares)
```

---

## Withdraw Flow

Burns supply shares and withdraws loan tokens from the market.

```mermaid
sequenceDiagram
    participant User
    participant Morpho
    participant IRM
    participant Token as LoanToken

    User->>Morpho: withdraw(marketParams, assets, shares, onBehalf, receiver)

    Note over Morpho: Validations
    Morpho->>Morpho: require(market.lastUpdate != 0)
    Morpho->>Morpho: require(exactlyOneZero(assets, shares))
    Morpho->>Morpho: require(receiver != address(0))

    Note over Morpho: Authorization Check
    Morpho->>Morpho: _isSenderAuthorized(onBehalf)
    alt msg.sender != onBehalf
        Morpho->>Morpho: require(isAuthorized[onBehalf][msg.sender])
    end

    Note over Morpho: Interest Accrual
    Morpho->>IRM: borrowRate(marketParams, market)
    IRM-->>Morpho: rate
    Morpho->>Morpho: Accrue interest

    Note over Morpho: Share Calculation
    alt assets provided (shares == 0)
        Morpho->>Morpho: shares = toSharesUp(assets)
    else shares provided (assets == 0)
        Morpho->>Morpho: assets = toAssetsDown(shares)
    end

    Note over Morpho: State Changes
    Morpho->>Morpho: position[onBehalf].supplyShares -= shares
    Morpho->>Morpho: market.totalSupplyShares -= shares
    Morpho->>Morpho: market.totalSupplyAssets -= assets

    Note over Morpho: Liquidity Check
    Morpho->>Morpho: require(totalBorrowAssets <= totalSupplyAssets)

    Morpho-->>Morpho: emit Withdraw(id, msg.sender, onBehalf, receiver, assets, shares)

    Note over Morpho: Token Transfer
    Morpho->>Token: safeTransfer(receiver, assets)
    Token-->>Morpho: success

    Morpho-->>User: return (assets, shares)
```

---

## Borrow Flow

Creates a debt position by minting borrow shares and transferring loan tokens.

```mermaid
sequenceDiagram
    participant User
    participant Morpho
    participant IRM
    participant Oracle
    participant Token as LoanToken

    User->>Morpho: borrow(marketParams, assets, shares, onBehalf, receiver)

    Note over Morpho: Validations
    Morpho->>Morpho: require(market.lastUpdate != 0)
    Morpho->>Morpho: require(exactlyOneZero(assets, shares))
    Morpho->>Morpho: require(receiver != address(0))

    Note over Morpho: Authorization Check
    Morpho->>Morpho: _isSenderAuthorized(onBehalf)
    alt msg.sender != onBehalf
        Morpho->>Morpho: require(isAuthorized[onBehalf][msg.sender])
    end

    Note over Morpho: Interest Accrual
    Morpho->>IRM: borrowRate(marketParams, market)
    IRM-->>Morpho: rate
    Morpho->>Morpho: Accrue interest

    Note over Morpho: Share Calculation
    alt assets provided (shares == 0)
        Morpho->>Morpho: shares = toSharesUp(assets)
    else shares provided (assets == 0)
        Morpho->>Morpho: assets = toAssetsDown(shares)
    end

    Note over Morpho: State Changes
    Morpho->>Morpho: position[onBehalf].borrowShares += shares
    Morpho->>Morpho: market.totalBorrowShares += shares
    Morpho->>Morpho: market.totalBorrowAssets += assets

    Note over Morpho: Health Check
    Morpho->>Oracle: price()
    Oracle-->>Morpho: collateralPrice
    Morpho->>Morpho: borrowed = borrowShares.toAssetsUp()
    Morpho->>Morpho: maxBorrow = collateral * price * lltv
    Morpho->>Morpho: require(maxBorrow >= borrowed)

    Note over Morpho: Liquidity Check
    Morpho->>Morpho: require(totalBorrowAssets <= totalSupplyAssets)

    Morpho-->>Morpho: emit Borrow(id, msg.sender, onBehalf, receiver, assets, shares)

    Note over Morpho: Token Transfer
    Morpho->>Token: safeTransfer(receiver, assets)
    Token-->>Morpho: success

    Morpho-->>User: return (assets, shares)
```

---

## Repay Flow

Repays borrowed tokens and reduces the debt position.

```mermaid
sequenceDiagram
    participant User
    participant Morpho
    participant IRM
    participant Token as LoanToken

    User->>Morpho: repay(marketParams, assets, shares, onBehalf, data)

    Note over Morpho: Validations
    Morpho->>Morpho: require(market.lastUpdate != 0)
    Morpho->>Morpho: require(exactlyOneZero(assets, shares))
    Morpho->>Morpho: require(onBehalf != address(0))

    Note over Morpho: Interest Accrual
    Morpho->>IRM: borrowRate(marketParams, market)
    IRM-->>Morpho: rate
    Morpho->>Morpho: Accrue interest

    Note over Morpho: Share Calculation
    alt assets provided (shares == 0)
        Morpho->>Morpho: shares = toSharesDown(assets)
    else shares provided (assets == 0)
        Morpho->>Morpho: assets = toAssetsUp(shares)
    end

    Note over Morpho: State Changes
    Morpho->>Morpho: position[onBehalf].borrowShares -= shares
    Morpho->>Morpho: market.totalBorrowShares -= shares
    Morpho->>Morpho: market.totalBorrowAssets = zeroFloorSub(total, assets)

    Morpho-->>Morpho: emit Repay(id, msg.sender, onBehalf, assets, shares)

    alt data.length > 0
        Note over Morpho,User: Callback (CEI - state already updated)
        Morpho->>User: onMorphoRepay(assets, data)
        User-->>Morpho: (user sources funds)
    end

    Note over Morpho: Token Transfer
    Morpho->>Token: safeTransferFrom(msg.sender, Morpho, assets)
    Token-->>Morpho: success

    Morpho-->>User: return (assets, shares)
```

---

## Supply Collateral Flow

Deposits collateral tokens to back borrowing positions.

```mermaid
sequenceDiagram
    participant User
    participant Morpho
    participant Token as CollateralToken

    User->>Morpho: supplyCollateral(marketParams, assets, onBehalf, data)

    Note over Morpho: Validations
    Morpho->>Morpho: require(market.lastUpdate != 0)
    Morpho->>Morpho: require(assets != 0)
    Morpho->>Morpho: require(onBehalf != address(0))

    Note over Morpho: No Interest Accrual
    Note over Morpho: (Collateral doesn't earn interest)

    Note over Morpho: State Changes
    Morpho->>Morpho: position[onBehalf].collateral += assets

    Morpho-->>Morpho: emit SupplyCollateral(id, msg.sender, onBehalf, assets)

    alt data.length > 0
        Note over Morpho,User: Callback (CEI - state already updated)
        Morpho->>User: onMorphoSupplyCollateral(assets, data)
        User-->>Morpho: (user sources funds)
    end

    Note over Morpho: Token Transfer
    Morpho->>Token: safeTransferFrom(msg.sender, Morpho, assets)
    Token-->>Morpho: success
```

---

## Withdraw Collateral Flow

Withdraws collateral tokens while maintaining position health.

```mermaid
sequenceDiagram
    participant User
    participant Morpho
    participant IRM
    participant Oracle
    participant Token as CollateralToken

    User->>Morpho: withdrawCollateral(marketParams, assets, onBehalf, receiver)

    Note over Morpho: Validations
    Morpho->>Morpho: require(market.lastUpdate != 0)
    Morpho->>Morpho: require(assets != 0)
    Morpho->>Morpho: require(receiver != address(0))

    Note over Morpho: Authorization Check
    Morpho->>Morpho: _isSenderAuthorized(onBehalf)
    alt msg.sender != onBehalf
        Morpho->>Morpho: require(isAuthorized[onBehalf][msg.sender])
    end

    Note over Morpho: Interest Accrual
    Morpho->>IRM: borrowRate(marketParams, market)
    IRM-->>Morpho: rate
    Morpho->>Morpho: Accrue interest (needed for accurate health check)

    Note over Morpho: State Changes
    Morpho->>Morpho: position[onBehalf].collateral -= assets

    Note over Morpho: Health Check (post-withdrawal)
    Morpho->>Oracle: price()
    Oracle-->>Morpho: collateralPrice
    Morpho->>Morpho: borrowed = borrowShares.toAssetsUp()
    Morpho->>Morpho: maxBorrow = (collateral - assets) * price * lltv
    Morpho->>Morpho: require(maxBorrow >= borrowed)

    Morpho-->>Morpho: emit WithdrawCollateral(id, msg.sender, onBehalf, receiver, assets)

    Note over Morpho: Token Transfer
    Morpho->>Token: safeTransfer(receiver, assets)
    Token-->>Morpho: success
```

---

## Liquidate Flow

Liquidates unhealthy positions by repaying debt and seizing collateral at a discount.

```mermaid
sequenceDiagram
    participant Liquidator
    participant Morpho
    participant IRM
    participant Oracle
    participant LoanToken
    participant CollateralToken

    Liquidator->>Morpho: liquidate(marketParams, borrower, seizedAssets, repaidShares, data)

    Note over Morpho: Validations
    Morpho->>Morpho: require(market.lastUpdate != 0)
    Morpho->>Morpho: require(exactlyOneZero(seizedAssets, repaidShares))

    Note over Morpho: Interest Accrual
    Morpho->>IRM: borrowRate(marketParams, market)
    IRM-->>Morpho: rate
    Morpho->>Morpho: Accrue interest

    Note over Morpho: Get Price & Check Unhealthy
    Morpho->>Oracle: price()
    Oracle-->>Morpho: collateralPrice
    Morpho->>Morpho: _isHealthy(borrower, collateralPrice)
    Morpho->>Morpho: require(!isHealthy) // Position must be unhealthy

    Note over Morpho: Calculate Liquidation Amounts
    Note over Morpho: LIF = min(1.15, 1/(1 - 0.3*(1-lltv)))
    alt seizedAssets provided
        Morpho->>Morpho: seizedAssetsQuoted = seizedAssets * price / 1e36
        Morpho->>Morpho: repaidAssets = seizedAssetsQuoted / LIF
        Morpho->>Morpho: repaidShares = toSharesUp(repaidAssets)
    else repaidShares provided
        Morpho->>Morpho: repaidAssets = toAssetsDown(repaidShares)
        Morpho->>Morpho: seizedAssetsQuoted = repaidAssets * LIF
        Morpho->>Morpho: seizedAssets = seizedAssetsQuoted * 1e36 / price
    end

    Note over Morpho: State Changes - Debt
    Morpho->>Morpho: position[borrower].borrowShares -= repaidShares
    Morpho->>Morpho: market.totalBorrowShares -= repaidShares
    Morpho->>Morpho: market.totalBorrowAssets = zeroFloorSub(total, repaidAssets)

    Note over Morpho: State Changes - Collateral
    Morpho->>Morpho: position[borrower].collateral -= seizedAssets

    Note over Morpho: Bad Debt Handling
    alt position[borrower].collateral == 0 AND borrowShares > 0
        Note over Morpho: Bad Debt Socialization
        Morpho->>Morpho: badDebtShares = position[borrower].borrowShares
        Morpho->>Morpho: badDebtAssets = toAssetsUp(badDebtShares)
        Morpho->>Morpho: market.totalBorrowShares -= badDebtShares
        Morpho->>Morpho: market.totalSupplyAssets -= badDebtAssets
        Morpho->>Morpho: position[borrower].borrowShares = 0
    end

    Morpho-->>Morpho: emit Liquidate(id, liquidator, borrower, ...)

    Note over Morpho: Collateral Transfer to Liquidator
    Morpho->>CollateralToken: safeTransfer(liquidator, seizedAssets)
    CollateralToken-->>Morpho: success

    alt data.length > 0
        Note over Morpho,Liquidator: Callback (CEI - state already updated)
        Morpho->>Liquidator: onMorphoLiquidate(repaidAssets, data)
        Liquidator-->>Morpho: (liquidator sources repayment funds)
    end

    Note over Morpho: Loan Token Repayment
    Morpho->>LoanToken: safeTransferFrom(liquidator, Morpho, repaidAssets)
    LoanToken-->>Morpho: success

    Morpho-->>Liquidator: return (seizedAssets, repaidAssets)
```

---

## Flash Loan Flow

Borrows tokens atomically with no fee - must be repaid in same transaction.

```mermaid
sequenceDiagram
    participant User
    participant Morpho
    participant Token

    User->>Morpho: flashLoan(token, assets, data)

    Note over Morpho: Validation
    Morpho->>Morpho: require(assets != 0)

    Note over Morpho: No Interest Accrual
    Note over Morpho: (Atomic operation - no time passes)

    Morpho-->>Morpho: emit FlashLoan(msg.sender, token, assets)

    Note over Morpho: Transfer Tokens to Borrower
    Morpho->>Token: safeTransfer(msg.sender, assets)
    Token-->>Morpho: success

    Note over Morpho,User: Required Callback
    Morpho->>User: onMorphoFlashLoan(assets, data)
    Note over User: User performs arbitrage,<br/>liquidation, or other operations
    User->>Token: approve(Morpho, assets)
    User-->>Morpho: callback returns

    Note over Morpho: Reclaim Tokens
    Morpho->>Token: safeTransferFrom(msg.sender, Morpho, assets)
    Token-->>Morpho: success

    Note over Morpho: No net state change
```

---

## Authorization Flow

Grants or revokes authorization for position management.

```mermaid
sequenceDiagram
    participant Owner
    participant Morpho

    alt Direct Authorization
        Owner->>Morpho: setAuthorization(authorized, isAuthorized)
        Morpho->>Morpho: require(newIsAuthorized != current)
        Morpho->>Morpho: isAuthorized[owner][authorized] = isAuthorized
        Morpho-->>Morpho: emit SetAuthorization(owner, owner, authorized, isAuthorized)
    else Signature-based Authorization
        Note over Owner: Owner signs EIP-712 message offline
        participant Relayer
        Relayer->>Morpho: setAuthorizationWithSig(authorization, signature)
        Morpho->>Morpho: require(block.timestamp <= deadline)
        Morpho->>Morpho: require(nonce == nonce[authorizer])
        Morpho->>Morpho: Verify signature via ecrecover
        Morpho->>Morpho: require(signatory == authorizer)
        Morpho->>Morpho: nonce[authorizer]++
        Morpho->>Morpho: isAuthorized[authorizer][authorized] = isAuthorized
        Morpho-->>Morpho: emit IncrementNonce(relayer, authorizer, nonce)
        Morpho-->>Morpho: emit SetAuthorization(relayer, authorizer, authorized, isAuthorized)
    end
```

---

## State Changes Summary

| Operation | User Position State | Market Global State |
|-----------|---------------------|---------------------|
| supply | +supplyShares | +totalSupplyShares, +totalSupplyAssets |
| withdraw | -supplyShares | -totalSupplyShares, -totalSupplyAssets |
| borrow | +borrowShares | +totalBorrowShares, +totalBorrowAssets |
| repay | -borrowShares | -totalBorrowShares, -totalBorrowAssets |
| supplyCollateral | +collateral | (none) |
| withdrawCollateral | -collateral | (none) |
| liquidate | -borrowShares, -collateral | -totalBorrowShares, -totalBorrowAssets, (bad debt: -totalSupplyAssets) |
| flashLoan | (none) | (none) |
| accrueInterest | (feeRecipient: +supplyShares) | +totalSupplyShares, +totalSupplyAssets, +totalBorrowAssets |

---

## Interest Accrual Detail

Interest accrues on all state-changing operations except supplyCollateral and flashLoan.

```mermaid
sequenceDiagram
    participant Caller
    participant Morpho
    participant IRM

    Caller->>Morpho: (any state-changing function)

    Note over Morpho: _accrueInterest(marketParams, id)

    Morpho->>Morpho: elapsed = block.timestamp - lastUpdate

    alt elapsed > 0 AND totalBorrowAssets > 0
        alt irm != address(0)
            Morpho->>IRM: borrowRate(marketParams, market)
            IRM-->>Morpho: borrowRate (per second, WAD scaled)
        else
            Morpho->>Morpho: borrowRate = 0
        end

        Note over Morpho: Taylor expansion for compound interest
        Morpho->>Morpho: interest = totalBorrowAssets * wTaylorCompounded(rate, elapsed)

        Morpho->>Morpho: totalBorrowAssets += interest
        Morpho->>Morpho: totalSupplyAssets += interest

        alt fee > 0
            Morpho->>Morpho: feeAmount = interest * fee / WAD
            Morpho->>Morpho: feeShares = toSharesDown(feeAmount)
            Morpho->>Morpho: position[feeRecipient].supplyShares += feeShares
            Morpho->>Morpho: totalSupplyShares += feeShares
        end

        Morpho-->>Morpho: emit AccrueInterest(id, borrowRate, interest, feeShares)
    end

    Morpho->>Morpho: lastUpdate = block.timestamp
```

---

## Rounding Directions by Operation

| Operation | Conversion | Direction | Reason |
|-----------|------------|-----------|--------|
| supply | assets -> shares | DOWN | User gets fewer shares |
| supply | shares -> assets | UP | User pays more |
| withdraw | assets -> shares | UP | User burns more shares |
| withdraw | shares -> assets | DOWN | User gets fewer assets |
| borrow | assets -> shares | UP | Borrower owes more |
| borrow | shares -> assets | DOWN | Borrower receives less |
| repay | assets -> shares | DOWN | Slightly borrower favored |
| repay | shares -> assets | UP | Borrower pays more |
| liquidate (seized) | - | DOWN | Liquidator gets less |
| liquidate (repaid) | - | UP | Liquidator pays more |
| health check (borrowed) | - | UP | Stricter - appears to owe more |
| health check (maxBorrow) | - | DOWN | Stricter - can borrow less |

---

## Callback Execution Order

All callbacks follow the CEI (Checks-Effects-Interactions) pattern:

1. **Checks**: Validate inputs and authorization
2. **Effects**: Update all state (shares, collateral, totals)
3. **Interactions**:
   - First: Execute callback (if data provided)
   - Then: Transfer tokens

This ordering ensures:
- State is finalized before any external calls
- Callbacks cannot manipulate pending state changes
- Reentrancy is safe because state is already updated
