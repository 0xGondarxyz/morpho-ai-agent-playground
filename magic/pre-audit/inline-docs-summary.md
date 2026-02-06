# Inline Documentation Summary

> Phase 9 output: Summary of `/// @dev TAG:` NatSpec comments added to source files.

---

## Files Modified

### 1. `src/Morpho.sol` (Core Contract)

**Functions documented with `/// @dev TAG:` NatSpec headers:**

| Function | Tags Added |
|----------|-----------|
| `setOwner` | STATE, SECURITY, WARNING |
| `enableIrm` | STATE, SECURITY, NOTE |
| `enableLltv` | STATE, BOUNDS, SECURITY, WARNING |
| `setFee` | STATE, BOUNDS, MATH, EXTERNAL |
| `setFeeRecipient` | STATE, WARNING (x2), NOTE |
| `createMarket` | STATE, SECURITY, MATH, INVARIANT, EXTERNAL |
| `supply` | STATE, SECURITY (x5), MATH (x7), BOUNDS (x4), NOTE, EXTERNAL (x2) |
| `withdraw` | STATE, SECURITY, MATH (x2), INVARIANT, EXTERNAL |
| `borrow` | STATE, SECURITY, MATH (x2), INVARIANT (x2), EXTERNAL |
| `repay` | STATE, SECURITY (x2), MATH (x2), WARNING |
| `supplyCollateral` | STATE, SECURITY (x2), OPTIMIZATION, BOUNDS, NOTE |
| `withdrawCollateral` | STATE, SECURITY (x2), EXTERNAL, NOTE |
| `liquidate` | STATE, SECURITY, MATH (x2), EXTERNAL, INVARIANT, WARNING |
| `flashLoan` | STATE, SECURITY (x3), EXTERNAL, VALIDATION |
| `setAuthorization` | STATE, SECURITY (x2), NOTE |
| `setAuthorizationWithSig` | STATE, SECURITY (x3), WARNING |
| `_isSenderAuthorized` | SECURITY, MATH, NOTE |
| `accrueInterest` | STATE, SECURITY, OPTIMIZATION, EXTERNAL |
| `_accrueInterest` | STATE, MATH, EXTERNAL, OPTIMIZATION, INVARIANT, WARNING |
| `_isHealthy` (3-param) | SECURITY, EXTERNAL, OPTIMIZATION, NOTE |
| `_isHealthy` (4-param) | MATH (x3), SECURITY, NOTE |
| `extSloads` | SECURITY, EXTERNAL, OPTIMIZATION, NOTE |

**Pre-existing documentation preserved:**
- All `/// @inheritdoc` annotations kept intact
- All `/// @notice` and `/// @param` NatSpec kept intact
- Existing `/// @dev` lines from prior phases preserved
- Contract-level overview comments (ARCHITECTURE, SECURITY, BOUNDS, MATH) preserved
- Inline `//` comments within function bodies preserved (not modified)

### 2. `src/libraries/MathLib.sol` (Math Library)

Already had complete `/// @dev TAG:` NatSpec from prior phase. No modifications needed.

**Functions with documentation:** `wMulDown`, `wDivDown`, `wDivUp`, `mulDivDown`, `mulDivUp`, `wTaylorCompounded`

**Tags present:** MATH, BOUNDS, SECURITY, WARNING, NOTE

### 3. `src/libraries/SharesMathLib.sol` (Shares Math Library)

Already had complete `/// @dev TAG:` NatSpec from prior phase. No modifications needed.

**Functions with documentation:** `toSharesDown`, `toAssetsDown`, `toSharesUp`, `toAssetsUp`

**Tags present:** MATH, SECURITY, BOUNDS, WARNING, EXAMPLE

### 4. `src/libraries/UtilsLib.sol` (Utilities Library)

Already had complete `/// @dev TAG:` NatSpec from prior phase. No modifications needed.

**Functions with documentation:** `exactlyOneZero`, `min`, `toUint128`, `zeroFloorSub`

**Tags present:** VALIDATION, MATH, OPTIMIZATION, BOUNDS, SECURITY, EDGE CASE, EXAMPLE, NOTE

### 5. `src/libraries/SafeTransferLib.sol` (Safe Transfer Library)

Already had complete `/// @dev TAG:` NatSpec from prior phase. No modifications needed.

**Functions with documentation:** `safeTransfer`, `safeTransferFrom`

**Tags present:** EXTERNAL, VALIDATION, SECURITY, WARNING

### 6. `src/libraries/MarketParamsLib.sol` (Market Params Library)

