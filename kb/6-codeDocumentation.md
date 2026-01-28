# Code Documentation

## Contract: Morpho
**File:** `src/Morpho.sol`
**Inherits:** IMorphoStaticTyping
**Description:** The core Morpho lending protocol - a singleton contract managing isolated lending markets

### State Variables

| Variable | Type | Visibility | Purpose |
|----------|------|------------|---------|
| DOMAIN_SEPARATOR | bytes32 | public immutable | EIP-712 domain separator for signatures |
| owner | address | public | Protocol administrator |
| feeRecipient | address | public | Address receiving protocol fees |
| position | mapping(Id => mapping(address => Position)) | public | User positions per market |
| market | mapping(Id => Market) | public | Market state data |
| isIrmEnabled | mapping(address => bool) | public | Whitelist of enabled IRMs |
| isLltvEnabled | mapping(uint256 => bool) | public | Whitelist of enabled LLTVs |
| isAuthorized | mapping(address => mapping(address => bool)) | public | Authorization delegations |
| nonce | mapping(address => uint256) | public | EIP-712 signature nonces |
| idToMarketParams | mapping(Id => MarketParams) | public | Market params lookup by ID |

### Modifiers

#### `onlyOwner`
**Logic:** `require(msg.sender == owner, ErrorsLib.NOT_OWNER)`
**Purpose:** Restricts function to protocol owner

---

### Functions

#### `constructor`

```solidity
constructor(address newOwner)
```

**Purpose:** Initializes the Morpho contract with an owner

**Parameters:**
| Param | Type | Description |
|-------|------|-------------|
| newOwner | address | Initial owner address |

**Validation:**
1. `require(newOwner != address(0))` - Owner cannot be zero address

**State Changes:**
| Variable | Change |
|----------|--------|
| DOMAIN_SEPARATOR | = keccak256(abi.encode(DOMAIN_TYPEHASH, block.chainid, address(this))) |
| owner | = newOwner |

**Events:**
- `EventsLib.SetOwner(newOwner)`

---

#### `setOwner`

```solidity
function setOwner(address newOwner) external onlyOwner
```

**Purpose:** Transfers ownership to a new address

**Access Control:** onlyOwner

**Validation:**
1. `require(newOwner != owner)` - Cannot set to current owner

**State Changes:**
| Variable | Change |
|----------|--------|
| owner | = newOwner |

**Events:**
- `EventsLib.SetOwner(newOwner)`

**Security Notes:**
- No two-step transfer - immediate ownership change
- Can transfer to zero address (ownership burned)

---

#### `enableIrm`

```solidity
function enableIrm(address irm) external onlyOwner
```

**Purpose:** Whitelists an IRM for market creation

**Access Control:** onlyOwner

**Validation:**
1. `require(!isIrmEnabled[irm])` - Cannot re-enable

**State Changes:**
| Variable | Change |
|----------|--------|
| isIrmEnabled[irm] | = true |

**Events:**
- `EventsLib.EnableIrm(irm)`

**Security Notes:**
- Cannot be disabled once enabled
- Owner must verify IRM is not malicious

---

#### `enableLltv`

```solidity
function enableLltv(uint256 lltv) external onlyOwner
```

**Purpose:** Whitelists an LLTV for market creation

**Access Control:** onlyOwner

**Validation:**
1. `require(!isLltvEnabled[lltv])` - Cannot re-enable
2. `require(lltv < WAD)` - LLTV must be < 100%

**State Changes:**
| Variable | Change |
|----------|--------|
| isLltvEnabled[lltv] | = true |

**Events:**
- `EventsLib.EnableLltv(lltv)`

**Security Notes:**
- Cannot be disabled once enabled
- Higher LLTV = more leverage = higher liquidation risk

---

#### `setFee`

```solidity
function setFee(MarketParams memory marketParams, uint256 newFee) external onlyOwner
```

**Purpose:** Sets the protocol fee for a specific market

**Access Control:** onlyOwner

