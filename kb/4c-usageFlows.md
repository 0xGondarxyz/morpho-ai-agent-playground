# Usage Flows

## Overview

| Operation | Function | Actors | Authorization | Callback |
|-----------|----------|--------|---------------|----------|
| Supply | supply() | Anyone | None | Optional |
| Withdraw | withdraw() | Self/Authorized | Required | None |
| Borrow | borrow() | Self/Authorized | Required | None |
| Repay | repay() | Anyone | None | Optional |
| Supply Collateral | supplyCollateral() | Anyone | None | Optional |
| Withdraw Collateral | withdrawCollateral() | Self/Authorized | Required | None |
| Liquidate | liquidate() | Anyone | None | Optional |
| Flash Loan | flashLoan() | Anyone | None | Required |

## Supply Flow

```mermaid
sequenceDiagram
    participant User
    participant Morpho
    participant IRM
    participant Token as Loan Token

    User->>Morpho: supply(params, assets, shares, onBehalf, data)

    rect rgb(255, 240, 240)
        Note over Morpho: Validation
        Morpho->>Morpho: require(market exists)
        Morpho->>Morpho: require(exactlyOneZero(assets, shares))
        Morpho->>Morpho: require(onBehalf != address(0))
    end

    rect rgb(240, 255, 240)
        Note over Morpho: Interest Accrual
        Morpho->>IRM: borrowRate(params, market)
        IRM-->>Morpho: rate
        Morpho->>Morpho: Calculate interest via Taylor expansion
        Morpho->>Morpho: Update totalBorrowAssets, totalSupplyAssets
        Morpho->>Morpho: Mint fee shares if fee > 0
    end

    rect rgb(240, 240, 255)
        Note over Morpho: Share Calculation
        alt assets > 0
            Morpho->>Morpho: shares = toSharesDown(assets)
        else shares > 0
            Morpho->>Morpho: assets = toAssetsUp(shares)
        end
    end

    rect rgb(255, 255, 240)
        Note over Morpho: State Update
        Morpho->>Morpho: position[onBehalf].supplyShares += shares
        Morpho->>Morpho: market.totalSupplyShares += shares
        Morpho->>Morpho: market.totalSupplyAssets += assets
    end

    Morpho-->>User: emit Supply(id, caller, onBehalf, assets, shares)

    alt data.length > 0
        Morpho->>User: onMorphoSupply(assets, data)
        User-->>Morpho: (callback return)
    end

    Morpho->>Token: safeTransferFrom(user, morpho, assets)
    Token-->>Morpho: success

    Morpho-->>User: return (assets, shares)
```

## Borrow Flow

```mermaid
sequenceDiagram
    participant User
    participant Morpho
    participant IRM
    participant Oracle
    participant Token as Loan Token

    User->>Morpho: borrow(params, assets, shares, onBehalf, receiver)

    rect rgb(255, 240, 240)
        Note over Morpho: Validation
        Morpho->>Morpho: require(market exists)
        Morpho->>Morpho: require(exactlyOneZero(assets, shares))
        Morpho->>Morpho: require(receiver != address(0))
        Morpho->>Morpho: require(_isSenderAuthorized(onBehalf))
    end

    rect rgb(240, 255, 240)
        Note over Morpho: Interest Accrual
        Morpho->>IRM: borrowRate(params, market)
        Morpho->>Morpho: Update interest
    end

    rect rgb(240, 240, 255)
        Note over Morpho: Share Calculation
        alt assets > 0
            Morpho->>Morpho: shares = toSharesUp(assets)
        else shares > 0
            Morpho->>Morpho: assets = toAssetsDown(shares)
        end
    end

    rect rgb(255, 255, 240)
        Note over Morpho: State Update
        Morpho->>Morpho: position[onBehalf].borrowShares += shares
        Morpho->>Morpho: market.totalBorrowShares += shares
        Morpho->>Morpho: market.totalBorrowAssets += assets
    end

    rect rgb(255, 220, 220)
        Note over Morpho: Health & Liquidity Check
        Morpho->>Oracle: price()
        Oracle-->>Morpho: collateralPrice
        Morpho->>Morpho: require(_isHealthy) - collateral * price * lltv >= debt
        Morpho->>Morpho: require(totalBorrow <= totalSupply)
    end

    Morpho-->>User: emit Borrow(id, caller, onBehalf, receiver, assets, shares)

    Morpho->>Token: safeTransfer(receiver, assets)
    Token-->>Morpho: success

    Morpho-->>User: return (assets, shares)
```

## Liquidation Flow

