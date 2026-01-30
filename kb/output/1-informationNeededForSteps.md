# Information Extraction - Morpho Blue Protocol

---

## META

PROJECT_TYPE: Foundry
SOURCE_DIR: src/
TEST_DIR: test/
SOLIDITY_VERSION: 0.8.19 (main contract), ^0.8.0 (libraries/interfaces)
LICENSE: BUSL-1.1 (main), GPL-2.0-or-later (libraries/interfaces)

---

## FILE: src/Morpho.sol

TYPE: Contract
NAME: Morpho
DESC: The Morpho contract - Singleton contract managing isolated lending markets. Each market identified by keccak256(MarketParams) containing (loanToken, collateralToken, oracle, irm, lltv). Markets are independent - no cross-collateralization between markets. Permissionless market creation with owner-whitelisted IRMs and LLTVs.

IMPORTS:
- ./interfaces/IMorpho.sol (Id, IMorphoStaticTyping, IMorphoBase, MarketParams, Position, Market, Authorization, Signature)
- ./interfaces/IMorphoCallbacks.sol (IMorphoLiquidateCallback, IMorphoRepayCallback, IMorphoSupplyCallback, IMorphoSupplyCollateralCallback, IMorphoFlashLoanCallback)
- ./interfaces/IIrm.sol (IIrm)
- ./interfaces/IERC20.sol (IERC20)
- ./interfaces/IOracle.sol (IOracle)
- ./libraries/ConstantsLib.sol (all constants)
- ./libraries/UtilsLib.sol (UtilsLib)
- ./libraries/EventsLib.sol (EventsLib)
- ./libraries/ErrorsLib.sol (ErrorsLib)
- ./libraries/MathLib.sol (MathLib, WAD)
- ./libraries/SharesMathLib.sol (SharesMathLib)
- ./libraries/MarketParamsLib.sol (MarketParamsLib)
- ./libraries/SafeTransferLib.sol (SafeTransferLib)

INHERITS: IMorphoStaticTyping

USES:
- MathLib for uint128
- MathLib for uint256
- UtilsLib for uint256
- SharesMathLib for uint256
- SafeTransferLib for IERC20
- MarketParamsLib for MarketParams

CONSTRUCTOR:
- signature: constructor(address newOwner)
- parameters: newOwner (address) - The new owner of the contract
- requires: newOwner != address(0) - ErrorsLib.ZERO_ADDRESS
- state_changes: Sets owner = newOwner, computes DOMAIN_SEPARATOR
- events: EventsLib.SetOwner(newOwner)

IMMUTABLES:
- DOMAIN_SEPARATOR (bytes32): EIP-712 domain separator - chain-specific to prevent cross-chain replay attacks. Computed as keccak256(abi.encode(DOMAIN_TYPEHASH, block.chainid, address(this)))

MODIFIERS:
- onlyOwner: Requires msg.sender == owner, reverts with ErrorsLib.NOT_OWNER

STATE:
- owner (address): Contract owner, can enable IRMs/LLTVs, set fees. Single admin - no timelock. No two-step transfer.
- feeRecipient (address): Receives supply shares representing protocol fees. If address(0), fees are lost.
- position (mapping(Id => mapping(address => Position))): Per-user position in each market. Position contains supplyShares (uint256), borrowShares (uint128), collateral (uint128).
- market (mapping(Id => Market)): Global market state. Market contains totalSupplyAssets, totalSupplyShares, totalBorrowAssets, totalBorrowShares (all uint128), lastUpdate (uint128), fee (uint128).
- isIrmEnabled (mapping(address => bool)): Whitelist of enabled Interest Rate Models. Once enabled, cannot be disabled.
- isLltvEnabled (mapping(uint256 => bool)): Whitelist of enabled Loan-to-Value ratios. Each LLTV must be < WAD (100%). Cannot be disabled.
- isAuthorized (mapping(address => mapping(address => bool))): Authorization for position management. isAuthorized[owner][manager] = true allows manager to withdraw/borrow from owner's positions.
- nonce (mapping(address => uint256)): Nonces for EIP-712 signature replay protection. Increments on each setAuthorizationWithSig call.
- idToMarketParams (mapping(Id => MarketParams)): Reverse lookup from market ID to MarketParams.

---

### FUNC: setOwner

SIG: function setOwner(address newOwner) external onlyOwner
VISIBILITY: external
MODIFIERS: onlyOwner
NATSPEC: @inheritdoc IMorphoBase - Transfers contract ownership to new address. No two-step transfer - immediate and irreversible. Can set owner to address(0), permanently disabling admin functions.
REQUIRES:
- require(newOwner != owner, ErrorsLib.ALREADY_SET) - Prevent no-op state change
READS: owner
WRITES: owner = newOwner
EVENTS: EventsLib.SetOwner(newOwner)
INTERNAL_CALLS: none
EXTERNAL_CALLS: none

---

### FUNC: enableIrm

SIG: function enableIrm(address irm) external onlyOwner
VISIBILITY: external
MODIFIERS: onlyOwner
NATSPEC: @inheritdoc IMorphoBase - Whitelists an Interest Rate Model for market creation. Once enabled, CANNOT be disabled. Owner must trust IRM code. address(0) is a valid IRM (creates 0% APR markets).
REQUIRES:
- require(!isIrmEnabled[irm], ErrorsLib.ALREADY_SET) - Prevent re-enabling already enabled IRM
READS: isIrmEnabled[irm]
WRITES: isIrmEnabled[irm] = true
EVENTS: EventsLib.EnableIrm(irm)
INTERNAL_CALLS: none
EXTERNAL_CALLS: none

---

### FUNC: enableLltv

SIG: function enableLltv(uint256 lltv) external onlyOwner
VISIBILITY: external
MODIFIERS: onlyOwner
NATSPEC: @inheritdoc IMorphoBase - Whitelists a Loan-to-Value ratio for market creation. lltv must be < WAD (1e18 = 100%). Common values: 0.8e18 (80%), 0.9e18 (90%). Higher LLTV = more leverage = higher liquidation risk. Cannot be disabled once enabled.
REQUIRES:
- require(!isLltvEnabled[lltv], ErrorsLib.ALREADY_SET) - Prevent re-enabling
- require(lltv < WAD, ErrorsLib.MAX_LLTV_EXCEEDED) - LLTV >= 100% would allow infinite borrowing
READS: isLltvEnabled[lltv]
WRITES: isLltvEnabled[lltv] = true
EVENTS: EventsLib.EnableLltv(lltv)
INTERNAL_CALLS: none
EXTERNAL_CALLS: none

---

### FUNC: setFee

