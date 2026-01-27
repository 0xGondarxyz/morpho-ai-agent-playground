# State Machine Diagram

## Position States

```mermaid
stateDiagram-v2
    [*] --> NoPosition

    NoPosition --> Lender: supply()
    Lender --> NoPosition: withdraw(all)
    Lender --> Lender: supply() / withdraw(partial)

    NoPosition --> Collateralized: supplyCollateral()
    Collateralized --> NoPosition: withdrawCollateral(all)\n[no debt]
    Collateralized --> Collateralized: supplyCollateral() / withdrawCollateral(partial)

    Collateralized --> Borrower: borrow()
    Borrower --> Collateralized: repay(all)
    Borrower --> Borrower: borrow() / repay(partial)

    Borrower --> Liquidated: liquidate()\n[unhealthy]
    Liquidated --> Collateralized: [collateral remains]
    Liquidated --> BadDebt: [no collateral, debt remains]

    note right of Borrower: Must stay healthy\nLTV < LLTV
    note right of Liquidated: Automatic transition\nbased on remaining\ncollateral/debt
```

## Health States (Borrowers Only)

```mermaid
stateDiagram-v2
    [*] --> Healthy: borrow()

    Healthy --> Unhealthy: price drops
    Healthy --> Unhealthy: interest accrues
    Unhealthy --> Healthy: repay()
    Unhealthy --> Healthy: supplyCollateral()
    Unhealthy --> Healthy: price rises

    Unhealthy --> Liquidated: liquidate()

    note right of Healthy: LTV < LLTV
    note right of Unhealthy: LTV >= LLTV\nCan be liquidated
```

## Market Lifecycle

```mermaid
stateDiagram-v2
    [*] --> NonExistent

    NonExistent --> Active: createMarket()

    Active --> Active: supply/borrow/etc
    Active --> Empty: all withdraw

    Empty --> Active: new supply

    note right of NonExistent: lastUpdate == 0
    note right of Active: lastUpdate > 0
    note right of Empty: All balances zero\nbut market still exists
```

## Combined User Journey

```mermaid
stateDiagram-v2
    direction LR

    state "User States" as user {
        [*] --> None

        state "Lender Path" as lender_path {
            None --> HasSupply: supply()
            HasSupply --> None: withdraw(all)
        }

        state "Borrower Path" as borrower_path {
            None --> HasCollateral: supplyCollateral()
            HasCollateral --> HasDebt: borrow()
            HasDebt --> HasCollateral: repay(all)
            HasCollateral --> None: withdrawCollateral(all)
        }

        state "Liquidation" as liq {
            HasDebt --> Liquidating: [unhealthy]
            Liquidating --> HasCollateral: [partial liq]
            Liquidating --> None: [full liq]
        }
    }
```

## Interest Accrual States

```mermaid
stateDiagram-v2
    [*] --> Fresh: lastUpdate = now

    Fresh --> Stale: time passes
    Stale --> Fresh: accrueInterest()\nor any operation

    note right of Fresh: Interest up to date
    note right of Stale: Pending interest\nnot yet applied
```

## Authorization States

```mermaid
stateDiagram-v2
    [*] --> Unauthorized

    Unauthorized --> Authorized: setAuthorization(op, true)
    Unauthorized --> Authorized: setAuthorizationWithSig()

    Authorized --> Unauthorized: setAuthorization(op, false)

    note right of Authorized: Can withdraw/borrow/\nwithdrawCollateral\non behalf
```