```mermaid
sequenceDiagram
    participant Liquidator
    participant Morpho
    participant IRM
    participant Oracle
    participant CollateralToken
    participant LoanToken

    Liquidator->>Morpho: liquidate(params, borrower, seizedAssets, repaidShares, data)

    rect rgb(255, 240, 240)
        Note over Morpho: Validation
        Morpho->>Morpho: require(market exists)
        Morpho->>Morpho: require(exactlyOneZero(seizedAssets, repaidShares))
    end

    rect rgb(240, 255, 240)
        Note over Morpho: Interest Accrual
        Morpho->>IRM: borrowRate(params, market)
        Morpho->>Morpho: Update interest
    end

    rect rgb(255, 220, 220)
        Note over Morpho: Health Check
        Morpho->>Oracle: price()
        Oracle-->>Morpho: collateralPrice
        Morpho->>Morpho: require(!_isHealthy) - position must be unhealthy
    end

    rect rgb(240, 240, 255)
        Note over Morpho: Incentive Calculation
        Morpho->>Morpho: liquidationIncentiveFactor = min(1.15, 1/(1-0.3*(1-lltv)))
        alt seizedAssets > 0
            Morpho->>Morpho: repaidShares = seizedAssetsQuoted / LIF
        else repaidShares > 0
            Morpho->>Morpho: seizedAssets = repaidAssets * LIF
        end
    end

    rect rgb(255, 255, 240)
        Note over Morpho: State Update
        Morpho->>Morpho: position[borrower].borrowShares -= repaidShares
        Morpho->>Morpho: market.totalBorrowShares -= repaidShares
        Morpho->>Morpho: market.totalBorrowAssets -= repaidAssets
        Morpho->>Morpho: position[borrower].collateral -= seizedAssets
    end

    rect rgb(255, 200, 200)
        Note over Morpho: Bad Debt Handling
        alt collateral == 0 && borrowShares > 0
            Morpho->>Morpho: badDebtAssets = remaining debt
            Morpho->>Morpho: market.totalBorrowAssets -= badDebt
            Morpho->>Morpho: market.totalSupplyAssets -= badDebt
            Morpho->>Morpho: position[borrower].borrowShares = 0
        end
    end

    Morpho-->>Liquidator: emit Liquidate(...)

    Morpho->>CollateralToken: safeTransfer(liquidator, seizedAssets)

    alt data.length > 0
        Morpho->>Liquidator: onMorphoLiquidate(repaidAssets, data)
        Liquidator-->>Morpho: (callback return)
    end

    Morpho->>LoanToken: safeTransferFrom(liquidator, morpho, repaidAssets)

    Morpho-->>Liquidator: return (seizedAssets, repaidAssets)
```

## Flash Loan Flow

```mermaid
sequenceDiagram
    participant Borrower
    participant Morpho
    participant Token

    Borrower->>Morpho: flashLoan(token, assets, data)

    rect rgb(255, 240, 240)
        Note over Morpho: Validation
        Morpho->>Morpho: require(assets != 0)
    end

    Morpho-->>Borrower: emit FlashLoan(caller, token, assets)

    rect rgb(240, 255, 240)
        Note over Morpho: Lend Assets
        Morpho->>Token: safeTransfer(borrower, assets)
    end

    rect rgb(255, 255, 200)
        Note over Morpho: Callback (Required)
        Morpho->>Borrower: onMorphoFlashLoan(assets, data)
        Note over Borrower: Execute arbitrage,<br/>liquidation, etc.
        Borrower-->>Morpho: return
    end

    rect rgb(255, 220, 220)
        Note over Morpho: Repay (same tx)
        Morpho->>Token: safeTransferFrom(borrower, morpho, assets)
        Note over Morpho: No fee charged
    end
```

## State Changes Summary

| Operation | User State Changes | Market State Changes |
|-----------|-------------------|---------------------|
| supply | +supplyShares | +totalSupplyShares, +totalSupplyAssets |
| withdraw | -supplyShares | -totalSupplyShares, -totalSupplyAssets |
| borrow | +borrowShares | +totalBorrowShares, +totalBorrowAssets |
| repay | -borrowShares | -totalBorrowShares, -totalBorrowAssets |
| supplyCollateral | +collateral | (none) |
| withdrawCollateral | -collateral | (none) |
| liquidate | -borrowShares, -collateral | -totalBorrowShares, -totalBorrowAssets, possibly -totalSupplyAssets (bad debt) |
| flashLoan | (none) | (none) |
| accrueInterest | +feeRecipient.supplyShares (if fee) | +totalBorrowAssets, +totalSupplyAssets, +totalSupplyShares (fee) |

## Rounding Directions

| Operation | Conversion | Rounding | Favors |
|-----------|-----------|----------|--------|
| supply (assets→shares) | toSharesDown | Down | Protocol |
| supply (shares→assets) | toAssetsUp | Up | Protocol |
| withdraw (assets→shares) | toSharesUp | Up | Protocol |
| withdraw (shares→assets) | toAssetsDown | Down | Protocol |
| borrow (assets→shares) | toSharesUp | Up | Protocol |
| borrow (shares→assets) | toAssetsDown | Down | Protocol |
| repay (assets→shares) | toSharesDown | Down | Protocol |
| repay (shares→assets) | toAssetsUp | Up | Protocol |
| _isHealthy (borrowed) | toAssetsUp | Up | Protocol |
| liquidate | Various | Protocol-favorable | Protocol |