SIG: function setFee(MarketParams memory marketParams, uint256 newFee) external onlyOwner
VISIBILITY: external
MODIFIERS: onlyOwner
NATSPEC: @inheritdoc IMorphoBase - Sets protocol fee for a market. Fee is percentage of interest accrued. newFee must be <= MAX_FEE (0.25e18 = 25%). Fee = interest * fee / WAD. Accrues interest with OLD fee before applying new fee (fair accounting).
REQUIRES:
- require(market[id].lastUpdate != 0, ErrorsLib.MARKET_NOT_CREATED) - Market must exist
- require(newFee != market[id].fee, ErrorsLib.ALREADY_SET) - Prevent no-op
- require(newFee <= MAX_FEE, ErrorsLib.MAX_FEE_EXCEEDED) - Cap at 25%
READS: market[id].lastUpdate, market[id].fee
WRITES: market[id].fee = uint128(newFee)
EVENTS: EventsLib.SetFee(id, newFee)
INTERNAL_CALLS: _accrueInterest(marketParams, id)
EXTERNAL_CALLS: (via _accrueInterest) IIrm(marketParams.irm).borrowRate(marketParams, market[id])

---

### FUNC: setFeeRecipient

SIG: function setFeeRecipient(address newFeeRecipient) external onlyOwner
VISIBILITY: external
MODIFIERS: onlyOwner
NATSPEC: @inheritdoc IMorphoBase - Sets address that receives protocol fee shares. If set to address(0), fees are LOST (shares minted to zero address). Changing recipient allows new recipient to claim any not-yet-accrued fees.
REQUIRES:
- require(newFeeRecipient != feeRecipient, ErrorsLib.ALREADY_SET) - Prevent no-op
READS: feeRecipient
WRITES: feeRecipient = newFeeRecipient
EVENTS: EventsLib.SetFeeRecipient(newFeeRecipient)
INTERNAL_CALLS: none
EXTERNAL_CALLS: none

---

### FUNC: createMarket

SIG: function createMarket(MarketParams memory marketParams) external
VISIBILITY: external
MODIFIERS: none
NATSPEC: @inheritdoc IMorphoBase - Creates a new isolated lending market with specified parameters. Permissionless - anyone can create markets using owner-whitelisted IRM and LLTV. Market ID = keccak256(abi.encode(loanToken, collateralToken, oracle, irm, lltv)). Same parameters always produce same ID - deterministic and collision-resistant. Calls IRM.borrowRate() to initialize stateful IRMs.
REQUIRES:
- require(isIrmEnabled[marketParams.irm], ErrorsLib.IRM_NOT_ENABLED) - IRM must be whitelisted
- require(isLltvEnabled[marketParams.lltv], ErrorsLib.LLTV_NOT_ENABLED) - LLTV must be whitelisted
- require(market[id].lastUpdate == 0, ErrorsLib.MARKET_ALREADY_CREATED) - Cannot recreate existing market
READS: isIrmEnabled[marketParams.irm], isLltvEnabled[marketParams.lltv], market[id].lastUpdate
WRITES: market[id].lastUpdate = uint128(block.timestamp), idToMarketParams[id] = marketParams
EVENTS: EventsLib.CreateMarket(id, marketParams)
INTERNAL_CALLS: marketParams.id()
EXTERNAL_CALLS: IIrm(marketParams.irm).borrowRate(marketParams, market[id]) (if irm != address(0))

---

### FUNC: supply

SIG: function supply(MarketParams memory marketParams, uint256 assets, uint256 shares, address onBehalf, bytes calldata data) external returns (uint256, uint256)
VISIBILITY: external
MODIFIERS: none
NATSPEC: @inheritdoc IMorphoBase - Deposits loan tokens into market, crediting supply shares to onBehalf. Permissionless - anyone can supply on behalf of any address (no authorization needed, only benefits recipient). Callback executes AFTER state update but BEFORE token transfer (CEI pattern). Caller can use callback to source funds. shares = assets * (totalShares + VIRTUAL_SHARES) / (totalAssets + VIRTUAL_ASSETS). Rounding - assets to shares rounds DOWN (protocol favored).
REQUIRES:
- require(market[id].lastUpdate != 0, ErrorsLib.MARKET_NOT_CREATED) - Market must exist
- require(UtilsLib.exactlyOneZero(assets, shares), ErrorsLib.INCONSISTENT_INPUT) - Exactly one must be 0
- require(onBehalf != address(0), ErrorsLib.ZERO_ADDRESS) - Cannot credit to zero address
READS: market[id].lastUpdate, market[id].totalSupplyAssets, market[id].totalSupplyShares
WRITES: position[id][onBehalf].supplyShares += shares, market[id].totalSupplyShares += shares.toUint128(), market[id].totalSupplyAssets += assets.toUint128()
EVENTS: EventsLib.Supply(id, msg.sender, onBehalf, assets, shares)
INTERNAL_CALLS: marketParams.id(), _accrueInterest(marketParams, id), assets.toSharesDown(...) or shares.toAssetsUp(...)
EXTERNAL_CALLS: IMorphoSupplyCallback(msg.sender).onMorphoSupply(assets, data) (if data.length > 0), IERC20(marketParams.loanToken).safeTransferFrom(msg.sender, address(this), assets)

---

### FUNC: withdraw

SIG: function withdraw(MarketParams memory marketParams, uint256 assets, uint256 shares, address onBehalf, address receiver) external returns (uint256, uint256)
VISIBILITY: external
MODIFIERS: none
NATSPEC: @inheritdoc IMorphoBase - Burns supply shares and withdraws loan tokens from market. Requires authorization - msg.sender must be onBehalf OR authorized by onBehalf. Rounding - assets to shares rounds UP (user burns more), shares to assets rounds DOWN (user gets less). After withdrawal, totalBorrowAssets <= totalSupplyAssets must hold (liquidity constraint).
REQUIRES:
- require(market[id].lastUpdate != 0, ErrorsLib.MARKET_NOT_CREATED)
- require(UtilsLib.exactlyOneZero(assets, shares), ErrorsLib.INCONSISTENT_INPUT)
- require(receiver != address(0), ErrorsLib.ZERO_ADDRESS)
- require(_isSenderAuthorized(onBehalf), ErrorsLib.UNAUTHORIZED)
- require(market[id].totalBorrowAssets <= market[id].totalSupplyAssets, ErrorsLib.INSUFFICIENT_LIQUIDITY)
READS: market[id].lastUpdate, market[id].totalSupplyAssets, market[id].totalSupplyShares, market[id].totalBorrowAssets, position[id][onBehalf].supplyShares, isAuthorized[onBehalf][msg.sender]
WRITES: position[id][onBehalf].supplyShares -= shares, market[id].totalSupplyShares -= shares.toUint128(), market[id].totalSupplyAssets -= assets.toUint128()
EVENTS: EventsLib.Withdraw(id, msg.sender, onBehalf, receiver, assets, shares)
INTERNAL_CALLS: marketParams.id(), _accrueInterest(marketParams, id), _isSenderAuthorized(onBehalf), assets.toSharesUp(...) or shares.toAssetsDown(...)
EXTERNAL_CALLS: IERC20(marketParams.loanToken).safeTransfer(receiver, assets)

---

### FUNC: borrow

