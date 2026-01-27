# Sequence Diagrams

## Supply Flow

```mermaid
sequenceDiagram
    actor Lender
    participant Morpho
    participant LoanToken

    Lender->>LoanToken: approve(morpho, amount)
    Lender->>Morpho: supply(params, assets, 0, lender, "")

    Morpho->>Morpho: _accrueInterest()
    Morpho->>Morpho: shares = assets.toSharesDown(...)
    Morpho->>Morpho: position[id][onBehalf].supplyShares += shares
    Morpho->>Morpho: market[id].totalSupplyShares += shares
    Morpho->>Morpho: market[id].totalSupplyAssets += assets

    Note over Morpho: emit Supply(id, caller, onBehalf, assets, shares)

    Morpho->>LoanToken: safeTransferFrom(lender, morpho, assets)
    Morpho-->>Lender: (assets, shares)
```

## Withdraw Flow

```mermaid
sequenceDiagram
    actor Lender
    participant Morpho
    participant LoanToken

    Lender->>Morpho: withdraw(params, assets, 0, lender, receiver)

    Morpho->>Morpho: require(_isSenderAuthorized(lender))
    Morpho->>Morpho: _accrueInterest()
    Morpho->>Morpho: shares = assets.toSharesUp(...)
    Morpho->>Morpho: position[id][onBehalf].supplyShares -= shares
    Morpho->>Morpho: require(totalBorrow <= totalSupply)

    Note over Morpho: emit Withdraw(...)

    Morpho->>LoanToken: safeTransfer(receiver, assets)
    Morpho-->>Lender: (assets, shares)
```

## Borrow Flow

```mermaid
sequenceDiagram
    actor Borrower
    participant Morpho
    participant Collateral
    participant LoanToken
    participant Oracle

    Note over Borrower: Step 1: Supply Collateral
    Borrower->>Collateral: approve(morpho, amount)
    Borrower->>Morpho: supplyCollateral(params, assets, borrower, "")
    Morpho->>Collateral: safeTransferFrom(borrower, morpho, assets)
    Morpho->>Morpho: position[id][borrower].collateral += assets

    Note over Borrower: Step 2: Borrow
    Borrower->>Morpho: borrow(params, assets, 0, borrower, borrower)
    Morpho->>Morpho: require(_isSenderAuthorized(borrower))
    Morpho->>Morpho: _accrueInterest()
    Morpho->>Morpho: shares = assets.toSharesUp(...)
    Morpho->>Morpho: position[id][borrower].borrowShares += shares

    Morpho->>Oracle: price()
    Oracle-->>Morpho: collateralPrice
    Morpho->>Morpho: require(_isHealthy(...))
    Morpho->>Morpho: require(totalBorrow <= totalSupply)

    Note over Morpho: emit Borrow(...)

    Morpho->>LoanToken: safeTransfer(borrower, assets)
    Morpho-->>Borrower: (assets, shares)
```

## Repay Flow

```mermaid
sequenceDiagram
    actor Borrower
    participant Morpho
    participant LoanToken

    Borrower->>LoanToken: approve(morpho, amount)
    Borrower->>Morpho: repay(params, assets, 0, borrower, "")

    Morpho->>Morpho: _accrueInterest()
    Morpho->>Morpho: shares = assets.toSharesDown(...)
    Morpho->>Morpho: position[id][borrower].borrowShares -= shares
    Morpho->>Morpho: market[id].totalBorrowAssets -= assets

    Note over Morpho: emit Repay(...)

    Morpho->>LoanToken: safeTransferFrom(borrower, morpho, assets)
    Morpho-->>Borrower: (assets, shares)
```

## Liquidation Flow