**Validation:**
1. `require(market[id].lastUpdate != 0)` - Market must exist
2. `require(newFee != market[id].fee)` - Cannot set to current value
3. `require(newFee <= MAX_FEE)` - Max 25%

**State Changes:**
| Variable | Change |
|----------|--------|
| market[id].fee | = uint128(newFee) |

**Internal Calls:**
- `_accrueInterest(marketParams, id)` - Accrue with old fee before changing

**Events:**
- `EventsLib.SetFee(id, newFee)`

---

#### `setFeeRecipient`

```solidity
function setFeeRecipient(address newFeeRecipient) external onlyOwner
```

**Purpose:** Sets the address that receives protocol fees

**Access Control:** onlyOwner

**Validation:**
1. `require(newFeeRecipient != feeRecipient)` - Cannot set to current

**State Changes:**
| Variable | Change |
|----------|--------|
| feeRecipient | = newFeeRecipient |

**Events:**
- `EventsLib.SetFeeRecipient(newFeeRecipient)`

**Security Notes:**
- Can be set to zero address (fees lost)
- New recipient gets pending unaccrued fees

---

#### `createMarket`

```solidity
function createMarket(MarketParams memory marketParams) external
```

**Purpose:** Creates a new lending market with specified parameters

**Access Control:** None (permissionless)

**Validation:**
1. `require(isIrmEnabled[marketParams.irm])` - IRM must be whitelisted
2. `require(isLltvEnabled[marketParams.lltv])` - LLTV must be whitelisted
3. `require(market[id].lastUpdate == 0)` - Market must not exist

**State Changes:**
| Variable | Change |
|----------|--------|
| market[id].lastUpdate | = uint128(block.timestamp) |
| idToMarketParams[id] | = marketParams |

**External Calls:**
- `IIrm(marketParams.irm).borrowRate(marketParams, market[id])` - Initialize stateful IRMs

**Events:**
- `EventsLib.CreateMarket(id, marketParams)`

**Security Notes:**
- Market ID = keccak256(marketParams)
- Same params = same market (cannot create duplicates)

---

#### `supply`

```solidity
function supply(
    MarketParams memory marketParams,
    uint256 assets,
    uint256 shares,
    address onBehalf,
    bytes calldata data
) external returns (uint256, uint256)
```

**Purpose:** Supplies assets to a market on behalf of a user

**Access Control:** None (permissionless - anyone can supply for anyone)

**Parameters:**
| Param | Type | Description |
|-------|------|-------------|
| marketParams | MarketParams | Market identifier |
| assets | uint256 | Amount to supply (or 0 to use shares) |
| shares | uint256 | Shares to mint (or 0 to use assets) |
| onBehalf | address | Position owner |
| data | bytes | Callback data (empty = no callback) |

**Returns:**
| Type | Description |
|------|-------------|
| uint256 | Actual assets supplied |
| uint256 | Shares minted |

**Validation:**
1. `require(market[id].lastUpdate != 0)` - Market must exist
2. `require(exactlyOneZero(assets, shares))` - Exactly one must be 0
3. `require(onBehalf != address(0))` - Valid recipient

**State Changes:**
| Variable | Change |
|----------|--------|
| position[id][onBehalf].supplyShares | += shares |
| market[id].totalSupplyShares | += shares |
| market[id].totalSupplyAssets | += assets |

**Internal Calls:**
- `_accrueInterest(marketParams, id)` - Update interest first

**External Calls:**
1. `IMorphoSupplyCallback(msg.sender).onMorphoSupply(assets, data)` - If data.length > 0
2. `IERC20(marketParams.loanToken).safeTransferFrom(msg.sender, address(this), assets)`

**Events:**
- `EventsLib.Supply(id, msg.sender, onBehalf, assets, shares)`

**Security Notes:**
- Callback BEFORE token transfer (CEI pattern - state updated first)
- Rounding: assets→shares rounds DOWN (protocol gets more)
- Rounding: shares→assets rounds UP (user pays more)

