# State Transitions

## Position States

| State | Description | How to Enter | How to Exit |
|-------|-------------|--------------|-------------|
| NoPosition | No interaction with market | Default state | supply() or supplyCollateral() |
| Lender | Has supply shares only | supply() | withdraw(all shares) |
| Collateralized | Has collateral only | supplyCollateral() | withdrawCollateral(all) |
| Borrower | Has collateral and debt | borrow() after collateral | repay(all) |
| LenderBorrower | Has supply shares AND collateral+debt | supply() + borrow() | Complex unwinding |

## Health States (Borrowers Only)

| State | Condition | Triggered By |
|-------|-----------|--------------|
| Healthy | LTV < LLTV | Default after borrow, repay, add collateral |
| Unhealthy | LTV >= LLTV | Price movement, interest accrual |
| Liquidated | After liquidation | liquidate() call |
| BadDebt | Debt remains with no collateral | Full liquidation with insufficient collateral |

### LTV Calculation
```
LTV = borrowedValue / collateralValue
    = (borrowShares.toAssetsUp(totalBorrow) * oraclePrice) / (collateral * ORACLE_PRICE_SCALE)
```

---

## Position Transition Table

| From | To | Function | Conditions |
|------|-----|----------|------------|
| NoPosition | Lender | supply() | assets/shares > 0 |
| NoPosition | Collateralized | supplyCollateral() | assets > 0 |
| Lender | NoPosition | withdraw() | withdraw all shares |
| Lender | Lender | supply()/withdraw() | partial amounts |
| Collateralized | NoPosition | withdrawCollateral() | withdraw all, no debt |
| Collateralized | Borrower | borrow() | stays healthy |
| Borrower | Collateralized | repay() | repay all debt |
| Borrower | Liquidated | liquidate() | was unhealthy |
| Liquidated | Collateralized | (automatic) | if collateral remains |
| Liquidated | BadDebt | (automatic) | if debt remains with no collateral |

---

## Health Transition Table

| From | To | Trigger | Mechanism |
|------|-----|---------|-----------|
| Healthy | Unhealthy | Price drop | Oracle returns lower collateral price |
| Healthy | Unhealthy | Interest | Debt increases over time |
| Unhealthy | Healthy | Repay | User repays some debt |
| Unhealthy | Healthy | Add collateral | User adds more collateral |
| Unhealthy | Healthy | Price rise | Oracle returns higher collateral price |
| Unhealthy | Liquidated | liquidate() | Liquidator intervenes |

---

## Market States

| State | Condition | Transition |
|-------|-----------|------------|
| NonExistent | lastUpdate == 0 | createMarket() |
| Active | lastUpdate > 0, totalSupply or totalBorrow > 0 | Normal operations |
| Empty | lastUpdate > 0, all zeros | All users withdrew |

### Market is Immutable
Once created, a market cannot be:
- Modified (oracle, IRM, LLTV are fixed)
- Deleted
- Paused

---

## Share Price Evolution

### Supply Shares
```
Supply share price = totalSupplyAssets / totalSupplyShares
- Increases with interest accrual
- Decreases with bad debt realization
```

### Borrow Shares
```
Borrow share price = totalBorrowAssets / totalBorrowShares
- Increases with interest accrual
- Never decreases (debt always grows or stays same)
```

---

## Interest Accrual Transitions

| Event | totalSupplyAssets | totalBorrowAssets | totalSupplyShares |
|-------|-------------------|-------------------|-------------------|
| Interest accrual | +interest | +interest | +feeShares (if fee > 0) |
| Bad debt realization | -badDebtAssets | -badDebtAssets | unchanged |

---

## Fee State

| State | Condition | Set By |
|-------|-----------|--------|
| NoFee | market.fee == 0 | Default, or owner sets 0 |
| WithFee | 0 < market.fee <= MAX_FEE | owner.setFee() |

Fee recipient state:
| State | Condition |
|-------|-----------|
| Active | feeRecipient != address(0) |
| Lost | feeRecipient == address(0), fees are burned |
