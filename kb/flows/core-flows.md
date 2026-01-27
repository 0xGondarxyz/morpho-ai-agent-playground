# Core Usage Flows

## 1. Supply Flow

### Actor
Lender

### Prerequisites
- Market exists (createMarket called)
- Tokens approved to Morpho (or use callback)
- onBehalf != address(0)

### Steps
1. (Optional) Approve Morpho to spend loanToken
2. Call `supply(marketParams, assets, shares, onBehalf, data)`
   - Exactly one of assets/shares must be zero
3. Contract calls `_accrueInterest()`
4. Contract calculates shares (if assets given) or assets (if shares given)
5. Contract updates position: `position[id][onBehalf].supplyShares += shares`
6. Contract updates market totals
7. Contract emits `Supply(id, caller, onBehalf, assets, shares)`
8. If `data.length > 0`: callback `onMorphoSupply(assets, data)`
9. Contract pulls loanToken from caller via `safeTransferFrom`

### Events
- `Supply(id, caller, onBehalf, assets, shares)`

### Revert Conditions
- `MARKET_NOT_CREATED` - market doesn't exist
- `INCONSISTENT_INPUT` - not exactly one zero between assets/shares
- `ZERO_ADDRESS` - onBehalf is address(0)
- ERC20 revert - transfer fails

---

## 2. Withdraw Flow

### Actor
Lender (or authorized operator)

### Prerequisites
- Has supply shares (or is authorized for someone who does)
- Sufficient liquidity in market

### Steps
1. Call `withdraw(marketParams, assets, shares, onBehalf, receiver)`
2. Contract verifies `_isSenderAuthorized(onBehalf)`
3. Contract calls `_accrueInterest()`
4. Contract calculates shares (if assets given) or assets (if shares given)
5. Contract updates position: `position[id][onBehalf].supplyShares -= shares`
6. Contract updates market totals
7. Contract verifies liquidity: `totalBorrowAssets <= totalSupplyAssets`
8. Contract emits `Withdraw(id, caller, onBehalf, receiver, assets, shares)`
9. Contract transfers loanToken to receiver via `safeTransfer`

### Events
- `Withdraw(id, caller, onBehalf, receiver, assets, shares)`

### Revert Conditions
- `MARKET_NOT_CREATED` - market doesn't exist
- `INCONSISTENT_INPUT` - not exactly one zero
- `ZERO_ADDRESS` - receiver is address(0)
- `UNAUTHORIZED` - not authorized to act for onBehalf
- `INSUFFICIENT_LIQUIDITY` - not enough available to withdraw
- Underflow - withdrawing more shares than owned

---

## 3. Supply Collateral Flow

### Actor
Borrower

### Prerequisites
- Market exists
- Collateral tokens approved (or use callback)

### Steps
1. (Optional) Approve Morpho to spend collateralToken
2. Call `supplyCollateral(marketParams, assets, onBehalf, data)`
3. Contract updates position: `position[id][onBehalf].collateral += assets`
4. Contract emits `SupplyCollateral(id, caller, onBehalf, assets)`
5. If `data.length > 0`: callback `onMorphoSupplyCollateral(assets, data)`
6. Contract pulls collateralToken from caller

### Events
- `SupplyCollateral(id, caller, onBehalf, assets)`

### Revert Conditions
- `MARKET_NOT_CREATED`
- `ZERO_ASSETS` - assets is 0
- `ZERO_ADDRESS` - onBehalf is address(0)
- ERC20 revert

**Note**: Interest is NOT accrued (saves gas, not needed for collateral).

---

## 4. Borrow Flow

### Actor
Borrower (or authorized operator)

### Prerequisites
- Has sufficient collateral
- Will remain healthy after borrow
- Market has sufficient liquidity

### Steps
1. Call `borrow(marketParams, assets, shares, onBehalf, receiver)`
2. Contract verifies `_isSenderAuthorized(onBehalf)`
3. Contract calls `_accrueInterest()`
4. Contract calculates shares (if assets given) or assets (if shares given)
5. Contract updates position: `position[id][onBehalf].borrowShares += shares`
6. Contract updates market totals
7. Contract verifies health: `_isHealthy(marketParams, id, onBehalf)`
8. Contract verifies liquidity: `totalBorrowAssets <= totalSupplyAssets`
9. Contract emits `Borrow(id, caller, onBehalf, receiver, assets, shares)`
10. Contract transfers loanToken to receiver

### Events
- `Borrow(id, caller, onBehalf, receiver, assets, shares)`

### Revert Conditions
- `MARKET_NOT_CREATED`
- `INCONSISTENT_INPUT`
- `ZERO_ADDRESS` - receiver is address(0)
- `UNAUTHORIZED`
- `INSUFFICIENT_COLLATERAL` - would be unhealthy
- `INSUFFICIENT_LIQUIDITY`

---

## 5. Repay Flow

### Actor
Borrower (or anyone for onBehalf)

### Prerequisites
- Has debt to repay
- Loan tokens approved (or use callback)

### Steps
1. (Optional) Approve Morpho to spend loanToken
2. Call `repay(marketParams, assets, shares, onBehalf, data)`
3. Contract calls `_accrueInterest()`
4. Contract calculates shares (if assets given) or assets (if shares given)
5. Contract updates position: `position[id][onBehalf].borrowShares -= shares`
6. Contract updates market totals (uses zeroFloorSub for rounding)
7. Contract emits `Repay(id, caller, onBehalf, assets, shares)`
8. If `data.length > 0`: callback `onMorphoRepay(assets, data)`
9. Contract pulls loanToken from caller

### Events
- `Repay(id, caller, onBehalf, assets, shares)`

