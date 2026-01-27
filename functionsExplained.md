# Morpho Blue - Functions Explained

## What is Morpho Blue?

Morpho Blue is a **minimalist, trustless lending protocol** that enables permissionless creation of isolated lending markets. Unlike traditional monolithic lending protocols (like Aave or Compound) where all assets share risk in a single pool, Morpho Blue allows anyone to create independent lending markets with specific parameters.

Each market in Morpho Blue is defined by 5 parameters:
- **Loan Token**: The asset being lent/borrowed
- **Collateral Token**: The asset used as collateral
- **Oracle**: Price feed for the collateral/loan pair
- **IRM (Interest Rate Model)**: Algorithm determining borrow rates
- **LLTV (Liquidation Loan-To-Value)**: Maximum collateralization ratio before liquidation

The protocol is designed to be:
- **Immutable**: No upgradability, no governance over core logic
- **Minimal**: ~650 lines of code with no external dependencies
- **Trustless**: Users only trust the specific market parameters they interact with

---

## Storage Variables

| Variable | Type | Description |
|----------|------|-------------|
| `DOMAIN_SEPARATOR` | `bytes32` | EIP-712 domain separator for signature verification |
| `owner` | `address` | Protocol owner who can enable IRMs/LLTVs and set fees |
| `feeRecipient` | `address` | Address receiving protocol fees as supply shares |
| `position` | `mapping(Id => mapping(address => Position))` | User positions per market |
| `market` | `mapping(Id => Market)` | Market state (totals, lastUpdate, fee) |
| `isIrmEnabled` | `mapping(address => bool)` | Whitelist of allowed IRMs |
| `isLltvEnabled` | `mapping(uint256 => bool)` | Whitelist of allowed LLTVs |
| `isAuthorized` | `mapping(address => mapping(address => bool))` | Delegation permissions |
| `nonce` | `mapping(address => uint256)` | Nonce for EIP-712 signatures |
| `idToMarketParams` | `mapping(Id => MarketParams)` | Market params lookup by ID |

---

## Functions

### Constructor

```solidity
constructor(address newOwner)
```

**What it does**: Initializes the Morpho contract with an owner and sets up the EIP-712 domain separator.

**Why it does it**: The owner is needed to govern protocol-level settings (enabling IRMs/LLTVs, setting fees). The domain separator is required for EIP-712 signature verification, enabling gasless authorizations.

**Relation to Morpho**: This is the entry point for deploying a new Morpho Blue instance. Each deployment creates an independent lending protocol.

---

### Owner Functions

#### `setOwner(address newOwner)`

**What it does**: Transfers ownership of the protocol to a new address.

**Why it does it**: Allows governance transitions. The owner controls which IRMs and LLTVs can be used for market creation, and can set fees on markets.

**Relation to Morpho**: Morpho Blue has minimal governance - the owner can only enable (not disable) IRMs/LLTVs and adjust fees. This function enables ownership transfer while maintaining the protocol's trustless nature.

---

#### `enableIrm(address irm)`

**What it does**: Adds an Interest Rate Model contract to the whitelist of allowed IRMs.

**Why it does it**: IRMs determine how interest rates change based on utilization. Whitelisting prevents malicious IRMs (that could return extreme rates or revert) from being used.

**Relation to Morpho**: Markets require an enabled IRM to be created. Once enabled, an IRM cannot be disabled - this ensures existing markets remain functional forever.

---

#### `enableLltv(uint256 lltv)`

**What it does**: Adds a Liquidation Loan-To-Value ratio to the whitelist. The LLTV must be less than 100% (WAD = 1e18).

**Why it does it**: LLTV determines how much can be borrowed against collateral. Higher LLTVs mean more capital efficiency but higher liquidation risk. Whitelisting prevents extreme values (like 99.99% LLTV which would be nearly impossible to liquidate safely).

**Relation to Morpho**: Each market has a fixed LLTV that cannot change. Enabling specific LLTVs allows market creators to choose appropriate risk parameters for their asset pairs.

---