SIG: function borrow(MarketParams memory marketParams, uint256 assets, uint256 shares, address onBehalf, address receiver) external returns (uint256, uint256)
VISIBILITY: external
MODIFIERS: none
NATSPEC: @inheritdoc IMorphoBase - Creates debt position by minting borrow shares and transferring loan tokens. Requires authorization AND health check. Position must remain healthy after borrow. Calls oracle.price() via _isHealthy(). Two invariants: (1) Health: collateral * price * lltv >= borrowed, (2) Liquidity: totalBorrow <= totalSupply. Rounding - assets to shares rounds UP (borrower owes more), shares to assets rounds DOWN.
REQUIRES:
- require(market[id].lastUpdate != 0, ErrorsLib.MARKET_NOT_CREATED)
- require(UtilsLib.exactlyOneZero(assets, shares), ErrorsLib.INCONSISTENT_INPUT)
- require(receiver != address(0), ErrorsLib.ZERO_ADDRESS)
- require(_isSenderAuthorized(onBehalf), ErrorsLib.UNAUTHORIZED)
- require(_isHealthy(marketParams, id, onBehalf), ErrorsLib.INSUFFICIENT_COLLATERAL)
- require(market[id].totalBorrowAssets <= market[id].totalSupplyAssets, ErrorsLib.INSUFFICIENT_LIQUIDITY)
READS: market[id].lastUpdate, market[id].totalBorrowAssets, market[id].totalBorrowShares, market[id].totalSupplyAssets, position[id][onBehalf].borrowShares, position[id][onBehalf].collateral
WRITES: position[id][onBehalf].borrowShares += shares.toUint128(), market[id].totalBorrowShares += shares.toUint128(), market[id].totalBorrowAssets += assets.toUint128()
EVENTS: EventsLib.Borrow(id, msg.sender, onBehalf, receiver, assets, shares)
INTERNAL_CALLS: marketParams.id(), _accrueInterest(marketParams, id), _isSenderAuthorized(onBehalf), _isHealthy(marketParams, id, onBehalf)
EXTERNAL_CALLS: IERC20(marketParams.loanToken).safeTransfer(receiver, assets), (via _isHealthy) IOracle(marketParams.oracle).price()

---

### FUNC: repay

SIG: function repay(MarketParams memory marketParams, uint256 assets, uint256 shares, address onBehalf, bytes calldata data) external returns (uint256, uint256)
VISIBILITY: external
MODIFIERS: none
NATSPEC: @inheritdoc IMorphoBase - Repays borrowed tokens, reducing debt position and market totals. Permissionless - anyone can repay on behalf of any borrower (benefits borrower). Callback executes AFTER state update but BEFORE token transfer (CEI pattern). Rounding - assets to shares rounds DOWN (borrower repays fewer shares - slightly borrower favored). Edge case: assets may exceed totalBorrowAssets by 1 due to rounding - handled by zeroFloorSub.
REQUIRES:
- require(market[id].lastUpdate != 0, ErrorsLib.MARKET_NOT_CREATED)
- require(UtilsLib.exactlyOneZero(assets, shares), ErrorsLib.INCONSISTENT_INPUT)
- require(onBehalf != address(0), ErrorsLib.ZERO_ADDRESS)
READS: market[id].lastUpdate, market[id].totalBorrowAssets, market[id].totalBorrowShares, position[id][onBehalf].borrowShares
WRITES: position[id][onBehalf].borrowShares -= shares.toUint128(), market[id].totalBorrowShares -= shares.toUint128(), market[id].totalBorrowAssets = UtilsLib.zeroFloorSub(market[id].totalBorrowAssets, assets).toUint128()
EVENTS: EventsLib.Repay(id, msg.sender, onBehalf, assets, shares)
INTERNAL_CALLS: marketParams.id(), _accrueInterest(marketParams, id), assets.toSharesDown(...) or shares.toAssetsUp(...)
EXTERNAL_CALLS: IMorphoRepayCallback(msg.sender).onMorphoRepay(assets, data) (if data.length > 0), IERC20(marketParams.loanToken).safeTransferFrom(msg.sender, address(this), assets)

---

### FUNC: supplyCollateral

SIG: function supplyCollateral(MarketParams memory marketParams, uint256 assets, address onBehalf, bytes calldata data) external
VISIBILITY: external
MODIFIERS: none
NATSPEC: @inheritdoc IMorphoBase - Deposits collateral tokens to back borrowing positions. Permissionless - anyone can supply collateral for any address (benefits recipient). Callback executes AFTER state update but BEFORE token transfer (CEI pattern). Does NOT accrue interest - collateral doesn't earn interest, saves gas. Collateral tracked as raw assets (uint128), NOT shares.
REQUIRES:
- require(market[id].lastUpdate != 0, ErrorsLib.MARKET_NOT_CREATED)
- require(assets != 0, ErrorsLib.ZERO_ASSETS)
- require(onBehalf != address(0), ErrorsLib.ZERO_ADDRESS)
READS: market[id].lastUpdate
WRITES: position[id][onBehalf].collateral += assets.toUint128()
EVENTS: EventsLib.SupplyCollateral(id, msg.sender, onBehalf, assets)
INTERNAL_CALLS: marketParams.id()
EXTERNAL_CALLS: IMorphoSupplyCollateralCallback(msg.sender).onMorphoSupplyCollateral(assets, data) (if data.length > 0), IERC20(marketParams.collateralToken).safeTransferFrom(msg.sender, address(this), assets)

---

### FUNC: withdrawCollateral

SIG: function withdrawCollateral(MarketParams memory marketParams, uint256 assets, address onBehalf, address receiver) external
VISIBILITY: external
MODIFIERS: none
NATSPEC: @inheritdoc IMorphoBase - Withdraws collateral tokens, reducing backing for borrow position. Requires authorization - only position owner or authorized managers can withdraw. Position must remain healthy after withdrawal - enforced by _isHealthy check. Calls oracle.price() via _isHealthy(). Unlike supplyCollateral, this DOES accrue interest because health check needs accurate debt.
REQUIRES:
- require(market[id].lastUpdate != 0, ErrorsLib.MARKET_NOT_CREATED)
- require(assets != 0, ErrorsLib.ZERO_ASSETS)
- require(receiver != address(0), ErrorsLib.ZERO_ADDRESS)
- require(_isSenderAuthorized(onBehalf), ErrorsLib.UNAUTHORIZED)
- require(_isHealthy(marketParams, id, onBehalf), ErrorsLib.INSUFFICIENT_COLLATERAL)
READS: market[id].lastUpdate, position[id][onBehalf].collateral, position[id][onBehalf].borrowShares
WRITES: position[id][onBehalf].collateral -= assets.toUint128()
EVENTS: EventsLib.WithdrawCollateral(id, msg.sender, onBehalf, receiver, assets)
INTERNAL_CALLS: marketParams.id(), _accrueInterest(marketParams, id), _isSenderAuthorized(onBehalf), _isHealthy(marketParams, id, onBehalf)
EXTERNAL_CALLS: IERC20(marketParams.collateralToken).safeTransfer(receiver, assets), (via _isHealthy) IOracle(marketParams.oracle).price()

---

### FUNC: liquidate

