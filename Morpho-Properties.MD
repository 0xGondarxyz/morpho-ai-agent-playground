# Morpho.sol Property Specification

## Table of Contents
1. [Variable Validation](#1-variable-validation)
2. [Variable Transition](#2-variable-transition)
3. [Local vs Aggregation of Variable](#3-local-vs-aggregation-of-variable)
4. [State](#4-state)
5. [State Transition](#5-state-transition)
6. [Local vs Aggregation of State](#6-local-vs-aggregation-of-state)
7. [Per-Operation Transitions](#7-per-operation-transitions)

---

## 1. Variable Validation

Properties that validate variable bounds and constraints at any point in time.

### Market Variables

| ID | Property | Notes |
|----|----------|-------|
| VV-01 | `market[id].fee <= MAX_FEE (0.25e18)` | Fee is bounded at 25% |
| VV-02 | `market[id].lastUpdate <= block.timestamp` | Last update cannot be in the future |
| VV-03 | `market[id].lastUpdate != 0` implies market exists | Zero lastUpdate means market not created |
| VV-04 | `market[id].totalBorrowAssets <= market[id].totalSupplyAssets` | Liquidity invariant - cannot borrow more than supplied |
| VV-05 | `market[id].totalBorrowShares == 0` implies `market[id].totalBorrowAssets == 0` | No shares means no assets borrowed |
| VV-06 | `market[id].totalSupplyShares == 0` implies `market[id].totalSupplyAssets == 0` | No shares means no assets supplied |

### Position Variables

| ID | Property | Notes |
|----|----------|-------|
| VV-07 | For any healthy position with `borrowShares > 0`: `collateral * price * lltv >= borrowedAssets` | Health invariant |
| VV-08 | `position[id][user].supplyShares <= market[id].totalSupplyShares` | No position can have more shares than total |
| VV-09 | `position[id][user].borrowShares <= market[id].totalBorrowShares` | No position can have more borrow shares than total |

### Global Variables

| ID | Property | Notes |
|----|----------|-------|
| VV-10 | `nonce[user]` is monotonically increasing | Nonces can only increase |
| VV-11 | If `isLltvEnabled[lltv] == true`, then `lltv < WAD (1e18)` | LLTV must be less than 100% |

---

## 2. Variable Transition

Properties about how individual variables change over time.

### Market Variables

| ID | Property | Notes |
|----|----------|-------|
| VT-01 | `market[id].lastUpdate` can only increase or stay the same | Time moves forward |
| VT-02 | `market[id].fee` can only change via `setFee()` by owner | Fee changes are restricted |
| VT-03 | `market[id].totalSupplyAssets` can increase via: supply, interest accrual; decrease via: withdraw, bad debt socialization | |
| VT-04 | `market[id].totalBorrowAssets` can increase via: borrow, interest accrual; decrease via: repay, liquidate, bad debt | |
| VT-05 | `market[id].totalSupplyShares` can increase via: supply, fee accrual; decrease via: withdraw | |
| VT-06 | `market[id].totalBorrowShares` can increase via: borrow; decrease via: repay, liquidate | |
| VT-07 | After interest accrual: `totalSupplyAssets_new - totalSupplyAssets_old == totalBorrowAssets_new - totalBorrowAssets_old` | Interest increases both equally |

### Position Variables

| ID | Property | Notes |
|----|----------|-------|
| VT-08 | `position[id][user].supplyShares` can increase via: supply; decrease via: withdraw | |
| VT-09 | `position[id][user].borrowShares` can increase via: borrow; decrease via: repay, liquidate | |
| VT-10 | `position[id][user].collateral` can increase via: supplyCollateral; decrease via: withdrawCollateral, liquidate | |
| VT-11 | `position[id][feeRecipient].supplyShares` increases during interest accrual when `fee > 0` | Fee recipient gets shares |

### Global Variables

| ID | Property | Notes |
|----|----------|-------|
| VT-12 | `nonce[user]` increases by exactly 1 per `setAuthorizationWithSig` call for that user | |
| VT-13 | `isIrmEnabled[irm]` can only transition from `false` to `true`, never back | Cannot disable IRM |
| VT-14 | `isLltvEnabled[lltv]` can only transition from `false` to `true`, never back | Cannot disable LLTV |
| VT-15 | `owner` can only be changed by current `owner` | |
| VT-16 | `feeRecipient` can only be changed by `owner` | |

---

## 3. Local vs Aggregation of Variable

Properties relating individual position values to market-level aggregates.

### Supply Shares Aggregation

| ID | Property | Notes |
|----|----------|-------|
| LA-01 | `SUM(position[id][user].supplyShares for all users) == market[id].totalSupplyShares` | Supply shares sum correctly |
| LA-02 | If `market[id].totalSupplyShares > 0`, there exists at least one user with `supplyShares > 0` | Non-zero total implies at least one position |

### Borrow Shares Aggregation

| ID | Property | Notes |
|----|----------|-------|
| LA-03 | `SUM(position[id][user].borrowShares for all users) == market[id].totalBorrowShares` | Borrow shares sum correctly |
| LA-04 | If `market[id].totalBorrowShares > 0`, there exists at least one user with `borrowShares > 0` | Non-zero total implies at least one position |

### Assets vs Shares Consistency

| ID | Property | Notes |
|----|----------|-------|
| LA-05 | `market[id].totalSupplyShares > 0` iff `market[id].totalSupplyAssets > 0` (after virtual offset consideration) | Shares and assets are coupled |
| LA-06 | `market[id].totalBorrowShares > 0` iff `market[id].totalBorrowAssets > 0` (after virtual offset consideration) | Shares and assets are coupled |

### Cross-Market Aggregation

| ID | Property | Notes |
|----|----------|-------|
| LA-07 | For each token, `SUM(market[id].totalSupplyAssets - market[id].totalBorrowAssets)` across all markets using that loan token <= contract's token balance | Token accounting is consistent |

---

## 4. State

Properties defining valid protocol states.

### Market States

| ID | Property | Notes |
|----|----------|-------|
| ST-01 | **Market Non-Existent**: `market[id].lastUpdate == 0` and all other fields are 0 | |
| ST-02 | **Market Empty**: `lastUpdate > 0`, `totalSupplyAssets == 0`, `totalBorrowAssets == 0` | Newly created or fully withdrawn |
| ST-03 | **Market Active**: `lastUpdate > 0`, `totalSupplyAssets > 0` | Has suppliers |
| ST-04 | **Market Has Borrowers**: `lastUpdate > 0`, `totalBorrowAssets > 0` | Has outstanding borrows |

### Position States

| ID | Property | Notes |
|----|----------|-------|
| ST-05 | **Empty Position**: `supplyShares == 0`, `borrowShares == 0`, `collateral == 0` | |
| ST-06 | **Supplier Only**: `supplyShares > 0`, `borrowShares == 0` | |
| ST-07 | **Borrower**: `borrowShares > 0` (must have `collateral > 0` to be healthy) | |
| ST-08 | **Collateral Only**: `collateral > 0`, `borrowShares == 0`, `supplyShares == 0` | Deposited collateral without borrowing |
| ST-09 | **Healthy Position**: If `borrowShares > 0`, then `collateral * price * lltv >= borrowedAssets` | |
| ST-10 | **Unhealthy Position**: If `borrowShares > 0` and `collateral * price * lltv < borrowedAssets` | Liquidatable |

### Authorization States

| ID | Property | Notes |
|----|----------|-------|
| ST-11 | User `A` can manage user `B`'s position iff `A == B` OR `isAuthorized[B][A] == true` | |

---

## 5. State Transition

Properties about valid state transitions.

### Market State Transitions

| ID | Property | Notes |
|----|----------|-------|
| STT-01 | Non-Existent -> Empty: only via `createMarket()` | Market creation is one-way |
| STT-02 | Empty -> Active: via `supply()` | First supply activates market |
| STT-03 | Active -> Empty: only if `totalSupplyShares` becomes 0 via `withdraw()` | All suppliers exit |
| STT-04 | Active (no borrowers) -> Has Borrowers: via `borrow()` | |
| STT-05 | Has Borrowers -> Active (no borrowers): via `repay()` or `liquidate()` reducing `totalBorrowShares` to 0 | |
| STT-06 | Non-Existent market cannot transition back to Non-Existent | Once created, always exists |

### Position State Transitions

| ID | Property | Notes |
|----|----------|-------|
| STT-07 | Empty -> Supplier: via `supply()` | |
| STT-08 | Empty -> Collateral Only: via `supplyCollateral()` | |
| STT-09 | Supplier -> Empty: via `withdraw()` all shares | |
| STT-10 | Collateral Only -> Borrower: via `borrow()` | |
| STT-11 | Borrower -> Collateral Only: via `repay()` all debt | |
| STT-12 | Borrower -> Empty: via `liquidate()` seizing all collateral and clearing debt | Only through liquidation with bad debt |
| STT-13 | Healthy -> Unhealthy: via price change OR interest accrual increasing debt | |
| STT-14 | Unhealthy -> Healthy: via `repay()`, `supplyCollateral()`, or price change | |

### Authorization State Transitions

| ID | Property | Notes |
|----|----------|-------|
| STT-15 | `isAuthorized[A][B]`: false -> true via `setAuthorization()` or `setAuthorizationWithSig()` | |
| STT-16 | `isAuthorized[A][B]`: true -> false via `setAuthorization()` or `setAuthorizationWithSig()` | |
| STT-17 | After `setAuthorizationWithSig()`, `nonce[authorizer]` increments by exactly 1 | |

---

## 6. Local vs Aggregation of State

Properties relating position-level states to market-level states.

| ID | Property | Notes |
|----|----------|-------|
| LAS-01 | Market "Has Borrowers" iff at least one position has `borrowShares > 0` | |
| LAS-02 | Market "Active" iff at least one position has `supplyShares > 0` | |
| LAS-03 | If no position is Unhealthy, then no liquidations can occur | |
| LAS-04 | Count of positions with `supplyShares > 0` can increase via `supply()` on new users | |
| LAS-05 | Total bad debt socialized equals reduction in `totalSupplyAssets` during liquidations with `collateral == 0` | |
| LAS-06 | If `market[id].fee > 0` and interest accrues, `feeRecipient`'s position must have increased `supplyShares` | |

---

## 7. Per-Operation Transitions

Detailed property specifications for each operation.

### 7.1 supply()

| ID | Property | Notes |
|----|----------|-------|
| OP-S-01 | `position[id][onBehalf].supplyShares` increases | |
| OP-S-02 | `market[id].totalSupplyShares` increases by same amount as position | |
| OP-S-03 | `market[id].totalSupplyAssets` increases by `assets` | |
| OP-S-04 | Contract's loan token balance increases by `assets` | |
| OP-S-05 | No other position's `supplyShares` changes | |
| OP-S-06 | `market[id].totalBorrowAssets` unchanged (except for interest accrual) | |
| OP-S-07 | `market[id].totalBorrowShares` unchanged (except for interest accrual) | |
| OP-S-08 | No position's `borrowShares` or `collateral` changes | |
| OP-S-09 | `market[id].lastUpdate` becomes `block.timestamp` | |
| OP-S-10 | **[FLAG: REPEATS CODE]** If `assets > 0`: `shares = assets * (totalSupplyShares + VIRTUAL_SHARES) / (totalSupplyAssets + VIRTUAL_ASSETS)` rounded down | Direct math copy |

### 7.2 withdraw()

| ID | Property | Notes |
|----|----------|-------|
| OP-W-01 | `position[id][onBehalf].supplyShares` decreases | |
| OP-W-02 | `market[id].totalSupplyShares` decreases by same amount as position | |
| OP-W-03 | `market[id].totalSupplyAssets` decreases by `assets` | |
| OP-W-04 | `receiver`'s loan token balance increases by `assets` | |
| OP-W-05 | Post-condition: `market[id].totalBorrowAssets <= market[id].totalSupplyAssets` | Liquidity maintained |
| OP-W-06 | Only authorized senders can withdraw | |
| OP-W-07 | No other position's `supplyShares` changes | |
| OP-W-08 | `market[id].lastUpdate` becomes `block.timestamp` | |
| OP-W-09 | **[FLAG: REPEATS CODE]** If `assets > 0`: `shares = assets * (totalSupplyShares + VIRTUAL_SHARES) / (totalSupplyAssets + VIRTUAL_ASSETS)` rounded up | Direct math copy |

### 7.3 borrow()

| ID | Property | Notes |
|----|----------|-------|
| OP-B-01 | `position[id][onBehalf].borrowShares` increases | |
| OP-B-02 | `market[id].totalBorrowShares` increases by same amount as position | |
| OP-B-03 | `market[id].totalBorrowAssets` increases by `assets` | |
| OP-B-04 | `receiver`'s loan token balance increases by `assets` | |
| OP-B-05 | Post-condition: position must be healthy | |
| OP-B-06 | Post-condition: `market[id].totalBorrowAssets <= market[id].totalSupplyAssets` | Liquidity maintained |
| OP-B-07 | Only authorized senders can borrow | |
| OP-B-08 | `position[id][onBehalf].collateral` unchanged | |
| OP-B-09 | No other position changes | |
| OP-B-10 | `market[id].lastUpdate` becomes `block.timestamp` | |
| OP-B-11 | **[FLAG: REPEATS CODE]** If `assets > 0`: `shares = assets * (totalBorrowShares + VIRTUAL_SHARES) / (totalBorrowAssets + VIRTUAL_ASSETS)` rounded up | Direct math copy |

### 7.4 repay()

| ID | Property | Notes |
|----|----------|-------|
| OP-R-01 | `position[id][onBehalf].borrowShares` decreases | |
| OP-R-02 | `market[id].totalBorrowShares` decreases by same amount as position | |
| OP-R-03 | `market[id].totalBorrowAssets` decreases (using zeroFloorSub) | |
| OP-R-04 | Contract's loan token balance increases by `assets` | |
| OP-R-05 | Anyone can repay on behalf of anyone (permissionless) | |
| OP-R-06 | `position[id][onBehalf].collateral` unchanged | |
| OP-R-07 | No other position changes | |
| OP-R-08 | `market[id].lastUpdate` becomes `block.timestamp` | |
| OP-R-09 | **[FLAG: REPEATS CODE]** If `assets > 0`: `shares = assets * (totalBorrowShares + VIRTUAL_SHARES) / (totalBorrowAssets + VIRTUAL_ASSETS)` rounded down | Direct math copy |

### 7.5 supplyCollateral()

| ID | Property | Notes |
|----|----------|-------|
| OP-SC-01 | `position[id][onBehalf].collateral` increases by `assets` | |
| OP-SC-02 | Contract's collateral token balance increases by `assets` | |
| OP-SC-03 | Anyone can supply collateral on behalf of anyone (permissionless) | |
| OP-SC-04 | `market[id].lastUpdate` unchanged (no interest accrual) | |
| OP-SC-05 | `market[id].totalSupplyAssets` unchanged | |
| OP-SC-06 | `market[id].totalBorrowAssets` unchanged | |
| OP-SC-07 | No position's `supplyShares` or `borrowShares` changes | |
| OP-SC-08 | No other position's `collateral` changes | |

### 7.6 withdrawCollateral()

| ID | Property | Notes |
|----|----------|-------|
| OP-WC-01 | `position[id][onBehalf].collateral` decreases by `assets` | |
| OP-WC-02 | `receiver`'s collateral token balance increases by `assets` | |
| OP-WC-03 | Post-condition: position must be healthy | |
| OP-WC-04 | Only authorized senders can withdraw collateral | |
| OP-WC-05 | `market[id].lastUpdate` becomes `block.timestamp` | |
| OP-WC-06 | No position's `supplyShares` changes | |
| OP-WC-07 | No other position's `collateral` or `borrowShares` changes | |

### 7.7 liquidate()

| ID | Property | Notes |
|----|----------|-------|
| OP-L-01 | Pre-condition: position must be unhealthy | |
| OP-L-02 | `position[id][borrower].borrowShares` decreases by `repaidShares` | |
| OP-L-03 | `position[id][borrower].collateral` decreases by `seizedAssets` | |
| OP-L-04 | `market[id].totalBorrowShares` decreases | |
| OP-L-05 | `market[id].totalBorrowAssets` decreases | |
| OP-L-06 | Liquidator receives `seizedAssets` of collateral token | |
| OP-L-07 | Contract receives `repaidAssets` of loan token | |
| OP-L-08 | Anyone can liquidate (permissionless) | |
| OP-L-09 | If `position[id][borrower].collateral == 0` after seizure, bad debt is socialized | |
| OP-L-10 | Bad debt socialization: `market[id].totalSupplyAssets` decreases by `badDebtAssets` | |
| OP-L-11 | Bad debt socialization: `position[id][borrower].borrowShares` becomes 0 | |
| OP-L-12 | `seizedAssets * price <= repaidAssets * liquidationIncentiveFactor` | Liquidator gets bonus |
| OP-L-13 | `market[id].lastUpdate` becomes `block.timestamp` | |
| OP-L-14 | No other borrower's position changes | |
| OP-L-15 | **[FLAG: REPEATS CODE]** `liquidationIncentiveFactor = min(1.15e18, WAD / (WAD - 0.3e18 * (WAD - lltv) / WAD))` | Direct math copy |

### 7.8 accrueInterest()

| ID | Property | Notes |
|----|----------|-------|
| OP-AI-01 | `market[id].lastUpdate` becomes `block.timestamp` | |
| OP-AI-02 | If `elapsed == 0`, no state changes except lastUpdate verification | |
| OP-AI-03 | If `irm == address(0)`, only `lastUpdate` changes | |
| OP-AI-04 | `interest = totalBorrowAssets * (e^(rate * elapsed) - 1)` approximately | |
| OP-AI-05 | `totalSupplyAssets` increases by `interest` | |
| OP-AI-06 | `totalBorrowAssets` increases by `interest` | |
| OP-AI-07 | `totalSupplyAssets_new - totalSupplyAssets_old == totalBorrowAssets_new - totalBorrowAssets_old` | Supply and borrow increase equally |
| OP-AI-08 | If `fee > 0`: `feeRecipient.supplyShares` increases | |
| OP-AI-09 | If `fee > 0`: `totalSupplyShares` increases by `feeShares` | |
| OP-AI-10 | If `fee == 0`: no share changes | |
| OP-AI-11 | No position's `borrowShares` or `collateral` changes | |
| OP-AI-12 | Interest accrual is idempotent within same block | |

### 7.9 flashLoan()

| ID | Property | Notes |
|----|----------|-------|
| OP-FL-01 | Contract's token balance unchanged after call (assets returned) | |
| OP-FL-02 | No state variables change | |
| OP-FL-03 | No market data changes | |
| OP-FL-04 | No position data changes | |
| OP-FL-05 | Anyone can flash loan (permissionless) | |

### 7.10 setAuthorization()

| ID | Property | Notes |
|----|----------|-------|
| OP-SA-01 | `isAuthorized[msg.sender][authorized]` changes to `newIsAuthorized` | |
| OP-SA-02 | No other `isAuthorized` entry changes | |
| OP-SA-03 | No market or position data changes | |
| OP-SA-04 | `nonce` values unchanged | |

### 7.11 setAuthorizationWithSig()

| ID | Property | Notes |
|----|----------|-------|
| OP-SAS-01 | `isAuthorized[authorizer][authorized]` changes to `authorization.isAuthorized` | |
| OP-SAS-02 | `nonce[authorizer]` increases by exactly 1 | |
| OP-SAS-03 | Signature must be valid for the authorizer | |
| OP-SAS-04 | `block.timestamp <= authorization.deadline` | |
| OP-SAS-05 | `authorization.nonce == nonce[authorizer]` (pre-increment value) | |
| OP-SAS-06 | Same nonce cannot be used twice | Replay protection |

### 7.12 createMarket()

| ID | Property | Notes |
|----|----------|-------|
| OP-CM-01 | Pre-condition: `market[id].lastUpdate == 0` | Market must not exist |
| OP-CM-02 | Pre-condition: `isIrmEnabled[marketParams.irm] == true` | IRM must be whitelisted |
| OP-CM-03 | Pre-condition: `isLltvEnabled[marketParams.lltv] == true` | LLTV must be whitelisted |
| OP-CM-04 | `market[id].lastUpdate` becomes `block.timestamp` | |
| OP-CM-05 | `market[id].totalSupplyAssets == 0` | |
| OP-CM-06 | `market[id].totalBorrowAssets == 0` | |
| OP-CM-07 | `market[id].totalSupplyShares == 0` | |
| OP-CM-08 | `market[id].totalBorrowShares == 0` | |
| OP-CM-09 | `market[id].fee == 0` | |
| OP-CM-10 | `idToMarketParams[id]` is set to `marketParams` | |
| OP-CM-11 | Anyone can create a market (permissionless) | |
| OP-CM-12 | Same market cannot be created twice | |

### 7.13 setFee()

| ID | Property | Notes |
|----|----------|-------|
| OP-SF-01 | Only owner can call | |
| OP-SF-02 | Pre-condition: market must exist | |
| OP-SF-03 | `newFee <= MAX_FEE` | |
| OP-SF-04 | Interest accrued with OLD fee before update | |
| OP-SF-05 | `market[id].fee` becomes `newFee` | |
| OP-SF-06 | `market[id].lastUpdate` becomes `block.timestamp` | |

### 7.14 setOwner()

| ID | Property | Notes |
|----|----------|-------|
| OP-SO-01 | Only current owner can call | |
| OP-SO-02 | `owner` becomes `newOwner` | |
| OP-SO-03 | No market or position data changes | |

### 7.15 setFeeRecipient()

| ID | Property | Notes |
|----|----------|-------|
| OP-SFR-01 | Only owner can call | |
| OP-SFR-02 | `feeRecipient` becomes `newFeeRecipient` | |
| OP-SFR-03 | No market or position data changes | |
| OP-SFR-04 | Old feeRecipient retains their accumulated `supplyShares` | |

### 7.16 enableIrm()

| ID | Property | Notes |
|----|----------|-------|
| OP-EI-01 | Only owner can call | |
| OP-EI-02 | `isIrmEnabled[irm]` becomes `true` | |
| OP-EI-03 | Cannot be called if already enabled | |

### 7.17 enableLltv()

| ID | Property | Notes |
|----|----------|-------|
| OP-EL-01 | Only owner can call | |
| OP-EL-02 | Pre-condition: `lltv < WAD` | |
| OP-EL-03 | `isLltvEnabled[lltv]` becomes `true` | |
| OP-EL-04 | Cannot be called if already enabled | |

---

## Summary of Flagged Properties

The following properties repeat the exact math from the code and may be difficult to independently verify:

| ID | Operation | Reason |
|----|-----------|--------|
| OP-S-10 | supply | Share calculation is identical to code |
| OP-W-09 | withdraw | Share calculation is identical to code |
| OP-B-11 | borrow | Share calculation is identical to code |
| OP-R-09 | repay | Share calculation is identical to code |
| OP-L-15 | liquidate | Liquidation incentive factor calculation is identical to code |

---

## Properties Excluded (Immutable/Obvious)

The following properties were excluded from this specification:

### Tied to Immutable Values
- DOMAIN_SEPARATOR correctness (computed once in constructor)
- VIRTUAL_SHARES and VIRTUAL_ASSETS constants
- MAX_FEE, LIQUIDATION_CURSOR, MAX_LIQUIDATION_INCENTIVE_FACTOR constants
- ORACLE_PRICE_SCALE constant

### Obvious/Trivial
- unsigned integers cannot be negative
- array lengths are non-negative
- mappings return default values for unset keys
- `block.timestamp` is always increasing across transactions
- division by zero reverts
- arithmetic overflow reverts (Solidity 0.8+)
