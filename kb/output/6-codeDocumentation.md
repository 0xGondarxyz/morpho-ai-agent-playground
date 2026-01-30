# Code Documentation

## Contract: Morpho

**File:** `src/Morpho.sol`
**Inherits:** IMorphoStaticTyping
**License:** BUSL-1.1
**Solidity Version:** 0.8.19

**Description:** Singleton contract managing isolated lending markets. Each market is identified by `keccak256(MarketParams)` containing (loanToken, collateralToken, oracle, irm, lltv). Markets are independent with no cross-collateralization. Permissionless market creation with owner-whitelisted IRMs and LLTVs.

---

### Imports

| Import | Components Used |
|--------|-----------------|
| `./interfaces/IMorpho.sol` | Id, IMorphoStaticTyping, IMorphoBase, MarketParams, Position, Market, Authorization, Signature |
| `./interfaces/IMorphoCallbacks.sol` | IMorphoLiquidateCallback, IMorphoRepayCallback, IMorphoSupplyCallback, IMorphoSupplyCollateralCallback, IMorphoFlashLoanCallback |
| `./interfaces/IIrm.sol` | IIrm |
| `./interfaces/IERC20.sol` | IERC20 |
| `./interfaces/IOracle.sol` | IOracle |
| `./libraries/ConstantsLib.sol` | All constants |
| `./libraries/UtilsLib.sol` | UtilsLib |
| `./libraries/EventsLib.sol` | EventsLib |
| `./libraries/ErrorsLib.sol` | ErrorsLib |
| `./libraries/MathLib.sol` | MathLib, WAD |
| `./libraries/SharesMathLib.sol` | SharesMathLib |
| `./libraries/MarketParamsLib.sol` | MarketParamsLib |
| `./libraries/SafeTransferLib.sol` | SafeTransferLib |

### Using Directives

| Library | Type |
|---------|------|
| MathLib | uint128 |
| MathLib | uint256 |
| UtilsLib | uint256 |
| SharesMathLib | uint256 |
| SafeTransferLib | IERC20 |
| MarketParamsLib | MarketParams |

---

### Immutables

| Variable | Type | Purpose |
|----------|------|---------|
| `DOMAIN_SEPARATOR` | bytes32 | EIP-712 domain separator. Chain-specific to prevent cross-chain replay attacks. Computed as `keccak256(abi.encode(DOMAIN_TYPEHASH, block.chainid, address(this)))` |

---

### State Variables

| Variable | Type | Visibility | Purpose |
|----------|------|------------|---------|
| `owner` | address | public | Contract owner. Can enable IRMs/LLTVs, set fees. Single admin with no timelock. No two-step transfer pattern. |
| `feeRecipient` | address | public | Receives supply shares representing protocol fees. If `address(0)`, fees are lost (shares minted to zero address). |
| `position` | mapping(Id => mapping(address => Position)) | public | Per-user position in each market. Position struct: supplyShares (uint256), borrowShares (uint128), collateral (uint128). |
| `market` | mapping(Id => Market) | public | Global market state. Market struct: totalSupplyAssets, totalSupplyShares, totalBorrowAssets, totalBorrowShares (all uint128), lastUpdate (uint128), fee (uint128). |
| `isIrmEnabled` | mapping(address => bool) | public | Whitelist of enabled Interest Rate Models. Once enabled, cannot be disabled. |
| `isLltvEnabled` | mapping(uint256 => bool) | public | Whitelist of enabled Loan-to-Value ratios. Each LLTV must be < WAD (100%). Cannot be disabled once enabled. |
| `isAuthorized` | mapping(address => mapping(address => bool)) | public | Authorization for position management. `isAuthorized[owner][manager] = true` allows manager to withdraw/borrow from owner's positions. |
| `nonce` | mapping(address => uint256) | public | Nonces for EIP-712 signature replay protection. Increments on each `setAuthorizationWithSig` call. |
| `idToMarketParams` | mapping(Id => MarketParams) | public | Reverse lookup from market ID to MarketParams. |

---

### Constructor

```solidity
constructor(address newOwner)
```

**Purpose:** Initializes the Morpho contract with an owner and computes the EIP-712 domain separator.

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| `newOwner` | address | The address that will own the contract |

**Validation:**
1. `require(newOwner != address(0), ErrorsLib.ZERO_ADDRESS)` - Owner cannot be zero address

**State Changes:**

| Variable | Change |
|----------|--------|
| `owner` | Set to `newOwner` |
| `DOMAIN_SEPARATOR` | Computed from `keccak256(abi.encode(DOMAIN_TYPEHASH, block.chainid, address(this)))` |

**Events:** `EventsLib.SetOwner(newOwner)`

---

### Modifiers

#### `onlyOwner`

**Logic:**
```solidity
require(msg.sender == owner, ErrorsLib.NOT_OWNER);
```

**Purpose:** Restricts function access to the contract owner only.

---

### Functions

---

#### `setOwner`

```solidity
function setOwner(address newOwner) external onlyOwner
```

**Purpose:** Transfers contract ownership to a new address. No two-step transfer - immediate and irreversible. Can set owner to `address(0)`, permanently disabling admin functions.

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| `newOwner` | address | The new owner address |

**Returns:** None

**Access Control:** `onlyOwner` - Only current owner can call

**Validation:**
1. `require(newOwner != owner, ErrorsLib.ALREADY_SET)` - Prevent no-op state change

**State Changes:**

| Variable | Change |
|----------|--------|
| `owner` | Set to `newOwner` |

**Internal Calls:** None

**External Calls:** None

**Events:** `EventsLib.SetOwner(newOwner)`

**Security Notes:**
- No two-step ownership transfer pattern
- Setting to `address(0)` is irreversible and disables all admin functions
- Immediate effect - no timelock

---

#### `enableIrm`

```solidity
function enableIrm(address irm) external onlyOwner
```

**Purpose:** Whitelists an Interest Rate Model for market creation. Once enabled, CANNOT be disabled. Owner must trust IRM code. `address(0)` is a valid IRM (creates 0% APR markets).

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| `irm` | address | The IRM contract address to enable |

**Returns:** None

**Access Control:** `onlyOwner` - Only owner can enable IRMs

**Validation:**
1. `require(!isIrmEnabled[irm], ErrorsLib.ALREADY_SET)` - Prevent re-enabling already enabled IRM

**State Changes:**

| Variable | Change |
|----------|--------|
| `isIrmEnabled[irm]` | Set to `true` |

**Internal Calls:** None

**External Calls:** None

**Events:** `EventsLib.EnableIrm(irm)`

**Security Notes:**
- Cannot be disabled once enabled
- `address(0)` as IRM creates markets with 0% interest rate
- Owner must fully trust IRM implementation before enabling

---

#### `enableLltv`

```solidity
function enableLltv(uint256 lltv) external onlyOwner
```

**Purpose:** Whitelists a Loan-to-Value ratio for market creation. LLTV must be < WAD (1e18 = 100%). Common values: 0.8e18 (80%), 0.9e18 (90%). Higher LLTV = more leverage = higher liquidation risk. Cannot be disabled once enabled.

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| `lltv` | uint256 | The LLTV value scaled by WAD (1e18) |

**Returns:** None

**Access Control:** `onlyOwner` - Only owner can enable LLTVs

**Validation:**
1. `require(!isLltvEnabled[lltv], ErrorsLib.ALREADY_SET)` - Prevent re-enabling
2. `require(lltv < WAD, ErrorsLib.MAX_LLTV_EXCEEDED)` - LLTV >= 100% would allow infinite borrowing