SIG: function liquidate(MarketParams memory marketParams, address borrower, uint256 seizedAssets, uint256 repaidShares, bytes calldata data) external returns (uint256, uint256)
VISIBILITY: external
MODIFIERS: none
NATSPEC: @inheritdoc IMorphoBase - Liquidates unhealthy positions by repaying debt and seizing collateral at a discount. Permissionless - anyone can liquidate unhealthy positions (economic incentive via liquidation bonus). LIF = min(1.15, 1/(1 - 0.3*(1-lltv))). At LLTV=0.8: LIF ~ 1.064 (6.4% bonus). At LLTV=0.5: LIF capped to 1.15 (15% max). Calls oracle.price(). BAD DEBT: If collateral == 0 after seizure, remaining debt is socialized to suppliers.
REQUIRES:
- require(market[id].lastUpdate != 0, ErrorsLib.MARKET_NOT_CREATED)
- require(UtilsLib.exactlyOneZero(seizedAssets, repaidShares), ErrorsLib.INCONSISTENT_INPUT)
- require(!_isHealthy(marketParams, id, borrower, collateralPrice), ErrorsLib.HEALTHY_POSITION)
READS: market[id].lastUpdate, market[id].totalBorrowAssets, market[id].totalBorrowShares, market[id].totalSupplyAssets, position[id][borrower].borrowShares, position[id][borrower].collateral
WRITES: position[id][borrower].borrowShares -= repaidShares.toUint128(), market[id].totalBorrowShares -= repaidShares.toUint128(), market[id].totalBorrowAssets (zeroFloorSub), position[id][borrower].collateral -= seizedAssets.toUint128(), (if bad debt) market[id].totalSupplyAssets -= badDebtAssets.toUint128(), position[id][borrower].borrowShares = 0
EVENTS: EventsLib.Liquidate(id, msg.sender, borrower, repaidAssets, repaidShares, seizedAssets, badDebtAssets, badDebtShares)
INTERNAL_CALLS: marketParams.id(), _accrueInterest(marketParams, id), _isHealthy(marketParams, id, borrower, collateralPrice)
EXTERNAL_CALLS: IOracle(marketParams.oracle).price(), IERC20(marketParams.collateralToken).safeTransfer(msg.sender, seizedAssets), IMorphoLiquidateCallback(msg.sender).onMorphoLiquidate(repaidAssets, data) (if data.length > 0), IERC20(marketParams.loanToken).safeTransferFrom(msg.sender, address(this), repaidAssets)

---

### FUNC: flashLoan

SIG: function flashLoan(address token, uint256 assets, bytes calldata data) external
VISIBILITY: external
MODIFIERS: none
NATSPEC: @inheritdoc IMorphoBase - No persistent state changes - tokens borrowed and repaid atomically. No fee charged - free flash loans. Access to ALL tokens held by contract (all market loan tokens, all market collateral tokens, and donations). Callback is REQUIRED - caller must implement IMorphoFlashLoanCallback. Caller must approve Morpho to reclaim tokens via safeTransferFrom.
REQUIRES:
- require(assets != 0, ErrorsLib.ZERO_ASSETS)
READS: none
WRITES: none (atomic)
EVENTS: EventsLib.FlashLoan(msg.sender, token, assets)
INTERNAL_CALLS: none
EXTERNAL_CALLS: IERC20(token).safeTransfer(msg.sender, assets), IMorphoFlashLoanCallback(msg.sender).onMorphoFlashLoan(assets, data), IERC20(token).safeTransferFrom(msg.sender, address(this), assets)

---

### FUNC: setAuthorization

SIG: function setAuthorization(address authorized, bool newIsAuthorized) external
VISIBILITY: external
MODIFIERS: none
NATSPEC: @inheritdoc IMorphoBase - Grants or revokes authorization for another address to manage caller's positions. Authorizing an address allows them to: withdraw() (withdraw supply), borrow() (increase debt), withdrawCollateral() (reduce collateral). Authorization can be revoked anytime. Self-authorization is implicit.
REQUIRES:
- require(newIsAuthorized != isAuthorized[msg.sender][authorized], ErrorsLib.ALREADY_SET)
READS: isAuthorized[msg.sender][authorized]
WRITES: isAuthorized[msg.sender][authorized] = newIsAuthorized
EVENTS: EventsLib.SetAuthorization(msg.sender, msg.sender, authorized, newIsAuthorized)
INTERNAL_CALLS: none
EXTERNAL_CALLS: none

---

### FUNC: setAuthorizationWithSig

SIG: function setAuthorizationWithSig(Authorization memory authorization, Signature calldata signature) external
VISIBILITY: external
MODIFIERS: none
NATSPEC: @inheritdoc IMorphoBase - Sets authorization using EIP-712 signature, enabling gasless authorization. Nonce system prevents replay attacks - each nonce usable exactly once. Deadline provides time-limited authorization windows. Domain separator is chain-specific to prevent cross-chain replay. Signature malleability has no security impact.
REQUIRES:
- require(block.timestamp <= authorization.deadline, ErrorsLib.SIGNATURE_EXPIRED)
- require(authorization.nonce == nonce[authorization.authorizer]++, ErrorsLib.INVALID_NONCE)
- require(signatory != address(0) && authorization.authorizer == signatory, ErrorsLib.INVALID_SIGNATURE)
READS: nonce[authorization.authorizer], DOMAIN_SEPARATOR
WRITES: nonce[authorization.authorizer]++, isAuthorized[authorization.authorizer][authorization.authorized] = authorization.isAuthorized
EVENTS: EventsLib.IncrementNonce(msg.sender, authorization.authorizer, authorization.nonce), EventsLib.SetAuthorization(msg.sender, authorization.authorizer, authorization.authorized, authorization.isAuthorized)
INTERNAL_CALLS: none
EXTERNAL_CALLS: none (ecrecover is a precompile)

---

### FUNC: accrueInterest

SIG: function accrueInterest(MarketParams memory marketParams) external
VISIBILITY: external
MODIFIERS: none
NATSPEC: @inheritdoc IMorphoBase - Manually triggers interest accrual for a market. Permissionless - useful for keepers or before querying accurate balances. No-op if called in same block (elapsed time = 0).
REQUIRES:
- require(market[id].lastUpdate != 0, ErrorsLib.MARKET_NOT_CREATED)
READS: market[id].lastUpdate
WRITES: (via _accrueInterest)
EVENTS: (via _accrueInterest)
INTERNAL_CALLS: marketParams.id(), _accrueInterest(marketParams, id)
EXTERNAL_CALLS: (via _accrueInterest)

---

### FUNC: _isSenderAuthorized

SIG: function _isSenderAuthorized(address onBehalf) internal view returns (bool)
VISIBILITY: internal view
MODIFIERS: none
NATSPEC: Returns whether the sender is authorized to manage onBehalf's positions. Returns true if msg.sender == onBehalf OR isAuthorized[onBehalf][msg.sender]. Self-authorization always passes.
REQUIRES: none
READS: isAuthorized[onBehalf][msg.sender]
WRITES: none
EVENTS: none
INTERNAL_CALLS: none
EXTERNAL_CALLS: none

---

### FUNC: _accrueInterest