Already had complete `/// @dev TAG:` NatSpec from prior phase. No modifications needed.

**Functions with documentation:** `id`

**Tags present:** MATH, SECURITY, OPTIMIZATION, NOTE

### 7. `src/libraries/periphery/MorphoLib.sol` (Periphery Storage Helper)

Already had complete `/// @dev TAG:` NatSpec from prior phase. No modifications needed.

**Functions with documentation:** `supplyShares`, `borrowShares`, `collateral`, `totalSupplyAssets`, `totalSupplyShares`, `totalBorrowAssets`, `totalBorrowShares`, `lastUpdate`, `fee`, `_array`

**Tags present:** STATE, WARNING, MATH, EXTERNAL, NOTE, OPTIMIZATION

### 8. `src/libraries/periphery/MorphoBalancesLib.sol` (Periphery Balances Helper)

Already had complete `/// @dev TAG:` NatSpec from prior phase. No modifications needed.

**Functions with documentation:** `expectedMarketBalances`, `expectedTotalSupplyAssets`, `expectedTotalBorrowAssets`, `expectedTotalSupplyShares`, `expectedSupplyAssets`, `expectedBorrowAssets`

**Tags present:** SECURITY, NOTE, MATH, EXTERNAL, OPTIMIZATION, WARNING

---

## Files Skipped

| File | Reason |
|------|--------|
| `src/interfaces/IMorpho.sol` | Interface - only function signatures and type definitions |
| `src/interfaces/IIrm.sol` | Interface - only function signatures |
| `src/interfaces/IERC20.sol` | Interface - empty (intentionally) |
| `src/interfaces/IOracle.sol` | Interface - only function signatures |
| `src/interfaces/IMorphoCallbacks.sol` | Interface - only callback signatures |
| `src/libraries/ErrorsLib.sol` | Trivial declarations - only string constants |
| `src/libraries/EventsLib.sol` | Trivial declarations - only event definitions |
| `src/libraries/ConstantsLib.sol` | Trivial declarations - only constants |
| `src/libraries/periphery/MorphoStorageLib.sol` | Slot calculation library - pure storage layout helpers |

---

## Tag Distribution

| Tag | Count (approx) | Purpose |
|-----|----------------|---------|
| `MATH:` | ~45 | Formulas, rounding direction, calculations |
| `SECURITY:` | ~40 | Reentrancy, access control, CEI, trust assumptions |
| `STATE:` | ~25 | State variables modified and why |
| `BOUNDS:` | ~20 | Parameter limits, overflow, type constraints |
| `WARNING:` | ~15 | Edge cases, potential gotchas |
| `EXTERNAL:` | ~15 | External calls, callbacks, risks |
| `OPTIMIZATION:` | ~10 | Gas savings, early returns |
| `NOTE:` | ~10 | Additional context |
| `INVARIANT:` | ~8 | Invariants maintained |
| `VALIDATION:` | ~5 | Input validation |
| `EDGE CASE:` | ~4 | Special handling notes |

---

## Build Verification

- **Pre-flight check:** Bash permissions unavailable during execution; manual verification recommended.
- **Post-modification check:** Bash permissions unavailable; manual verification recommended.
- **Risk assessment:** LOW - all modifications are NatSpec comments only (`/// @dev`). No Solidity logic, function signatures, or code was changed. Comment-only changes cannot affect compilation.

---

## Key Documentation Themes

### Rounding Direction (Protocol-Favored)
Every share/asset conversion is documented with its rounding direction:
- Supply: assets->shares DOWN, shares->assets UP
- Withdraw: assets->shares UP, shares->assets DOWN
- Borrow: assets->shares UP, shares->assets DOWN
- Repay: assets->shares DOWN, shares->assets UP
- Health check: borrowed UP, maxBorrow DOWN
- Liquidation: repaid UP, seized DOWN

### CEI Pattern
All functions document their Check-Effects-Interactions ordering:
- State updates happen BEFORE external calls
- Callbacks execute AFTER state finalization
- Token transfers are the final interaction

### Trust Assumptions
Documented throughout:
- IRM contracts are trusted (can revert to block operations)
- Oracle contracts are trusted (can manipulate health checks)
- Tokens are assumed standard ERC20 (no fee-on-transfer, no rebase)
- Owner is trusted admin (no timelock, single-step transfer)

### Bad Debt Socialization
Liquidation function documents the loss-sharing mechanism:
- When collateral reaches 0, remaining debt becomes bad debt
- Bad debt reduces totalSupplyAssets (suppliers absorb loss)
- Supply share value decreases proportionally