**State Changes:**

| Variable | Change |
|----------|--------|
| `isLltvEnabled[lltv]` | Set to `true` |

**Internal Calls:** None

**External Calls:** None

**Events:** `EventsLib.EnableLltv(lltv)`

**Security Notes:**
- Cannot be disabled once enabled
- LLTV must be strictly less than 100% (WAD)
- Higher LLTV increases liquidation risk for borrowers

---

#### `setFee`

```solidity
function setFee(MarketParams memory marketParams, uint256 newFee) external onlyOwner
```

**Purpose:** Sets protocol fee for a market. Fee is percentage of interest accrued. `newFee` must be <= MAX_FEE (0.25e18 = 25%). Fee = interest * fee / WAD. Accrues interest with OLD fee before applying new fee (fair accounting).

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| `marketParams` | MarketParams memory | The market parameters struct |
| `newFee` | uint256 | New fee rate scaled by WAD |

**Returns:** None

**Access Control:** `onlyOwner` - Only owner can set fees

**Validation:**
1. `require(market[id].lastUpdate != 0, ErrorsLib.MARKET_NOT_CREATED)` - Market must exist
2. `require(newFee != market[id].fee, ErrorsLib.ALREADY_SET)` - Prevent no-op
3. `require(newFee <= MAX_FEE, ErrorsLib.MAX_FEE_EXCEEDED)` - Cap at 25%

**State Changes:**

| Variable | Change |
|----------|--------|
| `market[id].fee` | Set to `uint128(newFee)` |
| (via `_accrueInterest`) | Market totals and lastUpdate updated |

**Internal Calls:**
- `marketParams.id()` - Compute market ID
- `_accrueInterest(marketParams, id)` - Accrue interest before fee change

**External Calls:**
- (via `_accrueInterest`) `IIrm(marketParams.irm).borrowRate(marketParams, market[id])`

**Events:** `EventsLib.SetFee(id, newFee)`

**Security Notes:**
- MAX_FEE is 25% (0.25e18)
- Interest is accrued with old fee before applying new fee
- Fee applies to interest accrued, not principal

---

#### `setFeeRecipient`

```solidity
function setFeeRecipient(address newFeeRecipient) external onlyOwner
```

**Purpose:** Sets address that receives protocol fee shares. If set to `address(0)`, fees are LOST (shares minted to zero address). Changing recipient allows new recipient to claim any not-yet-accrued fees.

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| `newFeeRecipient` | address | The new fee recipient address |

**Returns:** None

**Access Control:** `onlyOwner` - Only owner can set fee recipient

**Validation:**
1. `require(newFeeRecipient != feeRecipient, ErrorsLib.ALREADY_SET)` - Prevent no-op

**State Changes:**

| Variable | Change |
|----------|--------|
| `feeRecipient` | Set to `newFeeRecipient` |

**Internal Calls:** None

**External Calls:** None

**Events:** `EventsLib.SetFeeRecipient(newFeeRecipient)`

**Security Notes:**
- Setting to `address(0)` causes fees to be lost
- Already accrued fees remain with previous recipient as supply shares
- New recipient receives all future fee accruals

---

#### `createMarket`

```solidity
function createMarket(MarketParams memory marketParams) external
```

**Purpose:** Creates a new isolated lending market with specified parameters. Permissionless - anyone can create markets using owner-whitelisted IRM and LLTV. Market ID = `keccak256(abi.encode(loanToken, collateralToken, oracle, irm, lltv))`. Same parameters always produce same ID - deterministic and collision-resistant. Calls `IRM.borrowRate()` to initialize stateful IRMs.

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| `marketParams` | MarketParams memory | Struct containing loanToken, collateralToken, oracle, irm, lltv |

**Returns:** None

**Access Control:** Permissionless - anyone can call

**Validation:**
1. `require(isIrmEnabled[marketParams.irm], ErrorsLib.IRM_NOT_ENABLED)` - IRM must be whitelisted
2. `require(isLltvEnabled[marketParams.lltv], ErrorsLib.LLTV_NOT_ENABLED)` - LLTV must be whitelisted
3. `require(market[id].lastUpdate == 0, ErrorsLib.MARKET_ALREADY_CREATED)` - Cannot recreate existing market

**State Changes:**

| Variable | Change |
|----------|--------|
| `market[id].lastUpdate` | Set to `uint128(block.timestamp)` |
| `idToMarketParams[id]` | Set to `marketParams` |

**Internal Calls:**
- `marketParams.id()` - Compute market ID

**External Calls:**
- `IIrm(marketParams.irm).borrowRate(marketParams, market[id])` (if `irm != address(0)`)

**Events:** `EventsLib.CreateMarket(id, marketParams)`

**Security Notes:**
- Market ID is deterministic - same params = same ID
- Cannot recreate an existing market
- IRM is called to initialize stateful interest rate models
- No validation of oracle/token contract code

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

**Purpose:** Deposits loan tokens into market, crediting supply shares to `onBehalf`. Permissionless - anyone can supply on behalf of any address (no authorization needed, only benefits recipient). Callback executes AFTER state update but BEFORE token transfer (CEI pattern). Caller can use callback to source funds.

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| `marketParams` | MarketParams memory | The market parameters |
| `assets` | uint256 | Amount of loan tokens to supply (or 0 if using shares) |
| `shares` | uint256 | Amount of supply shares to receive (or 0 if using assets) |
| `onBehalf` | address | Address to credit supply shares to |
| `data` | bytes calldata | Callback data (callback triggered if length > 0) |

**Returns:**

| Type | Description |
|------|-------------|
| uint256 | Actual assets supplied |
| uint256 | Actual shares minted |

**Access Control:** Permissionless

**Validation:**
1. `require(market[id].lastUpdate != 0, ErrorsLib.MARKET_NOT_CREATED)` - Market must exist
2. `require(UtilsLib.exactlyOneZero(assets, shares), ErrorsLib.INCONSISTENT_INPUT)` - Exactly one must be 0
3. `require(onBehalf != address(0), ErrorsLib.ZERO_ADDRESS)` - Cannot credit to zero address

**State Changes:**

| Variable | Change |
|----------|--------|
| `position[id][onBehalf].supplyShares` | Increased by `shares` |
| `market[id].totalSupplyShares` | Increased by `shares.toUint128()` |
| `market[id].totalSupplyAssets` | Increased by `assets.toUint128()` |

**Internal Calls:**
- `marketParams.id()` - Compute market ID
- `_accrueInterest(marketParams, id)` - Accrue interest first
- `assets.toSharesDown(...)` or `shares.toAssetsUp(...)` - Conversion

**External Calls:**
- `IMorphoSupplyCallback(msg.sender).onMorphoSupply(assets, data)` (if `data.length > 0`)
- `IERC20(marketParams.loanToken).safeTransferFrom(msg.sender, address(this), assets)`

**Events:** `EventsLib.Supply(id, msg.sender, onBehalf, assets, shares)`

**Security Notes:**
- **Rounding:** Assets to shares rounds DOWN (protocol favored)
- **CEI Pattern:** State updated before token transfer
- Callback executes after state update, before token pull
- No authorization needed - only benefits recipient

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