---

#### `withdraw`

```solidity
function withdraw(
    MarketParams memory marketParams,
    uint256 assets,
    uint256 shares,
    address onBehalf,
    address receiver
) external returns (uint256, uint256)
```

**Purpose:** Withdraws assets from a market

**Access Control:** `_isSenderAuthorized(onBehalf)` - Must be self or authorized

**Validation:**
1. `require(market[id].lastUpdate != 0)` - Market must exist
2. `require(exactlyOneZero(assets, shares))` - Exactly one must be 0
3. `require(receiver != address(0))` - Valid receiver
4. `require(_isSenderAuthorized(onBehalf))` - Authorization check
5. `require(totalBorrowAssets <= totalSupplyAssets)` - Sufficient liquidity

**State Changes:**
| Variable | Change |
|----------|--------|
| position[id][onBehalf].supplyShares | -= shares |
| market[id].totalSupplyShares | -= shares |
| market[id].totalSupplyAssets | -= assets |

**External Calls:**
- `IERC20(marketParams.loanToken).safeTransfer(receiver, assets)`

**Events:**
- `EventsLib.Withdraw(id, msg.sender, onBehalf, receiver, assets, shares)`

**Security Notes:**
- Rounding: assets→shares rounds UP (user burns more shares)
- Rounding: shares→assets rounds DOWN (user gets less)
- Liquidity check AFTER state update

---

#### `borrow`

```solidity
function borrow(
    MarketParams memory marketParams,
    uint256 assets,
    uint256 shares,
    address onBehalf,
    address receiver
) external returns (uint256, uint256)
```

**Purpose:** Borrows assets against collateral

**Access Control:** `_isSenderAuthorized(onBehalf)` - Must be self or authorized

**Validation:**
1. `require(market[id].lastUpdate != 0)` - Market must exist
2. `require(exactlyOneZero(assets, shares))` - Exactly one must be 0
3. `require(receiver != address(0))` - Valid receiver
4. `require(_isSenderAuthorized(onBehalf))` - Authorization check
5. `require(_isHealthy(...))` - Position must be healthy after borrow
6. `require(totalBorrowAssets <= totalSupplyAssets)` - Sufficient liquidity

**State Changes:**
| Variable | Change |
|----------|--------|
| position[id][onBehalf].borrowShares | += shares |
| market[id].totalBorrowShares | += shares |
| market[id].totalBorrowAssets | += assets |

**External Calls:**
- `IERC20(marketParams.loanToken).safeTransfer(receiver, assets)`

**Events:**
- `EventsLib.Borrow(id, msg.sender, onBehalf, receiver, assets, shares)`

**Security Notes:**
- Health check calls oracle - external dependency
- Rounding: assets→shares rounds UP (user owes more)
- Both health AND liquidity checks after state update

---

#### `repay`

```solidity
function repay(
    MarketParams memory marketParams,
    uint256 assets,
    uint256 shares,
    address onBehalf,
    bytes calldata data
) external returns (uint256, uint256)
```

**Purpose:** Repays borrowed assets

**Access Control:** None (permissionless - anyone can repay for anyone)

**Validation:**
1. `require(market[id].lastUpdate != 0)` - Market must exist
2. `require(exactlyOneZero(assets, shares))` - Exactly one must be 0
3. `require(onBehalf != address(0))` - Valid debtor

**State Changes:**
| Variable | Change |
|----------|--------|
| position[id][onBehalf].borrowShares | -= shares |
| market[id].totalBorrowShares | -= shares |
| market[id].totalBorrowAssets | = zeroFloorSub(totalBorrowAssets, assets) |

**External Calls:**
1. `IMorphoRepayCallback(msg.sender).onMorphoRepay(assets, data)` - If data.length > 0
2. `IERC20(marketParams.loanToken).safeTransferFrom(msg.sender, address(this), assets)`

**Events:**
- `EventsLib.Repay(id, msg.sender, onBehalf, assets, shares)`