SIG: function _accrueInterest(MarketParams memory marketParams, Id id) internal
VISIBILITY: internal
MODIFIERS: none
NATSPEC: Accrues interest for the given market marketParams. Computes and applies interest accrual. Uses continuous compounding via Taylor expansion: e^(rt) - 1 ~ rt + (rt)^2/2 + (rt)^3/6. Calls IRM.borrowRate(). If IRM reverts, entire accrual fails. Assumes marketParams and id match.
REQUIRES: none (caller responsibility)
READS: market[id].lastUpdate, market[id].totalBorrowAssets, market[id].totalSupplyAssets, market[id].totalSupplyShares, market[id].fee
WRITES: market[id].totalBorrowAssets += interest.toUint128(), market[id].totalSupplyAssets += interest.toUint128(), position[id][feeRecipient].supplyShares += feeShares, market[id].totalSupplyShares += feeShares.toUint128(), market[id].lastUpdate = uint128(block.timestamp)
EVENTS: EventsLib.AccrueInterest(id, borrowRate, interest, feeShares)
INTERNAL_CALLS: borrowRate.wTaylorCompounded(elapsed), interest.wMulDown(market[id].fee), feeAmount.toSharesDown(...)
EXTERNAL_CALLS: IIrm(marketParams.irm).borrowRate(marketParams, market[id]) (if irm != address(0))

---

### FUNC: _isHealthy (3-param)

SIG: function _isHealthy(MarketParams memory marketParams, Id id, address borrower) internal view returns (bool)
VISIBILITY: internal view
MODIFIERS: none
NATSPEC: Returns whether the position of borrower in the given market marketParams is healthy. Checks if borrower's position is healthy by querying oracle. Returns true immediately if no debt (skips oracle call). Assumes marketParams and id match.
REQUIRES: none
READS: position[id][borrower].borrowShares
WRITES: none
EVENTS: none
INTERNAL_CALLS: _isHealthy(marketParams, id, borrower, collateralPrice)
EXTERNAL_CALLS: IOracle(marketParams.oracle).price()

---

### FUNC: _isHealthy (4-param)

SIG: function _isHealthy(MarketParams memory marketParams, Id id, address borrower, uint256 collateralPrice) internal view returns (bool)
VISIBILITY: internal view
MODIFIERS: none
NATSPEC: Returns whether the position of borrower in the given market with the given collateralPrice is healthy. Formula: healthy = (collateral * price / 1e36 * lltv) >= borrowed. Rounding: borrowed rounds UP (borrower appears to owe more), maxBorrow rounds DOWN (borrower can borrow less). Assumes marketParams and id match.
REQUIRES: none
READS: position[id][borrower].borrowShares, position[id][borrower].collateral, market[id].totalBorrowAssets, market[id].totalBorrowShares
WRITES: none
EVENTS: none
INTERNAL_CALLS: borrowShares.toAssetsUp(...), collateral.mulDivDown(collateralPrice, ORACLE_PRICE_SCALE).wMulDown(marketParams.lltv)
EXTERNAL_CALLS: none

---

### FUNC: extSloads

SIG: function extSloads(bytes32[] calldata slots) external view returns (bytes32[] memory res)
VISIBILITY: external view
MODIFIERS: none
NATSPEC: @inheritdoc IMorphoBase - Returns the data stored on the different slots.
REQUIRES: none
READS: arbitrary storage slots via assembly
WRITES: none
EVENTS: none
INTERNAL_CALLS: none
EXTERNAL_CALLS: none

---

## FILE: src/interfaces/IMorpho.sol

TYPE: Interface
NAME: IMorphoBase, IMorphoStaticTyping, IMorpho
DESC: Core interfaces defining the Morpho protocol's public API. IMorphoBase contains all function signatures. IMorphoStaticTyping inherits IMorphoBase with static-typed position/market getters. IMorpho is the recommended interface with struct returns.

IMPORTS: none

STRUCTS:
- MarketParams: loanToken (address), collateralToken (address), oracle (address), irm (address), lltv (uint256)
- Position: supplyShares (uint256), borrowShares (uint128), collateral (uint128)
- Market: totalSupplyAssets (uint128), totalSupplyShares (uint128), totalBorrowAssets (uint128), totalBorrowShares (uint128), lastUpdate (uint128), fee (uint128)
- Authorization: authorizer (address), authorized (address), isAuthorized (bool), nonce (uint256), deadline (uint256)
- Signature: v (uint8), r (bytes32), s (bytes32)

TYPES:
- Id: bytes32 (custom type)

---

## FILE: src/interfaces/IIrm.sol

TYPE: Interface
NAME: IIrm
DESC: Interface that Interest Rate Models (IRMs) used by Morpho must implement.

IMPORTS:
- ./IMorpho.sol (MarketParams, Market)

FUNCTIONS:
- borrowRate(MarketParams memory marketParams, Market memory market) external returns (uint256): Returns borrow rate per second scaled by WAD. May modify storage (stateful IRMs).
- borrowRateView(MarketParams memory marketParams, Market memory market) external view returns (uint256): Returns borrow rate without modifying storage.

---

## FILE: src/interfaces/IERC20.sol

TYPE: Interface
NAME: IERC20
DESC: Empty interface to prevent calling transfer/transferFrom instead of safeTransfer/safeTransferFrom.

---

## FILE: src/interfaces/IMorphoCallbacks.sol

TYPE: Interface
NAME: IMorphoLiquidateCallback, IMorphoRepayCallback, IMorphoSupplyCallback, IMorphoSupplyCollateralCallback, IMorphoFlashLoanCallback
DESC: Callback interfaces for users wanting to use callbacks in liquidate, repay, supply, supplyCollateral, and flashLoan functions. Callbacks are only called if data is not empty.

FUNCTIONS:
- onMorphoLiquidate(uint256 repaidAssets, bytes calldata data): Called on liquidation
- onMorphoRepay(uint256 assets, bytes calldata data): Called on repayment
- onMorphoSupply(uint256 assets, bytes calldata data): Called on supply
- onMorphoSupplyCollateral(uint256 assets, bytes calldata data): Called on collateral supply
- onMorphoFlashLoan(uint256 assets, bytes calldata data): Called on flash loan

---

## FILE: src/interfaces/IOracle.sol

TYPE: Interface
NAME: IOracle
DESC: Interface that oracles used by Morpho must implement. It is the user's responsibility to select markets with safe oracles.

FUNCTIONS:
- price() external view returns (uint256): Returns the price of 1 asset of collateral token quoted in 1 asset of loan token, scaled by 1e36.

---

## FILE: src/libraries/ConstantsLib.sol

TYPE: Library (constants file)
NAME: ConstantsLib
DESC: Library containing protocol constants.

CONSTANTS:
- MAX_FEE: 0.25e18 (25% maximum fee)
- ORACLE_PRICE_SCALE: 1e36 (oracle price scale)
- LIQUIDATION_CURSOR: 0.3e18 (30% liquidation cursor)
- MAX_LIQUIDATION_INCENTIVE_FACTOR: 1.15e18 (15% max liquidation bonus)
- DOMAIN_TYPEHASH: keccak256("EIP712Domain(uint256 chainId,address verifyingContract)")
- AUTHORIZATION_TYPEHASH: keccak256("Authorization(address authorizer,address authorized,bool isAuthorized,uint256 nonce,uint256 deadline)")

---

## FILE: src/libraries/MathLib.sol

TYPE: Library
NAME: MathLib
DESC: Library to manage fixed-point arithmetic with WAD (1e18) precision.

CONSTANTS:
- WAD: 1e18