**Purpose:** Burns supply shares and withdraws loan tokens from market. Requires authorization - `msg.sender` must be `onBehalf` OR authorized by `onBehalf`.

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| `marketParams` | MarketParams memory | The market parameters |
| `assets` | uint256 | Amount of loan tokens to withdraw (or 0 if using shares) |
| `shares` | uint256 | Amount of supply shares to burn (or 0 if using assets) |
| `onBehalf` | address | Address to burn supply shares from |
| `receiver` | address | Address to receive withdrawn tokens |

**Returns:**

| Type | Description |
|------|-------------|
| uint256 | Actual assets withdrawn |
| uint256 | Actual shares burned |

**Access Control:** Requires authorization - `msg.sender == onBehalf` OR `isAuthorized[onBehalf][msg.sender]`

**Validation:**
1. `require(market[id].lastUpdate != 0, ErrorsLib.MARKET_NOT_CREATED)` - Market must exist
2. `require(UtilsLib.exactlyOneZero(assets, shares), ErrorsLib.INCONSISTENT_INPUT)` - Exactly one must be 0
3. `require(receiver != address(0), ErrorsLib.ZERO_ADDRESS)` - Cannot send to zero address
4. `require(_isSenderAuthorized(onBehalf), ErrorsLib.UNAUTHORIZED)` - Must be authorized
5. `require(market[id].totalBorrowAssets <= market[id].totalSupplyAssets, ErrorsLib.INSUFFICIENT_LIQUIDITY)` - Liquidity constraint

**State Changes:**

| Variable | Change |
|----------|--------|
| `position[id][onBehalf].supplyShares` | Decreased by `shares` |
| `market[id].totalSupplyShares` | Decreased by `shares.toUint128()` |
| `market[id].totalSupplyAssets` | Decreased by `assets.toUint128()` |

**Internal Calls:**
- `marketParams.id()` - Compute market ID
- `_accrueInterest(marketParams, id)` - Accrue interest first
- `_isSenderAuthorized(onBehalf)` - Check authorization
- `assets.toSharesUp(...)` or `shares.toAssetsDown(...)` - Conversion

**External Calls:**
- `IERC20(marketParams.loanToken).safeTransfer(receiver, assets)`

**Events:** `EventsLib.Withdraw(id, msg.sender, onBehalf, receiver, assets, shares)`

**Security Notes:**
- **Rounding:** Assets to shares rounds UP (user burns more), shares to assets rounds DOWN (user gets less)
- **CEI Pattern:** State updated before token transfer
- Liquidity check ensures sufficient funds remain for borrowers

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

**Purpose:** Creates debt position by minting borrow shares and transferring loan tokens. Requires authorization AND health check. Position must remain healthy after borrow.

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| `marketParams` | MarketParams memory | The market parameters |
| `assets` | uint256 | Amount of loan tokens to borrow (or 0 if using shares) |
| `shares` | uint256 | Amount of borrow shares to mint (or 0 if using assets) |
| `onBehalf` | address | Address to assign debt to |
| `receiver` | address | Address to receive borrowed tokens |

**Returns:**

| Type | Description |
|------|-------------|
| uint256 | Actual assets borrowed |
| uint256 | Actual shares minted |

**Access Control:** Requires authorization - `msg.sender == onBehalf` OR `isAuthorized[onBehalf][msg.sender]`

**Validation:**
1. `require(market[id].lastUpdate != 0, ErrorsLib.MARKET_NOT_CREATED)` - Market must exist
2. `require(UtilsLib.exactlyOneZero(assets, shares), ErrorsLib.INCONSISTENT_INPUT)` - Exactly one must be 0
3. `require(receiver != address(0), ErrorsLib.ZERO_ADDRESS)` - Cannot send to zero address
4. `require(_isSenderAuthorized(onBehalf), ErrorsLib.UNAUTHORIZED)` - Must be authorized
5. `require(_isHealthy(marketParams, id, onBehalf), ErrorsLib.INSUFFICIENT_COLLATERAL)` - Position must be healthy
6. `require(market[id].totalBorrowAssets <= market[id].totalSupplyAssets, ErrorsLib.INSUFFICIENT_LIQUIDITY)` - Liquidity constraint

**State Changes:**

| Variable | Change |
|----------|--------|
| `position[id][onBehalf].borrowShares` | Increased by `shares.toUint128()` |
| `market[id].totalBorrowShares` | Increased by `shares.toUint128()` |
| `market[id].totalBorrowAssets` | Increased by `assets.toUint128()` |

**Internal Calls:**
- `marketParams.id()` - Compute market ID
- `_accrueInterest(marketParams, id)` - Accrue interest first
- `_isSenderAuthorized(onBehalf)` - Check authorization
- `_isHealthy(marketParams, id, onBehalf)` - Health check

**External Calls:**
- `IERC20(marketParams.loanToken).safeTransfer(receiver, assets)`
- (via `_isHealthy`) `IOracle(marketParams.oracle).price()`

**Events:** `EventsLib.Borrow(id, msg.sender, onBehalf, receiver, assets, shares)`

**Security Notes:**
- **Rounding:** Assets to shares rounds UP (borrower owes more), shares to assets rounds DOWN
- **CEI Pattern:** State updated before token transfer
- Health check occurs AFTER debt is added
- Calls oracle for price - oracle manipulation is a risk

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

**Purpose:** Repays borrowed tokens, reducing debt position and market totals. Permissionless - anyone can repay on behalf of any borrower (benefits borrower). Callback executes AFTER state update but BEFORE token transfer (CEI pattern).

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| `marketParams` | MarketParams memory | The market parameters |
| `assets` | uint256 | Amount of loan tokens to repay (or 0 if using shares) |
| `shares` | uint256 | Amount of borrow shares to burn (or 0 if using assets) |
| `onBehalf` | address | Address whose debt to repay |
| `data` | bytes calldata | Callback data (callback triggered if length > 0) |

**Returns:**

| Type | Description |
|------|-------------|
| uint256 | Actual assets repaid |
| uint256 | Actual shares burned |

**Access Control:** Permissionless

**Validation:**
1. `require(market[id].lastUpdate != 0, ErrorsLib.MARKET_NOT_CREATED)` - Market must exist
2. `require(UtilsLib.exactlyOneZero(assets, shares), ErrorsLib.INCONSISTENT_INPUT)` - Exactly one must be 0
3. `require(onBehalf != address(0), ErrorsLib.ZERO_ADDRESS)` - Cannot repay for zero address

**State Changes:**

| Variable | Change |
|----------|--------|
| `position[id][onBehalf].borrowShares` | Decreased by `shares.toUint128()` |
| `market[id].totalBorrowShares` | Decreased by `shares.toUint128()` |
| `market[id].totalBorrowAssets` | Set to `UtilsLib.zeroFloorSub(market[id].totalBorrowAssets, assets).toUint128()` |

**Internal Calls:**
- `marketParams.id()` - Compute market ID
- `_accrueInterest(marketParams, id)` - Accrue interest first
- `assets.toSharesDown(...)` or `shares.toAssetsUp(...)` - Conversion

**External Calls:**
- `IMorphoRepayCallback(msg.sender).onMorphoRepay(assets, data)` (if `data.length > 0`)
- `IERC20(marketParams.loanToken).safeTransferFrom(msg.sender, address(this), assets)`

**Events:** `EventsLib.Repay(id, msg.sender, onBehalf, assets, shares)`

**Security Notes:**
- **Rounding:** Assets to shares rounds DOWN (borrower repays fewer shares - slightly borrower favored)
- **CEI Pattern:** State updated before token transfer
- Uses `zeroFloorSub` to handle edge case where assets may exceed totalBorrowAssets by 1 due to rounding
- No authorization needed - only benefits borrower

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

