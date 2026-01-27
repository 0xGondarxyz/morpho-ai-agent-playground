# Create Usage Flow Charts

Render visual diagrams from flow knowledge base.

---

## Input Files Required

All files must exist before running this prompt:
- `kb/flows/state-transitions.md`
- `kb/flows/core-flows.md`

---

## Step 1: Create State Machine Diagram

### Task
Visualize user state transitions.

### Input
- `kb/flows/state-transitions.md`

### Instructions

Create Mermaid state diagram showing:
1. All position states
2. Transitions between states
3. Functions that trigger transitions

### Output
Create: `charts/state-machine.md`

Example structure:

    # State Machine Diagram

    ## Position States

    ```mermaid
    stateDiagram-v2
        [*] --> NoPosition

        NoPosition --> Lender: supply()
        Lender --> NoPosition: withdraw(all)

        NoPosition --> Borrower: supplyCollateral()
        Borrower --> NoPosition: withdrawCollateral(all)

        Borrower --> ActiveBorrow: borrow()
        ActiveBorrow --> Borrower: repay(all)

        ActiveBorrow --> Liquidated: liquidate()
        Liquidated --> Borrower: [remaining collateral]
    ```

    ## Health States

    ```mermaid
    stateDiagram-v2
        Healthy --> Unhealthy: price drops
        Unhealthy --> Healthy: repay / add collateral
        Unhealthy --> Liquidated: liquidate()
    ```

---

## Step 2: Create Sequence Diagrams

### Task
Create sequence diagrams for each flow.

### Input
- `kb/flows/core-flows.md`

### Instructions

For each flow in core-flows.md, create a sequence diagram showing:
1. Actors involved
2. Contract interactions
3. External calls (tokens, oracles)
4. Return values

### Output
Create: `charts/sequence-diagrams.md`

Example structure:

    # Sequence Diagrams

    ## Supply Flow

    ```mermaid
    sequenceDiagram
        actor Lender
        participant Morpho
        participant LoanToken

        Lender->>LoanToken: approve(morpho, amount)
        Lender->>Morpho: supply(params, assets, 0, lender, "")
        Morpho->>Morpho: accrueInterest()
        Morpho->>LoanToken: transferFrom(lender, morpho, assets)
        Morpho->>Morpho: mint shares
        Morpho-->>Lender: (assets, shares)
        Note over Morpho: emit Supply()
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
        Morpho->>Collateral: transferFrom(borrower, morpho, assets)

        Note over Borrower: Step 2: Borrow
        Borrower->>Morpho: borrow(params, assets, 0, borrower, borrower)
        Morpho->>Morpho: accrueInterest()
        Morpho->>Oracle: price()
        Morpho->>Morpho: check LTV < LLTV
        Morpho->>LoanToken: transfer(borrower, assets)
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

        Liquidator->>Morpho: liquidate(params, borrower, seizedAssets, "")
        Morpho->>Morpho: accrueInterest()
        Morpho->>Oracle: price()
        Morpho->>Morpho: verify LTV >= LLTV
        Morpho->>Morpho: calculate repaid amount
        Morpho->>LoanToken: transferFrom(liquidator, morpho, repaid)
        Morpho->>Collateral: transfer(liquidator, seized)
        Morpho-->>Liquidator: (seized, repaid)
    ```

    ## Flash Loan Flow

    ```mermaid
    sequenceDiagram
        actor Caller
        participant Morpho
        participant LoanToken
        participant Callback

        Caller->>Morpho: flashLoan(token, assets, data)
        Morpho->>LoanToken: transfer(caller, assets)
        Morpho->>Callback: onMorphoFlashLoan(assets, data)
        Note over Callback: Use funds, must repay
        Callback->>LoanToken: transfer(morpho, assets)
        Morpho-->>Caller: success
    ```

---

## Step 3: Create Quick Reference

### Task
Create user-friendly flow summary.

### Input
- `kb/flows/core-flows.md`

### Instructions

Create a quick reference table for common actions.

### Output
Create: `charts/flow-quickref.md`

Example structure:

    # Flow Quick Reference

    ## Overview Diagram

    ```mermaid
    graph LR
        subgraph Lending
            S[Supply] --> W[Withdraw]
        end

        subgraph Borrowing
            SC[Supply Collateral] --> B[Borrow]
            B --> R[Repay]
            R --> WC[Withdraw Collateral]
        end

        subgraph Risk
            B -.->|unhealthy| L[Liquidate]
        end

        S -->|provides liquidity| B
        R -->|returns liquidity| W
    ```

    ## Action Reference

    | I want to... | Call | Prerequisites |
    |--------------|------|---------------|
    | Earn yield | `supply()` | Approve tokens |
    | Stop earning | `withdraw()` | Have shares, liquidity available |
    | Get a loan | `supplyCollateral()` then `borrow()` | Approve collateral |
    | Increase loan | `borrow()` | Stay healthy (LTV < LLTV) |
    | Reduce loan | `repay()` | Approve loan tokens |
    | Close loan | `repay(all)` then `withdrawCollateral()` | Approve loan tokens |
    | Liquidate | `liquidate()` | Target is unhealthy |
    | Create market | `createMarket()` | IRM and LLTV enabled |
    | Flash loan | `flashLoan()` | Implement callback |

---

## Summary

| Step | Input | Output |
|------|-------|--------|
| 1 | state-transitions.md | charts/state-machine.md |
| 2 | core-flows.md | charts/sequence-diagrams.md |
| 3 | core-flows.md | charts/flow-quickref.md |

## Folder Structure

```
charts/
├── state-machine.md
├── sequence-diagrams.md
└── flow-quickref.md
```