#### `setFee(MarketParams memory marketParams, uint256 newFee)`

**What it does**: Sets the protocol fee for a specific market. Maximum fee is 25% (MAX_FEE = 0.25e18). Accrues interest before changing the fee.

**Why it does it**: Fees generate protocol revenue. They're taken as a percentage of interest paid by borrowers. Accruing interest first ensures the old fee rate applies to accumulated interest before the change.

**Relation to Morpho**: Fees are the only protocol-level extraction. They're distributed as supply shares to `feeRecipient`, meaning the fee recipient earns proportionally to their "share" of the market.

---

#### `setFeeRecipient(address newFeeRecipient)`

**What it does**: Changes the address that receives protocol fees.

**Why it does it**: Allows redirecting fee revenue to a new address (e.g., treasury, DAO, or burn address).

**Relation to Morpho**: The fee recipient accumulates supply shares over time as interest accrues. They can withdraw these shares like any other supplier.

---

### Market Creation

#### `createMarket(MarketParams memory marketParams)`

**What it does**: Creates a new lending market with the specified parameters. Validates that the IRM and LLTV are enabled, and that the market doesn't already exist. Initializes the IRM if it's stateful.

**Why it does it**: This is how new isolated lending markets come into existence. Each market is identified by a unique ID derived from hashing all its parameters.

**Relation to Morpho**: This is a core feature of Morpho Blue - permissionless market creation. Anyone can create a market for any token pair, as long as they use whitelisted IRMs and LLTVs. The market ID is deterministic, preventing duplicate markets.

---

### Supply Management

#### `supply(MarketParams, uint256 assets, uint256 shares, address onBehalf, bytes data)`

**What it does**: Deposits loan tokens into a market. The supplier receives "supply shares" representing their claim on the pool. Can specify either `assets` (exact token amount) or `shares` (exact share amount). Supports callbacks for flash-mint patterns.

**Why it does it**: Suppliers provide liquidity that borrowers can use. In return, suppliers earn interest from borrowers. The share system handles interest accrual - as interest accumulates, each share becomes worth more assets.

**Relation to Morpho**: Supply is the foundation of lending. Without suppliers, there's nothing to borrow. Morpho uses a share-based accounting system where `totalSupplyAssets / totalSupplyShares` gives the current exchange rate.

---

#### `withdraw(MarketParams, uint256 assets, uint256 shares, address onBehalf, address receiver)`

**What it does**: Removes supplied assets from a market. Burns the caller's supply shares and transfers loan tokens to the receiver. Requires authorization if withdrawing on behalf of another user.

**Why it does it**: Allows suppliers to exit their position and reclaim their assets plus earned interest. The check `totalBorrowAssets <= totalSupplyAssets` ensures there's enough liquidity.

**Relation to Morpho**: Withdrawal is how suppliers realize their gains. The authorization system allows smart contracts or delegated managers to withdraw on a user's behalf.

---

### Borrow Management

#### `borrow(MarketParams, uint256 assets, uint256 shares, address onBehalf, address receiver)`

**What it does**: Takes a loan from the market. The borrower receives loan tokens and incurs "borrow shares" representing their debt. Requires the borrower to have sufficient collateral (health check).

**Why it does it**: Borrowing is the demand side of lending. Borrowers get immediate liquidity while their collateral remains locked. The health check ensures the position is sufficiently collateralized.

**Relation to Morpho**: Borrowing generates interest that benefits suppliers. The share system means borrowers owe an increasing amount of assets over time as `totalBorrowAssets / totalBorrowShares` grows.

---

#### `repay(MarketParams, uint256 assets, uint256 shares, address onBehalf, bytes data)`

**What it does**: Pays back borrowed assets. Burns borrow shares and transfers loan tokens from the caller to the contract. Supports callbacks for flash-repay patterns.

**Why it does it**: Repayment reduces debt, making positions healthier and freeing up collateral for withdrawal. Anyone can repay on behalf of any borrower (no authorization needed).