**Purpose:** Deposits collateral tokens to back borrowing positions. Permissionless - anyone can supply collateral for any address (benefits recipient). Callback executes AFTER state update but BEFORE token transfer (CEI pattern). Does NOT accrue interest - collateral doesn't earn interest, saves gas. Collateral tracked as raw assets (uint128), NOT shares.

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| `marketParams` | MarketParams memory | The market parameters |
| `assets` | uint256 | Amount of collateral tokens to deposit |
| `onBehalf` | address | Address to credit collateral to |
| `data` | bytes calldata | Callback data (callback triggered if length > 0) |

**Returns:** None

**Access Control:** Permissionless

**Validation:**
1. `require(market[id].lastUpdate != 0, ErrorsLib.MARKET_NOT_CREATED)` - Market must exist
2. `require(assets != 0, ErrorsLib.ZERO_ASSETS)` - Cannot supply zero
3. `require(onBehalf != address(0), ErrorsLib.ZERO_ADDRESS)` - Cannot credit to zero address

**State Changes:**

| Variable | Change |
|----------|--------|
| `position[id][onBehalf].collateral` | Increased by `assets.toUint128()` |

**Internal Calls:**
- `marketParams.id()` - Compute market ID

**External Calls:**
- `IMorphoSupplyCollateralCallback(msg.sender).onMorphoSupplyCollateral(assets, data)` (if `data.length > 0`)
- `IERC20(marketParams.collateralToken).safeTransferFrom(msg.sender, address(this), assets)`

**Events:** `EventsLib.SupplyCollateral(id, msg.sender, onBehalf, assets)`

**Security Notes:**
- **No interest accrual** - collateral does not earn interest
- **CEI Pattern:** State updated before token transfer
- Collateral is tracked in raw assets, not shares
- No authorization needed - only benefits recipient

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

**Purpose:** Withdraws collateral tokens, reducing backing for borrow position. Requires authorization - only position owner or authorized managers can withdraw. Position must remain healthy after withdrawal - enforced by `_isHealthy` check.

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| `marketParams` | MarketParams memory | The market parameters |
| `assets` | uint256 | Amount of collateral tokens to withdraw |
| `onBehalf` | address | Address to withdraw collateral from |
| `receiver` | address | Address to receive withdrawn tokens |

**Returns:** None

**Access Control:** Requires authorization - `msg.sender == onBehalf` OR `isAuthorized[onBehalf][msg.sender]`

**Validation:**
1. `require(market[id].lastUpdate != 0, ErrorsLib.MARKET_NOT_CREATED)` - Market must exist
2. `require(assets != 0, ErrorsLib.ZERO_ASSETS)` - Cannot withdraw zero
3. `require(receiver != address(0), ErrorsLib.ZERO_ADDRESS)` - Cannot send to zero address
4. `require(_isSenderAuthorized(onBehalf), ErrorsLib.UNAUTHORIZED)` - Must be authorized
5. `require(_isHealthy(marketParams, id, onBehalf), ErrorsLib.INSUFFICIENT_COLLATERAL)` - Position must remain healthy

**State Changes:**

| Variable | Change |
|----------|--------|
| `position[id][onBehalf].collateral` | Decreased by `assets.toUint128()` |

**Internal Calls:**
- `marketParams.id()` - Compute market ID
- `_accrueInterest(marketParams, id)` - Accrue interest (needed for accurate health check)
- `_isSenderAuthorized(onBehalf)` - Check authorization
- `_isHealthy(marketParams, id, onBehalf)` - Health check

**External Calls:**
- `IERC20(marketParams.collateralToken).safeTransfer(receiver, assets)`
- (via `_isHealthy`) `IOracle(marketParams.oracle).price()`

**Events:** `EventsLib.WithdrawCollateral(id, msg.sender, onBehalf, receiver, assets)`

**Security Notes:**
- **CEI Pattern:** State updated before token transfer
- Unlike `supplyCollateral`, this DOES accrue interest because health check needs accurate debt
- Health check occurs AFTER collateral is reduced
- Calls oracle for price - oracle manipulation is a risk

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

**Purpose:** Liquidates unhealthy positions by repaying debt and seizing collateral at a discount. Permissionless - anyone can liquidate unhealthy positions (economic incentive via liquidation bonus). LIF = min(1.15, 1/(1 - 0.3*(1-lltv))). At LLTV=0.8: LIF ~ 1.064 (6.4% bonus). At LLTV=0.5: LIF capped to 1.15 (15% max).

**BAD DEBT:** If collateral == 0 after seizure, remaining debt is socialized to suppliers.

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| `marketParams` | MarketParams memory | The market parameters |
| `borrower` | address | Address of the position to liquidate |
| `seizedAssets` | uint256 | Amount of collateral to seize (or 0 if using repaidShares) |
| `repaidShares` | uint256 | Amount of borrow shares to repay (or 0 if using seizedAssets) |
| `data` | bytes calldata | Callback data (callback triggered if length > 0) |

**Returns:**

| Type | Description |
|------|-------------|
| uint256 | Actual assets seized |
| uint256 | Actual shares repaid |

**Access Control:** Permissionless

**Validation:**
1. `require(market[id].lastUpdate != 0, ErrorsLib.MARKET_NOT_CREATED)` - Market must exist
2. `require(UtilsLib.exactlyOneZero(seizedAssets, repaidShares), ErrorsLib.INCONSISTENT_INPUT)` - Exactly one must be 0
3. `require(!_isHealthy(marketParams, id, borrower, collateralPrice), ErrorsLib.HEALTHY_POSITION)` - Position must be unhealthy

**State Changes:**

| Variable | Change |
|----------|--------|
| `position[id][borrower].borrowShares` | Decreased by `repaidShares.toUint128()` |
| `market[id].totalBorrowShares` | Decreased by `repaidShares.toUint128()` |
| `market[id].totalBorrowAssets` | Uses `zeroFloorSub` to decrease |
| `position[id][borrower].collateral` | Decreased by `seizedAssets.toUint128()` |
| (if bad debt) `market[id].totalSupplyAssets` | Decreased by `badDebtAssets.toUint128()` |
| (if bad debt) `position[id][borrower].borrowShares` | Set to 0 |

**Internal Calls:**
- `marketParams.id()` - Compute market ID
- `_accrueInterest(marketParams, id)` - Accrue interest first
- `_isHealthy(marketParams, id, borrower, collateralPrice)` - Check position is unhealthy

**External Calls:**
- `IOracle(marketParams.oracle).price()` - Get collateral price
- `IERC20(marketParams.collateralToken).safeTransfer(msg.sender, seizedAssets)` - Send seized collateral
- `IMorphoLiquidateCallback(msg.sender).onMorphoLiquidate(repaidAssets, data)` (if `data.length > 0`)
- `IERC20(marketParams.loanToken).safeTransferFrom(msg.sender, address(this), repaidAssets)` - Pull repayment

**Events:** `EventsLib.Liquidate(id, msg.sender, borrower, repaidAssets, repaidShares, seizedAssets, badDebtAssets, badDebtShares)`

