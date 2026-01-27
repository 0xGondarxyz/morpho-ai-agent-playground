# Create Usage Flows Knowledge Base

Document user flows and state transitions.

---

## Input Files Required

- `kb/roles/actors.md`
- `kb/roles/permissions.md`
- `kb/setup/deployable-contracts.md`

---

## Step 1: Document State Transitions

### Task
Identify user state machines.

### Input
- `kb/setup/deployable-contracts.md`
- `kb/roles/permissions.md`

### Instructions

For each deployable contract (read .sol from deployable-contracts.md):
1. Identify user "states":
   - Position states: NoPosition → HasSupply → HasBorrow
   - Health states: Healthy → Unhealthy → Liquidated
2. Map which functions transition between states
3. Document conditions for each transition

### Output
Create: `kb/flows/state-transitions.md`

Example structure:

    # State Transitions

    ## Position States

    | State | Description | How to Enter | How to Exit |
    |-------|-------------|--------------|-------------|
    | NoPosition | No interaction | Default | supply/supplyCollateral |
    | Lender | Has supply shares | supply() | withdraw(all) |
    | Borrower | Has collateral | supplyCollateral() | withdrawCollateral(all) |
    | ActiveBorrow | Has debt | borrow() | repay(all) |

    ## Health States (Borrowers Only)

    | State | Condition | Triggered By |
    |-------|-----------|--------------|
    | Healthy | LTV < LLTV | Default after borrow |
    | Unhealthy | LTV >= LLTV | Price movement |
    | Liquidated | After liquidation | liquidate() call |

    ## Transition Table

    | From | To | Function | Conditions |
    |------|-----|----------|------------|
    | NoPosition | Lender | supply() | amount > 0 |
    | Lender | NoPosition | withdraw() | withdraw all |
    | NoPosition | Borrower | supplyCollateral() | amount > 0 |
    | Borrower | ActiveBorrow | borrow() | healthy after |
    | ActiveBorrow | Borrower | repay() | repay all debt |
    | ActiveBorrow | Liquidated | liquidate() | LTV >= LLTV |

---

## Step 2: Document Core Flows

### Task
Create step-by-step flow documentation.

### Input
- `kb/flows/state-transitions.md`
- `kb/setup/deployable-contracts.md`

### Instructions

For each major flow, document:
1. Actor performing the flow
2. Prerequisites
3. Step-by-step calls
4. State changes
5. Events emitted
6. Revert conditions

### Flows to Document
- Supply/Withdraw (Lending)
- SupplyCollateral/Borrow/Repay/WithdrawCollateral (Borrowing)
- Liquidation
- Market Creation
- Flash Loan
- Authorization

### Output
Create: `kb/flows/core-flows.md`

Example structure:

    # Core Usage Flows

    ## 1. Supply Flow

    ### Actor
    Lender

    ### Prerequisites
    - Market exists (createMarket called)
    - Tokens approved to contract

    ### Steps
    1. Approve contract to spend loanToken
    2. Call `supply(marketParams, assets, shares, onBehalf, data)`
    3. Contract calls `accrueInterest()`
    4. Contract transfers loanToken from caller
    5. Contract mints supply shares to onBehalf

    ### Events
    - `Supply(id, caller, onBehalf, assets, shares)`

    ### Revert Conditions
    - Market not created: `MarketNotCreated()`
    - Zero amount: `ZeroAssets()`
    - Transfer fails: ERC20 revert

    ---

    ## 2. Withdraw Flow

    ### Actor
    Lender (or authorized operator)

    ### Prerequisites
    - Has supply shares
    - Sufficient liquidity in market

    ### Steps
    1. Call `withdraw(marketParams, assets, shares, onBehalf, receiver)`
    2. Contract checks authorization (if onBehalf != caller)
    3. Contract calls `accrueInterest()`
    4. Contract burns shares from onBehalf
    5. Contract transfers loanToken to receiver

    ### Events
    - `Withdraw(id, caller, onBehalf, receiver, assets, shares)`

    ### Revert Conditions
    - Not authorized: `Unauthorized()`
    - Insufficient shares: `InsufficientShares()`
    - Insufficient liquidity: `InsufficientLiquidity()`

    ---

    ## 3. Borrow Flow
    [Similar format...]

    ## 4. Liquidation Flow
    [Similar format...]

    ## 5. Flash Loan Flow
    [Similar format...]

---

## Summary

| Step | Input | Output |
|------|-------|--------|
| 1 | deployable-contracts.md + permissions.md | kb/flows/state-transitions.md |
| 2 | state-transitions.md + deployable-contracts.md | kb/flows/core-flows.md |

## Folder Structure

```
kb/flows/
├── state-transitions.md
└── core-flows.md
```