**Relation to Morpho**: Repayment closes the lending cycle. When all debt is repaid, the borrower can withdraw all their collateral. The callback enables atomic operations like leveraging/deleveraging.

---

### Collateral Management

#### `supplyCollateral(MarketParams, uint256 assets, address onBehalf, bytes data)`

**What it does**: Deposits collateral tokens into a market. Does NOT accrue interest (gas optimization). Supports callbacks.

**Why it does it**: Collateral backs borrowing positions. More collateral = higher borrowing capacity. Interest isn't accrued because collateral doesn't affect interest calculations.

**Relation to Morpho**: Collateral is stored separately from supply positions. It doesn't earn interest but enables borrowing. The separation allows clear accounting of what's lendable vs. what's backing loans.

---

#### `withdrawCollateral(MarketParams, uint256 assets, address onBehalf, address receiver)`

**What it does**: Removes collateral from a market. Requires authorization and performs a health check to ensure the remaining collateral still supports the debt.

**Why it does it**: Allows borrowers to retrieve excess collateral or exit positions after repaying debt. The health check prevents withdrawing too much collateral.

**Relation to Morpho**: This is how borrowers reclaim their collateral. After full repayment, all collateral can be withdrawn. The authorization requirement prevents unauthorized draining of collateral.

---

### Liquidation

#### `liquidate(MarketParams, address borrower, uint256 seizedAssets, uint256 repaidShares, bytes data)`

**What it does**: Liquidates an unhealthy position by repaying some debt and seizing collateral at a discount. Calculates a liquidation incentive (up to 15% bonus). Handles bad debt if collateral is fully depleted.

**Why it does it**: Liquidation is the enforcement mechanism that keeps the protocol solvent. When a position's collateral value drops below the debt value (adjusted by LLTV), liquidators step in to reduce systemic risk.

**Relation to Morpho**: This is Morpho's risk management. The liquidation incentive factor rewards liquidators for maintaining protocol health. Bad debt handling socializes losses among suppliers when collateral is insufficient.

**Liquidation Incentive Formula**:
```
incentiveFactor = min(1.15, 1 / (1 - 0.3 * (1 - LLTV)))
```
This creates a dynamic incentive based on LLTV - higher LLTV markets get closer to the 15% max incentive.

---

### Flash Loans

#### `flashLoan(address token, uint256 assets, bytes data)`

**What it does**: Lends any token held by the contract within a single transaction. The borrower must return the full amount by the end of the callback. No fee is charged.

**Why it does it**: Flash loans enable complex DeFi operations like arbitrage, liquidations, and collateral swaps without requiring upfront capital. The atomic nature (borrow + return in same tx) eliminates default risk.

**Relation to Morpho**: Flash loans access ALL tokens in the contract - not just a specific market's liquidity. This includes supplied assets, deposited collateral, and any donations. Zero fees make Morpho competitive for flash loan use cases.

---

### Authorization

#### `setAuthorization(address authorized, bool newIsAuthorized)`

**What it does**: Grants or revokes permission for another address to manage the caller's positions across all markets.

**Why it does it**: Enables delegation to smart contracts, bots, or other accounts. Useful for portfolio management, automated strategies, or protocol integrations.

**Relation to Morpho**: Authorization is required for `withdraw`, `borrow`, and `withdrawCollateral` on behalf of others. This creates a flexible permission system without per-market granularity (keeping the contract simple).

---

#### `setAuthorizationWithSig(Authorization authorization, Signature signature)`

**What it does**: Sets authorization using an EIP-712 signature instead of a direct transaction. Validates the signature, increments the nonce, and applies the authorization.

**Why it does it**: Enables gasless authorizations where a third party can submit the signed message. Useful for meta-transactions and better UX. The nonce prevents replay attacks.

**Relation to Morpho**: This is the gasless equivalent of `setAuthorization`. Users can sign permissions offline, and anyone can submit them on-chain. Each signature can only be used once due to nonce incrementing.

---

### Interest Management

#### `accrueInterest(MarketParams memory marketParams)`