**Security Notes:**
- **Liquidation Incentive Factor (LIF):** Calculated as `min(MAX_LIQUIDATION_INCENTIVE_FACTOR, WAD / (WAD - LIQUIDATION_CURSOR * (WAD - lltv)))`
- **Bad Debt Socialization:** If borrower has no collateral left after seizure, remaining debt is absorbed by reducing `totalSupplyAssets`
- **CEI Pattern:** State updated before token transfers
- Calls oracle for price - oracle manipulation could enable unfair liquidations
- **Rounding:** All rounding favors protocol/liquidator

---

#### `flashLoan`

```solidity
function flashLoan(address token, uint256 assets, bytes calldata data) external
```

**Purpose:** No persistent state changes - tokens borrowed and repaid atomically. No fee charged - free flash loans. Access to ALL tokens held by contract (all market loan tokens, all market collateral tokens, and donations). Callback is REQUIRED - caller must implement `IMorphoFlashLoanCallback`. Caller must approve Morpho to reclaim tokens via `safeTransferFrom`.

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| `token` | address | The token to flash loan |
| `assets` | uint256 | Amount of tokens to borrow |
| `data` | bytes calldata | Callback data passed to borrower |

**Returns:** None

**Access Control:** Permissionless

**Validation:**
1. `require(assets != 0, ErrorsLib.ZERO_ASSETS)` - Cannot flash loan zero

**State Changes:** None (atomic)

**Internal Calls:** None

**External Calls:**
- `IERC20(token).safeTransfer(msg.sender, assets)` - Send tokens to borrower
- `IMorphoFlashLoanCallback(msg.sender).onMorphoFlashLoan(assets, data)` - Execute callback
- `IERC20(token).safeTransferFrom(msg.sender, address(this), assets)` - Reclaim tokens

**Events:** `EventsLib.FlashLoan(msg.sender, token, assets)`

**Security Notes:**
- **No fee** - flash loans are free
- **Atomic** - must return tokens in same transaction
- Can access ANY token held by contract, not just specific market tokens
- Borrower must pre-approve Morpho for token reclaim
- **Reentrancy:** Callback executes with tokens sent but before reclaim - CEI not applicable as no state changes

---

#### `setAuthorization`

```solidity
function setAuthorization(address authorized, bool newIsAuthorized) external
```

**Purpose:** Grants or revokes authorization for another address to manage caller's positions. Authorizing an address allows them to: `withdraw()` (withdraw supply), `borrow()` (increase debt), `withdrawCollateral()` (reduce collateral). Authorization can be revoked anytime. Self-authorization is implicit.

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| `authorized` | address | The address to grant/revoke authorization for |
| `newIsAuthorized` | bool | True to authorize, false to revoke |

**Returns:** None