### Revert Conditions
- `MARKET_NOT_CREATED`
- `INCONSISTENT_INPUT`
- `ZERO_ADDRESS` - onBehalf is address(0)
- Underflow - repaying more than borrowed
- ERC20 revert

---

## 6. Withdraw Collateral Flow

### Actor
Borrower (or authorized operator)

### Prerequisites
- Has collateral
- Will remain healthy after withdrawal (if has debt)

### Steps
1. Call `withdrawCollateral(marketParams, assets, onBehalf, receiver)`
2. Contract verifies `_isSenderAuthorized(onBehalf)`
3. Contract calls `_accrueInterest()`
4. Contract updates position: `position[id][onBehalf].collateral -= assets`
5. Contract verifies health: `_isHealthy(marketParams, id, onBehalf)`
6. Contract emits `WithdrawCollateral(id, caller, onBehalf, receiver, assets)`
7. Contract transfers collateralToken to receiver

### Events
- `WithdrawCollateral(id, caller, onBehalf, receiver, assets)`

### Revert Conditions
- `MARKET_NOT_CREATED`
- `ZERO_ASSETS`
- `ZERO_ADDRESS` - receiver is address(0)
- `UNAUTHORIZED`
- `INSUFFICIENT_COLLATERAL` - would be unhealthy
- Underflow - withdrawing more than deposited

---

## 7. Liquidation Flow

### Actor
Liquidator (anyone)

### Prerequisites
- Borrower position is unhealthy (LTV >= LLTV)
- Liquidator has/can acquire loan tokens

### Steps
1. Call `liquidate(marketParams, borrower, seizedAssets, repaidShares, data)`
2. Contract calls `_accrueInterest()`
3. Contract gets oracle price
4. Contract verifies position unhealthy: `!_isHealthy(..., collateralPrice)`
5. Contract calculates liquidation incentive factor (LIF)
6. Contract calculates seizedAssets or repaidShares (one must be zero)
7. Contract calculates repaidAssets
8. Contract updates borrower's borrowShares and collateral
9. Contract updates market totals
10. If borrower has 0 collateral but remaining debt: realize bad debt
11. Contract emits `Liquidate(...)`
12. Contract transfers collateral to liquidator
13. If `data.length > 0`: callback `onMorphoLiquidate(repaidAssets, data)`
14. Contract pulls loanToken from liquidator

### LIF Calculation
```solidity
LIF = min(MAX_LIQUIDATION_INCENTIVE_FACTOR, WAD / (WAD - LIQUIDATION_CURSOR * (WAD - lltv)))
```

### Events
- `Liquidate(id, caller, borrower, repaidAssets, repaidShares, seizedAssets, badDebtAssets, badDebtShares)`

### Revert Conditions
- `MARKET_NOT_CREATED`
- `INCONSISTENT_INPUT`
- `HEALTHY_POSITION` - borrower is healthy
- Underflow - seizing more collateral than available

---

## 8. Flash Loan Flow

### Actor
Flash Borrower (anyone)

### Prerequisites
- Implement `IMorphoFlashLoanCallback`
- Can repay in same transaction

### Steps
1. Call `flashLoan(token, assets, data)`
2. Contract emits `FlashLoan(caller, token, assets)`
3. Contract transfers tokens to caller
4. Contract calls `onMorphoFlashLoan(assets, data)` on caller
5. (Callback executes - must approve Morpho)
6. Contract pulls tokens back from caller

### Events
- `FlashLoan(caller, token, assets)`

### Revert Conditions
- `ZERO_ASSETS` - assets is 0
- Callback doesn't approve/have tokens
- ERC20 revert

**Note**: Flash loans have access to ALL tokens in contract (liquidity + collateral).

---

## 9. Market Creation Flow

### Actor
Anyone

### Prerequisites
- IRM is enabled (or address(0))
- LLTV is enabled
- Market doesn't already exist

### Steps
1. Call `createMarket(marketParams)`
2. Contract verifies IRM enabled
3. Contract verifies LLTV enabled
4. Contract verifies market doesn't exist
5. Contract sets `market[id].lastUpdate = block.timestamp`
6. Contract stores `idToMarketParams[id] = marketParams`
7. Contract emits `CreateMarket(id, marketParams)`
8. If IRM != address(0): call `IRM.borrowRate()` to initialize

### Events
- `CreateMarket(id, marketParams)`

### Revert Conditions
- `IRM_NOT_ENABLED`
- `LLTV_NOT_ENABLED`
- `MARKET_ALREADY_CREATED`

---

## 10. Authorization Flow

### Actor
User (for direct) or Anyone (for signature)

### Direct Authorization
1. Call `setAuthorization(authorized, newIsAuthorized)`
2. Contract verifies state change
3. Contract updates `isAuthorized[caller][authorized]`
4. Contract emits `SetAuthorization(caller, caller, authorized, newIsAuthorized)`

### Signature Authorization
1. Call `setAuthorizationWithSig(authorization, signature)`
2. Contract verifies deadline not passed
3. Contract verifies and increments nonce
4. Contract verifies EIP-712 signature
5. Contract updates `isAuthorized[authorizer][authorized]`
6. Contract emits `IncrementNonce` and `SetAuthorization`

### Events
- `SetAuthorization(caller, authorizer, authorized, newIsAuthorized)`
- `IncrementNonce(caller, authorizer, usedNonce)` (signature only)

### Revert Conditions
- `ALREADY_SET` - no state change (direct)
- `SIGNATURE_EXPIRED` - deadline passed
- `INVALID_NONCE` - wrong nonce
- `INVALID_SIGNATURE` - signature doesn't match