**What it does**: Manually triggers interest accrual for a market. Updates `totalBorrowAssets`, `totalSupplyAssets`, and mints fee shares to `feeRecipient`.

**Why it does it**: Interest normally accrues lazily (on supply/withdraw/borrow/repay). This function allows explicit accrual, useful for accurate off-chain calculations or before fee changes.

**Relation to Morpho**: Interest is calculated using Taylor series approximation for continuous compounding: `interest = totalBorrowAssets * (e^(rate * time) - 1)`. The IRM provides the current borrow rate based on utilization.

---

#### `_accrueInterest(MarketParams, Id id)` (internal)

**What it does**: Core interest accrual logic. Calculates elapsed time, queries the IRM for the borrow rate, computes interest using `wTaylorCompounded`, and mints fee shares if applicable.

**Why it does it**: Centralizes interest logic for reuse across multiple functions. The Taylor approximation avoids expensive exponentiation while maintaining accuracy.

**Relation to Morpho**: This is called at the start of most state-changing operations. The pattern ensures interest is always up-to-date before any position changes, maintaining accounting integrity.

---

### Health Check

#### `_isHealthy(MarketParams, Id id, address borrower)` (internal)

**What it does**: Checks if a borrower's position is healthy by comparing their debt to their maximum borrowing capacity.

**Formula**:
```
maxBorrow = collateral * collateralPrice * LLTV
healthy = maxBorrow >= borrowed
```

**Why it does it**: Enforces collateralization requirements. Called after borrowing and collateral withdrawal to prevent undercollateralized positions.

**Relation to Morpho**: Health checks are Morpho's solvency guarantee. A position is only unhealthy when the oracle price has moved against the borrower, enabling liquidation.

---

### Storage View

#### `extSloads(bytes32[] calldata slots)`

**What it does**: Reads arbitrary storage slots and returns their values. Uses assembly for direct storage access.

**Why it does it**: Enables efficient batched storage reads for off-chain integrations. Cheaper than multiple view function calls, especially useful for indexers and analytics.

**Relation to Morpho**: This is a utility function for external consumers. It doesn't affect protocol logic but improves composability and gas efficiency for reading complex state.

---

## Internal Helper

#### `_isSenderAuthorized(address onBehalf)` (internal)

**What it does**: Returns `true` if the caller is either the `onBehalf` address itself or has been authorized by `onBehalf`.

**Why it does it**: Centralizes authorization logic. Users always control their own positions, and can optionally delegate to others.

**Relation to Morpho**: This is the gatekeeper for sensitive operations (withdraw, borrow, withdrawCollateral). It ensures only authorized parties can move assets out of positions.

---

## Key Constants

| Constant | Value | Description |
|----------|-------|-------------|
| `MAX_FEE` | 25% (0.25e18) | Maximum protocol fee on interest |
| `ORACLE_PRICE_SCALE` | 1e36 | Price scaling for oracle values |
| `LIQUIDATION_CURSOR` | 30% (0.3e18) | Controls liquidation incentive curve |
| `MAX_LIQUIDATION_INCENTIVE_FACTOR` | 15% (1.15e18) | Maximum liquidation bonus |
| `WAD` | 1e18 | Standard fixed-point denominator |

---

## Accounting Model

Morpho uses a **share-based accounting system**:

1. **Supply Shares**: Represent claim on supplied assets
   - Exchange rate: `totalSupplyAssets / totalSupplyShares`
   - As interest accrues, each share is worth more assets

2. **Borrow Shares**: Represent debt owed
   - Exchange rate: `totalBorrowAssets / totalBorrowShares`
   - As interest accrues, each share represents more debt

This model elegantly handles interest without iterating over all positions - only the totals need updating.

---

## Security Considerations

1. **Rounding**: Always rounds against the user and in favor of the protocol
2. **Reentrancy**: Callbacks are called AFTER state changes (checks-effects-interactions)
3. **Authorization**: Strict checks prevent unauthorized position management
4. **Immutability**: No admin functions can break existing markets
5. **Bad Debt Socialization**: Suppliers absorb losses when liquidations don't cover debt