**Access Control:** Permissionless (manages caller's own authorizations)

**Validation:**
1. `require(newIsAuthorized != isAuthorized[msg.sender][authorized], ErrorsLib.ALREADY_SET)` - Prevent no-op

**State Changes:**

| Variable | Change |
|----------|--------|
| `isAuthorized[msg.sender][authorized]` | Set to `newIsAuthorized` |

**Internal Calls:** None

**External Calls:** None

**Events:** `EventsLib.SetAuthorization(msg.sender, msg.sender, authorized, newIsAuthorized)`

**Security Notes:**
- Authorization is per-user, not per-market
- Authorized managers can perform harmful actions (borrow, withdraw)
- Authorization can be revoked at any time

---

#### `setAuthorizationWithSig`

```solidity
function setAuthorizationWithSig(
    Authorization memory authorization,
    Signature calldata signature
) external
```

**Purpose:** Sets authorization using EIP-712 signature, enabling gasless authorization. Nonce system prevents replay attacks - each nonce usable exactly once. Deadline provides time-limited authorization windows. Domain separator is chain-specific to prevent cross-chain replay. Signature malleability has no security impact.

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| `authorization` | Authorization memory | Struct with authorizer, authorized, isAuthorized, nonce, deadline |
| `signature` | Signature calldata | EIP-712 signature (v, r, s) |

**Returns:** None

**Access Control:** Permissionless (anyone can submit valid signatures)

**Validation:**
1. `require(block.timestamp <= authorization.deadline, ErrorsLib.SIGNATURE_EXPIRED)` - Signature not expired
2. `require(authorization.nonce == nonce[authorization.authorizer]++, ErrorsLib.INVALID_NONCE)` - Nonce matches and increments
3. `require(signatory != address(0) && authorization.authorizer == signatory, ErrorsLib.INVALID_SIGNATURE)` - Valid signature from authorizer

**State Changes:**

| Variable | Change |
|----------|--------|
| `nonce[authorization.authorizer]` | Incremented |
| `isAuthorized[authorization.authorizer][authorization.authorized]` | Set to `authorization.isAuthorized` |

**Internal Calls:** None

**External Calls:** None (ecrecover is a precompile)

**Events:**
- `EventsLib.IncrementNonce(msg.sender, authorization.authorizer, authorization.nonce)`
- `EventsLib.SetAuthorization(msg.sender, authorization.authorizer, authorization.authorized, authorization.isAuthorized)`

**Security Notes:**
- **Nonce strictly increments** - prevents replay attacks
- **Deadline** - time-bound authorization
- **Domain separator** - chain-specific to prevent cross-chain replay
- **Signature malleability** - acknowledged as having no security impact
- Uses `ecrecover` - ensure signatory is not address(0)

---

#### `accrueInterest`

```solidity
function accrueInterest(MarketParams memory marketParams) external
```

**Purpose:** Manually triggers interest accrual for a market. Permissionless - useful for keepers or before querying accurate balances. No-op if called in same block (elapsed time = 0).

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| `marketParams` | MarketParams memory | The market parameters |

**Returns:** None

**Access Control:** Permissionless

**Validation:**
1. `require(market[id].lastUpdate != 0, ErrorsLib.MARKET_NOT_CREATED)` - Market must exist

**State Changes:** (via `_accrueInterest`)

**Internal Calls:**
- `marketParams.id()` - Compute market ID
- `_accrueInterest(marketParams, id)` - Perform accrual

**External Calls:** (via `_accrueInterest`)

**Events:** (via `_accrueInterest`)

**Security Notes:**
- No-op if called multiple times in same block
- Useful for getting accurate balances before queries

---

#### `extSloads`

```solidity
function extSloads(bytes32[] calldata slots) external view returns (bytes32[] memory res)
```

**Purpose:** Returns the data stored on the different slots. Allows efficient batch reading of arbitrary storage slots.

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| `slots` | bytes32[] calldata | Array of storage slot identifiers |

**Returns:**

| Type | Description |
|------|-------------|
| bytes32[] memory | Array of values at each slot |

**Access Control:** Permissionless (view function)

**Validation:** None

**State Changes:** None

**Internal Calls:** None

**External Calls:** None

**Events:** None

**Security Notes:**
- Uses assembly to read arbitrary storage slots
- Intended for integrators to efficiently read multiple values
- No validation of slot values - caller must know correct slots

---

#### `_isSenderAuthorized`

```solidity
function _isSenderAuthorized(address onBehalf) internal view returns (bool)
```

**Purpose:** Returns whether the sender is authorized to manage `onBehalf`'s positions. Returns true if `msg.sender == onBehalf` OR `isAuthorized[onBehalf][msg.sender]`. Self-authorization always passes.

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| `onBehalf` | address | The address whose positions are being managed |

**Returns:**

| Type | Description |
|------|-------------|
| bool | True if sender is authorized |

**Access Control:** Internal

**Validation:** None

**State Changes:** None

**Internal Calls:** None

**External Calls:** None

**Events:** None

**Security Notes:**
- Self-authorization is implicit (msg.sender == onBehalf)
- Used by withdraw, borrow, withdrawCollateral

---

#### `_accrueInterest`

```solidity
function _accrueInterest(MarketParams memory marketParams, Id id) internal
```

**Purpose:** Accrues interest for the given market. Computes and applies interest accrual. Uses continuous compounding via Taylor expansion: e^(rt) - 1 ~ rt + (rt)^2/2 + (rt)^3/6. Calls `IRM.borrowRate()`. If IRM reverts, entire accrual fails. Assumes `marketParams` and `id` match.

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| `marketParams` | MarketParams memory | The market parameters |
| `id` | Id | The market ID |

**Returns:** None

**Access Control:** Internal

**Validation:** None (caller responsibility)

**State Changes:**

| Variable | Change |
|----------|--------|
| `market[id].totalBorrowAssets` | Increased by `interest.toUint128()` |
| `market[id].totalSupplyAssets` | Increased by `interest.toUint128()` |
| `position[id][feeRecipient].supplyShares` | Increased by `feeShares` |
| `market[id].totalSupplyShares` | Increased by `feeShares.toUint128()` |
| `market[id].lastUpdate` | Set to `uint128(block.timestamp)` |

**Internal Calls:**
- `borrowRate.wTaylorCompounded(elapsed)` - Compute compound interest factor
- `interest.wMulDown(market[id].fee)` - Calculate fee amount
- `feeAmount.toSharesDown(...)` - Convert fee to shares

**External Calls:**
- `IIrm(marketParams.irm).borrowRate(marketParams, market[id])` (if `irm != address(0)`)

**Events:** `EventsLib.AccrueInterest(id, borrowRate, interest, feeShares)`

**Security Notes:**
- **Taylor expansion** for continuous compounding - approximation accurate for typical rates
- If `irm == address(0)`, borrow rate is 0
- IRM revert blocks all operations requiring interest accrual
- Fee shares minted to feeRecipient (or lost if feeRecipient is address(0))

---

#### `_isHealthy` (3-param)

```solidity
function _isHealthy(
    MarketParams memory marketParams,
    Id id,
    address borrower
) internal view returns (bool)
```

**Purpose:** Returns whether the position of `borrower` in the given market is healthy. Checks if borrower's position is healthy by querying oracle. Returns true immediately if no debt (skips oracle call). Assumes `marketParams` and `id` match.

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| `marketParams` | MarketParams memory | The market parameters |
| `id` | Id | The market ID |
| `borrower` | address | The borrower address |

**Returns:**

| Type | Description |
|------|-------------|
| bool | True if position is healthy |

**Access Control:** Internal view

**Validation:** None

**State Changes:** None

**Internal Calls:**
- `_isHealthy(marketParams, id, borrower, collateralPrice)` - Delegate to 4-param version

**External Calls:**
- `IOracle(marketParams.oracle).price()` - Get collateral price

**Events:** None

**Security Notes:**
- Returns true immediately if `borrowShares == 0` (no debt)
- Oracle call skipped for positions with no debt (gas optimization)

---

#### `_isHealthy` (4-param)

```solidity
function _isHealthy(
    MarketParams memory marketParams,
    Id id,
    address borrower,
    uint256 collateralPrice
) internal view returns (bool)
```

**Purpose:** Returns whether the position of `borrower` in the given market with the given `collateralPrice` is healthy. Formula: healthy = (collateral * price / 1e36 * lltv) >= borrowed. Assumes `marketParams` and `id` match.

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| `marketParams` | MarketParams memory | The market parameters |
| `id` | Id | The market ID |
| `borrower` | address | The borrower address |
| `collateralPrice` | uint256 | The collateral price from oracle |

**Returns:**

| Type | Description |
|------|-------------|
| bool | True if position is healthy |

**Access Control:** Internal view

**Validation:** None

**State Changes:** None

**Internal Calls:**
- `borrowShares.toAssetsUp(...)` - Convert borrow shares to assets (rounds UP)
- `collateral.mulDivDown(collateralPrice, ORACLE_PRICE_SCALE).wMulDown(marketParams.lltv)` - Calculate max borrow

**External Calls:** None

**Events:** None

**Security Notes:**
- **Rounding:** Borrowed rounds UP (stricter - borrower appears to owe more)
- **Rounding:** maxBorrow rounds DOWN (stricter - borrower can borrow less)
- Both rounding directions favor the protocol (conservative health check)

---

## Library: MathLib

**File:** `src/libraries/MathLib.sol`
**License:** GPL-2.0-or-later
**Solidity Version:** ^0.8.0

**Description:** Library to manage fixed-point arithmetic with WAD (1e18) precision.

### Constants

| Constant | Value | Purpose |
|----------|-------|---------|
| `WAD` | 1e18 | Base unit for fixed-point math |

### Functions

#### `wMulDown`

```solidity
function wMulDown(uint256 x, uint256 y) internal pure returns (uint256)
```

**Purpose:** Returns (x * y) / WAD rounded down.

**Rounding:** DOWN

---

#### `wDivDown`

```solidity
function wDivDown(uint256 x, uint256 y) internal pure returns (uint256)
```

**Purpose:** Returns (x * WAD) / y rounded down.

**Rounding:** DOWN

---

#### `wDivUp`

```solidity
function wDivUp(uint256 x, uint256 y) internal pure returns (uint256)
```

**Purpose:** Returns (x * WAD) / y rounded up.

**Rounding:** UP

---

#### `mulDivDown`

```solidity
function mulDivDown(uint256 x, uint256 y, uint256 d) internal pure returns (uint256)
```

**Purpose:** Returns (x * y) / d rounded down.

**Rounding:** DOWN

---

#### `mulDivUp`

```solidity
function mulDivUp(uint256 x, uint256 y, uint256 d) internal pure returns (uint256)
```

**Purpose:** Returns (x * y + (d - 1)) / d rounded up.

**Rounding:** UP

---

#### `wTaylorCompounded`

```solidity
function wTaylorCompounded(uint256 x, uint256 n) internal pure returns (uint256)
```

**Purpose:** Returns sum of first three non-zero terms of Taylor expansion of e^(nx) - 1 for continuous compound interest. Formula: nx + (nx)^2/2 + (nx)^3/6.

**Security Notes:**
- Approximation is accurate for typical interest rates
- Higher order terms are negligible for small rates

---

## Library: SharesMathLib

**File:** `src/libraries/SharesMathLib.sol`
**License:** GPL-2.0-or-later
**Solidity Version:** ^0.8.0

**Description:** Shares management library. Uses OpenZeppelin's virtual shares method to mitigate share price manipulation attacks.

### Constants

| Constant | Value | Purpose |
|----------|-------|---------|
| `VIRTUAL_SHARES` | 1e6 | Prevents share inflation attacks |
| `VIRTUAL_ASSETS` | 1 | Enforces minimum conversion rate when market is empty |

### Functions

#### `toSharesDown`

```solidity
function toSharesDown(uint256 assets, uint256 totalAssets, uint256 totalShares) internal pure returns (uint256)
```

**Purpose:** Converts assets to shares, rounding down.

**Formula:** `assets * (totalShares + VIRTUAL_SHARES) / (totalAssets + VIRTUAL_ASSETS)`

**Rounding:** DOWN

---

#### `toAssetsDown`

```solidity
function toAssetsDown(uint256 shares, uint256 totalAssets, uint256 totalShares) internal pure returns (uint256)
```

**Purpose:** Converts shares to assets, rounding down.

**Formula:** `shares * (totalAssets + VIRTUAL_ASSETS) / (totalShares + VIRTUAL_SHARES)`

**Rounding:** DOWN

---

#### `toSharesUp`

```solidity
function toSharesUp(uint256 assets, uint256 totalAssets, uint256 totalShares) internal pure returns (uint256)
```

**Purpose:** Converts assets to shares, rounding up.

**Rounding:** UP

---

#### `toAssetsUp`

```solidity
function toAssetsUp(uint256 shares, uint256 totalAssets, uint256 totalShares) internal pure returns (uint256)
```

**Purpose:** Converts shares to assets, rounding up.

**Rounding:** UP

---

## Library: UtilsLib

**File:** `src/libraries/UtilsLib.sol`
**License:** GPL-2.0-or-later
**Solidity Version:** ^0.8.0

**Description:** Library exposing utility helpers.

### Functions

#### `exactlyOneZero`

```solidity
function exactlyOneZero(uint256 x, uint256 y) internal pure returns (bool z)
```

**Purpose:** Returns true if exactly one of x and y is zero.

---

#### `min`

```solidity
function min(uint256 x, uint256 y) internal pure returns (uint256 z)
```

**Purpose:** Returns the minimum of x and y.

---

#### `toUint128`

```solidity
function toUint128(uint256 x) internal pure returns (uint128)
```

**Purpose:** Safely casts to uint128.

**Validation:** `require(x <= type(uint128).max, ErrorsLib.MAX_UINT128_EXCEEDED)`

---

#### `zeroFloorSub`

```solidity
function zeroFloorSub(uint256 x, uint256 y) internal pure returns (uint256 z)
```

**Purpose:** Returns max(0, x - y). Prevents underflow by returning 0 if y > x.

---

## Library: SafeTransferLib

**File:** `src/libraries/SafeTransferLib.sol`
**License:** GPL-2.0-or-later
**Solidity Version:** ^0.8.0

**Description:** Library to manage transfers of tokens, handles non-standard ERC20 tokens that don't return boolean.

### Functions

#### `safeTransfer`

```solidity
function safeTransfer(IERC20 token, address to, uint256 value) internal
```

**Purpose:** Transfers tokens with checks for code existence and return value.

**Validation:**
1. `require(address(token).code.length > 0, ErrorsLib.NO_CODE)` - Token must have code
2. `require(success, ErrorsLib.TRANSFER_REVERTED)` - Call must succeed
3. `require(returndata.length == 0 || abi.decode(returndata, (bool)), ErrorsLib.TRANSFER_RETURNED_FALSE)` - Return value must be empty or true

---

#### `safeTransferFrom`

```solidity
function safeTransferFrom(IERC20 token, address from, address to, uint256 value) internal
```

**Purpose:** TransferFrom with same checks as safeTransfer.

**Validation:**
1. `require(address(token).code.length > 0, ErrorsLib.NO_CODE)` - Token must have code
2. `require(success, ErrorsLib.TRANSFER_FROM_REVERTED)` - Call must succeed
3. `require(returndata.length == 0 || abi.decode(returndata, (bool)), ErrorsLib.TRANSFER_FROM_RETURNED_FALSE)` - Return value must be empty or true

---

## Library: MarketParamsLib

**File:** `src/libraries/MarketParamsLib.sol`
**License:** GPL-2.0-or-later
**Solidity Version:** ^0.8.0

**Description:** Library to convert market parameters to market ID.

### Constants

| Constant | Value | Purpose |
|----------|-------|---------|
| `MARKET_PARAMS_BYTES_LENGTH` | 160 (5 * 32) | Size of MarketParams struct in bytes |

### Functions

#### `id`

```solidity
function id(MarketParams memory marketParams) internal pure returns (Id marketParamsId)
```

**Purpose:** Returns keccak256 hash of market params as Id.

**Formula:** `keccak256(abi.encode(marketParams))`

---

## Library: ConstantsLib

**File:** `src/libraries/ConstantsLib.sol`
**License:** GPL-2.0-or-later
**Solidity Version:** ^0.8.0

**Description:** Library containing protocol constants.

### Constants

| Constant | Value | Purpose |
|----------|-------|---------|
| `MAX_FEE` | 0.25e18 (25%) | Maximum protocol fee |
| `ORACLE_PRICE_SCALE` | 1e36 | Oracle price scaling factor |
| `LIQUIDATION_CURSOR` | 0.3e18 (30%) | Used in LIF calculation |
| `MAX_LIQUIDATION_INCENTIVE_FACTOR` | 1.15e18 (15% max) | Cap on liquidation bonus |
| `DOMAIN_TYPEHASH` | keccak256("EIP712Domain(uint256 chainId,address verifyingContract)") | EIP-712 domain type hash |
| `AUTHORIZATION_TYPEHASH` | keccak256("Authorization(address authorizer,address authorized,bool isAuthorized,uint256 nonce,uint256 deadline)") | EIP-712 authorization type hash |

---

## Library: ErrorsLib

**File:** `src/libraries/ErrorsLib.sol`
**License:** GPL-2.0-or-later
**Solidity Version:** ^0.8.0

**Description:** Library exposing error messages as string constants.

### Error Strings

| Constant | Value | Used In |
|----------|-------|---------|
| `NOT_OWNER` | "not owner" | `onlyOwner` modifier |
| `MAX_LLTV_EXCEEDED` | "max LLTV exceeded" | `enableLltv` |
| `MAX_FEE_EXCEEDED` | "max fee exceeded" | `setFee` |
| `ALREADY_SET` | "already set" | Multiple setters |
| `IRM_NOT_ENABLED` | "IRM not enabled" | `createMarket` |
| `LLTV_NOT_ENABLED` | "LLTV not enabled" | `createMarket` |
| `MARKET_ALREADY_CREATED` | "market already created" | `createMarket` |
| `NO_CODE` | "no code" | `SafeTransferLib` |
| `MARKET_NOT_CREATED` | "market not created" | Multiple functions |
| `INCONSISTENT_INPUT` | "inconsistent input" | Supply/borrow functions |
| `ZERO_ASSETS` | "zero assets" | `supplyCollateral`, `withdrawCollateral`, `flashLoan` |
| `ZERO_ADDRESS` | "zero address" | Constructor, multiple functions |
| `UNAUTHORIZED` | "unauthorized" | `withdraw`, `borrow`, `withdrawCollateral` |
| `INSUFFICIENT_COLLATERAL` | "insufficient collateral" | `borrow`, `withdrawCollateral` |
| `INSUFFICIENT_LIQUIDITY` | "insufficient liquidity" | `withdraw`, `borrow` |
| `HEALTHY_POSITION` | "position is healthy" | `liquidate` |
| `INVALID_SIGNATURE` | "invalid signature" | `setAuthorizationWithSig` |
| `SIGNATURE_EXPIRED` | "signature expired" | `setAuthorizationWithSig` |
| `INVALID_NONCE` | "invalid nonce" | `setAuthorizationWithSig` |
| `TRANSFER_REVERTED` | "transfer reverted" | `SafeTransferLib` |
| `TRANSFER_RETURNED_FALSE` | "transfer returned false" | `SafeTransferLib` |
| `TRANSFER_FROM_REVERTED` | "transferFrom reverted" | `SafeTransferLib` |
| `TRANSFER_FROM_RETURNED_FALSE` | "transferFrom returned false" | `SafeTransferLib` |
| `MAX_UINT128_EXCEEDED` | "max uint128 exceeded" | `UtilsLib.toUint128` |

---

## Library: EventsLib

**File:** `src/libraries/EventsLib.sol`
**License:** GPL-2.0-or-later
**Solidity Version:** ^0.8.0

**Description:** Library exposing all events emitted by the Morpho contract.

### Events

| Event | Parameters | Emitted By |
|-------|------------|------------|
| `SetOwner` | `address indexed newOwner` | `setOwner`, constructor |
| `SetFee` | `Id indexed id, uint256 newFee` | `setFee` |
| `SetFeeRecipient` | `address indexed newFeeRecipient` | `setFeeRecipient` |
| `EnableIrm` | `address indexed irm` | `enableIrm` |
| `EnableLltv` | `uint256 lltv` | `enableLltv` |
| `CreateMarket` | `Id indexed id, MarketParams marketParams` | `createMarket` |
| `Supply` | `Id indexed id, address indexed caller, address indexed onBehalf, uint256 assets, uint256 shares` | `supply` |
| `Withdraw` | `Id indexed id, address caller, address indexed onBehalf, address indexed receiver, uint256 assets, uint256 shares` | `withdraw` |
| `Borrow` | `Id indexed id, address caller, address indexed onBehalf, address indexed receiver, uint256 assets, uint256 shares` | `borrow` |
| `Repay` | `Id indexed id, address indexed caller, address indexed onBehalf, uint256 assets, uint256 shares` | `repay` |
| `SupplyCollateral` | `Id indexed id, address indexed caller, address indexed onBehalf, uint256 assets` | `supplyCollateral` |
| `WithdrawCollateral` | `Id indexed id, address caller, address indexed onBehalf, address indexed receiver, uint256 assets` | `withdrawCollateral` |
| `Liquidate` | `Id indexed id, address indexed caller, address indexed borrower, uint256 repaidAssets, uint256 repaidShares, uint256 seizedAssets, uint256 badDebtAssets, uint256 badDebtShares` | `liquidate` |
| `FlashLoan` | `address indexed caller, address indexed token, uint256 assets` | `flashLoan` |
| `SetAuthorization` | `address indexed caller, address indexed authorizer, address indexed authorized, bool newIsAuthorized` | `setAuthorization`, `setAuthorizationWithSig` |
| `IncrementNonce` | `address indexed caller, address indexed authorizer, uint256 usedNonce` | `setAuthorizationWithSig` |
| `AccrueInterest` | `Id indexed id, uint256 prevBorrowRate, uint256 interest, uint256 feeShares` | `_accrueInterest` |

---

## Security Summary

### Reentrancy Vectors

| Function | External Call | Before/After State Update | CEI Compliant |
|----------|---------------|---------------------------|---------------|
| `supply` | `onMorphoSupply` callback, `safeTransferFrom` | After | Yes |
| `withdraw` | `safeTransfer` | After | Yes |
| `borrow` | `safeTransfer` | After | Yes |
| `repay` | `onMorphoRepay` callback, `safeTransferFrom` | After | Yes |
| `supplyCollateral` | `onMorphoSupplyCollateral` callback, `safeTransferFrom` | After | Yes |
| `withdrawCollateral` | `safeTransfer` | After | Yes |
| `liquidate` | `price()`, `safeTransfer`, `onMorphoLiquidate` callback, `safeTransferFrom` | After | Yes |
| `flashLoan` | `safeTransfer`, `onMorphoFlashLoan` callback, `safeTransferFrom` | N/A (no state) | N/A |
| `createMarket` | `borrowRate()` | After | Yes |
| `_accrueInterest` | `borrowRate()` | Before lastUpdate | Yes |

**Notes:**
- All functions follow CEI (Checks-Effects-Interactions) pattern
- Callbacks execute after state updates, before token transfers
- Flash loans have no state changes, so reentrancy is not a concern

---

### Privileged Functions

| Function | Required Role | Capabilities |
|----------|---------------|--------------|
| `setOwner` | Owner | Transfer ownership (immediate, no timelock) |
| `enableIrm` | Owner | Whitelist IRM (irreversible) |
| `enableLltv` | Owner | Whitelist LLTV (irreversible) |
| `setFee` | Owner | Set market fee (up to 25%) |
| `setFeeRecipient` | Owner | Set fee recipient address |

**Risk Assessment:**
- Single admin with no timelock
- No two-step ownership transfer
- IRMs and LLTVs cannot be disabled once enabled
- Owner can be set to address(0) to permanently disable admin functions

---

### Critical Invariants Checked

| Invariant | Where Checked | Error Message |
|-----------|---------------|---------------|
| `totalBorrowAssets <= totalSupplyAssets` | `withdraw`, `borrow` | "insufficient liquidity" |
| Health: `collateral * price * lltv >= borrowed` | `borrow`, `withdrawCollateral` | "insufficient collateral" |
| Unhealthy for liquidation | `liquidate` | "position is healthy" |
| LLTV < WAD (100%) | `enableLltv` | "max LLTV exceeded" |
| Fee <= MAX_FEE (25%) | `setFee` | "max fee exceeded" |
| Market exists | Multiple functions | "market not created" |
| Market not exists | `createMarket` | "market already created" |
| IRM enabled | `createMarket` | "IRM not enabled" |
| LLTV enabled | `createMarket` | "LLTV not enabled" |
| Nonce valid | `setAuthorizationWithSig` | "invalid nonce" |
| Signature not expired | `setAuthorizationWithSig` | "signature expired" |
| Valid signature | `setAuthorizationWithSig` | "invalid signature" |

---

### Rounding Direction Summary

| Operation | Direction | Favors |
|-----------|-----------|--------|
| Supply: assets -> shares | DOWN | Protocol |
| Supply: shares -> assets | UP | Protocol |
| Withdraw: assets -> shares | UP | Protocol |
| Withdraw: shares -> assets | DOWN | Protocol |
| Borrow: assets -> shares | UP | Protocol |
| Borrow: shares -> assets | DOWN | Protocol |
| Repay: assets -> shares | DOWN | Borrower (slightly) |
| Repay: shares -> assets | UP | Protocol |
| Health check: borrowed | UP | Protocol (stricter) |
| Health check: maxBorrow | DOWN | Protocol (stricter) |
| Liquidation | Various | Protocol/Liquidator |
| Fee calculation | DOWN | Protocol |

---

### Trust Assumptions

| Component | Trust Requirement |
|-----------|-------------------|
| Owner | Can enable IRMs/LLTVs, set fees. Must act responsibly. |
| IRM | Must not revert on `borrowRate()`, must not return extreme rates. |
| Oracle | Must return correct price scaled by 1e36, must not be manipulable. |
| Tokens | Must be ERC-20 compliant, no fee-on-transfer, no rebasing. |

---

### Key Design Decisions

1. **Isolated Markets:** No cross-collateralization between markets
2. **Singleton Contract:** All markets managed by single contract
3. **Virtual Shares:** 1e6 virtual shares + 1 virtual asset prevents inflation attacks
4. **Free Flash Loans:** No fee charged for flash loans
5. **Bad Debt Socialization:** Remaining debt after liquidation absorbed by suppliers
6. **EIP-712 Signatures:** Enables gasless authorization
7. **No Timelock:** Owner actions take effect immediately
8. **Irreversible Whitelisting:** IRMs and LLTVs cannot be disabled once enabled