**Security Notes:**
- `zeroFloorSub` handles edge case where assets > totalBorrowAssets (by 1 due to rounding)
- Callback BEFORE token transfer

---

#### `supplyCollateral`

```solidity
function supplyCollateral(
    MarketParams memory marketParams,
    uint256 assets,
    address onBehalf,
    bytes calldata data
) external
```

**Purpose:** Deposits collateral to a market

**Access Control:** None (permissionless)

**Validation:**
1. `require(market[id].lastUpdate != 0)` - Market must exist
2. `require(assets != 0)` - Must supply something
3. `require(onBehalf != address(0))` - Valid recipient

**State Changes:**
| Variable | Change |
|----------|--------|
| position[id][onBehalf].collateral | += assets |

**External Calls:**
1. `IMorphoSupplyCollateralCallback(msg.sender).onMorphoSupplyCollateral(assets, data)` - If data.length > 0
2. `IERC20(marketParams.collateralToken).safeTransferFrom(msg.sender, address(this), assets)`

**Events:**
- `EventsLib.SupplyCollateral(id, msg.sender, onBehalf, assets)`

**Security Notes:**
- Does NOT accrue interest (gas optimization)
- Collateral is tracked as raw assets, not shares

---

#### `withdrawCollateral`

```solidity
function withdrawCollateral(
    MarketParams memory marketParams,
    uint256 assets,
    address onBehalf,
    address receiver
) external
```

**Purpose:** Withdraws collateral from a market

**Access Control:** `_isSenderAuthorized(onBehalf)` - Must be self or authorized

**Validation:**
1. `require(market[id].lastUpdate != 0)` - Market must exist
2. `require(assets != 0)` - Must withdraw something
3. `require(receiver != address(0))` - Valid receiver
4. `require(_isSenderAuthorized(onBehalf))` - Authorization check
5. `require(_isHealthy(...))` - Position must be healthy after withdrawal

**State Changes:**
| Variable | Change |
|----------|--------|
| position[id][onBehalf].collateral | -= assets |

**External Calls:**
- `IERC20(marketParams.collateralToken).safeTransfer(receiver, assets)`

**Events:**
- `EventsLib.WithdrawCollateral(id, msg.sender, onBehalf, receiver, assets)`

**Security Notes:**
- Health check calls oracle - external dependency
- Must accrue interest for accurate health calculation

---

#### `liquidate`

```solidity
function liquidate(
    MarketParams memory marketParams,
    address borrower,
    uint256 seizedAssets,
    uint256 repaidShares,
    bytes calldata data
) external returns (uint256, uint256)
```

**Purpose:** Liquidates an unhealthy position

**Access Control:** None (permissionless)

**Validation:**
1. `require(market[id].lastUpdate != 0)` - Market must exist
2. `require(exactlyOneZero(seizedAssets, repaidShares))` - Exactly one must be 0
3. `require(!_isHealthy(...))` - Position must be UNHEALTHY

**State Changes:**
| Variable | Change |
|----------|--------|
| position[id][borrower].borrowShares | -= repaidShares |
| market[id].totalBorrowShares | -= repaidShares |
| market[id].totalBorrowAssets | -= repaidAssets |
| position[id][borrower].collateral | -= seizedAssets |
| (if bad debt) market[id].totalSupplyAssets | -= badDebtAssets |

**External Calls:**
1. `IOracle(marketParams.oracle).price()` - Get collateral price
2. `IERC20(marketParams.collateralToken).safeTransfer(msg.sender, seizedAssets)`
3. `IMorphoLiquidateCallback(msg.sender).onMorphoLiquidate(repaidAssets, data)` - If data.length > 0
4. `IERC20(marketParams.loanToken).safeTransferFrom(msg.sender, address(this), repaidAssets)`

**Events:**
- `EventsLib.Liquidate(id, msg.sender, borrower, repaidAssets, repaidShares, seizedAssets, badDebtAssets, badDebtShares)`

