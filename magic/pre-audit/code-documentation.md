# Morpho Blue -- Code Documentation

> Function-by-function pre-audit reference for the Morpho Blue lending protocol.
> Generated from source at `src/` in the morpho-blue repository.

---

## Table of Contents

1. [Contract: Morpho](#contract-morpho)
2. [Interface: IMorphoBase / IMorphoStaticTyping / IMorpho](#interface-imorpho)
3. [Interface: IIrm](#interface-iirm)
4. [Interface: IOracle](#interface-ioracle)
5. [Interface: IERC20](#interface-ierc20)
6. [Interface: IMorphoCallbacks](#interface-imorphocallbacks)
7. [Library: MathLib](#library-mathlib)
8. [Library: SharesMathLib](#library-sharesmathlib)
9. [Library: UtilsLib](#library-utilslib)
10. [Library: SafeTransferLib](#library-safetransferlib)
11. [Library: MarketParamsLib](#library-marketparamslib)
12. [Library: ErrorsLib](#library-errorslib)
13. [Library: EventsLib](#library-eventslib)
14. [Library: ConstantsLib](#library-constantslib)
15. [Library: MorphoStorageLib (periphery)](#library-morphostoragelib)
16. [Library: MorphoLib (periphery)](#library-morpholib)
17. [Library: MorphoBalancesLib (periphery)](#library-morphobalanceslib)
18. [Security Summary](#security-summary)

---

## Contract: Morpho

| Property | Value |
|----------|-------|
| **File** | `src/Morpho.sol` |
| **Type** | contract |
| **Inherits** | `IMorphoStaticTyping` |
| **Uses** | `MathLib for uint128`, `MathLib for uint256`, `UtilsLib for uint256`, `SharesMathLib for uint256`, `SafeTransferLib for IERC20`, `MarketParamsLib for MarketParams` |
| **License** | BUSL-1.1 |
| **Solidity** | 0.8.19 |

### State Variables

| Name | Type | Mutability | Description |
|------|------|------------|-------------|
| `DOMAIN_SEPARATOR` | `bytes32` | immutable | EIP-712 domain separator, computed at deployment from chain ID and contract address |
| `owner` | `address` | mutable | Contract owner; can enable IRMs/LLTVs, set fees, transfer ownership |
| `feeRecipient` | `address` | mutable | Address receiving protocol fee shares across all markets |
| `position` | `mapping(Id => mapping(address => Position))` | mutable | Per-user position in each market (supplyShares, borrowShares, collateral) |
| `market` | `mapping(Id => Market)` | mutable | Global market state (totals, lastUpdate, fee) |
| `isIrmEnabled` | `mapping(address => bool)` | mutable | Whitelist of enabled Interest Rate Models |
| `isLltvEnabled` | `mapping(uint256 => bool)` | mutable | Whitelist of enabled Loan-to-Value ratios |
| `isAuthorized` | `mapping(address => mapping(address => bool))` | mutable | Authorization for position management delegation |
| `nonce` | `mapping(address => uint256)` | mutable | EIP-712 nonces for replay protection |
| `idToMarketParams` | `mapping(Id => MarketParams)` | mutable | Reverse lookup from market ID to parameters |

### Modifier: onlyOwner

**Purpose:** Restricts function execution to the contract owner.

**Validation:** `require(msg.sender == owner, ErrorsLib.NOT_OWNER)`

---

### Function: constructor

    constructor(address newOwner)

**Purpose:** Initializes the Morpho contract with an owner and computes the EIP-712 domain separator.

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| `newOwner` | `address` | The initial owner of the contract |

**Returns:** None (constructor)

**Access Control:** None (deployment only)

**Validations:**

| Condition | Error | Description |
|-----------|-------|-------------|
| `newOwner != address(0)` | `ErrorsLib.ZERO_ADDRESS` | Prevents deployment with no owner |

**State Changes:**

- WRITES: `DOMAIN_SEPARATOR` = `keccak256(abi.encode(DOMAIN_TYPEHASH, block.chainid, address(this)))`
- WRITES: `owner` = `newOwner`

**Internal Calls:** None

**External Calls:** None

**Events Emitted:**

- `EventsLib.SetOwner(newOwner)`

**Security Notes:**

- CEI: Not applicable (constructor).
- Reentrancy: No external calls; no risk.
- Trust assumptions: `newOwner` is trusted as the sole admin. No two-step transfer.
- The `DOMAIN_SEPARATOR` is chain-specific but does NOT include `block.chainid` dynamically at signing time, so forks sharing the same chain ID can replay signatures.

---

### Function: setOwner

    function setOwner(address newOwner) external onlyOwner

**Purpose:** Transfers contract ownership to a new address.

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| `newOwner` | `address` | The new owner address |

**Returns:** None

**Access Control:** `onlyOwner` -- only the current `owner` can call.

**Validations:**

| Condition | Error | Description |
|-----------|-------|-------------|
| `msg.sender == owner` | `ErrorsLib.NOT_OWNER` | Via `onlyOwner` modifier |
| `newOwner != owner` | `ErrorsLib.ALREADY_SET` | Prevents no-op writes |

**State Changes:**

- READS: `owner`
- WRITES: `owner` = `newOwner`

**Internal Calls:** None

**External Calls:** None

**Events Emitted:**

- `EventsLib.SetOwner(newOwner)`

**Security Notes:**

- CEI: Checks then effects; no interactions. Handled correctly.
- Reentrancy: No external calls; no risk.
- Trust assumptions: No two-step transfer. Can set to `address(0)` permanently disabling admin. This is documented behavior.

---

### Function: enableIrm

    function enableIrm(address irm) external onlyOwner

**Purpose:** Enables an Interest Rate Model for market creation.

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| `irm` | `address` | The IRM contract address to enable |

**Returns:** None

**Access Control:** `onlyOwner`

**Validations:**

| Condition | Error | Description |
|-----------|-------|-------------|
| `msg.sender == owner` | `ErrorsLib.NOT_OWNER` | Via `onlyOwner` modifier |
| `!isIrmEnabled[irm]` | `ErrorsLib.ALREADY_SET` | Cannot re-enable |

**State Changes:**

- READS: `isIrmEnabled[irm]`
- WRITES: `isIrmEnabled[irm]` = `true`

**Internal Calls:** None

**External Calls:** None

**Events Emitted:**

- `EventsLib.EnableIrm(irm)`

**Security Notes:**

- CEI: Checks then effects; no interactions. Handled correctly.
- Reentrancy: No external calls; no risk.
- Trust assumptions: Once enabled, an IRM cannot be disabled. Owner must verify IRM correctness before enabling. `address(0)` is a valid IRM (creates zero-rate markets).

---

### Function: enableLltv

    function enableLltv(uint256 lltv) external onlyOwner

**Purpose:** Enables a Loan-to-Value ratio for market creation.

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| `lltv` | `uint256` | The LLTV value (WAD-scaled, e.g., 0.8e18 = 80%) |

**Returns:** None

**Access Control:** `onlyOwner`

**Validations:**

| Condition | Error | Description |
|-----------|-------|-------------|
| `msg.sender == owner` | `ErrorsLib.NOT_OWNER` | Via `onlyOwner` modifier |
| `!isLltvEnabled[lltv]` | `ErrorsLib.ALREADY_SET` | Cannot re-enable |
| `lltv < WAD` | `ErrorsLib.MAX_LLTV_EXCEEDED` | LLTV must be < 100% |

**State Changes:**

- READS: `isLltvEnabled[lltv]`
- WRITES: `isLltvEnabled[lltv]` = `true`

**Internal Calls:** None

**External Calls:** None

**Events Emitted:**

- `EventsLib.EnableLltv(lltv)`

**Security Notes:**

- CEI: Checks then effects; no interactions. Handled correctly.
- Reentrancy: No external calls; no risk.
- Trust assumptions: LLTV >= WAD would allow infinite borrowing. Once enabled, cannot be disabled. `lltv = 0` is technically valid but creates a market where no borrowing is possible.

---

### Function: setFee

    function setFee(MarketParams memory marketParams, uint256 newFee) external onlyOwner

**Purpose:** Sets the protocol fee for a specific market. Accrues interest with old fee first.

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| `marketParams` | `MarketParams memory` | The market parameters identifying the market |
| `newFee` | `uint256` | The new fee (WAD-scaled; 0.25e18 = 25% of interest) |

**Returns:** None

**Access Control:** `onlyOwner`

**Validations:**

| Condition | Error | Description |
|-----------|-------|-------------|
| `msg.sender == owner` | `ErrorsLib.NOT_OWNER` | Via `onlyOwner` modifier |
| `market[id].lastUpdate != 0` | `ErrorsLib.MARKET_NOT_CREATED` | Market must exist |
| `newFee != market[id].fee` | `ErrorsLib.ALREADY_SET` | Prevents no-op |
| `newFee <= MAX_FEE` | `ErrorsLib.MAX_FEE_EXCEEDED` | Fee capped at 25% |

**State Changes:**

- READS: `market[id].lastUpdate`, `market[id].fee`, `market[id].totalBorrowAssets`, `market[id].totalSupplyAssets`, `market[id].totalSupplyShares`, `market[id].totalBorrowShares`, `feeRecipient`
- WRITES: `market[id].fee`, `market[id].totalBorrowAssets`, `market[id].totalSupplyAssets`, `market[id].totalSupplyShares`, `market[id].lastUpdate`, `position[id][feeRecipient].supplyShares` (all via `_accrueInterest`)

**Internal Calls:**

- `_accrueInterest(marketParams, id)` -- accrues with old fee before setting new fee

**External Calls:**

- `[typed]` `IIrm(marketParams.irm).borrowRate(marketParams, market[id])` (via `_accrueInterest`, conditional: irm != address(0) && elapsed != 0)

**Events Emitted:**

- `EventsLib.AccrueInterest(id, borrowRate, interest, feeShares)` (via `_accrueInterest`)
- `EventsLib.SetFee(id, newFee)`

**Security Notes:**

- CEI: Interest accrual (with IRM external call) happens before fee update. The external IRM call is the only interaction, and all subsequent state changes depend only on its return value. Pattern is effectively CEI.
- Reentrancy: IRM `borrowRate()` could theoretically reenter, but the protocol trusts enabled IRMs. If IRM reenters, `_accrueInterest` would see `elapsed == 0` on second entry and return early.
- Trust assumptions: Owner must ensure IRM is non-malicious.

---

### Function: setFeeRecipient

    function setFeeRecipient(address newFeeRecipient) external onlyOwner

**Purpose:** Sets the address that receives protocol fee shares.

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| `newFeeRecipient` | `address` | The new fee recipient address |

**Returns:** None

**Access Control:** `onlyOwner`

**Validations:**

| Condition | Error | Description |
|-----------|-------|-------------|
| `msg.sender == owner` | `ErrorsLib.NOT_OWNER` | Via `onlyOwner` modifier |
| `newFeeRecipient != feeRecipient` | `ErrorsLib.ALREADY_SET` | Prevents no-op |

**State Changes:**

- READS: `feeRecipient`
- WRITES: `feeRecipient` = `newFeeRecipient`

**Internal Calls:** None

**External Calls:** None

**Events Emitted:**

- `EventsLib.SetFeeRecipient(newFeeRecipient)`

**Security Notes:**

- CEI: Checks then effects; no interactions. Handled correctly.
- Reentrancy: No external calls; no risk.
- Trust assumptions: Setting to `address(0)` causes fee shares to be minted to the zero address and effectively lost. Changing the recipient does NOT accrue interest on all markets -- the new recipient can claim not-yet-accrued fees from all markets. To avoid this, interest should be manually accrued on relevant markets before changing.

---

### Function: createMarket

    function createMarket(MarketParams memory marketParams) external

**Purpose:** Creates a new isolated lending market. Permissionless.

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| `marketParams` | `MarketParams memory` | The market configuration (loanToken, collateralToken, oracle, irm, lltv) |

**Returns:** None

**Access Control:** None (permissionless); IRM and LLTV must be owner-whitelisted.

**Validations:**

| Condition | Error | Description |
|-----------|-------|-------------|
| `isIrmEnabled[marketParams.irm]` | `ErrorsLib.IRM_NOT_ENABLED` | IRM must be whitelisted |
| `isLltvEnabled[marketParams.lltv]` | `ErrorsLib.LLTV_NOT_ENABLED` | LLTV must be whitelisted |
| `market[id].lastUpdate == 0` | `ErrorsLib.MARKET_ALREADY_CREATED` | Cannot recreate existing market |

**State Changes:**

- READS: `isIrmEnabled[marketParams.irm]`, `isLltvEnabled[marketParams.lltv]`, `market[id].lastUpdate`
- WRITES: `market[id].lastUpdate` = `uint128(block.timestamp)`, `idToMarketParams[id]` = `marketParams`

**Internal Calls:** None

**External Calls:**

- `[typed]` `IIrm(marketParams.irm).borrowRate(marketParams, market[id])` -- conditional: only if `marketParams.irm != address(0)`. Initializes stateful IRMs.

**Events Emitted:**

- `EventsLib.CreateMarket(id, marketParams)`

**Security Notes:**

- CEI: State is written before the IRM external call. The IRM call result is not used; it exists only to initialize stateful IRMs. Correct CEI.
- Reentrancy: IRM call happens after state writes. If IRM reenters `createMarket`, the second call will revert because `market[id].lastUpdate != 0`. Safe.
- Trust assumptions: Market creator trusts that the oracle, IRM, and tokens behave correctly. The protocol trusts that tokens are ERC20-compliant (no fee-on-transfer, no rebase, no reentrant transfer).
- Markets are immutable once created -- parameters cannot be changed.

---

### Function: supply

    function supply(
        MarketParams memory marketParams,
        uint256 assets,
        uint256 shares,
        address onBehalf,
        bytes calldata data
    ) external returns (uint256, uint256)

**Purpose:** Deposits loan tokens into a market, crediting supply shares to `onBehalf`.

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| `marketParams` | `MarketParams memory` | The target market |
| `assets` | `uint256` | Amount of loan tokens to supply (set 0 to use shares) |
| `shares` | `uint256` | Amount of supply shares to mint (set 0 to use assets) |
| `onBehalf` | `address` | Recipient of the supply position |
| `data` | `bytes calldata` | Callback data; empty to skip callback |

**Returns:**

| Name | Type | Description |
|------|------|-------------|
| `assets` | `uint256` | Actual assets supplied |
| `shares` | `uint256` | Actual shares minted |

**Access Control:** None (permissionless -- supplying benefits the recipient).

**Validations:**

| Condition | Error | Description |
|-----------|-------|-------------|
| `market[id].lastUpdate != 0` | `ErrorsLib.MARKET_NOT_CREATED` | Market must exist |
| `UtilsLib.exactlyOneZero(assets, shares)` | `ErrorsLib.INCONSISTENT_INPUT` | Exactly one must be zero |
| `onBehalf != address(0)` | `ErrorsLib.ZERO_ADDRESS` | Cannot credit zero address |

**State Changes:**

- READS: `market[id].lastUpdate`, `market[id].totalSupplyAssets`, `market[id].totalSupplyShares`, `market[id].totalBorrowAssets`, `market[id].totalBorrowShares`, `market[id].fee`, `feeRecipient`
- WRITES: `position[id][onBehalf].supplyShares` += `shares`, `market[id].totalSupplyShares` += `shares`, `market[id].totalSupplyAssets` += `assets`, plus `_accrueInterest` writes

**Internal Calls:**

- `_accrueInterest(marketParams, id)`

**External Calls:**

- `[typed]` `IIrm(marketParams.irm).borrowRate(marketParams, market[id])` (via `_accrueInterest`)
- `[typed]` `IMorphoSupplyCallback(msg.sender).onMorphoSupply(assets, data)` (conditional: `data.length > 0`)
- `[low-level]` `IERC20(marketParams.loanToken).safeTransferFrom(msg.sender, address(this), assets)` (via SafeTransferLib)

**Events Emitted:**

- `EventsLib.AccrueInterest(id, borrowRate, interest, feeShares)` (via `_accrueInterest`)
- `EventsLib.Supply(id, msg.sender, onBehalf, assets, shares)`

**Security Notes:**

- CEI: State updates (position and totals) happen before the callback and token transfer. Correct CEI.
- Reentrancy: Callback executes after state update. If caller reenters, state is already consistent. The final `safeTransferFrom` pulls tokens -- if it fails, entire transaction reverts.
- Rounding direction: If `assets > 0`, shares = `toSharesDown(assets, ...)` -- user gets fewer shares (protocol favored). If `shares > 0`, assets = `toAssetsUp(shares, ...)` -- user pays more (protocol favored).
- Trust assumptions: Token must not have fee-on-transfer or rebasing behavior. Callback is optional and controlled by caller.

---

### Function: withdraw

    function withdraw(
        MarketParams memory marketParams,
        uint256 assets,
        uint256 shares,
        address onBehalf,
        address receiver
    ) external returns (uint256, uint256)

**Purpose:** Burns supply shares and withdraws loan tokens from a market.

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| `marketParams` | `MarketParams memory` | The target market |
| `assets` | `uint256` | Amount of loan tokens to withdraw (set 0 to use shares) |
| `shares` | `uint256` | Amount of supply shares to burn (set 0 to use assets) |
| `onBehalf` | `address` | Owner of the supply position to withdraw from |
| `receiver` | `address` | Recipient of the withdrawn tokens |

**Returns:**

| Name | Type | Description |
|------|------|-------------|
| `assets` | `uint256` | Actual assets withdrawn |
| `shares` | `uint256` | Actual shares burned |

**Access Control:** `msg.sender` must be `onBehalf` or authorized via `isAuthorized[onBehalf][msg.sender]`.

**Validations:**

| Condition | Error | Description |
|-----------|-------|-------------|
| `market[id].lastUpdate != 0` | `ErrorsLib.MARKET_NOT_CREATED` | Market must exist |
| `UtilsLib.exactlyOneZero(assets, shares)` | `ErrorsLib.INCONSISTENT_INPUT` | Exactly one must be zero |
| `receiver != address(0)` | `ErrorsLib.ZERO_ADDRESS` | Cannot send to zero address |
| `_isSenderAuthorized(onBehalf)` | `ErrorsLib.UNAUTHORIZED` | Sender must be authorized |
| `market[id].totalBorrowAssets <= market[id].totalSupplyAssets` | `ErrorsLib.INSUFFICIENT_LIQUIDITY` | Liquidity check post-withdrawal |

**State Changes:**

- READS: `market[id].*`, `position[id][onBehalf].supplyShares`, `isAuthorized[onBehalf][msg.sender]`, `feeRecipient`
- WRITES: `position[id][onBehalf].supplyShares` -= `shares`, `market[id].totalSupplyShares` -= `shares`, `market[id].totalSupplyAssets` -= `assets`, plus `_accrueInterest` writes

**Internal Calls:**

- `_accrueInterest(marketParams, id)`
- `_isSenderAuthorized(onBehalf)`

**External Calls:**

- `[typed]` `IIrm(marketParams.irm).borrowRate(marketParams, market[id])` (via `_accrueInterest`)
- `[low-level]` `IERC20(marketParams.loanToken).safeTransfer(receiver, assets)` (via SafeTransferLib)

**Events Emitted:**

- `EventsLib.AccrueInterest(id, borrowRate, interest, feeShares)` (via `_accrueInterest`)
- `EventsLib.Withdraw(id, msg.sender, onBehalf, receiver, assets, shares)`

**Security Notes:**

- CEI: All checks and state updates precede the token transfer. Correct CEI.
- Reentrancy: No callback. Token transfer is the only external call and happens last. If the token reenters, state is already updated. Safe.
- Rounding direction: If `assets > 0`, shares = `toSharesUp(assets, ...)` -- user burns more shares (protocol favored). If `shares > 0`, assets = `toAssetsDown(shares, ...)` -- user gets fewer assets (protocol favored).
- Liquidity invariant: `totalBorrowAssets <= totalSupplyAssets` is checked after state update, ensuring withdrawal doesn't break the backing of borrows.
- Underflow on `supplyShares -= shares` acts as implicit balance check.

---

### Function: borrow

    function borrow(
        MarketParams memory marketParams,
        uint256 assets,
        uint256 shares,
        address onBehalf,
        address receiver
    ) external returns (uint256, uint256)

**Purpose:** Creates a debt position by minting borrow shares and transferring loan tokens.

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| `marketParams` | `MarketParams memory` | The target market |
| `assets` | `uint256` | Amount of loan tokens to borrow (set 0 to use shares) |
| `shares` | `uint256` | Amount of borrow shares to mint (set 0 to use assets) |
| `onBehalf` | `address` | Owner of the borrow position |
| `receiver` | `address` | Recipient of the borrowed tokens |

**Returns:**

| Name | Type | Description |
|------|------|-------------|
| `assets` | `uint256` | Actual assets borrowed |
| `shares` | `uint256` | Actual borrow shares minted |

**Access Control:** `msg.sender` must be `onBehalf` or authorized via `isAuthorized[onBehalf][msg.sender]`.

**Validations:**

| Condition | Error | Description |
|-----------|-------|-------------|
| `market[id].lastUpdate != 0` | `ErrorsLib.MARKET_NOT_CREATED` | Market must exist |
| `UtilsLib.exactlyOneZero(assets, shares)` | `ErrorsLib.INCONSISTENT_INPUT` | Exactly one must be zero |
| `receiver != address(0)` | `ErrorsLib.ZERO_ADDRESS` | Cannot send to zero address |
| `_isSenderAuthorized(onBehalf)` | `ErrorsLib.UNAUTHORIZED` | Sender must be authorized |
| `_isHealthy(marketParams, id, onBehalf)` | `ErrorsLib.INSUFFICIENT_COLLATERAL` | Position must remain healthy post-borrow |
| `market[id].totalBorrowAssets <= market[id].totalSupplyAssets` | `ErrorsLib.INSUFFICIENT_LIQUIDITY` | Liquidity check |

**State Changes:**

- READS: `market[id].*`, `position[id][onBehalf].borrowShares`, `position[id][onBehalf].collateral`, `isAuthorized[onBehalf][msg.sender]`, `feeRecipient`
- WRITES: `position[id][onBehalf].borrowShares` += `shares`, `market[id].totalBorrowShares` += `shares`, `market[id].totalBorrowAssets` += `assets`, plus `_accrueInterest` writes

**Internal Calls:**

- `_accrueInterest(marketParams, id)`
- `_isSenderAuthorized(onBehalf)`
- `_isHealthy(marketParams, id, onBehalf)` -- calls `IOracle.price()`

**External Calls:**

- `[typed]` `IIrm(marketParams.irm).borrowRate(marketParams, market[id])` (via `_accrueInterest`)
- `[typed]` `IOracle(marketParams.oracle).price()` (via `_isHealthy`)
- `[low-level]` `IERC20(marketParams.loanToken).safeTransfer(receiver, assets)` (via SafeTransferLib)

**Events Emitted:**

- `EventsLib.AccrueInterest(id, borrowRate, interest, feeShares)` (via `_accrueInterest`)
- `EventsLib.Borrow(id, msg.sender, onBehalf, receiver, assets, shares)`

**Security Notes:**

- CEI: State updates happen before both the health check (which calls oracle) and the token transfer. The oracle call reads price but doesn't modify Morpho state. Correct CEI.
- Reentrancy: Oracle and IRM are trusted external contracts. If oracle reenters, state is already consistent. Token transfer last.
- Rounding direction: If `assets > 0`, shares = `toSharesUp(assets, ...)` -- borrower owes more shares (protocol favored). If `shares > 0`, assets = `toAssetsDown(shares, ...)` -- borrower gets fewer assets (protocol favored). Health check uses `toAssetsUp` for borrowed amount (borrower appears to owe more) and `mulDivDown`/`wMulDown` for maxBorrow (borrower can borrow less).
- Trust assumptions: Oracle integrity is critical. Manipulated oracle can enable under-collateralized borrows.

---

### Function: repay

    function repay(
        MarketParams memory marketParams,
        uint256 assets,
        uint256 shares,
        address onBehalf,
        bytes calldata data
    ) external returns (uint256, uint256)

**Purpose:** Repays borrowed tokens, reducing the debt position.

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| `marketParams` | `MarketParams memory` | The target market |
| `assets` | `uint256` | Amount of loan tokens to repay (set 0 to use shares) |
| `shares` | `uint256` | Amount of borrow shares to burn (set 0 to use assets) |
| `onBehalf` | `address` | Owner of the borrow position to repay |
| `data` | `bytes calldata` | Callback data; empty to skip callback |

**Returns:**

| Name | Type | Description |
|------|------|-------------|
| `assets` | `uint256` | Actual assets repaid |
| `shares` | `uint256` | Actual borrow shares burned |

**Access Control:** None (permissionless -- repaying benefits the borrower).

**Validations:**

| Condition | Error | Description |
|-----------|-------|-------------|
| `market[id].lastUpdate != 0` | `ErrorsLib.MARKET_NOT_CREATED` | Market must exist |
| `UtilsLib.exactlyOneZero(assets, shares)` | `ErrorsLib.INCONSISTENT_INPUT` | Exactly one must be zero |
| `onBehalf != address(0)` | `ErrorsLib.ZERO_ADDRESS` | Cannot repay for zero address |

**State Changes:**

- READS: `market[id].*`, `position[id][onBehalf].borrowShares`, `feeRecipient`
- WRITES: `position[id][onBehalf].borrowShares` -= `shares`, `market[id].totalBorrowShares` -= `shares`, `market[id].totalBorrowAssets` = `zeroFloorSub(totalBorrowAssets, assets)`, plus `_accrueInterest` writes

**Internal Calls:**

- `_accrueInterest(marketParams, id)`

**External Calls:**

- `[typed]` `IIrm(marketParams.irm).borrowRate(marketParams, market[id])` (via `_accrueInterest`)
- `[typed]` `IMorphoRepayCallback(msg.sender).onMorphoRepay(assets, data)` (conditional: `data.length > 0`)
- `[low-level]` `IERC20(marketParams.loanToken).safeTransferFrom(msg.sender, address(this), assets)` (via SafeTransferLib)

**Events Emitted:**

- `EventsLib.AccrueInterest(id, borrowRate, interest, feeShares)` (via `_accrueInterest`)
- `EventsLib.Repay(id, msg.sender, onBehalf, assets, shares)`

**Security Notes:**

- CEI: State updates happen before callback and token transfer. Correct CEI.
- Reentrancy: Callback executes after state update. Safe against reentrancy.
- Rounding direction: If `assets > 0`, shares = `toSharesDown(assets, ...)` -- borrower repays fewer shares (mildly borrower-favored; negligible). If `shares > 0`, assets = `toAssetsUp(shares, ...)` -- borrower pays more assets (protocol favored).
- Edge case: `zeroFloorSub` used for `totalBorrowAssets` update because rounding can cause `assets` to exceed `totalBorrowAssets` by 1 wei. Without `zeroFloorSub`, this would underflow and revert.
- Front-running: An attacker can front-run a repay with a small repay, making the victim's transaction revert on underflow of `borrowShares`. Using `shares` input instead of `assets` is recommended for full repayment.

---

### Function: supplyCollateral

    function supplyCollateral(
        MarketParams memory marketParams,
        uint256 assets,
        address onBehalf,
        bytes calldata data
    ) external

**Purpose:** Deposits collateral tokens to back borrowing positions.

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| `marketParams` | `MarketParams memory` | The target market |
| `assets` | `uint256` | Amount of collateral tokens to deposit |
| `onBehalf` | `address` | Recipient of the collateral position |
| `data` | `bytes calldata` | Callback data; empty to skip callback |

**Returns:** None

**Access Control:** None (permissionless -- depositing collateral benefits the recipient).

**Validations:**

| Condition | Error | Description |
|-----------|-------|-------------|
| `market[id].lastUpdate != 0` | `ErrorsLib.MARKET_NOT_CREATED` | Market must exist |
| `assets != 0` | `ErrorsLib.ZERO_ASSETS` | Must supply non-zero amount |
| `onBehalf != address(0)` | `ErrorsLib.ZERO_ADDRESS` | Cannot credit zero address |

**State Changes:**

- READS: `market[id].lastUpdate`
- WRITES: `position[id][onBehalf].collateral` += `assets`

**Internal Calls:** None (interest accrual skipped -- collateral does not earn interest)

**External Calls:**

- `[typed]` `IMorphoSupplyCollateralCallback(msg.sender).onMorphoSupplyCollateral(assets, data)` (conditional: `data.length > 0`)
- `[low-level]` `IERC20(marketParams.collateralToken).safeTransferFrom(msg.sender, address(this), assets)` (via SafeTransferLib)

**Events Emitted:**

- `EventsLib.SupplyCollateral(id, msg.sender, onBehalf, assets)`

**Security Notes:**

- CEI: State update before callback and transfer. Correct CEI.
- Reentrancy: Callback executes after state update. Safe.
- Rounding direction: No math conversions -- collateral is tracked as raw uint128 assets.
- Trust assumptions: Collateral token must be ERC20-compliant, no fee-on-transfer, no rebasing.
- Gas optimization: No interest accrual because collateral does not earn interest, and supplying collateral only improves health.

---

### Function: withdrawCollateral

    function withdrawCollateral(
        MarketParams memory marketParams,
        uint256 assets,
        address onBehalf,
        address receiver
    ) external

**Purpose:** Withdraws collateral tokens, reducing the position's collateral backing.

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| `marketParams` | `MarketParams memory` | The target market |
| `assets` | `uint256` | Amount of collateral to withdraw |
| `onBehalf` | `address` | Owner of the collateral position |
| `receiver` | `address` | Recipient of the collateral tokens |

**Returns:** None

**Access Control:** `msg.sender` must be `onBehalf` or authorized via `isAuthorized[onBehalf][msg.sender]`.

**Validations:**

| Condition | Error | Description |
|-----------|-------|-------------|
| `market[id].lastUpdate != 0` | `ErrorsLib.MARKET_NOT_CREATED` | Market must exist |
| `assets != 0` | `ErrorsLib.ZERO_ASSETS` | Must withdraw non-zero |
| `receiver != address(0)` | `ErrorsLib.ZERO_ADDRESS` | Cannot send to zero address |
| `_isSenderAuthorized(onBehalf)` | `ErrorsLib.UNAUTHORIZED` | Sender must be authorized |
| `_isHealthy(marketParams, id, onBehalf)` | `ErrorsLib.INSUFFICIENT_COLLATERAL` | Position must remain healthy |

**State Changes:**

- READS: `market[id].*`, `position[id][onBehalf].collateral`, `position[id][onBehalf].borrowShares`, `isAuthorized[onBehalf][msg.sender]`, `feeRecipient`
- WRITES: `position[id][onBehalf].collateral` -= `assets`, plus `_accrueInterest` writes

**Internal Calls:**

- `_accrueInterest(marketParams, id)` -- needed for accurate debt in health check
- `_isSenderAuthorized(onBehalf)`
- `_isHealthy(marketParams, id, onBehalf)` -- calls `IOracle.price()`

**External Calls:**

- `[typed]` `IIrm(marketParams.irm).borrowRate(marketParams, market[id])` (via `_accrueInterest`)
- `[typed]` `IOracle(marketParams.oracle).price()` (via `_isHealthy`)
- `[low-level]` `IERC20(marketParams.collateralToken).safeTransfer(receiver, assets)` (via SafeTransferLib)

**Events Emitted:**

- `EventsLib.AccrueInterest(id, borrowRate, interest, feeShares)` (via `_accrueInterest`)
- `EventsLib.WithdrawCollateral(id, msg.sender, onBehalf, receiver, assets)`

**Security Notes:**

- CEI: State update (collateral decrease) happens before oracle call and token transfer. Correct CEI.
- Reentrancy: Oracle is a trusted external contract. Token transfer is last. Safe.
- Rounding direction: Health check rounds in favor of protocol (borrowed UP, maxBorrow DOWN).
- Underflow on `collateral -= assets` acts as implicit balance check.

---

### Function: liquidate

    function liquidate(
        MarketParams memory marketParams,
        address borrower,
        uint256 seizedAssets,
        uint256 repaidShares,
        bytes calldata data
    ) external returns (uint256, uint256)

**Purpose:** Liquidates an unhealthy position by repaying debt and seizing collateral at a discount.

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| `marketParams` | `MarketParams memory` | The target market |
| `borrower` | `address` | The owner of the position to liquidate |
| `seizedAssets` | `uint256` | Amount of collateral to seize (set 0 to use repaidShares) |
| `repaidShares` | `uint256` | Amount of borrow shares to repay (set 0 to use seizedAssets) |
| `data` | `bytes calldata` | Callback data; empty to skip callback |

**Returns:**

| Name | Type | Description |
|------|------|-------------|
| `seizedAssets` | `uint256` | Actual collateral seized |
| `repaidAssets` | `uint256` | Actual loan tokens repaid |

**Access Control:** None (permissionless -- economic incentive drives participation).

**Validations:**

| Condition | Error | Description |
|-----------|-------|-------------|
| `market[id].lastUpdate != 0` | `ErrorsLib.MARKET_NOT_CREATED` | Market must exist |
| `UtilsLib.exactlyOneZero(seizedAssets, repaidShares)` | `ErrorsLib.INCONSISTENT_INPUT` | Exactly one must be zero |
| `!_isHealthy(marketParams, id, borrower, collateralPrice)` | `ErrorsLib.HEALTHY_POSITION` | Position must be unhealthy |

**State Changes:**

- READS: `market[id].*`, `position[id][borrower].borrowShares`, `position[id][borrower].collateral`, `feeRecipient`
- WRITES: `position[id][borrower].borrowShares` -= `repaidShares`, `market[id].totalBorrowShares` -= `repaidShares`, `market[id].totalBorrowAssets` -= `repaidAssets` (via `zeroFloorSub`), `position[id][borrower].collateral` -= `seizedAssets`
- WRITES (bad debt): If `collateral == 0` after seizure: `market[id].totalBorrowAssets` -= `badDebtAssets`, `market[id].totalSupplyAssets` -= `badDebtAssets`, `market[id].totalBorrowShares` -= `badDebtShares`, `position[id][borrower].borrowShares` = 0
- Plus `_accrueInterest` writes

**Internal Calls:**

- `_accrueInterest(marketParams, id)`
- `_isHealthy(marketParams, id, borrower, collateralPrice)` -- 4-param version with pre-fetched price

**External Calls:**

- `[typed]` `IIrm(marketParams.irm).borrowRate(marketParams, market[id])` (via `_accrueInterest`)
- `[typed]` `IOracle(marketParams.oracle).price()` -- directly called for liquidation price
- `[typed]` `IMorphoLiquidateCallback(msg.sender).onMorphoLiquidate(repaidAssets, data)` (conditional: `data.length > 0`)
- `[low-level]` `IERC20(marketParams.collateralToken).safeTransfer(msg.sender, seizedAssets)` (via SafeTransferLib)
- `[low-level]` `IERC20(marketParams.loanToken).safeTransferFrom(msg.sender, address(this), repaidAssets)` (via SafeTransferLib)

**Events Emitted:**

- `EventsLib.AccrueInterest(id, borrowRate, interest, feeShares)` (via `_accrueInterest`)
- `EventsLib.Liquidate(id, msg.sender, borrower, repaidAssets, repaidShares, seizedAssets, badDebtAssets, badDebtShares)`

**Security Notes:**

- CEI: All state updates (borrower position, market totals, bad debt) happen before collateral transfer, callback, and repayment transfer. Correct CEI.
- Reentrancy: Oracle called before state changes (acceptable -- reads price). Collateral transfer to liquidator happens before callback. If liquidator reenters, state is already updated. Safe.
- Rounding direction:
    - When `seizedAssets > 0`: `repaidShares` calculated using `mulDivUp`, `wDivUp`, `toSharesUp` -- liquidator repays MORE (protocol favored).
    - When `repaidShares > 0`: `seizedAssets` calculated using `toAssetsDown`, `wMulDown`, `mulDivDown` -- liquidator seizes LESS collateral (protocol favored).
    - `repaidAssets = toAssetsUp(repaidShares, ...)` -- liquidator pays more.
- Bad debt socialization: When borrower's collateral reaches 0 but debt remains, the remaining debt is subtracted from both `totalBorrowAssets` and `totalSupplyAssets`. This dilutes all suppliers proportionally -- supply share value decreases.
- Liquidation Incentive Factor (LIF): `min(1.15, 1 / (1 - 0.3 * (1 - lltv)))`. At LLTV=0.8, LIF ~= 1.064 (6.4% bonus). Capped at 15%.
- Front-running: An attacker can front-run a liquidation with a small repay to make it revert. Use repaidShares input to avoid this.
- `zeroFloorSub` handles the edge case where `repaidAssets` slightly exceeds `totalBorrowAssets` due to rounding.

---

### Function: flashLoan

    function flashLoan(address token, uint256 assets, bytes calldata data) external

**Purpose:** Executes a zero-fee flash loan of any token held by the contract.

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| `token` | `address` | The token to flash loan |
| `assets` | `uint256` | Amount to borrow |
| `data` | `bytes calldata` | Callback data |

**Returns:** None

**Access Control:** None (permissionless).

**Validations:**

| Condition | Error | Description |
|-----------|-------|-------------|
| `assets != 0` | `ErrorsLib.ZERO_ASSETS` | Must borrow non-zero |

**State Changes:**

- READS: None
- WRITES: None (tokens sent and returned atomically)

**Internal Calls:** None

**External Calls:**

- `[low-level]` `IERC20(token).safeTransfer(msg.sender, assets)` (via SafeTransferLib) -- send tokens to caller
- `[typed]` `IMorphoFlashLoanCallback(msg.sender).onMorphoFlashLoan(assets, data)` -- mandatory callback
- `[low-level]` `IERC20(token).safeTransferFrom(msg.sender, address(this), assets)` (via SafeTransferLib) -- reclaim tokens

**Events Emitted:**

- `EventsLib.FlashLoan(msg.sender, token, assets)`

**Security Notes:**

- CEI: No state changes, so pattern is irrelevant. The transfer-callback-transferFrom sequence is atomic.
- Reentrancy: No state to corrupt. Reentering other Morpho functions during callback is safe because flash loan doesn't modify any state variables.
- Trust assumptions: Flash loans access ALL tokens held by the contract (all market liquidity, all collateral, donations). This is by design. Caller must approve Morpho to reclaim tokens via `transferFrom`.
- The callback is NOT optional for flash loans (unlike supply/repay callbacks). `msg.sender` must implement `IMorphoFlashLoanCallback`.
- Zero fee -- not ERC-3156 compliant but compatible with minor wrapper.

---

### Function: setAuthorization

    function setAuthorization(address authorized, bool newIsAuthorized) external

**Purpose:** Grants or revokes authorization for another address to manage the caller's positions.

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| `authorized` | `address` | The address to authorize/deauthorize |
| `newIsAuthorized` | `bool` | The new authorization status |

**Returns:** None

**Access Control:** None (only affects `msg.sender`'s authorization mapping).

**Validations:**

| Condition | Error | Description |
|-----------|-------|-------------|
| `newIsAuthorized != isAuthorized[msg.sender][authorized]` | `ErrorsLib.ALREADY_SET` | Prevents no-op |

**State Changes:**

- READS: `isAuthorized[msg.sender][authorized]`
- WRITES: `isAuthorized[msg.sender][authorized]` = `newIsAuthorized`

**Internal Calls:** None

**External Calls:** None

**Events Emitted:**

- `EventsLib.SetAuthorization(msg.sender, msg.sender, authorized, newIsAuthorized)`

**Security Notes:**

- CEI: Checks then effects; no interactions. Handled correctly.
- Reentrancy: No external calls; no risk.
- Trust assumptions: Authorizing an address grants it power to withdraw, borrow, and withdrawCollateral from the caller's positions across ALL markets. Authorization is global, not per-market.

---

### Function: setAuthorizationWithSig

    function setAuthorizationWithSig(
        Authorization memory authorization,
        Signature calldata signature
    ) external

**Purpose:** Sets authorization using an EIP-712 signature, enabling gasless/meta-transaction authorization.

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| `authorization` | `Authorization memory` | Struct with authorizer, authorized, isAuthorized, nonce, deadline |
| `signature` | `Signature calldata` | EIP-712 signature (v, r, s) |

**Returns:** None

**Access Control:** None (anyone can submit a valid signature).

**Validations:**

| Condition | Error | Description |
|-----------|-------|-------------|
| `block.timestamp <= authorization.deadline` | `ErrorsLib.SIGNATURE_EXPIRED` | Signature must not be expired |
| `authorization.nonce == nonce[authorization.authorizer]++` | `ErrorsLib.INVALID_NONCE` | Nonce must match and is consumed |
| `signatory != address(0) && authorization.authorizer == signatory` | `ErrorsLib.INVALID_SIGNATURE` | Recovered signer must match authorizer |

**State Changes:**

- READS: `nonce[authorization.authorizer]`, `DOMAIN_SEPARATOR`
- WRITES: `nonce[authorization.authorizer]` (incremented), `isAuthorized[authorization.authorizer][authorization.authorized]` = `authorization.isAuthorized`

**Internal Calls:** None

**External Calls:** None

**Events Emitted:**

- `EventsLib.IncrementNonce(msg.sender, authorization.authorizer, authorization.nonce)`
- `EventsLib.SetAuthorization(msg.sender, authorization.authorizer, authorization.authorized, authorization.isAuthorized)`

**Security Notes:**

- CEI: Checks then effects; no interactions. Handled correctly.
- Reentrancy: No external calls; no risk.
- Trust assumptions: EIP-712 provides cross-chain replay protection via `DOMAIN_SEPARATOR` (includes chain ID). However, forks sharing the same chain ID can replay signatures.
- Nonce is post-incremented atomically (`nonce[auth.authorizer]++`). Each nonce usable exactly once. Nonces are sequential -- cannot skip.
- `ecrecover` returns `address(0)` for invalid signatures; the double check (`signatory != address(0) && authorizer == signatory`) handles this.
- Signature malleability (flipping `s`) has no security impact since the nonce is consumed regardless.
- The `ALREADY_SET` check from `setAuthorization` is intentionally absent here. The nonce increment is the desired side effect; the authorization value change is secondary.

---

### Function: accrueInterest

    function accrueInterest(MarketParams memory marketParams) external

**Purpose:** Manually triggers interest accrual for a market.

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| `marketParams` | `MarketParams memory` | The target market |

**Returns:** None

**Access Control:** None (permissionless).

**Validations:**

| Condition | Error | Description |
|-----------|-------|-------------|
| `market[id].lastUpdate != 0` | `ErrorsLib.MARKET_NOT_CREATED` | Market must exist |

**State Changes:**

- Via `_accrueInterest` (see below)

**Internal Calls:**

- `_accrueInterest(marketParams, id)`

**External Calls:**

- `[typed]` `IIrm(marketParams.irm).borrowRate(marketParams, market[id])` (via `_accrueInterest`)

**Events Emitted:**

- `EventsLib.AccrueInterest(id, borrowRate, interest, feeShares)` (via `_accrueInterest`)

**Security Notes:**

- CEI: Delegated to `_accrueInterest`. The IRM call happens before state writes within `_accrueInterest`. See `_accrueInterest` notes.
- Useful for keepers to keep market state current, or before querying accurate balances off-chain.

---

### Function: _accrueInterest (internal)

    function _accrueInterest(MarketParams memory marketParams, Id id) internal

**Purpose:** Computes and applies interest accrual for a market. Core internal function called by most operations.

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| `marketParams` | `MarketParams memory` | The market parameters |
| `id` | `Id` | The market ID (must match marketParams) |

**Returns:** None

**Access Control:** Internal only.

**Validations:** None (caller must ensure market exists and params match id).

**State Changes:**

- READS: `market[id].lastUpdate`, `market[id].totalBorrowAssets`, `market[id].totalSupplyAssets`, `market[id].totalSupplyShares`, `market[id].fee`, `feeRecipient`
- WRITES: `market[id].totalBorrowAssets` += `interest`, `market[id].totalSupplyAssets` += `interest`, `market[id].totalSupplyShares` += `feeShares` (if fee > 0), `market[id].lastUpdate` = `block.timestamp`, `position[id][feeRecipient].supplyShares` += `feeShares` (if fee > 0)

**Internal Calls:** None

**External Calls:**

- `[typed]` `IIrm(marketParams.irm).borrowRate(marketParams, market[id])` -- conditional: only if `irm != address(0)` AND `elapsed != 0`

**Events Emitted:**

- `EventsLib.AccrueInterest(id, borrowRate, interest, feeShares)` -- only if `irm != address(0)` and `elapsed != 0`

**Security Notes:**

- CEI: The IRM external call happens before state writes. The call returns a rate value that determines subsequent state changes. If IRM reenters, `elapsed` would be 0 and the function returns early. Safe.
- Rounding direction: `interest = totalBorrowAssets.wMulDown(rate.wTaylorCompounded(elapsed))` -- rounds DOWN. Slightly less interest accrued (marginally borrower-favored). `feeShares = feeAmount.toSharesDown(...)` -- fee recipient gets slightly fewer shares (marginally fee-recipient-unfavored).
- Taylor expansion: Uses 3-term approximation of `e^(rt) - 1`. Accurate for typical DeFi rates (< 100% APR). Underestimates true compound interest very slightly.
- If `elapsed == 0` (same block), returns immediately. This means multiple operations in the same block share the same interest state.
- `lastUpdate` is always written, even for zero-rate markets (`irm == address(0)`).

---

### Function: _isSenderAuthorized (internal)

    function _isSenderAuthorized(address onBehalf) internal view returns (bool)

**Purpose:** Checks if `msg.sender` is authorized to manage `onBehalf`'s positions.

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| `onBehalf` | `address` | The position owner to check authorization for |

**Returns:**

| Name | Type | Description |
|------|------|-------------|
| (unnamed) | `bool` | True if sender is authorized |

**Access Control:** Internal view.

**Validations:** None.

**State Changes:**

- READS: `isAuthorized[onBehalf][msg.sender]`
- WRITES: None

**Internal Calls:** None

**External Calls:** None

**Events Emitted:** None

**Security Notes:**

- Self-authorization: `msg.sender == onBehalf` always returns true. Users can always manage their own positions.
- Global authorization: `isAuthorized` applies to all markets, not per-market.

---

### Function: _isHealthy (3-param, internal)

    function _isHealthy(
        MarketParams memory marketParams,
        Id id,
        address borrower
    ) internal view returns (bool)

**Purpose:** Checks if a borrower's position is healthy by querying the oracle for collateral price.

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| `marketParams` | `MarketParams memory` | The market parameters |
| `id` | `Id` | The market ID |
| `borrower` | `address` | The borrower to check |

**Returns:**

| Name | Type | Description |
|------|------|-------------|
| (unnamed) | `bool` | True if position is healthy |

**Access Control:** Internal view.

**Validations:** None.

**State Changes:**

- READS: `position[id][borrower].borrowShares`, `market[id].totalBorrowAssets`, `market[id].totalBorrowShares`, `position[id][borrower].collateral`
- WRITES: None

**Internal Calls:**

- `_isHealthy(marketParams, id, borrower, collateralPrice)` -- 4-param version

**External Calls:**

- `[typed]` `IOracle(marketParams.oracle).price()` -- conditional: only if `borrowShares != 0`

**Events Emitted:** None

**Security Notes:**

- Optimization: Returns `true` immediately if `borrowShares == 0` (no debt = always healthy). Saves oracle call gas.
- Trust assumptions: Oracle price is critical for health determination. Manipulated price could mark healthy positions as unhealthy (blocking withdrawals/borrows) or unhealthy positions as healthy (allowing under-collateralized borrows).

---

### Function: _isHealthy (4-param, internal)

    function _isHealthy(
        MarketParams memory marketParams,
        Id id,
        address borrower,
        uint256 collateralPrice
    ) internal view returns (bool)

**Purpose:** Checks position health with a pre-fetched collateral price (avoids redundant oracle calls).

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| `marketParams` | `MarketParams memory` | The market parameters |
| `id` | `Id` | The market ID |
| `borrower` | `address` | The borrower to check |
| `collateralPrice` | `uint256` | Pre-fetched oracle price (scaled by 1e36) |

**Returns:**

| Name | Type | Description |
|------|------|-------------|
| (unnamed) | `bool` | True if position is healthy |

**Access Control:** Internal view.

**Validations:** None.

**State Changes:**

- READS: `position[id][borrower].borrowShares`, `market[id].totalBorrowAssets`, `market[id].totalBorrowShares`, `position[id][borrower].collateral`
- WRITES: None

**Internal Calls:** None

**External Calls:** None

**Events Emitted:** None

**Security Notes:**

- Rounding direction:
    - `borrowed = borrowShares.toAssetsUp(totalBorrow...)` -- rounds UP, borrower appears to owe more.
    - `maxBorrow = collateral.mulDivDown(price, 1e36).wMulDown(lltv)` -- rounds DOWN, borrower can borrow less.
    - Combined effect: positions right at the boundary are considered unhealthy (protocol favored).
- Formula: `healthy = maxBorrow >= borrowed` where `maxBorrow = collateral * price / 1e36 * lltv / 1e18`.

---

### Function: extSloads

    function extSloads(bytes32[] calldata slots) external view returns (bytes32[] memory res)

**Purpose:** Reads arbitrary storage slots. Used by periphery libraries for gas-efficient storage access.

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| `slots` | `bytes32[] calldata` | Array of storage slot identifiers to read |

**Returns:**

| Name | Type | Description |
|------|------|-------------|
| `res` | `bytes32[] memory` | Array of values stored at the requested slots |

**Access Control:** None (permissionless view function).

**Validations:** None.

**State Changes:**

- READS: Arbitrary storage slots via `sload` assembly
- WRITES: None

**Internal Calls:** None

**External Calls:** None

**Events Emitted:** None

**Security Notes:**

- Read-only access to all storage. Cannot modify state.
- Assembly uses `memory-safe` annotation.
- No sensitive data is hidden -- all storage is publicly readable on-chain anyway.

---

## Interface: IMorphoBase / IMorphoStaticTyping / IMorpho

| Property | Value |
|----------|-------|
| **File** | `src/interfaces/IMorpho.sol` |
| **Type** | interface (3 interfaces) |
| **Inherits** | `IMorphoStaticTyping is IMorphoBase`; `IMorpho is IMorphoBase` |

Defines types: `Id`, `MarketParams`, `Position`, `Market`, `Authorization`, `Signature`.

`IMorphoBase` declares all external functions. `IMorphoStaticTyping` adds static return types for `position()`, `market()`, and `idToMarketParams()` getters. `IMorpho` adds struct return types for the same getters.

All functions documented in the Morpho contract section above. Interface functions have no implementation.

---

## Interface: IIrm

| Property | Value |
|----------|-------|
| **File** | `src/interfaces/IIrm.sol` |
| **Type** | interface |
| **Inherits** | None |

### Function: borrowRate

    function borrowRate(MarketParams memory marketParams, Market memory market) external returns (uint256)

**Purpose:** Returns the borrow rate per second (WAD-scaled). May modify IRM state (e.g., adaptive rate models).

### Function: borrowRateView

    function borrowRateView(MarketParams memory marketParams, Market memory market) external view returns (uint256)

**Purpose:** Returns the borrow rate per second (WAD-scaled) without modifying state. Used by periphery view libraries.

---

## Interface: IOracle

| Property | Value |
|----------|-------|
| **File** | `src/interfaces/IOracle.sol` |
| **Type** | interface |
| **Inherits** | None |

### Function: price

    function price() external view returns (uint256)

**Purpose:** Returns the price of 1 asset of collateral token quoted in loan token, scaled by 1e36.

**Security Notes:** Oracle is a critical trust assumption. Price manipulation can enable under-collateralized borrowing or unfair liquidations. The price scale is `10^(36 + loanDecimals - collateralDecimals)`.

---

## Interface: IERC20

| Property | Value |
|----------|-------|
| **File** | `src/interfaces/IERC20.sol` |
| **Type** | interface |
| **Inherits** | None |

Empty interface. Exists solely to prevent calling `transfer`/`transferFrom` directly instead of `safeTransfer`/`safeTransferFrom`. The `SafeTransferLib` functions take `IERC20` as a type parameter, and since `IERC20` has no `transfer`/`transferFrom` functions, the compiler prevents accidental direct calls.

---

## Interface: IMorphoCallbacks

| Property | Value |
|----------|-------|
| **File** | `src/interfaces/IMorphoCallbacks.sol` |
| **Type** | interface (5 interfaces) |
| **Inherits** | None |

### IMorphoSupplyCallback.onMorphoSupply

    function onMorphoSupply(uint256 assets, bytes calldata data) external

**Purpose:** Called during `supply()` if `data.length > 0`. Allows caller to source funds.

### IMorphoRepayCallback.onMorphoRepay

    function onMorphoRepay(uint256 assets, bytes calldata data) external

**Purpose:** Called during `repay()` if `data.length > 0`. Allows caller to source repayment funds.

### IMorphoSupplyCollateralCallback.onMorphoSupplyCollateral

    function onMorphoSupplyCollateral(uint256 assets, bytes calldata data) external

**Purpose:** Called during `supplyCollateral()` if `data.length > 0`. Allows caller to source collateral.

### IMorphoLiquidateCallback.onMorphoLiquidate

    function onMorphoLiquidate(uint256 repaidAssets, bytes calldata data) external

**Purpose:** Called during `liquidate()` if `data.length > 0`. Allows liquidator to source repayment using seized collateral.

### IMorphoFlashLoanCallback.onMorphoFlashLoan

    function onMorphoFlashLoan(uint256 assets, bytes calldata data) external

**Purpose:** Called during `flashLoan()`. Mandatory (not conditional on data length). Caller must repay via approval.

---

## Library: MathLib

| Property | Value |
|----------|-------|
| **File** | `src/libraries/MathLib.sol` |
| **Type** | library |
| **Inherits** | None |
| **Uses** | None |

File-level constant: `WAD = 1e18`

### Function: wMulDown

    function wMulDown(uint256 x, uint256 y) internal pure returns (uint256)

**Purpose:** Returns `(x * y) / WAD` rounded down.

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| `x` | `uint256` | First operand |
| `y` | `uint256` | Second operand (WAD-scaled multiplier) |

**Returns:** `uint256` -- WAD-scaled product, rounded down.

**Internal Calls:** `mulDivDown(x, y, WAD)`

**Security Notes:**

- Rounding: DOWN. Use when result should favor the protocol (user receives less).
- Overflow: Reverts if `x * y > type(uint256).max`. No phantom overflow protection.

---

### Function: wDivDown

    function wDivDown(uint256 x, uint256 y) internal pure returns (uint256)

**Purpose:** Returns `(x * WAD) / y` rounded down.

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| `x` | `uint256` | Numerator |
| `y` | `uint256` | Denominator |

**Returns:** `uint256` -- WAD-scaled quotient, rounded down.

**Internal Calls:** `mulDivDown(x, WAD, y)`

**Security Notes:**

- Rounding: DOWN.
- Reverts if `y == 0` or `x * WAD` overflows.

---

### Function: wDivUp

    function wDivUp(uint256 x, uint256 y) internal pure returns (uint256)

**Purpose:** Returns `(x * WAD) / y` rounded up.

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| `x` | `uint256` | Numerator |
| `y` | `uint256` | Denominator |

**Returns:** `uint256` -- WAD-scaled quotient, rounded up.

**Internal Calls:** `mulDivUp(x, WAD, y)`

**Security Notes:**

- Rounding: UP. Use when user should pay more (e.g., debt calculations).
- Reverts if `y == 0` or `x * WAD` overflows.

---

### Function: mulDivDown

    function mulDivDown(uint256 x, uint256 y, uint256 d) internal pure returns (uint256)

**Purpose:** Returns `(x * y) / d` rounded down. General-purpose multiply-then-divide.

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| `x` | `uint256` | First multiplicand |
| `y` | `uint256` | Second multiplicand |
| `d` | `uint256` | Divisor |

**Returns:** `uint256` -- result rounded down.

**Security Notes:**

- Rounding: DOWN. Result <= true value.
- No phantom overflow protection (unlike OpenZeppelin's `mulDiv`). Reverts if `x * y > type(uint256).max`.
- Reverts if `d == 0`.
- Implementation: `(x * y) / d`

---

### Function: mulDivUp

    function mulDivUp(uint256 x, uint256 y, uint256 d) internal pure returns (uint256)

**Purpose:** Returns `(x * y) / d` rounded up.

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| `x` | `uint256` | First multiplicand |
| `y` | `uint256` | Second multiplicand |
| `d` | `uint256` | Divisor |

**Returns:** `uint256` -- result rounded up.

**Security Notes:**

- Rounding: UP. Result >= true value.
- Implementation: `(x * y + (d - 1)) / d`
- Reverts if `d == 0` (underflow on `d - 1` when d == 0 in Solidity 0.8).
- Overflow possible if `x * y + (d - 1) > type(uint256).max`.

---

### Function: wTaylorCompounded

    function wTaylorCompounded(uint256 x, uint256 n) internal pure returns (uint256)

**Purpose:** Approximates `e^(x*n) - 1` using first three non-zero terms of Taylor expansion. Used for continuous compound interest.

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| `x` | `uint256` | Per-second rate (WAD-scaled) |
| `n` | `uint256` | Time in seconds |

**Returns:** `uint256` -- Approximation of `e^(xn) - 1` (WAD-scaled).

**Internal Calls:**

- `mulDivDown(firstTerm, firstTerm, 2 * WAD)` -- second term
- `mulDivDown(secondTerm, firstTerm, 3 * WAD)` -- third term

**Security Notes:**

- Rounding: Each term rounds DOWN via `mulDivDown`.
- Approximation accuracy: For typical DeFi rates (< 100% APR) and block-by-block accrual, error is negligible. Underestimates true compound interest (slightly borrower-favored).
- Overflow: `x * n` (firstTerm) can overflow for extreme rates or very long time periods.
- Formula: `result = xn + (xn)^2 / (2 * WAD) + (xn)^3 / (6 * WAD^2)`

---

## Library: SharesMathLib

| Property | Value |
|----------|-------|
| **File** | `src/libraries/SharesMathLib.sol` |
| **Type** | library |
| **Inherits** | None |
| **Uses** | `MathLib for uint256` |

Constants: `VIRTUAL_SHARES = 1e6`, `VIRTUAL_ASSETS = 1`

### Function: toSharesDown

    function toSharesDown(uint256 assets, uint256 totalAssets, uint256 totalShares) internal pure returns (uint256)

**Purpose:** Converts assets to shares, rounding down.

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| `assets` | `uint256` | Amount of assets to convert |
| `totalAssets` | `uint256` | Total assets in pool |
| `totalShares` | `uint256` | Total shares in pool |

**Returns:** `uint256` -- Number of shares, rounded down.

**Internal Calls:** `mulDivDown(assets, totalShares + VIRTUAL_SHARES, totalAssets + VIRTUAL_ASSETS)`

**Security Notes:**

- Rounding: DOWN. Depositor gets fewer shares (protocol favored). Used in `supply()` when user specifies assets, and `repay()` when user specifies assets.
- Virtual amounts prevent share inflation attacks and division by zero.

---

### Function: toAssetsDown

    function toAssetsDown(uint256 shares, uint256 totalAssets, uint256 totalShares) internal pure returns (uint256)

**Purpose:** Converts shares to assets, rounding down.

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| `shares` | `uint256` | Amount of shares to convert |
| `totalAssets` | `uint256` | Total assets in pool |
| `totalShares` | `uint256` | Total shares in pool |

**Returns:** `uint256` -- Number of assets, rounded down.

**Internal Calls:** `mulDivDown(shares, totalAssets + VIRTUAL_ASSETS, totalShares + VIRTUAL_SHARES)`

**Security Notes:**

- Rounding: DOWN. User receives fewer assets (protocol favored). Used in `withdraw()` when user specifies shares, `borrow()` when user specifies shares, and liquidation `seizedAssets` calculation.

---

### Function: toSharesUp

    function toSharesUp(uint256 assets, uint256 totalAssets, uint256 totalShares) internal pure returns (uint256)

**Purpose:** Converts assets to shares, rounding up.

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| `assets` | `uint256` | Amount of assets to convert |
| `totalAssets` | `uint256` | Total assets in pool |
| `totalShares` | `uint256` | Total shares in pool |

**Returns:** `uint256` -- Number of shares, rounded up.

**Internal Calls:** `mulDivUp(assets, totalShares + VIRTUAL_SHARES, totalAssets + VIRTUAL_ASSETS)`

**Security Notes:**

- Rounding: UP. User burns more shares or owes more debt shares (protocol favored). Used in `withdraw()` when user specifies assets, `borrow()` when user specifies assets, and liquidation `repaidShares` calculation.

---

### Function: toAssetsUp

    function toAssetsUp(uint256 shares, uint256 totalAssets, uint256 totalShares) internal pure returns (uint256)

**Purpose:** Converts shares to assets, rounding up.

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| `shares` | `uint256` | Amount of shares to convert |
| `totalAssets` | `uint256` | Total assets in pool |
| `totalShares` | `uint256` | Total shares in pool |

**Returns:** `uint256` -- Number of assets, rounded up.

**Internal Calls:** `mulDivUp(shares, totalAssets + VIRTUAL_ASSETS, totalShares + VIRTUAL_SHARES)`

**Security Notes:**

- Rounding: UP. User pays more assets or owes more debt (protocol favored). Used in `supply()` when user specifies shares, `repay()` when user specifies shares, health check borrowed calculation, and liquidation `repaidAssets` calculation.

---

## Library: UtilsLib

| Property | Value |
|----------|-------|
| **File** | `src/libraries/UtilsLib.sol` |
| **Type** | library |
| **Inherits** | None |
| **Uses** | None |

### Function: exactlyOneZero

    function exactlyOneZero(uint256 x, uint256 y) internal pure returns (bool z)

**Purpose:** Returns true if exactly one of `x` and `y` is zero.

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| `x` | `uint256` | First value |
| `y` | `uint256` | Second value |

**Returns:** `bool` -- true if exactly one is zero.

**Security Notes:**

- Assembly: `z := xor(iszero(x), iszero(y))`. Gas-efficient branchless implementation.
- Used to enforce that users specify either assets OR shares, not both or neither.

---

### Function: min

    function min(uint256 x, uint256 y) internal pure returns (uint256 z)

**Purpose:** Returns the minimum of `x` and `y`.

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| `x` | `uint256` | First value |
| `y` | `uint256` | Second value |

**Returns:** `uint256` -- the smaller value.

**Security Notes:**

- Assembly: `z := xor(x, mul(xor(x, y), lt(y, x)))`. Branchless.
- Used to cap liquidation incentive factor and bad debt assets.

---

### Function: toUint128

    function toUint128(uint256 x) internal pure returns (uint128)

**Purpose:** Safely downcasts uint256 to uint128, reverting on overflow.

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| `x` | `uint256` | Value to downcast |

**Returns:** `uint128` -- the downcasted value.

**Validations:**

| Condition | Error | Description |
|-----------|-------|-------------|
| `x <= type(uint128).max` | `ErrorsLib.MAX_UINT128_EXCEEDED` | Prevents silent truncation |

**Security Notes:**

- Critical for market integrity. All market totals and position values stored as uint128.
- Max uint128 = ~3.4e38. For 18-decimal tokens, this allows ~3.4e20 tokens -- sufficient for any realistic scenario.

---

### Function: zeroFloorSub

    function zeroFloorSub(uint256 x, uint256 y) internal pure returns (uint256 z)

**Purpose:** Returns `max(0, x - y)` without underflow.

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| `x` | `uint256` | Minuend |
| `y` | `uint256` | Subtrahend |

**Returns:** `uint256` -- `x - y` if `x > y`, else 0.

**Security Notes:**

- Assembly: `z := mul(gt(x, y), sub(x, y))`. Branchless.
- Critical for `repay()` and `liquidate()` where rounding can cause `repaidAssets` to exceed `totalBorrowAssets` by 1 wei. Without `zeroFloorSub`, these operations would revert on underflow.

---

## Library: SafeTransferLib

| Property | Value |
|----------|-------|
| **File** | `src/libraries/SafeTransferLib.sol` |
| **Type** | library |
| **Inherits** | None |
| **Uses** | None |

Declares internal interface `IERC20Internal` with `transfer` and `transferFrom` for ABI encoding.

### Function: safeTransfer

    function safeTransfer(IERC20 token, address to, uint256 value) internal

**Purpose:** Safely transfers ERC20 tokens from the contract, handling non-standard implementations.

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| `token` | `IERC20` | The token to transfer |
| `to` | `address` | Recipient |
| `value` | `uint256` | Amount to transfer |

**Returns:** None

**Validations:**

| Condition | Error | Description |
|-----------|-------|-------------|
| `address(token).code.length > 0` | `ErrorsLib.NO_CODE` | Token must have code (not EOA) |
| `success` | `ErrorsLib.TRANSFER_REVERTED` | Low-level call must succeed |
| `returndata.length == 0 \|\| abi.decode(returndata, (bool))` | `ErrorsLib.TRANSFER_RETURNED_FALSE` | Must return empty or true |

**External Calls:**

- `[low-level]` `address(token).call(abi.encodeCall(IERC20Internal.transfer, (to, value)))`

**Security Notes:**

- Three-check pattern: (1) code exists, (2) call succeeded, (3) return data valid. Handles USDT and other non-standard tokens.
- Does NOT support fee-on-transfer tokens. Actual amount received may differ from `value`.
- Does NOT support rebasing tokens.

---

### Function: safeTransferFrom

    function safeTransferFrom(IERC20 token, address from, address to, uint256 value) internal

**Purpose:** Safely transfers ERC20 tokens via allowance, handling non-standard implementations.

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| `token` | `IERC20` | The token to transfer |
| `from` | `address` | Source address |
| `to` | `address` | Recipient |
| `value` | `uint256` | Amount to transfer |

**Returns:** None

**Validations:**

| Condition | Error | Description |
|-----------|-------|-------------|
| `address(token).code.length > 0` | `ErrorsLib.NO_CODE` | Token must have code |
| `success` | `ErrorsLib.TRANSFER_FROM_REVERTED` | Low-level call must succeed |
| `returndata.length == 0 \|\| abi.decode(returndata, (bool))` | `ErrorsLib.TRANSFER_FROM_RETURNED_FALSE` | Must return empty or true |

**External Calls:**

- `[low-level]` `address(token).call(abi.encodeCall(IERC20Internal.transferFrom, (from, to, value)))`

**Security Notes:**

- Same three-check pattern as `safeTransfer`.
- Requires `from` to have approved `to` (typically `address(this)`) for at least `value`.
- Some tokens (e.g., USDT) require allowance to be set to 0 before setting a new non-zero value. Morpho always pulls the exact needed amount, so this is generally not an issue.

---

## Library: MarketParamsLib

| Property | Value |
|----------|-------|
| **File** | `src/libraries/MarketParamsLib.sol` |
| **Type** | library |
| **Inherits** | None |
| **Uses** | None |

Constant: `MARKET_PARAMS_BYTES_LENGTH = 5 * 32` (160 bytes)

### Function: id

    function id(MarketParams memory marketParams) internal pure returns (Id marketParamsId)

**Purpose:** Computes the market ID by hashing the market parameters.

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| `marketParams` | `MarketParams memory` | The market parameters to hash |

**Returns:** `Id` (bytes32) -- deterministic market identifier.

**Security Notes:**

- Assembly: `marketParamsId := keccak256(marketParams, MARKET_PARAMS_BYTES_LENGTH)`. Direct memory hash avoids `abi.encode` overhead.
- Deterministic: Same parameters always produce the same ID.
- Collision resistant: Different parameters produce different IDs (keccak256 property).
- Requires `marketParams` to be in memory (not calldata/storage) for direct memory hashing.

---

## Library: ErrorsLib

| Property | Value |
|----------|-------|
| **File** | `src/libraries/ErrorsLib.sol` |
| **Type** | library |
| **Inherits** | None |

No functions. Contains only `string internal constant` error messages:

| Constant | Value | Used In |
|----------|-------|---------|
| `NOT_OWNER` | `"not owner"` | `onlyOwner` modifier |
| `MAX_LLTV_EXCEEDED` | `"max LLTV exceeded"` | `enableLltv` |
| `MAX_FEE_EXCEEDED` | `"max fee exceeded"` | `setFee` |
| `ALREADY_SET` | `"already set"` | Multiple setters |
| `IRM_NOT_ENABLED` | `"IRM not enabled"` | `createMarket` |
| `LLTV_NOT_ENABLED` | `"LLTV not enabled"` | `createMarket` |
| `MARKET_ALREADY_CREATED` | `"market already created"` | `createMarket` |
| `NO_CODE` | `"no code"` | `SafeTransferLib` |
| `MARKET_NOT_CREATED` | `"market not created"` | Most operations |
| `INCONSISTENT_INPUT` | `"inconsistent input"` | supply/withdraw/borrow/repay/liquidate |
| `ZERO_ASSETS` | `"zero assets"` | supplyCollateral/withdrawCollateral/flashLoan |
| `ZERO_ADDRESS` | `"zero address"` | constructor, supply, repay, supplyCollateral |
| `UNAUTHORIZED` | `"unauthorized"` | withdraw/borrow/withdrawCollateral |
| `INSUFFICIENT_COLLATERAL` | `"insufficient collateral"` | borrow/withdrawCollateral |
| `INSUFFICIENT_LIQUIDITY` | `"insufficient liquidity"` | withdraw/borrow |
| `HEALTHY_POSITION` | `"position is healthy"` | liquidate |
| `INVALID_SIGNATURE` | `"invalid signature"` | setAuthorizationWithSig |
| `SIGNATURE_EXPIRED` | `"signature expired"` | setAuthorizationWithSig |
| `INVALID_NONCE` | `"invalid nonce"` | setAuthorizationWithSig |
| `TRANSFER_REVERTED` | `"transfer reverted"` | safeTransfer |
| `TRANSFER_RETURNED_FALSE` | `"transfer returned false"` | safeTransfer |
| `TRANSFER_FROM_REVERTED` | `"transferFrom reverted"` | safeTransferFrom |
| `TRANSFER_FROM_RETURNED_FALSE` | `"transferFrom returned false"` | safeTransferFrom |
| `MAX_UINT128_EXCEEDED` | `"max uint128 exceeded"` | toUint128 |

---

## Library: EventsLib

| Property | Value |
|----------|-------|
| **File** | `src/libraries/EventsLib.sol` |
| **Type** | library |
| **Inherits** | None |

No functions. Contains only event declarations. See Morpho contract events for usage.

---

## Library: ConstantsLib

| Property | Value |
|----------|-------|
| **File** | `src/libraries/ConstantsLib.sol` |
| **Type** | file-level constants |

| Constant | Value | Description |
|----------|-------|-------------|
| `MAX_FEE` | `0.25e18` | Maximum protocol fee (25% of interest) |
| `ORACLE_PRICE_SCALE` | `1e36` | Oracle price scaling factor |
| `LIQUIDATION_CURSOR` | `0.3e18` | Liquidation incentive curve parameter |
| `MAX_LIQUIDATION_INCENTIVE_FACTOR` | `1.15e18` | Maximum 15% liquidation bonus |
| `DOMAIN_TYPEHASH` | `keccak256("EIP712Domain(...)")` | EIP-712 domain type hash |
| `AUTHORIZATION_TYPEHASH` | `keccak256("Authorization(...)")` | EIP-712 authorization type hash |

---

## Library: MorphoStorageLib

| Property | Value |
|----------|-------|
| **File** | `src/libraries/periphery/MorphoStorageLib.sol` |
| **Type** | library (periphery) |
| **Inherits** | None |

Provides pure functions that compute Solidity storage slot positions for Morpho's state variables. Used by `MorphoLib` and `MorphoBalancesLib` to efficiently read storage via `extSloads`.

### Slot Constants

| Constant | Slot | Variable |
|----------|------|----------|
| `OWNER_SLOT` | 0 | `owner` |
| `FEE_RECIPIENT_SLOT` | 1 | `feeRecipient` |
| `POSITION_SLOT` | 2 | `position` mapping |
| `MARKET_SLOT` | 3 | `market` mapping |
| `IS_IRM_ENABLED_SLOT` | 4 | `isIrmEnabled` mapping |
| `IS_LLTV_ENABLED_SLOT` | 5 | `isLltvEnabled` mapping |
| `IS_AUTHORIZED_SLOT` | 6 | `isAuthorized` mapping |
| `NONCE_SLOT` | 7 | `nonce` mapping |
| `ID_TO_MARKET_PARAMS_SLOT` | 8 | `idToMarketParams` mapping |

### Functions (all pure, no state changes, no external calls)

- `ownerSlot()` -- returns slot for `owner`
- `feeRecipientSlot()` -- returns slot for `feeRecipient`
- `positionSupplySharesSlot(Id, address)` -- returns slot for `position[id][user].supplyShares`
- `positionBorrowSharesAndCollateralSlot(Id, address)` -- returns slot for packed `borrowShares` + `collateral`
- `marketTotalSupplyAssetsAndSharesSlot(Id)` -- returns slot for packed `totalSupplyAssets` + `totalSupplyShares`
- `marketTotalBorrowAssetsAndSharesSlot(Id)` -- returns slot for packed `totalBorrowAssets` + `totalBorrowShares`
- `marketLastUpdateAndFeeSlot(Id)` -- returns slot for packed `lastUpdate` + `fee`
- `isIrmEnabledSlot(address)` -- returns slot for `isIrmEnabled[irm]`
- `isLltvEnabledSlot(uint256)` -- returns slot for `isLltvEnabled[lltv]`
- `isAuthorizedSlot(address, address)` -- returns slot for `isAuthorized[authorizer][authorizee]`
- `nonceSlot(address)` -- returns slot for `nonce[authorizer]`
- `idToLoanTokenSlot(Id)` -- returns slot for `idToMarketParams[id].loanToken`
- `idToCollateralTokenSlot(Id)` -- returns slot for `idToMarketParams[id].collateralToken`
- `idToOracleSlot(Id)` -- returns slot for `idToMarketParams[id].oracle`
- `idToIrmSlot(Id)` -- returns slot for `idToMarketParams[id].irm`
- `idToLltvSlot(Id)` -- returns slot for `idToMarketParams[id].lltv`

**Security Notes:** All functions are pure. Slot computation matches Solidity's storage layout rules for mappings and structs. If Morpho's storage layout changes, this library must be updated.

---

## Library: MorphoLib

| Property | Value |
|----------|-------|
| **File** | `src/libraries/periphery/MorphoLib.sol` |
| **Type** | library (periphery) |
| **Inherits** | None |
| **Uses** | None (but calls MorphoStorageLib and morpho.extSloads) |

Helper library for reading Morpho storage values via `extSloads`. All functions are `internal view`.

### Functions

All follow the same pattern: compute storage slot via `MorphoStorageLib`, call `morpho.extSloads(slot)`, extract value from returned bytes32.

- `supplyShares(IMorpho, Id, address)` -- returns uint256
- `borrowShares(IMorpho, Id, address)` -- returns lower uint128 from packed slot
- `collateral(IMorpho, Id, address)` -- returns upper uint128 from packed slot (>> 128)
- `totalSupplyAssets(IMorpho, Id)` -- returns lower uint128 from packed slot
- `totalSupplyShares(IMorpho, Id)` -- returns upper uint128 from packed slot (>> 128)
- `totalBorrowAssets(IMorpho, Id)` -- returns lower uint128 from packed slot
- `totalBorrowShares(IMorpho, Id)` -- returns upper uint128 from packed slot (>> 128)
- `lastUpdate(IMorpho, Id)` -- returns lower uint128 from packed slot
- `fee(IMorpho, Id)` -- returns upper uint128 from packed slot (>> 128)
- `_array(bytes32)` -- private helper creating single-element bytes32 array

**External Calls (all functions):** `[typed]` `morpho.extSloads(slot)` -- reads storage via Morpho's `extSloads`.

**Security Notes:**

- Read-only. Cannot modify Morpho state.
- WARNING: Supply and borrow values may be STALE -- they do NOT include interest accrued since `lastUpdate`. Use `MorphoBalancesLib.expected*` functions for accurate values, or call `accrueInterest()` first.
- Collateral values are always current (collateral does not accrue interest).
- `totalBorrowShares` is always current (shares do not change with interest accrual).

---

## Library: MorphoBalancesLib

| Property | Value |
|----------|-------|
| **File** | `src/libraries/periphery/MorphoBalancesLib.sol` |
| **Type** | library (periphery) |
| **Inherits** | None |
| **Uses** | `MathLib for uint256`, `MathLib for uint128`, `UtilsLib for uint256`, `MorphoLib for IMorpho`, `SharesMathLib for uint256`, `MarketParamsLib for MarketParams` |

Provides view-only functions that simulate interest accrual without modifying state.

### Function: expectedMarketBalances

    function expectedMarketBalances(
        IMorpho morpho,
        MarketParams memory marketParams
    ) internal view returns (uint256, uint256, uint256, uint256)

**Purpose:** Returns expected (totalSupplyAssets, totalSupplyShares, totalBorrowAssets, totalBorrowShares) after simulating interest accrual.

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| `morpho` | `IMorpho` | The Morpho contract |
| `marketParams` | `MarketParams memory` | The target market |

**Returns:** `(uint256 totalSupplyAssets, uint256 totalSupplyShares, uint256 totalBorrowAssets, uint256 totalBorrowShares)`

**External Calls:**

- `[typed]` `morpho.market(id)` -- reads current market state
- `[typed]` `IIrm(marketParams.irm).borrowRateView(marketParams, market)` -- view-only rate query (conditional)

**Security Notes:**

- Uses `borrowRateView()` (view) instead of `borrowRate()` (may modify state). Safe for off-chain queries.
- Simulates exact same math as `_accrueInterest`: Taylor expansion, fee calculation, fee share minting.

---

### Function: expectedTotalSupplyAssets

    function expectedTotalSupplyAssets(IMorpho morpho, MarketParams memory marketParams) internal view returns (uint256)

**Purpose:** Returns expected total supply assets after interest accrual.

**Internal Calls:** `expectedMarketBalances(morpho, marketParams)`

---

### Function: expectedTotalBorrowAssets

    function expectedTotalBorrowAssets(IMorpho morpho, MarketParams memory marketParams) internal view returns (uint256)

**Purpose:** Returns expected total borrow assets after interest accrual.

**Internal Calls:** `expectedMarketBalances(morpho, marketParams)`

---

### Function: expectedTotalSupplyShares

    function expectedTotalSupplyShares(IMorpho morpho, MarketParams memory marketParams) internal view returns (uint256)

**Purpose:** Returns expected total supply shares after interest accrual (including fee shares).

**Internal Calls:** `expectedMarketBalances(morpho, marketParams)`

---

### Function: expectedSupplyAssets

    function expectedSupplyAssets(
        IMorpho morpho,
        MarketParams memory marketParams,
        address user
    ) internal view returns (uint256)

**Purpose:** Returns the expected supply asset balance for `user` after interest accrual.

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| `morpho` | `IMorpho` | The Morpho contract |
| `marketParams` | `MarketParams memory` | The target market |
| `user` | `address` | The user to query |

**Internal Calls:** `morpho.supplyShares(id, user)`, `expectedMarketBalances(morpho, marketParams)`, `toAssetsDown(...)`

**Security Notes:**

- Rounding: DOWN. User's displayed balance never exceeds actual redeemable amount.
- WARNING: Inaccurate for `feeRecipient` -- their share increase from fees is not included in `supplyShares` read.

---

### Function: expectedBorrowAssets

    function expectedBorrowAssets(
        IMorpho morpho,
        MarketParams memory marketParams,
        address user
    ) internal view returns (uint256)

**Purpose:** Returns the expected borrow asset balance for `user` after interest accrual.

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| `morpho` | `IMorpho` | The Morpho contract |
| `marketParams` | `MarketParams memory` | The target market |
| `user` | `address` | The user to query |

**Internal Calls:** `morpho.borrowShares(id, user)`, `expectedMarketBalances(morpho, marketParams)`, `toAssetsUp(...)`

**Security Notes:**

- Rounding: UP. User's displayed debt never underestimates actual debt. Conservative for the user.

---

## Security Summary

### Table 1: Reentrancy Vectors

| Function | External Call | State Modified After | Protected |
|----------|--------------|---------------------|-----------|
| `supply` | `IIrm.borrowRate()` via `_accrueInterest` | Interest state writes after IRM call within `_accrueInterest`; but supply state writes happen after `_accrueInterest` returns | YES -- IRM reentry sees elapsed=0, returns early |
| `supply` | `IMorphoSupplyCallback.onMorphoSupply()` | Token transfer only (no state) | YES -- all state updated before callback |
| `supply` | `IERC20.safeTransferFrom()` | None | YES -- last operation |
| `withdraw` | `IIrm.borrowRate()` via `_accrueInterest` | Same as above | YES -- IRM reentry sees elapsed=0 |
| `withdraw` | `IERC20.safeTransfer()` | None | YES -- last operation |
| `borrow` | `IIrm.borrowRate()` via `_accrueInterest` | Same as above | YES |
| `borrow` | `IOracle.price()` via `_isHealthy` | None (view call) | YES -- state already updated |
| `borrow` | `IERC20.safeTransfer()` | None | YES -- last operation |
| `repay` | `IIrm.borrowRate()` via `_accrueInterest` | Same as above | YES |
| `repay` | `IMorphoRepayCallback.onMorphoRepay()` | Token transfer only | YES -- all state updated before callback |
| `repay` | `IERC20.safeTransferFrom()` | None | YES -- last operation |
| `supplyCollateral` | `IMorphoSupplyCollateralCallback.onMorphoSupplyCollateral()` | Token transfer only | YES -- state updated before callback |
| `supplyCollateral` | `IERC20.safeTransferFrom()` | None | YES -- last operation |
| `withdrawCollateral` | `IIrm.borrowRate()` via `_accrueInterest` | Same as above | YES |
| `withdrawCollateral` | `IOracle.price()` via `_isHealthy` | None | YES -- state already updated |
| `withdrawCollateral` | `IERC20.safeTransfer()` | None | YES -- last operation |
| `liquidate` | `IIrm.borrowRate()` via `_accrueInterest` | Same as above | YES |
| `liquidate` | `IOracle.price()` | LIF calculation and state updates follow | YES -- state updated before transfers |
| `liquidate` | `IMorphoLiquidateCallback.onMorphoLiquidate()` | Token transfer only | YES -- all state updated before callback |
| `liquidate` | `IERC20.safeTransfer()` + `IERC20.safeTransferFrom()` | Callback between them | YES -- callback after state finalized |
| `flashLoan` | `IERC20.safeTransfer()` | Callback and transferFrom follow | YES -- no state to corrupt |
| `flashLoan` | `IMorphoFlashLoanCallback.onMorphoFlashLoan()` | TransferFrom follows | YES -- no persistent state changes |
| `flashLoan` | `IERC20.safeTransferFrom()` | None | YES -- last operation |
| `createMarket` | `IIrm.borrowRate()` | None | YES -- state already written |
| `setFee` | `IIrm.borrowRate()` via `_accrueInterest` | Fee update follows | YES -- accrual independent of fee update |

### Table 2: Privileged Functions

| Function | Contract | Required Role | Impact |
|----------|----------|---------------|--------|
| `setOwner` | Morpho | `owner` | Transfers complete admin control; irreversible; can set to address(0) |
| `enableIrm` | Morpho | `owner` | Permanently whitelists an IRM; cannot be undone |
| `enableLltv` | Morpho | `owner` | Permanently whitelists an LLTV; cannot be undone |
| `setFee` | Morpho | `owner` | Sets protocol fee (0-25%) on market interest; accrues with old fee first |
| `setFeeRecipient` | Morpho | `owner` | Redirects all future fee shares; pending fees may go to new recipient |
| `withdraw` | Morpho | `onBehalf` or authorized | Withdraws supply from someone else's position |
| `borrow` | Morpho | `onBehalf` or authorized | Borrows against someone else's collateral, creating debt |
| `withdrawCollateral` | Morpho | `onBehalf` or authorized | Reduces collateral backing on someone else's position |

### Table 3: Critical Invariants Checked

| Invariant | Checked In | How |
|-----------|------------|-----|
| totalBorrowAssets <= totalSupplyAssets (liquidity) | `withdraw`, `borrow` | `require(market[id].totalBorrowAssets <= market[id].totalSupplyAssets, ErrorsLib.INSUFFICIENT_LIQUIDITY)` after state update |
| Position health: collateral * price * lltv >= borrowed | `borrow`, `withdrawCollateral` | `require(_isHealthy(marketParams, id, onBehalf), ErrorsLib.INSUFFICIENT_COLLATERAL)` after state update |
| Position unhealthy for liquidation | `liquidate` | `require(!_isHealthy(marketParams, id, borrower, collateralPrice), ErrorsLib.HEALTHY_POSITION)` |
| Exactly one of assets/shares is zero | `supply`, `withdraw`, `borrow`, `repay`, `liquidate` | `require(UtilsLib.exactlyOneZero(assets, shares), ErrorsLib.INCONSISTENT_INPUT)` |
| Market exists (lastUpdate != 0) | All market operations | `require(market[id].lastUpdate != 0, ErrorsLib.MARKET_NOT_CREATED)` |
| Market not already created | `createMarket` | `require(market[id].lastUpdate == 0, ErrorsLib.MARKET_ALREADY_CREATED)` |
| IRM whitelisted | `createMarket` | `require(isIrmEnabled[marketParams.irm], ErrorsLib.IRM_NOT_ENABLED)` |
| LLTV whitelisted and < 100% | `createMarket`, `enableLltv` | `require(isLltvEnabled[marketParams.lltv], ...)` and `require(lltv < WAD, ...)` |
| Fee <= 25% | `setFee` | `require(newFee <= MAX_FEE, ErrorsLib.MAX_FEE_EXCEEDED)` |
| Authorization for position management | `withdraw`, `borrow`, `withdrawCollateral` | `require(_isSenderAuthorized(onBehalf), ErrorsLib.UNAUTHORIZED)` |
| Non-zero recipient/onBehalf | Multiple functions | `require(onBehalf != address(0), ErrorsLib.ZERO_ADDRESS)` or `require(receiver != address(0), ErrorsLib.ZERO_ADDRESS)` |
| Signature validity and nonce | `setAuthorizationWithSig` | Deadline check, nonce match + increment, ecrecover verification |
| uint128 overflow prevention | All state-writing operations | `toUint128()` reverts if value > type(uint128).max |
| Rounding favors protocol | All share/asset conversions | Consistent use of `toSharesDown`/`toSharesUp`/`toAssetsDown`/`toAssetsUp` based on context |
| Bad debt socialization | `liquidate` | When `collateral == 0` post-seizure, remaining debt subtracted from both `totalBorrowAssets` and `totalSupplyAssets` |
| Token has code | All transfers | `require(address(token).code.length > 0, ErrorsLib.NO_CODE)` in SafeTransferLib |