FUNCTIONS:
- wMulDown(uint256 x, uint256 y) internal pure returns (uint256): Returns (x * y) / WAD rounded down
- wDivDown(uint256 x, uint256 y) internal pure returns (uint256): Returns (x * WAD) / y rounded down
- wDivUp(uint256 x, uint256 y) internal pure returns (uint256): Returns (x * WAD) / y rounded up
- mulDivDown(uint256 x, uint256 y, uint256 d) internal pure returns (uint256): Returns (x * y) / d rounded down
- mulDivUp(uint256 x, uint256 y, uint256 d) internal pure returns (uint256): Returns (x * y + (d - 1)) / d rounded up
- wTaylorCompounded(uint256 x, uint256 n) internal pure returns (uint256): Returns sum of first three non-zero terms of Taylor expansion of e^(nx) - 1 for continuous compound interest

---

## FILE: src/libraries/SharesMathLib.sol

TYPE: Library
NAME: SharesMathLib
DESC: Shares management library. Uses OpenZeppelin's virtual shares method to mitigate share price manipulation attacks.

IMPORTS:
- ./MathLib.sol

CONSTANTS:
- VIRTUAL_SHARES: 1e6 (prevents share inflation attacks)
- VIRTUAL_ASSETS: 1 (enforces conversion rate when market is empty)

FUNCTIONS:
- toSharesDown(uint256 assets, uint256 totalAssets, uint256 totalShares) internal pure returns (uint256): Converts assets to shares, rounding down
- toAssetsDown(uint256 shares, uint256 totalAssets, uint256 totalShares) internal pure returns (uint256): Converts shares to assets, rounding down
- toSharesUp(uint256 assets, uint256 totalAssets, uint256 totalShares) internal pure returns (uint256): Converts assets to shares, rounding up
- toAssetsUp(uint256 shares, uint256 totalAssets, uint256 totalShares) internal pure returns (uint256): Converts shares to assets, rounding up

---

## FILE: src/libraries/UtilsLib.sol

TYPE: Library
NAME: UtilsLib
DESC: Library exposing utility helpers.

IMPORTS:
- ./ErrorsLib.sol

FUNCTIONS:
- exactlyOneZero(uint256 x, uint256 y) internal pure returns (bool z): Returns true if exactly one of x and y is zero
- min(uint256 x, uint256 y) internal pure returns (uint256 z): Returns the minimum of x and y
- toUint128(uint256 x) internal pure returns (uint128): Safely casts to uint128, reverts if exceeds max
- zeroFloorSub(uint256 x, uint256 y) internal pure returns (uint256 z): Returns max(0, x - y)

---

## FILE: src/libraries/ErrorsLib.sol

TYPE: Library
NAME: ErrorsLib
DESC: Library exposing error messages as string constants.

ERROR_STRINGS:
- NOT_OWNER: "not owner"
- MAX_LLTV_EXCEEDED: "max LLTV exceeded"
- MAX_FEE_EXCEEDED: "max fee exceeded"
- ALREADY_SET: "already set"
- IRM_NOT_ENABLED: "IRM not enabled"
- LLTV_NOT_ENABLED: "LLTV not enabled"
- MARKET_ALREADY_CREATED: "market already created"
- NO_CODE: "no code"
- MARKET_NOT_CREATED: "market not created"
- INCONSISTENT_INPUT: "inconsistent input"
- ZERO_ASSETS: "zero assets"
- ZERO_ADDRESS: "zero address"
- UNAUTHORIZED: "unauthorized"
- INSUFFICIENT_COLLATERAL: "insufficient collateral"
- INSUFFICIENT_LIQUIDITY: "insufficient liquidity"
- HEALTHY_POSITION: "position is healthy"
- INVALID_SIGNATURE: "invalid signature"
- SIGNATURE_EXPIRED: "signature expired"
- INVALID_NONCE: "invalid nonce"
- TRANSFER_REVERTED: "transfer reverted"
- TRANSFER_RETURNED_FALSE: "transfer returned false"
- TRANSFER_FROM_REVERTED: "transferFrom reverted"
- TRANSFER_FROM_RETURNED_FALSE: "transferFrom returned false"
- MAX_UINT128_EXCEEDED: "max uint128 exceeded"

---

## FILE: src/libraries/EventsLib.sol

TYPE: Library
NAME: EventsLib
DESC: Library exposing all events emitted by the Morpho contract.

IMPORTS:
- ../interfaces/IMorpho.sol (Id, MarketParams)

EVENTS:
- SetOwner(address indexed newOwner)
- SetFee(Id indexed id, uint256 newFee)
- SetFeeRecipient(address indexed newFeeRecipient)
- EnableIrm(address indexed irm)
- EnableLltv(uint256 lltv)
- CreateMarket(Id indexed id, MarketParams marketParams)
- Supply(Id indexed id, address indexed caller, address indexed onBehalf, uint256 assets, uint256 shares)
- Withdraw(Id indexed id, address caller, address indexed onBehalf, address indexed receiver, uint256 assets, uint256 shares)
- Borrow(Id indexed id, address caller, address indexed onBehalf, address indexed receiver, uint256 assets, uint256 shares)
- Repay(Id indexed id, address indexed caller, address indexed onBehalf, uint256 assets, uint256 shares)
- SupplyCollateral(Id indexed id, address indexed caller, address indexed onBehalf, uint256 assets)
- WithdrawCollateral(Id indexed id, address caller, address indexed onBehalf, address indexed receiver, uint256 assets)
- Liquidate(Id indexed id, address indexed caller, address indexed borrower, uint256 repaidAssets, uint256 repaidShares, uint256 seizedAssets, uint256 badDebtAssets, uint256 badDebtShares)
- FlashLoan(address indexed caller, address indexed token, uint256 assets)
- SetAuthorization(address indexed caller, address indexed authorizer, address indexed authorized, bool newIsAuthorized)
- IncrementNonce(address indexed caller, address indexed authorizer, uint256 usedNonce)
- AccrueInterest(Id indexed id, uint256 prevBorrowRate, uint256 interest, uint256 feeShares)

---

## FILE: src/libraries/SafeTransferLib.sol

TYPE: Library
NAME: SafeTransferLib
DESC: Library to manage transfers of tokens, handles non-standard ERC20 tokens that don't return boolean.

IMPORTS:
- ../interfaces/IERC20.sol
- ./ErrorsLib.sol

INTERNAL_INTERFACE:
- IERC20Internal: transfer(address to, uint256 value), transferFrom(address from, address to, uint256 value)

FUNCTIONS:
- safeTransfer(IERC20 token, address to, uint256 value) internal: Transfers tokens with checks for code existence and return value
- safeTransferFrom(IERC20 token, address from, address to, uint256 value) internal: TransferFrom with same checks

REQUIRES:
- require(address(token).code.length > 0, ErrorsLib.NO_CODE)
- require(success, ErrorsLib.TRANSFER_REVERTED / TRANSFER_FROM_REVERTED)
- require(returndata.length == 0 || abi.decode(returndata, (bool)), ErrorsLib.TRANSFER_RETURNED_FALSE / TRANSFER_FROM_RETURNED_FALSE)

---

## FILE: src/libraries/MarketParamsLib.sol