**Security Notes:**
- Liquidation incentive = min(1.15, 1/(1 - 0.3*(1-lltv)))
- Bad debt socialized if collateral == 0 after seizure
- Collateral transfer BEFORE callback

---

#### `flashLoan`

```solidity
function flashLoan(address token, uint256 assets, bytes calldata data) external
```

**Purpose:** Executes a flash loan (borrow and repay in same tx)

**Access Control:** None (permissionless)

**Validation:**
1. `require(assets != 0)` - Must borrow something

**External Calls:**
1. `IERC20(token).safeTransfer(msg.sender, assets)` - Lend
2. `IMorphoFlashLoanCallback(msg.sender).onMorphoFlashLoan(assets, data)` - Callback
3. `IERC20(token).safeTransferFrom(msg.sender, address(this), assets)` - Repay

**Events:**
- `EventsLib.FlashLoan(msg.sender, token, assets)`

**Security Notes:**
- No fee charged
- Access to ALL contract tokens (all markets + donations)
- Callback is MANDATORY (must implement interface)

---

#### `_accrueInterest` (internal)

```solidity
function _accrueInterest(MarketParams memory marketParams, Id id) internal
```

**Purpose:** Accrues interest for a market

**Visibility:** internal

**State Changes:**
| Variable | Change |
|----------|--------|
| market[id].totalBorrowAssets | += interest |
| market[id].totalSupplyAssets | += interest |
| market[id].lastUpdate | = block.timestamp |
| position[id][feeRecipient].supplyShares | += feeShares (if fee > 0) |
| market[id].totalSupplyShares | += feeShares (if fee > 0) |

**External Calls:**
- `IIrm(marketParams.irm).borrowRate(marketParams, market[id])` - Get current rate

**Security Notes:**
- Skipped if elapsed == 0 (same block)
- Skipped if irm == address(0)
- Uses Taylor expansion: e^(r*t) - 1 ≈ rt + (rt)²/2 + (rt)³/6
- Fee shares minted to feeRecipient

---

#### `_isHealthy` (internal)

```solidity
function _isHealthy(MarketParams memory marketParams, Id id, address borrower) internal view returns (bool)
function _isHealthy(MarketParams memory marketParams, Id id, address borrower, uint256 collateralPrice) internal view returns (bool)
```

**Purpose:** Checks if a position is healthy (collateral >= debt * lltv)

**Formula:** `maxBorrow = collateral * price / ORACLE_PRICE_SCALE * lltv`
**Health:** `maxBorrow >= borrowed`

**External Calls:**
- `IOracle(marketParams.oracle).price()` - First overload only

**Security Notes:**
- Rounds in protocol's favor (borrowed rounds UP, maxBorrow rounds DOWN)
- Returns true if borrowShares == 0 (no debt = healthy)

---

## Security Summary

### Reentrancy Vectors
| Function | External Call | State Updated First | Risk |
|----------|---------------|---------------------|------|
| supply | onMorphoSupply callback | Yes | Low |
| repay | onMorphoRepay callback | Yes | Low |
| supplyCollateral | onMorphoSupplyCollateral callback | Yes | Low |
| liquidate | onMorphoLiquidate callback | Yes | Low |
| flashLoan | onMorphoFlashLoan callback | N/A (no state change) | Low |

### Privileged Functions
| Function | Role | Impact |
|----------|------|--------|
| setOwner | Owner | Transfer admin control |
| enableIrm | Owner | Whitelist interest model |
| enableLltv | Owner | Whitelist loan-to-value ratio |
| setFee | Owner | Set market fee (max 25%) |
| setFeeRecipient | Owner | Set fee recipient |

### Critical Invariants Checked
| Invariant | Where Checked |
|-----------|---------------|
| totalBorrow <= totalSupply | withdraw(), borrow() |
| position health | borrow(), withdrawCollateral() |
| fee <= MAX_FEE | setFee() |
| lltv < WAD | enableLltv() |