```mermaid
sequenceDiagram
    actor Liquidator
    participant Morpho
    participant Oracle
    participant LoanToken
    participant Collateral

    Liquidator->>Morpho: liquidate(params, borrower, seizedAssets, 0, "")

    Morpho->>Morpho: _accrueInterest()
    Morpho->>Oracle: price()
    Oracle-->>Morpho: collateralPrice

    Morpho->>Morpho: require(!_isHealthy(borrower, collateralPrice))
    Morpho->>Morpho: Calculate LIF
    Morpho->>Morpho: repaidShares = seizedAssets * price / LIF
    Morpho->>Morpho: repaidAssets = repaidShares.toAssetsUp(...)

    Morpho->>Morpho: borrower.borrowShares -= repaidShares
    Morpho->>Morpho: borrower.collateral -= seizedAssets

    alt borrower.collateral == 0 AND borrower.borrowShares > 0
        Morpho->>Morpho: Realize bad debt
        Morpho->>Morpho: totalBorrowAssets -= badDebt
        Morpho->>Morpho: totalSupplyAssets -= badDebt
    end

    Note over Morpho: emit Liquidate(...)

    Morpho->>Collateral: safeTransfer(liquidator, seizedAssets)

    opt callback
        Morpho->>Liquidator: onMorphoLiquidate(repaidAssets, data)
    end

    Morpho->>LoanToken: safeTransferFrom(liquidator, morpho, repaidAssets)
    Morpho-->>Liquidator: (seizedAssets, repaidAssets)
```

## Flash Loan Flow

```mermaid
sequenceDiagram
    actor Caller
    participant Morpho
    participant Token
    participant Callback as Caller Contract

    Caller->>Morpho: flashLoan(token, assets, data)

    Note over Morpho: emit FlashLoan(caller, token, assets)

    Morpho->>Token: safeTransfer(caller, assets)
    Morpho->>Callback: onMorphoFlashLoan(assets, data)

    Note over Callback: Use funds<br/>Must repay

    Callback->>Token: approve(morpho, assets)

    Morpho->>Token: safeTransferFrom(caller, morpho, assets)
    Morpho-->>Caller: success
```

## Authorization with Signature Flow

```mermaid
sequenceDiagram
    actor User
    actor Relayer
    participant Morpho

    Note over User: Create authorization struct
    User->>User: authorization = {authorizer, authorized, isAuthorized, nonce, deadline}
    User->>User: Sign EIP-712 digest

    User->>Relayer: authorization + signature

    Relayer->>Morpho: setAuthorizationWithSig(authorization, signature)

    Morpho->>Morpho: require(block.timestamp <= deadline)
    Morpho->>Morpho: require(nonce == nonce[authorizer])
    Morpho->>Morpho: nonce[authorizer]++
    Morpho->>Morpho: Compute EIP-712 digest
    Morpho->>Morpho: signatory = ecrecover(digest, v, r, s)
    Morpho->>Morpho: require(signatory == authorizer)
    Morpho->>Morpho: isAuthorized[authorizer][authorized] = isAuthorized

    Note over Morpho: emit IncrementNonce(...)
    Note over Morpho: emit SetAuthorization(...)

    Morpho-->>Relayer: success
```

## Interest Accrual Flow

```mermaid
sequenceDiagram
    participant Morpho
    participant IRM

    Note over Morpho: _accrueInterest(marketParams, id)

    Morpho->>Morpho: elapsed = now - lastUpdate
    alt elapsed == 0
        Morpho-->>Morpho: return (no-op)
    end

    alt irm != address(0)
        Morpho->>IRM: borrowRate(marketParams, market)
        IRM-->>Morpho: rate

        Morpho->>Morpho: interest = totalBorrow * rate.compounded(elapsed)
        Morpho->>Morpho: totalBorrowAssets += interest
        Morpho->>Morpho: totalSupplyAssets += interest

        alt fee > 0
            Morpho->>Morpho: feeAmount = interest * fee
            Morpho->>Morpho: feeShares = feeAmount.toSharesDown(...)
            Morpho->>Morpho: feeRecipient.supplyShares += feeShares
            Morpho->>Morpho: totalSupplyShares += feeShares
        end

        Note over Morpho: emit AccrueInterest(...)
    end

    Morpho->>Morpho: lastUpdate = now
```