TYPE: Library
NAME: MarketParamsLib
DESC: Library to convert market parameters to market ID.

IMPORTS:
- ../interfaces/IMorpho.sol (Id, MarketParams)

CONSTANTS:
- MARKET_PARAMS_BYTES_LENGTH: 5 * 32 = 160 bytes

FUNCTIONS:
- id(MarketParams memory marketParams) internal pure returns (Id marketParamsId): Returns keccak256 hash of market params as Id

---

## FILE: src/libraries/periphery/MorphoLib.sol

TYPE: Library (Periphery)
NAME: MorphoLib
DESC: Helper library to access Morpho storage variables via extSloads. Warning: Supply and borrow getters may return outdated values that do not include accrued interest.

IMPORTS:
- ../../interfaces/IMorpho.sol (IMorpho, Id)
- ./MorphoStorageLib.sol

FUNCTIONS:
- supplyShares(IMorpho morpho, Id id, address user) internal view returns (uint256)
- borrowShares(IMorpho morpho, Id id, address user) internal view returns (uint256)
- collateral(IMorpho morpho, Id id, address user) internal view returns (uint256)
- totalSupplyAssets(IMorpho morpho, Id id) internal view returns (uint256)
- totalSupplyShares(IMorpho morpho, Id id) internal view returns (uint256)
- totalBorrowAssets(IMorpho morpho, Id id) internal view returns (uint256)
- totalBorrowShares(IMorpho morpho, Id id) internal view returns (uint256)
- lastUpdate(IMorpho morpho, Id id) internal view returns (uint256)
- fee(IMorpho morpho, Id id) internal view returns (uint256)

---

## FILE: src/libraries/periphery/MorphoBalancesLib.sol

TYPE: Library (Periphery)
NAME: MorphoBalancesLib
DESC: Helper library exposing getters with expected value after interest accrual. Not used in Morpho itself, intended for integrators.

IMPORTS:
- ../../interfaces/IMorpho.sol (Id, MarketParams, Market, IMorpho)
- ../../interfaces/IIrm.sol
- ../MathLib.sol
- ../UtilsLib.sol
- ./MorphoLib.sol
- ../SharesMathLib.sol
- ../MarketParamsLib.sol

FUNCTIONS:
- expectedMarketBalances(IMorpho morpho, MarketParams memory marketParams) internal view returns (uint256, uint256, uint256, uint256): Returns expected totalSupplyAssets, totalSupplyShares, totalBorrowAssets, totalBorrowShares after accrual
- expectedTotalSupplyAssets(IMorpho morpho, MarketParams memory marketParams) internal view returns (uint256)
- expectedTotalBorrowAssets(IMorpho morpho, MarketParams memory marketParams) internal view returns (uint256)
- expectedTotalSupplyShares(IMorpho morpho, MarketParams memory marketParams) internal view returns (uint256)
- expectedSupplyAssets(IMorpho morpho, MarketParams memory marketParams, address user) internal view returns (uint256): Warning: Wrong for feeRecipient
- expectedBorrowAssets(IMorpho morpho, MarketParams memory marketParams, address user) internal view returns (uint256): Warning: May be greater than total due to rounding

---

## FILE: src/libraries/periphery/MorphoStorageLib.sol

TYPE: Library (Periphery)
NAME: MorphoStorageLib
DESC: Helper library exposing getters to access Morpho storage variables' slot positions. Not used in Morpho itself, intended for integrators.

IMPORTS:
- ../../interfaces/IMorpho.sol (Id)

STORAGE_SLOTS:
- OWNER_SLOT: 0
- FEE_RECIPIENT_SLOT: 1
- POSITION_SLOT: 2
- MARKET_SLOT: 3
- IS_IRM_ENABLED_SLOT: 4
- IS_LLTV_ENABLED_SLOT: 5
- IS_AUTHORIZED_SLOT: 6
- NONCE_SLOT: 7
- ID_TO_MARKET_PARAMS_SLOT: 8

SLOT_OFFSETS:
- LOAN_TOKEN_OFFSET: 0
- COLLATERAL_TOKEN_OFFSET: 1
- ORACLE_OFFSET: 2
- IRM_OFFSET: 3
- LLTV_OFFSET: 4
- SUPPLY_SHARES_OFFSET: 0
- BORROW_SHARES_AND_COLLATERAL_OFFSET: 1
- TOTAL_SUPPLY_ASSETS_AND_SHARES_OFFSET: 0
- TOTAL_BORROW_ASSETS_AND_SHARES_OFFSET: 1
- LAST_UPDATE_AND_FEE_OFFSET: 2

FUNCTIONS:
- ownerSlot() internal pure returns (bytes32)
- feeRecipientSlot() internal pure returns (bytes32)
- positionSupplySharesSlot(Id id, address user) internal pure returns (bytes32)
- positionBorrowSharesAndCollateralSlot(Id id, address user) internal pure returns (bytes32)
- marketTotalSupplyAssetsAndSharesSlot(Id id) internal pure returns (bytes32)
- marketTotalBorrowAssetsAndSharesSlot(Id id) internal pure returns (bytes32)
- marketLastUpdateAndFeeSlot(Id id) internal pure returns (bytes32)
- isIrmEnabledSlot(address irm) internal pure returns (bytes32)
- isLltvEnabledSlot(uint256 lltv) internal pure returns (bytes32)
- isAuthorizedSlot(address authorizer, address authorizee) internal pure returns (bytes32)
- nonceSlot(address authorizer) internal pure returns (bytes32)
- idToLoanTokenSlot(Id id) internal pure returns (bytes32)
- idToCollateralTokenSlot(Id id) internal pure returns (bytes32)
- idToOracleSlot(Id id) internal pure returns (bytes32)
- idToIrmSlot(Id id) internal pure returns (bytes32)
- idToLltvSlot(Id id) internal pure returns (bytes32)

---

## FILE: src/mocks/OracleMock.sol

TYPE: Mock Contract
NAME: OracleMock
DESC: Mock oracle for testing that allows setting price manually.

IMPORTS:
- ../interfaces/IOracle.sol

INHERITS: IOracle

STATE:
- price (uint256): Settable price value

FUNCTIONS:
- setPrice(uint256 newPrice) external: Sets the mock price
- price() external view returns (uint256): Returns the set price (inherited from IOracle)

---

## FILE: src/mocks/IrmMock.sol

TYPE: Mock Contract
NAME: IrmMock
DESC: Mock IRM for testing. Simple model where x% utilization = x% APR.

IMPORTS:
- ../interfaces/IIrm.sol
- ../interfaces/IMorpho.sol (MarketParams, Market)
- ../libraries/MathLib.sol

INHERITS: IIrm

USES: MathLib for uint128

FUNCTIONS:
- borrowRateView(MarketParams memory, Market memory market) public pure returns (uint256): Returns utilization / 365 days. 0 if no supply.
- borrowRate(MarketParams memory marketParams, Market memory market) external pure returns (uint256): Calls borrowRateView

---

## FILE: src/mocks/ERC20Mock.sol

TYPE: Mock Contract
NAME: ERC20Mock
DESC: Mock ERC20 token for testing with setBalance function.

IMPORTS:
- ./interfaces/IERC20.sol

INHERITS: IERC20 (mock interface)

STATE:
- totalSupply (uint256)
- balanceOf (mapping(address => uint256))
- allowance (mapping(address => mapping(address => uint256)))

FUNCTIONS:
- setBalance(address account, uint256 amount) public virtual: Sets balance directly, adjusts totalSupply
- approve(address spender, uint256 amount) public virtual returns (bool)
- transfer(address to, uint256 amount) public virtual returns (bool)
- transferFrom(address from, address to, uint256 amount) public virtual returns (bool)

EVENTS:
- Transfer(address indexed from, address indexed to, uint256 value)
- Approval(address indexed owner, address indexed spender, uint256 value)

---

## FILE: src/mocks/FlashBorrowerMock.sol

TYPE: Mock Contract
NAME: FlashBorrowerMock
DESC: Mock flash loan borrower for testing.

IMPORTS:
- ./interfaces/IERC20.sol
- ../interfaces/IMorpho.sol
- ../interfaces/IMorphoCallbacks.sol

INHERITS: IMorphoFlashLoanCallback

IMMUTABLES:
- MORPHO (IMorpho private immutable)

CONSTRUCTOR:
- signature: constructor(IMorpho newMorpho)
- sets: MORPHO = newMorpho

FUNCTIONS:
- flashLoan(address token, uint256 assets, bytes calldata data) external: Calls MORPHO.flashLoan
- onMorphoFlashLoan(uint256 assets, bytes calldata data) external: Decodes token from data, approves Morpho to reclaim

---

## FILE: src/mocks/interfaces/IERC20.sol

TYPE: Interface (Mock)
NAME: IERC20
DESC: Full ERC20 interface for mock contracts.

EVENTS:
- Transfer(address indexed from, address indexed to, uint256 value)
- Approval(address indexed owner, address indexed spender, uint256 value)

FUNCTIONS:
- totalSupply() external view returns (uint256)
- balanceOf(address account) external view returns (uint256)
- transfer(address to, uint256 value) external returns (bool)
- allowance(address owner, address spender) external view returns (uint256)
- approve(address spender, uint256 value) external returns (bool)
- transferFrom(address from, address to, uint256 value) external returns (bool)

---

## SETUP: test/recon/Setup.sol

```solidity
function setup() internal virtual override {
    morpho = new Morpho(); // TODO: Add parameters here
}
```

DEPLOYMENT_PATTERN:
1. Deploy Morpho contract with owner address
2. (Missing in test setup) Enable IRMs via enableIrm()
3. (Missing in test setup) Enable LLTVs via enableLltv()
4. (Missing in test setup) Create markets via createMarket()
5. (Missing in test setup) Set fee recipient via setFeeRecipient()
6. (Missing in test setup) Set market fees via setFee()

ACTORS:
- Admin: address(this) in test context
- Actor: Managed via ActorManager

MODIFIERS:
- asAdmin: Pranks as address(this)
- asActor: Pranks as _getActor()

---

## README

The repository is an AI-Powered Protocol Knowledge Base Generator. It analyzes Solidity codebases and produces structured documentation for security auditors and developers.

The actual protocol being analyzed is Morpho Blue - a minimal, immutable lending primitive that enables efficient and trust-minimized markets for any pair of ERC20 tokens.

KEY_FEATURES:
1. Isolated Markets - Each market is independent with no cross-collateralization
2. Permissionless Market Creation - Anyone can create markets using whitelisted IRMs and LLTVs
3. Singleton Contract - All markets managed by single Morpho contract
4. Share-based Accounting - Uses virtual shares (1e6) and virtual assets (1) to prevent inflation attacks
5. CEI Pattern - All state updates before external calls for reentrancy safety
6. EIP-712 Signatures - Supports gasless authorization via signatures
7. Flash Loans - Free flash loans with access to all contract tokens
8. Bad Debt Socialization - Underwater positions' bad debt is shared among suppliers
9. Liquidation Incentives - Dynamic incentive factor based on LLTV (up to 15% max)

TRUST_ASSUMPTIONS:
1. Owner - Can enable (not disable) IRMs and LLTVs, set fees up to 25%, set fee recipient
2. IRM - Must not revert on borrowRate, must not return extreme rates
3. Oracle - Must return correct price scaled by 1e36, must not be manipulable
4. Tokens - Must be ERC-20 compliant (can omit return values), no fee-on-transfer, no rebasing

---

## RUNTIME_EXTERNAL_CALLS

1. IIrm(marketParams.irm).borrowRate(marketParams, market[id])
   - Called in: createMarket, _accrueInterest
   - Purpose: Get current borrow rate for interest calculation
   - Risk: Malicious IRM could return extreme rates or revert to block operations

2. IOracle(marketParams.oracle).price()
   - Called in: _isHealthy, liquidate
   - Purpose: Get collateral price for health checks
   - Risk: Oracle manipulation could enable unfair liquidations or block legitimate operations

3. IERC20(token).safeTransfer(to, amount)
   - Called in: withdraw, borrow, withdrawCollateral, liquidate, flashLoan
   - Purpose: Transfer tokens to users
   - Risk: Token reentrancy (mitigated by CEI pattern)

4. IERC20(token).safeTransferFrom(from, to, amount)
   - Called in: supply, repay, supplyCollateral, liquidate, flashLoan
   - Purpose: Pull tokens from users
   - Risk: Token reentrancy (mitigated by CEI pattern)

5. Callback interfaces (IMorphoSupplyCallback, IMorphoRepayCallback, etc.)
   - Called in: supply, repay, supplyCollateral, liquidate, flashLoan
   - Purpose: Allow users to source funds during operations
   - Risk: Callback reentrancy (mitigated by CEI pattern - state already updated)

---

## KEY_INVARIANTS

1. totalBorrowAssets <= totalSupplyAssets (liquidity constraint)
2. For each position: collateral * price * lltv >= borrowed (health invariant)
3. Sum of all position.supplyShares == market.totalSupplyShares
4. Sum of all position.borrowShares == market.totalBorrowShares
5. LLTV < WAD (100%) for all markets
6. Fee <= MAX_FEE (25%) for all markets
7. Virtual shares (1e6) and virtual assets (1) prevent share manipulation
8. Nonces strictly increment (no replay attacks)
9. Domain separator is chain-specific (no cross-chain replay)

---

## ROUNDING_DIRECTIONS

Supply:
- assets -> shares: DOWN (user gets fewer shares)
- shares -> assets: UP (user pays more assets)

Withdraw:
- assets -> shares: UP (user burns more shares)
- shares -> assets: DOWN (user gets fewer assets)

Borrow:
- assets -> shares: UP (borrower owes more shares)
- shares -> assets: DOWN (borrower gets fewer assets)

Repay:
- assets -> shares: DOWN (borrower repays fewer shares - slightly borrower favored)
- shares -> assets: UP (borrower pays more assets)

Liquidation:
- All rounding favors protocol/liquidator
- seizedAssetsQuoted: UP
- repaidShares: UP
- seizedAssets: DOWN

Health Check:
- borrowed: UP (stricter check)
- maxBorrow: DOWN (stricter check)

---
