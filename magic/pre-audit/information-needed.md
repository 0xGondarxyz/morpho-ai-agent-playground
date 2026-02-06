---
META
project_type: Foundry
source_dir: src/
test_dir: test/
excluded_dirs: lib/, node_modules/
---

FILE: src/Morpho.sol
TYPE: contract
NAME: Morpho
DESC: The Morpho contract.
IMPORTS:
- ./interfaces/IMorpho.sol (Id, IMorphoStaticTyping, IMorphoBase, MarketParams, Position, Market, Authorization, Signature)
- ./interfaces/IMorphoCallbacks.sol (IMorphoLiquidateCallback, IMorphoRepayCallback, IMorphoSupplyCallback, IMorphoSupplyCollateralCallback, IMorphoFlashLoanCallback)
- ./interfaces/IIrm.sol (IIrm)
- ./interfaces/IERC20.sol (IERC20)
- ./interfaces/IOracle.sol (IOracle)
- ./libraries/ConstantsLib.sol (wildcard)
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
CONSTRUCTOR: (address newOwner)
IMMUTABLES:
- DOMAIN_SEPARATOR: bytes32
MODIFIERS:
- onlyOwner: require(msg.sender == owner, ErrorsLib.NOT_OWNER)
STATE:
- owner: address
- feeRecipient: address
- position: mapping(Id => mapping(address => Position))
- market: mapping(Id => Market)
- isIrmEnabled: mapping(address => bool)
- isLltvEnabled: mapping(uint256 => bool)
- isAuthorized: mapping(address => mapping(address => bool))
- nonce: mapping(address => uint256)
- idToMarketParams: mapping(Id => MarketParams)
EXTERNAL_CALLS:
- [typed] IIrm(marketParams.irm).borrowRate(marketParams, market[id])
- [typed] IOracle(marketParams.oracle).price()
- [typed] IMorphoSupplyCallback(msg.sender).onMorphoSupply(assets, data)
- [typed] IMorphoRepayCallback(msg.sender).onMorphoRepay(assets, data)
- [typed] IMorphoSupplyCollateralCallback(msg.sender).onMorphoSupplyCollateral(assets, data)
- [typed] IMorphoLiquidateCallback(msg.sender).onMorphoLiquidate(repaidAssets, data)
- [typed] IMorphoFlashLoanCallback(msg.sender).onMorphoFlashLoan(assets, data)
- [low-level] address(token).call(abi.encodeCall(IERC20Internal.transfer, ...)) (via SafeTransferLib)
- [low-level] address(token).call(abi.encodeCall(IERC20Internal.transferFrom, ...)) (via SafeTransferLib)

FUNC: constructor
SIG: constructor(address newOwner)
VISIBILITY: public
MODIFIERS: none
NATSPEC: @param newOwner The new owner of the contract.
REQUIRES:
- require(newOwner != address(0), ErrorsLib.ZERO_ADDRESS)
READS: [none]
WRITES: DOMAIN_SEPARATOR, owner
EVENTS: EventsLib.SetOwner(newOwner)
INTERNAL_CALLS: [none]
EXTERNAL_CALLS: [none]
---

FUNC: setOwner
SIG: function setOwner(address newOwner) external onlyOwner
VISIBILITY: external
MODIFIERS: onlyOwner
NATSPEC: @notice Sets `newOwner` as `owner` of the contract.
REQUIRES:
- require(msg.sender == owner, ErrorsLib.NOT_OWNER) (via onlyOwner)
- require(newOwner != owner, ErrorsLib.ALREADY_SET)
READS: owner
WRITES: owner
EVENTS: EventsLib.SetOwner(newOwner)
INTERNAL_CALLS: [none]
EXTERNAL_CALLS: [none]
---

FUNC: enableIrm
SIG: function enableIrm(address irm) external onlyOwner
VISIBILITY: external
MODIFIERS: onlyOwner
NATSPEC: @notice Enables `irm` as a possible IRM for market creation.
REQUIRES:
- require(msg.sender == owner, ErrorsLib.NOT_OWNER) (via onlyOwner)
- require(!isIrmEnabled[irm], ErrorsLib.ALREADY_SET)
READS: isIrmEnabled
WRITES: isIrmEnabled[irm]
EVENTS: EventsLib.EnableIrm(irm)
INTERNAL_CALLS: [none]
EXTERNAL_CALLS: [none]
---

FUNC: enableLltv
SIG: function enableLltv(uint256 lltv) external onlyOwner
VISIBILITY: external
MODIFIERS: onlyOwner
NATSPEC: @notice Enables `lltv` as a possible LLTV for market creation.
REQUIRES:
- require(msg.sender == owner, ErrorsLib.NOT_OWNER) (via onlyOwner)
- require(!isLltvEnabled[lltv], ErrorsLib.ALREADY_SET)
- require(lltv < WAD, ErrorsLib.MAX_LLTV_EXCEEDED)
READS: isLltvEnabled
WRITES: isLltvEnabled[lltv]
EVENTS: EventsLib.EnableLltv(lltv)
INTERNAL_CALLS: [none]
EXTERNAL_CALLS: [none]
---

FUNC: setFee
SIG: function setFee(MarketParams memory marketParams, uint256 newFee) external onlyOwner
VISIBILITY: external
MODIFIERS: onlyOwner
NATSPEC: @notice Sets the `newFee` for the given market `marketParams`.
REQUIRES:
- require(msg.sender == owner, ErrorsLib.NOT_OWNER) (via onlyOwner)
- require(market[id].lastUpdate != 0, ErrorsLib.MARKET_NOT_CREATED)
- require(newFee != market[id].fee, ErrorsLib.ALREADY_SET)
- require(newFee <= MAX_FEE, ErrorsLib.MAX_FEE_EXCEEDED)
READS: market[id].lastUpdate, market[id].fee, market[id].totalBorrowAssets, market[id].totalSupplyAssets, market[id].totalSupplyShares, market[id].totalBorrowShares
WRITES: market[id].fee, market[id].totalBorrowAssets, market[id].totalSupplyAssets, market[id].totalSupplyShares, market[id].lastUpdate, position[id][feeRecipient].supplyShares
EVENTS: EventsLib.SetFee(id, newFee), EventsLib.AccrueInterest(id, borrowRate, interest, feeShares)
INTERNAL_CALLS: _accrueInterest(marketParams, id)
EXTERNAL_CALLS:
- [typed] IIrm(marketParams.irm).borrowRate(marketParams, market[id]) (via _accrueInterest)
---

FUNC: setFeeRecipient
SIG: function setFeeRecipient(address newFeeRecipient) external onlyOwner
VISIBILITY: external
MODIFIERS: onlyOwner
NATSPEC: @notice Sets `newFeeRecipient` as `feeRecipient` of the fee.
REQUIRES:
- require(msg.sender == owner, ErrorsLib.NOT_OWNER) (via onlyOwner)
- require(newFeeRecipient != feeRecipient, ErrorsLib.ALREADY_SET)
READS: feeRecipient
WRITES: feeRecipient
EVENTS: EventsLib.SetFeeRecipient(newFeeRecipient)
INTERNAL_CALLS: [none]
EXTERNAL_CALLS: [none]
---

FUNC: createMarket
SIG: function createMarket(MarketParams memory marketParams) external
VISIBILITY: external
MODIFIERS: none
NATSPEC: @notice Creates the market `marketParams`.
REQUIRES:
- require(isIrmEnabled[marketParams.irm], ErrorsLib.IRM_NOT_ENABLED)
- require(isLltvEnabled[marketParams.lltv], ErrorsLib.LLTV_NOT_ENABLED)
- require(market[id].lastUpdate == 0, ErrorsLib.MARKET_ALREADY_CREATED)
READS: isIrmEnabled, isLltvEnabled, market[id].lastUpdate
WRITES: market[id].lastUpdate, idToMarketParams[id]
EVENTS: EventsLib.CreateMarket(id, marketParams)
INTERNAL_CALLS: [none]
EXTERNAL_CALLS:
- [typed] IIrm(marketParams.irm).borrowRate(marketParams, market[id]) (conditional: if irm != address(0))
---

FUNC: supply
SIG: function supply(MarketParams memory marketParams, uint256 assets, uint256 shares, address onBehalf, bytes calldata data) external returns (uint256, uint256)
VISIBILITY: external
MODIFIERS: none
NATSPEC: @notice Supplies `assets` or `shares` on behalf of `onBehalf`, optionally calling back the caller's `onMorphoSupply` function with the given `data`.
REQUIRES:
- require(market[id].lastUpdate != 0, ErrorsLib.MARKET_NOT_CREATED)
- require(UtilsLib.exactlyOneZero(assets, shares), ErrorsLib.INCONSISTENT_INPUT)
- require(onBehalf != address(0), ErrorsLib.ZERO_ADDRESS)
READS: market[id].lastUpdate, market[id].totalSupplyAssets, market[id].totalSupplyShares, market[id].totalBorrowAssets, market[id].totalBorrowShares, market[id].fee, feeRecipient
WRITES: position[id][onBehalf].supplyShares, market[id].totalSupplyShares, market[id].totalSupplyAssets, market[id].totalBorrowAssets, market[id].lastUpdate, position[id][feeRecipient].supplyShares
EVENTS: EventsLib.Supply(id, msg.sender, onBehalf, assets, shares), EventsLib.AccrueInterest(id, borrowRate, interest, feeShares)
INTERNAL_CALLS: _accrueInterest(marketParams, id)
EXTERNAL_CALLS:
- [typed] IIrm(marketParams.irm).borrowRate(marketParams, market[id]) (via _accrueInterest)
- [typed] IMorphoSupplyCallback(msg.sender).onMorphoSupply(assets, data) (conditional: if data.length > 0)
- [low-level] IERC20(marketParams.loanToken).safeTransferFrom(msg.sender, address(this), assets) (via SafeTransferLib)
---

FUNC: withdraw
SIG: function withdraw(MarketParams memory marketParams, uint256 assets, uint256 shares, address onBehalf, address receiver) external returns (uint256, uint256)
VISIBILITY: external
MODIFIERS: none
NATSPEC: @notice Withdraws `assets` or `shares` on behalf of `onBehalf` and sends the assets to `receiver`.
REQUIRES:
- require(market[id].lastUpdate != 0, ErrorsLib.MARKET_NOT_CREATED)
- require(UtilsLib.exactlyOneZero(assets, shares), ErrorsLib.INCONSISTENT_INPUT)
- require(receiver != address(0), ErrorsLib.ZERO_ADDRESS)
- require(_isSenderAuthorized(onBehalf), ErrorsLib.UNAUTHORIZED)
- require(market[id].totalBorrowAssets <= market[id].totalSupplyAssets, ErrorsLib.INSUFFICIENT_LIQUIDITY)
READS: market[id].lastUpdate, market[id].totalSupplyAssets, market[id].totalSupplyShares, market[id].totalBorrowAssets, market[id].totalBorrowShares, market[id].fee, position[id][onBehalf].supplyShares, isAuthorized[onBehalf][msg.sender], feeRecipient
WRITES: position[id][onBehalf].supplyShares, market[id].totalSupplyShares, market[id].totalSupplyAssets, market[id].totalBorrowAssets, market[id].lastUpdate, position[id][feeRecipient].supplyShares
EVENTS: EventsLib.Withdraw(id, msg.sender, onBehalf, receiver, assets, shares), EventsLib.AccrueInterest(id, borrowRate, interest, feeShares)
INTERNAL_CALLS: _accrueInterest(marketParams, id), _isSenderAuthorized(onBehalf)
EXTERNAL_CALLS:
- [typed] IIrm(marketParams.irm).borrowRate(marketParams, market[id]) (via _accrueInterest)
- [low-level] IERC20(marketParams.loanToken).safeTransfer(receiver, assets) (via SafeTransferLib)
---

FUNC: borrow
SIG: function borrow(MarketParams memory marketParams, uint256 assets, uint256 shares, address onBehalf, address receiver) external returns (uint256, uint256)
VISIBILITY: external
MODIFIERS: none
NATSPEC: @notice Borrows `assets` or `shares` on behalf of `onBehalf` and sends the assets to `receiver`.
REQUIRES:
- require(market[id].lastUpdate != 0, ErrorsLib.MARKET_NOT_CREATED)
- require(UtilsLib.exactlyOneZero(assets, shares), ErrorsLib.INCONSISTENT_INPUT)
- require(receiver != address(0), ErrorsLib.ZERO_ADDRESS)
- require(_isSenderAuthorized(onBehalf), ErrorsLib.UNAUTHORIZED)
- require(_isHealthy(marketParams, id, onBehalf), ErrorsLib.INSUFFICIENT_COLLATERAL)
- require(market[id].totalBorrowAssets <= market[id].totalSupplyAssets, ErrorsLib.INSUFFICIENT_LIQUIDITY)
READS: market[id].lastUpdate, market[id].totalBorrowAssets, market[id].totalBorrowShares, market[id].totalSupplyAssets, market[id].totalSupplyShares, market[id].fee, position[id][onBehalf].borrowShares, position[id][onBehalf].collateral, isAuthorized[onBehalf][msg.sender], feeRecipient
WRITES: position[id][onBehalf].borrowShares, market[id].totalBorrowShares, market[id].totalBorrowAssets, market[id].totalSupplyAssets, market[id].totalSupplyShares, market[id].lastUpdate, position[id][feeRecipient].supplyShares
EVENTS: EventsLib.Borrow(id, msg.sender, onBehalf, receiver, assets, shares), EventsLib.AccrueInterest(id, borrowRate, interest, feeShares)
INTERNAL_CALLS: _accrueInterest(marketParams, id), _isSenderAuthorized(onBehalf), _isHealthy(marketParams, id, onBehalf)
EXTERNAL_CALLS:
- [typed] IIrm(marketParams.irm).borrowRate(marketParams, market[id]) (via _accrueInterest)
- [typed] IOracle(marketParams.oracle).price() (via _isHealthy)
- [low-level] IERC20(marketParams.loanToken).safeTransfer(receiver, assets) (via SafeTransferLib)
---

FUNC: repay
SIG: function repay(MarketParams memory marketParams, uint256 assets, uint256 shares, address onBehalf, bytes calldata data) external returns (uint256, uint256)
VISIBILITY: external
MODIFIERS: none
NATSPEC: @notice Repays `assets` or `shares` on behalf of `onBehalf`, optionally calling back the caller's `onMorphoRepay` function with the given `data`.
REQUIRES:
- require(market[id].lastUpdate != 0, ErrorsLib.MARKET_NOT_CREATED)
- require(UtilsLib.exactlyOneZero(assets, shares), ErrorsLib.INCONSISTENT_INPUT)
- require(onBehalf != address(0), ErrorsLib.ZERO_ADDRESS)
READS: market[id].lastUpdate, market[id].totalBorrowAssets, market[id].totalBorrowShares, market[id].totalSupplyAssets, market[id].totalSupplyShares, market[id].fee, position[id][onBehalf].borrowShares, feeRecipient
WRITES: position[id][onBehalf].borrowShares, market[id].totalBorrowShares, market[id].totalBorrowAssets, market[id].totalSupplyAssets, market[id].totalSupplyShares, market[id].lastUpdate, position[id][feeRecipient].supplyShares
EVENTS: EventsLib.Repay(id, msg.sender, onBehalf, assets, shares), EventsLib.AccrueInterest(id, borrowRate, interest, feeShares)
INTERNAL_CALLS: _accrueInterest(marketParams, id)
EXTERNAL_CALLS:
- [typed] IIrm(marketParams.irm).borrowRate(marketParams, market[id]) (via _accrueInterest)
- [typed] IMorphoRepayCallback(msg.sender).onMorphoRepay(assets, data) (conditional: if data.length > 0)
- [low-level] IERC20(marketParams.loanToken).safeTransferFrom(msg.sender, address(this), assets) (via SafeTransferLib)
---

FUNC: supplyCollateral
SIG: function supplyCollateral(MarketParams memory marketParams, uint256 assets, address onBehalf, bytes calldata data) external
VISIBILITY: external
MODIFIERS: none
NATSPEC: @notice Supplies `assets` of collateral on behalf of `onBehalf`, optionally calling back the caller's `onMorphoSupplyCollateral` function with the given `data`.
REQUIRES:
- require(market[id].lastUpdate != 0, ErrorsLib.MARKET_NOT_CREATED)
- require(assets != 0, ErrorsLib.ZERO_ASSETS)
- require(onBehalf != address(0), ErrorsLib.ZERO_ADDRESS)
READS: market[id].lastUpdate
WRITES: position[id][onBehalf].collateral
EVENTS: EventsLib.SupplyCollateral(id, msg.sender, onBehalf, assets)
INTERNAL_CALLS: [none]
EXTERNAL_CALLS:
- [typed] IMorphoSupplyCollateralCallback(msg.sender).onMorphoSupplyCollateral(assets, data) (conditional: if data.length > 0)
- [low-level] IERC20(marketParams.collateralToken).safeTransferFrom(msg.sender, address(this), assets) (via SafeTransferLib)
---

FUNC: withdrawCollateral
SIG: function withdrawCollateral(MarketParams memory marketParams, uint256 assets, address onBehalf, address receiver) external
VISIBILITY: external
MODIFIERS: none
NATSPEC: @notice Withdraws `assets` of collateral on behalf of `onBehalf` and sends the assets to `receiver`.
REQUIRES:
- require(market[id].lastUpdate != 0, ErrorsLib.MARKET_NOT_CREATED)
- require(assets != 0, ErrorsLib.ZERO_ASSETS)
- require(receiver != address(0), ErrorsLib.ZERO_ADDRESS)
- require(_isSenderAuthorized(onBehalf), ErrorsLib.UNAUTHORIZED)
- require(_isHealthy(marketParams, id, onBehalf), ErrorsLib.INSUFFICIENT_COLLATERAL)
READS: market[id].lastUpdate, market[id].totalBorrowAssets, market[id].totalBorrowShares, market[id].totalSupplyAssets, market[id].totalSupplyShares, market[id].fee, position[id][onBehalf].collateral, position[id][onBehalf].borrowShares, isAuthorized[onBehalf][msg.sender], feeRecipient
WRITES: position[id][onBehalf].collateral, market[id].totalBorrowAssets, market[id].totalSupplyAssets, market[id].totalSupplyShares, market[id].lastUpdate, position[id][feeRecipient].supplyShares
EVENTS: EventsLib.WithdrawCollateral(id, msg.sender, onBehalf, receiver, assets), EventsLib.AccrueInterest(id, borrowRate, interest, feeShares)
INTERNAL_CALLS: _accrueInterest(marketParams, id), _isSenderAuthorized(onBehalf), _isHealthy(marketParams, id, onBehalf)
EXTERNAL_CALLS:
- [typed] IIrm(marketParams.irm).borrowRate(marketParams, market[id]) (via _accrueInterest)
- [typed] IOracle(marketParams.oracle).price() (via _isHealthy)
- [low-level] IERC20(marketParams.collateralToken).safeTransfer(receiver, assets) (via SafeTransferLib)
---

FUNC: liquidate
SIG: function liquidate(MarketParams memory marketParams, address borrower, uint256 seizedAssets, uint256 repaidShares, bytes calldata data) external returns (uint256, uint256)
VISIBILITY: external
MODIFIERS: none
NATSPEC: @notice Liquidates the given `repaidShares` of debt asset or seize the given `seizedAssets` of collateral on the given market `marketParams` of the given `borrower`'s position.
REQUIRES:
- require(market[id].lastUpdate != 0, ErrorsLib.MARKET_NOT_CREATED)
- require(UtilsLib.exactlyOneZero(seizedAssets, repaidShares), ErrorsLib.INCONSISTENT_INPUT)
- require(!_isHealthy(marketParams, id, borrower, collateralPrice), ErrorsLib.HEALTHY_POSITION)
READS: market[id].lastUpdate, market[id].totalBorrowAssets, market[id].totalBorrowShares, market[id].totalSupplyAssets, market[id].totalSupplyShares, market[id].fee, position[id][borrower].borrowShares, position[id][borrower].collateral, feeRecipient
WRITES: position[id][borrower].borrowShares, market[id].totalBorrowShares, market[id].totalBorrowAssets, position[id][borrower].collateral, market[id].totalSupplyAssets, market[id].totalSupplyShares, market[id].lastUpdate, position[id][feeRecipient].supplyShares
EVENTS: EventsLib.Liquidate(id, msg.sender, borrower, repaidAssets, repaidShares, seizedAssets, badDebtAssets, badDebtShares), EventsLib.AccrueInterest(id, borrowRate, interest, feeShares)
INTERNAL_CALLS: _accrueInterest(marketParams, id), _isHealthy(marketParams, id, borrower, collateralPrice)
EXTERNAL_CALLS:
- [typed] IIrm(marketParams.irm).borrowRate(marketParams, market[id]) (via _accrueInterest)
- [typed] IOracle(marketParams.oracle).price()
- [typed] IMorphoLiquidateCallback(msg.sender).onMorphoLiquidate(repaidAssets, data) (conditional: if data.length > 0)
- [low-level] IERC20(marketParams.collateralToken).safeTransfer(msg.sender, seizedAssets) (via SafeTransferLib)
- [low-level] IERC20(marketParams.loanToken).safeTransferFrom(msg.sender, address(this), repaidAssets) (via SafeTransferLib)
---

FUNC: flashLoan
SIG: function flashLoan(address token, uint256 assets, bytes calldata data) external
VISIBILITY: external
MODIFIERS: none
NATSPEC: @notice Executes a flash loan.
REQUIRES:
- require(assets != 0, ErrorsLib.ZERO_ASSETS)
READS: [none]
WRITES: [none]
EVENTS: EventsLib.FlashLoan(msg.sender, token, assets)
INTERNAL_CALLS: [none]
EXTERNAL_CALLS:
- [low-level] IERC20(token).safeTransfer(msg.sender, assets) (via SafeTransferLib)
- [typed] IMorphoFlashLoanCallback(msg.sender).onMorphoFlashLoan(assets, data)
- [low-level] IERC20(token).safeTransferFrom(msg.sender, address(this), assets) (via SafeTransferLib)
---

FUNC: setAuthorization
SIG: function setAuthorization(address authorized, bool newIsAuthorized) external
VISIBILITY: external
MODIFIERS: none
NATSPEC: @notice Sets the authorization for `authorized` to manage `msg.sender`'s positions.
REQUIRES:
- require(newIsAuthorized != isAuthorized[msg.sender][authorized], ErrorsLib.ALREADY_SET)
READS: isAuthorized[msg.sender][authorized]
WRITES: isAuthorized[msg.sender][authorized]
EVENTS: EventsLib.SetAuthorization(msg.sender, msg.sender, authorized, newIsAuthorized)
INTERNAL_CALLS: [none]
EXTERNAL_CALLS: [none]
---

FUNC: setAuthorizationWithSig
SIG: function setAuthorizationWithSig(Authorization memory authorization, Signature calldata signature) external
VISIBILITY: external
MODIFIERS: none
NATSPEC: @notice Sets the authorization for `authorization.authorized` to manage `authorization.authorizer`'s positions.
REQUIRES:
- require(block.timestamp <= authorization.deadline, ErrorsLib.SIGNATURE_EXPIRED)
- require(authorization.nonce == nonce[authorization.authorizer]++, ErrorsLib.INVALID_NONCE)
- require(signatory != address(0) && authorization.authorizer == signatory, ErrorsLib.INVALID_SIGNATURE)
READS: nonce[authorization.authorizer], DOMAIN_SEPARATOR
WRITES: nonce[authorization.authorizer], isAuthorized[authorization.authorizer][authorization.authorized]
EVENTS: EventsLib.IncrementNonce(msg.sender, authorization.authorizer, authorization.nonce), EventsLib.SetAuthorization(msg.sender, authorization.authorizer, authorization.authorized, authorization.isAuthorized)
INTERNAL_CALLS: [none]
EXTERNAL_CALLS: [none]
---

FUNC: accrueInterest
SIG: function accrueInterest(MarketParams memory marketParams) external
VISIBILITY: external
MODIFIERS: none
NATSPEC: @notice Accrues interest for the given market `marketParams`.
REQUIRES:
- require(market[id].lastUpdate != 0, ErrorsLib.MARKET_NOT_CREATED)
READS: market[id].lastUpdate, market[id].totalBorrowAssets, market[id].totalSupplyAssets, market[id].totalSupplyShares, market[id].totalBorrowShares, market[id].fee, feeRecipient
WRITES: market[id].totalBorrowAssets, market[id].totalSupplyAssets, market[id].totalSupplyShares, market[id].lastUpdate, position[id][feeRecipient].supplyShares
EVENTS: EventsLib.AccrueInterest(id, borrowRate, interest, feeShares)
INTERNAL_CALLS: _accrueInterest(marketParams, id)
EXTERNAL_CALLS:
- [typed] IIrm(marketParams.irm).borrowRate(marketParams, market[id]) (via _accrueInterest)
---

FUNC: _accrueInterest
SIG: function _accrueInterest(MarketParams memory marketParams, Id id) internal
VISIBILITY: internal
MODIFIERS: none
NATSPEC: @dev Accrues interest for the given market `marketParams`. Assumes that the inputs `marketParams` and `id` match.
REQUIRES: [none]
READS: market[id].lastUpdate, market[id].totalBorrowAssets, market[id].totalSupplyAssets, market[id].totalSupplyShares, market[id].fee, feeRecipient
WRITES: market[id].totalBorrowAssets, market[id].totalSupplyAssets, market[id].totalSupplyShares, market[id].lastUpdate, position[id][feeRecipient].supplyShares
EVENTS: EventsLib.AccrueInterest(id, borrowRate, interest, feeShares)
INTERNAL_CALLS: [none]
EXTERNAL_CALLS:
- [typed] IIrm(marketParams.irm).borrowRate(marketParams, market[id]) (conditional: if irm != address(0) && elapsed != 0)
---

FUNC: _isSenderAuthorized
SIG: function _isSenderAuthorized(address onBehalf) internal view returns (bool)
VISIBILITY: internal
MODIFIERS: none
NATSPEC: @dev Returns whether the sender is authorized to manage `onBehalf`'s positions.
REQUIRES: [none]
READS: isAuthorized[onBehalf][msg.sender]
WRITES: [none]
EVENTS: [none]
INTERNAL_CALLS: [none]
EXTERNAL_CALLS: [none]
---

FUNC: _isHealthy (3-param)
SIG: function _isHealthy(MarketParams memory marketParams, Id id, address borrower) internal view returns (bool)
VISIBILITY: internal
MODIFIERS: none
NATSPEC: @dev Returns whether the position of `borrower` in the given market `marketParams` is healthy. Assumes that the inputs `marketParams` and `id` match.
REQUIRES: [none]
READS: position[id][borrower].borrowShares, market[id].totalBorrowAssets, market[id].totalBorrowShares, position[id][borrower].collateral
WRITES: [none]
EVENTS: [none]
INTERNAL_CALLS: _isHealthy(marketParams, id, borrower, collateralPrice)
EXTERNAL_CALLS:
- [typed] IOracle(marketParams.oracle).price() (conditional: if borrowShares != 0)
---

FUNC: _isHealthy (4-param)
SIG: function _isHealthy(MarketParams memory marketParams, Id id, address borrower, uint256 collateralPrice) internal view returns (bool)
VISIBILITY: internal
MODIFIERS: none
NATSPEC: @dev Returns whether the position of `borrower` in the given market `marketParams` with the given `collateralPrice` is healthy. Rounds in favor of the protocol.
REQUIRES: [none]
READS: position[id][borrower].borrowShares, market[id].totalBorrowAssets, market[id].totalBorrowShares, position[id][borrower].collateral
WRITES: [none]
EVENTS: [none]
INTERNAL_CALLS: [none]
EXTERNAL_CALLS: [none]
---

FUNC: extSloads
SIG: function extSloads(bytes32[] calldata slots) external view returns (bytes32[] memory res)
VISIBILITY: external
MODIFIERS: none
NATSPEC: @notice Returns the data stored on the different `slots`.
REQUIRES: [none]
READS: arbitrary storage slots (via sload assembly)
WRITES: [none]
EVENTS: [none]
INTERNAL_CALLS: [none]
EXTERNAL_CALLS: [none]
---

FILE: src/interfaces/IMorpho.sol
TYPE: interface
NAME: IMorphoBase, IMorphoStaticTyping, IMorpho
DESC: Main interface with type definitions. IMorphoBase defines core functions. IMorphoStaticTyping adds static return types. IMorpho adds struct return types.
IMPORTS: [none]
INHERITS:
- IMorphoStaticTyping is IMorphoBase
- IMorpho is IMorphoBase
USES: [none]
CONSTRUCTOR: [none]
IMMUTABLES: [none]
MODIFIERS: [none]
STATE: [none]
TYPES:
- type Id is bytes32
- struct MarketParams { address loanToken; address collateralToken; address oracle; address irm; uint256 lltv; }
- struct Position { uint256 supplyShares; uint128 borrowShares; uint128 collateral; }
- struct Market { uint128 totalSupplyAssets; uint128 totalSupplyShares; uint128 totalBorrowAssets; uint128 totalBorrowShares; uint128 lastUpdate; uint128 fee; }
- struct Authorization { address authorizer; address authorized; bool isAuthorized; uint256 nonce; uint256 deadline; }
- struct Signature { uint8 v; bytes32 r; bytes32 s; }

FUNC: DOMAIN_SEPARATOR
SIG: function DOMAIN_SEPARATOR() external view returns (bytes32)
VISIBILITY: external
MODIFIERS: none
NATSPEC: @notice The EIP-712 domain separator.
---

FUNC: owner
SIG: function owner() external view returns (address)
VISIBILITY: external
MODIFIERS: none
NATSPEC: @notice The owner of the contract.
---

FUNC: feeRecipient
SIG: function feeRecipient() external view returns (address)
VISIBILITY: external
MODIFIERS: none
NATSPEC: @notice The fee recipient of all markets.
---

FUNC: isIrmEnabled
SIG: function isIrmEnabled(address irm) external view returns (bool)
VISIBILITY: external
MODIFIERS: none
NATSPEC: @notice Whether the `irm` is enabled.
---

FUNC: isLltvEnabled
SIG: function isLltvEnabled(uint256 lltv) external view returns (bool)
VISIBILITY: external
MODIFIERS: none
NATSPEC: @notice Whether the `lltv` is enabled.
---

FUNC: isAuthorized
SIG: function isAuthorized(address authorizer, address authorized) external view returns (bool)
VISIBILITY: external
MODIFIERS: none
NATSPEC: @notice Whether `authorized` is authorized to modify `authorizer`'s position on all markets.
---

FUNC: nonce
SIG: function nonce(address authorizer) external view returns (uint256)
VISIBILITY: external
MODIFIERS: none
NATSPEC: @notice The `authorizer`'s current nonce.
---

FUNC: setOwner (IMorphoBase)
SIG: function setOwner(address newOwner) external
VISIBILITY: external
MODIFIERS: none
NATSPEC: @notice Sets `newOwner` as `owner` of the contract.
---

FUNC: enableIrm (IMorphoBase)
SIG: function enableIrm(address irm) external
VISIBILITY: external
MODIFIERS: none
NATSPEC: @notice Enables `irm` as a possible IRM for market creation.
---

FUNC: enableLltv (IMorphoBase)
SIG: function enableLltv(uint256 lltv) external
VISIBILITY: external
MODIFIERS: none
NATSPEC: @notice Enables `lltv` as a possible LLTV for market creation.
---

FUNC: setFee (IMorphoBase)
SIG: function setFee(MarketParams memory marketParams, uint256 newFee) external
VISIBILITY: external
MODIFIERS: none
NATSPEC: @notice Sets the `newFee` for the given market `marketParams`.
---

FUNC: setFeeRecipient (IMorphoBase)
SIG: function setFeeRecipient(address newFeeRecipient) external
VISIBILITY: external
MODIFIERS: none
NATSPEC: @notice Sets `newFeeRecipient` as `feeRecipient` of the fee.
---

FUNC: createMarket (IMorphoBase)
SIG: function createMarket(MarketParams memory marketParams) external
VISIBILITY: external
MODIFIERS: none
NATSPEC: @notice Creates the market `marketParams`.
---

FUNC: supply (IMorphoBase)
SIG: function supply(MarketParams memory marketParams, uint256 assets, uint256 shares, address onBehalf, bytes memory data) external returns (uint256 assetsSupplied, uint256 sharesSupplied)
VISIBILITY: external
MODIFIERS: none
NATSPEC: @notice Supplies `assets` or `shares` on behalf of `onBehalf`.
---

FUNC: withdraw (IMorphoBase)
SIG: function withdraw(MarketParams memory marketParams, uint256 assets, uint256 shares, address onBehalf, address receiver) external returns (uint256 assetsWithdrawn, uint256 sharesWithdrawn)
VISIBILITY: external
MODIFIERS: none
NATSPEC: @notice Withdraws `assets` or `shares` on behalf of `onBehalf` and sends the assets to `receiver`.
---

FUNC: borrow (IMorphoBase)
SIG: function borrow(MarketParams memory marketParams, uint256 assets, uint256 shares, address onBehalf, address receiver) external returns (uint256 assetsBorrowed, uint256 sharesBorrowed)
VISIBILITY: external
MODIFIERS: none
NATSPEC: @notice Borrows `assets` or `shares` on behalf of `onBehalf` and sends the assets to `receiver`.
---

FUNC: repay (IMorphoBase)
SIG: function repay(MarketParams memory marketParams, uint256 assets, uint256 shares, address onBehalf, bytes memory data) external returns (uint256 assetsRepaid, uint256 sharesRepaid)
VISIBILITY: external
MODIFIERS: none
NATSPEC: @notice Repays `assets` or `shares` on behalf of `onBehalf`.
---

FUNC: supplyCollateral (IMorphoBase)
SIG: function supplyCollateral(MarketParams memory marketParams, uint256 assets, address onBehalf, bytes memory data) external
VISIBILITY: external
MODIFIERS: none
NATSPEC: @notice Supplies `assets` of collateral on behalf of `onBehalf`.
---

FUNC: withdrawCollateral (IMorphoBase)
SIG: function withdrawCollateral(MarketParams memory marketParams, uint256 assets, address onBehalf, address receiver) external
VISIBILITY: external
MODIFIERS: none
NATSPEC: @notice Withdraws `assets` of collateral on behalf of `onBehalf` and sends the assets to `receiver`.
---

FUNC: liquidate (IMorphoBase)
SIG: function liquidate(MarketParams memory marketParams, address borrower, uint256 seizedAssets, uint256 repaidShares, bytes memory data) external returns (uint256, uint256)
VISIBILITY: external
MODIFIERS: none
NATSPEC: @notice Liquidates the given `repaidShares` of debt asset or seize the given `seizedAssets` of collateral.
---

FUNC: flashLoan (IMorphoBase)
SIG: function flashLoan(address token, uint256 assets, bytes calldata data) external
VISIBILITY: external
MODIFIERS: none
NATSPEC: @notice Executes a flash loan.
---

FUNC: setAuthorization (IMorphoBase)
SIG: function setAuthorization(address authorized, bool newIsAuthorized) external
VISIBILITY: external
MODIFIERS: none
NATSPEC: @notice Sets the authorization for `authorized` to manage `msg.sender`'s positions.
---

FUNC: setAuthorizationWithSig (IMorphoBase)
SIG: function setAuthorizationWithSig(Authorization calldata authorization, Signature calldata signature) external
VISIBILITY: external
MODIFIERS: none
NATSPEC: @notice Sets the authorization for `authorization.authorized` to manage `authorization.authorizer`'s positions.
---

FUNC: accrueInterest (IMorphoBase)
SIG: function accrueInterest(MarketParams memory marketParams) external
VISIBILITY: external
MODIFIERS: none
NATSPEC: @notice Accrues interest for the given market `marketParams`.
---

FUNC: extSloads (IMorphoBase)
SIG: function extSloads(bytes32[] memory slots) external view returns (bytes32[] memory)
VISIBILITY: external
MODIFIERS: none
NATSPEC: @notice Returns the data stored on the different `slots`.
---

FUNC: position (IMorphoStaticTyping)
SIG: function position(Id id, address user) external view returns (uint256 supplyShares, uint128 borrowShares, uint128 collateral)
VISIBILITY: external
MODIFIERS: none
NATSPEC: @notice The state of the position of `user` on the market corresponding to `id`.
---

FUNC: market (IMorphoStaticTyping)
SIG: function market(Id id) external view returns (uint128 totalSupplyAssets, uint128 totalSupplyShares, uint128 totalBorrowAssets, uint128 totalBorrowShares, uint128 lastUpdate, uint128 fee)
VISIBILITY: external
MODIFIERS: none
NATSPEC: @notice The state of the market corresponding to `id`.
---

FUNC: idToMarketParams (IMorphoStaticTyping)
SIG: function idToMarketParams(Id id) external view returns (address loanToken, address collateralToken, address oracle, address irm, uint256 lltv)
VISIBILITY: external
MODIFIERS: none
NATSPEC: @notice The market params corresponding to `id`.
---

FUNC: position (IMorpho)
SIG: function position(Id id, address user) external view returns (Position memory p)
VISIBILITY: external
MODIFIERS: none
NATSPEC: @notice The state of the position of `user` on the market corresponding to `id`.
---

FUNC: market (IMorpho)
SIG: function market(Id id) external view returns (Market memory m)
VISIBILITY: external
MODIFIERS: none
NATSPEC: @notice The state of the market corresponding to `id`.
---

FUNC: idToMarketParams (IMorpho)
SIG: function idToMarketParams(Id id) external view returns (MarketParams memory)
VISIBILITY: external
MODIFIERS: none
NATSPEC: @notice The market params corresponding to `id`.
---

FILE: src/interfaces/IIrm.sol
TYPE: interface
NAME: IIrm
DESC: Interface that Interest Rate Models (IRMs) used by Morpho must implement.
IMPORTS:
- ./IMorpho.sol (MarketParams, Market)
INHERITS: [none]
USES: [none]
CONSTRUCTOR: [none]
IMMUTABLES: [none]
MODIFIERS: [none]
STATE: [none]

FUNC: borrowRate
SIG: function borrowRate(MarketParams memory marketParams, Market memory market) external returns (uint256)
VISIBILITY: external
MODIFIERS: none
NATSPEC: @notice Returns the borrow rate per second (scaled by WAD) of the market `marketParams`.
---

FUNC: borrowRateView
SIG: function borrowRateView(MarketParams memory marketParams, Market memory market) external view returns (uint256)
VISIBILITY: external
MODIFIERS: none
NATSPEC: @notice Returns the borrow rate per second (scaled by WAD) of the market `marketParams` without modifying any storage.
---

FILE: src/interfaces/IERC20.sol
TYPE: interface
NAME: IERC20
DESC: Empty interface used to prevent calling transfer/transferFrom instead of safeTransfer/safeTransferFrom.
IMPORTS: [none]
INHERITS: [none]
USES: [none]
CONSTRUCTOR: [none]
IMMUTABLES: [none]
MODIFIERS: [none]
STATE: [none]
---

FILE: src/interfaces/IMorphoCallbacks.sol
TYPE: interface
NAME: IMorphoLiquidateCallback, IMorphoRepayCallback, IMorphoSupplyCallback, IMorphoSupplyCollateralCallback, IMorphoFlashLoanCallback
DESC: Callback interfaces for users of liquidate, repay, supply, supplyCollateral, and flashLoan.
IMPORTS: [none]
INHERITS: [none]
USES: [none]
CONSTRUCTOR: [none]
IMMUTABLES: [none]
MODIFIERS: [none]
STATE: [none]

FUNC: onMorphoLiquidate
SIG: function onMorphoLiquidate(uint256 repaidAssets, bytes calldata data) external
VISIBILITY: external
MODIFIERS: none
NATSPEC: @notice Callback called when a liquidation occurs.
---

FUNC: onMorphoRepay
SIG: function onMorphoRepay(uint256 assets, bytes calldata data) external
VISIBILITY: external
MODIFIERS: none
NATSPEC: @notice Callback called when a repayment occurs.
---

FUNC: onMorphoSupply
SIG: function onMorphoSupply(uint256 assets, bytes calldata data) external
VISIBILITY: external
MODIFIERS: none
NATSPEC: @notice Callback called when a supply occurs.
---

FUNC: onMorphoSupplyCollateral
SIG: function onMorphoSupplyCollateral(uint256 assets, bytes calldata data) external
VISIBILITY: external
MODIFIERS: none
NATSPEC: @notice Callback called when a supply of collateral occurs.
---

FUNC: onMorphoFlashLoan
SIG: function onMorphoFlashLoan(uint256 assets, bytes calldata data) external
VISIBILITY: external
MODIFIERS: none
NATSPEC: @notice Callback called when a flash loan occurs.
---

FILE: src/interfaces/IOracle.sol
TYPE: interface
NAME: IOracle
DESC: Interface that oracles used by Morpho must implement.
IMPORTS: [none]
INHERITS: [none]
USES: [none]
CONSTRUCTOR: [none]
IMMUTABLES: [none]
MODIFIERS: [none]
STATE: [none]

FUNC: price
SIG: function price() external view returns (uint256)
VISIBILITY: external
MODIFIERS: none
NATSPEC: @notice Returns the price of 1 asset of collateral token quoted in 1 asset of loan token, scaled by 1e36.
---

FILE: src/libraries/MathLib.sol
TYPE: library
NAME: MathLib
DESC: Library to manage fixed-point arithmetic.
IMPORTS: [none]
INHERITS: [none]
USES: [none]
CONSTRUCTOR: [none]
IMMUTABLES: [none]
MODIFIERS: [none]
STATE: [none]
FILE_CONSTANTS:
- WAD: uint256 = 1e18

FUNC: wMulDown
SIG: function wMulDown(uint256 x, uint256 y) internal pure returns (uint256)
VISIBILITY: internal
MODIFIERS: none
NATSPEC: @dev Returns (`x` * `y`) / `WAD` rounded down.
REQUIRES: [none]
READS: [none]
WRITES: [none]
EVENTS: [none]
INTERNAL_CALLS: mulDivDown(x, y, WAD)
EXTERNAL_CALLS: [none]
---

FUNC: wDivDown
SIG: function wDivDown(uint256 x, uint256 y) internal pure returns (uint256)
VISIBILITY: internal
MODIFIERS: none
NATSPEC: @dev Returns (`x` * `WAD`) / `y` rounded down.
REQUIRES: [none]
READS: [none]
WRITES: [none]
EVENTS: [none]
INTERNAL_CALLS: mulDivDown(x, WAD, y)
EXTERNAL_CALLS: [none]
---

FUNC: wDivUp
SIG: function wDivUp(uint256 x, uint256 y) internal pure returns (uint256)
VISIBILITY: internal
MODIFIERS: none
NATSPEC: @dev Returns (`x` * `WAD`) / `y` rounded up.
REQUIRES: [none]
READS: [none]
WRITES: [none]
EVENTS: [none]
INTERNAL_CALLS: mulDivUp(x, WAD, y)
EXTERNAL_CALLS: [none]
---

FUNC: mulDivDown
SIG: function mulDivDown(uint256 x, uint256 y, uint256 d) internal pure returns (uint256)
VISIBILITY: internal
MODIFIERS: none
NATSPEC: @dev Returns (`x` * `y`) / `d` rounded down.
REQUIRES: [none]
READS: [none]
WRITES: [none]
EVENTS: [none]
INTERNAL_CALLS: [none]
EXTERNAL_CALLS: [none]
---

FUNC: mulDivUp
SIG: function mulDivUp(uint256 x, uint256 y, uint256 d) internal pure returns (uint256)
VISIBILITY: internal
MODIFIERS: none
NATSPEC: @dev Returns (`x` * `y`) / `d` rounded up.
REQUIRES: [none]
READS: [none]
WRITES: [none]
EVENTS: [none]
INTERNAL_CALLS: [none]
EXTERNAL_CALLS: [none]
---

FUNC: wTaylorCompounded
SIG: function wTaylorCompounded(uint256 x, uint256 n) internal pure returns (uint256)
VISIBILITY: internal
MODIFIERS: none
NATSPEC: @dev Returns the sum of the first three non-zero terms of a Taylor expansion of e^(nx) - 1.
REQUIRES: [none]
READS: [none]
WRITES: [none]
EVENTS: [none]
INTERNAL_CALLS: mulDivDown(firstTerm, firstTerm, 2 * WAD), mulDivDown(secondTerm, firstTerm, 3 * WAD)
EXTERNAL_CALLS: [none]
---

FILE: src/libraries/SharesMathLib.sol
TYPE: library
NAME: SharesMathLib
DESC: Shares management library.
IMPORTS:
- ./MathLib.sol (MathLib)
INHERITS: [none]
USES:
- MathLib for uint256
CONSTRUCTOR: [none]
IMMUTABLES: [none]
MODIFIERS: [none]
STATE: [none]
CONSTANTS:
- VIRTUAL_SHARES: uint256 = 1e6
- VIRTUAL_ASSETS: uint256 = 1

FUNC: toSharesDown
SIG: function toSharesDown(uint256 assets, uint256 totalAssets, uint256 totalShares) internal pure returns (uint256)
VISIBILITY: internal
MODIFIERS: none
NATSPEC: @dev Calculates the value of `assets` quoted in shares, rounding down.
REQUIRES: [none]
READS: [none]
WRITES: [none]
EVENTS: [none]
INTERNAL_CALLS: mulDivDown(assets, totalShares + VIRTUAL_SHARES, totalAssets + VIRTUAL_ASSETS)
EXTERNAL_CALLS: [none]
---

FUNC: toAssetsDown
SIG: function toAssetsDown(uint256 shares, uint256 totalAssets, uint256 totalShares) internal pure returns (uint256)
VISIBILITY: internal
MODIFIERS: none
NATSPEC: @dev Calculates the value of `shares` quoted in assets, rounding down.
REQUIRES: [none]
READS: [none]
WRITES: [none]
EVENTS: [none]
INTERNAL_CALLS: mulDivDown(shares, totalAssets + VIRTUAL_ASSETS, totalShares + VIRTUAL_SHARES)
EXTERNAL_CALLS: [none]
---

FUNC: toSharesUp
SIG: function toSharesUp(uint256 assets, uint256 totalAssets, uint256 totalShares) internal pure returns (uint256)
VISIBILITY: internal
MODIFIERS: none
NATSPEC: @dev Calculates the value of `assets` quoted in shares, rounding up.
REQUIRES: [none]
READS: [none]
WRITES: [none]
EVENTS: [none]
INTERNAL_CALLS: mulDivUp(assets, totalShares + VIRTUAL_SHARES, totalAssets + VIRTUAL_ASSETS)
EXTERNAL_CALLS: [none]
---

FUNC: toAssetsUp
SIG: function toAssetsUp(uint256 shares, uint256 totalAssets, uint256 totalShares) internal pure returns (uint256)
VISIBILITY: internal
MODIFIERS: none
NATSPEC: @dev Calculates the value of `shares` quoted in assets, rounding up.
REQUIRES: [none]
READS: [none]
WRITES: [none]
EVENTS: [none]
INTERNAL_CALLS: mulDivUp(shares, totalAssets + VIRTUAL_ASSETS, totalShares + VIRTUAL_SHARES)
EXTERNAL_CALLS: [none]
---

FILE: src/libraries/UtilsLib.sol
TYPE: library
NAME: UtilsLib
DESC: Library exposing helpers.
IMPORTS:
- ../libraries/ErrorsLib.sol (ErrorsLib)
INHERITS: [none]
USES: [none]
CONSTRUCTOR: [none]
IMMUTABLES: [none]
MODIFIERS: [none]
STATE: [none]

FUNC: exactlyOneZero
SIG: function exactlyOneZero(uint256 x, uint256 y) internal pure returns (bool z)
VISIBILITY: internal
MODIFIERS: none
NATSPEC: @dev Returns true if exactly one of `x` and `y` is zero.
REQUIRES: [none]
READS: [none]
WRITES: [none]
EVENTS: [none]
INTERNAL_CALLS: [none]
EXTERNAL_CALLS: [none]
---

FUNC: min
SIG: function min(uint256 x, uint256 y) internal pure returns (uint256 z)
VISIBILITY: internal
MODIFIERS: none
NATSPEC: @dev Returns the minimum of `x` and `y`.
REQUIRES: [none]
READS: [none]
WRITES: [none]
EVENTS: [none]
INTERNAL_CALLS: [none]
EXTERNAL_CALLS: [none]
---

FUNC: toUint128
SIG: function toUint128(uint256 x) internal pure returns (uint128)
VISIBILITY: internal
MODIFIERS: none
NATSPEC: @dev Safely casts uint256 to uint128, reverting on overflow.
REQUIRES:
- require(x <= type(uint128).max, ErrorsLib.MAX_UINT128_EXCEEDED)
READS: [none]
WRITES: [none]
EVENTS: [none]
INTERNAL_CALLS: [none]
EXTERNAL_CALLS: [none]
---

FUNC: zeroFloorSub
SIG: function zeroFloorSub(uint256 x, uint256 y) internal pure returns (uint256 z)
VISIBILITY: internal
MODIFIERS: none
NATSPEC: @dev Returns max(0, x - y) without underflow.
REQUIRES: [none]
READS: [none]
WRITES: [none]
EVENTS: [none]
INTERNAL_CALLS: [none]
EXTERNAL_CALLS: [none]
---

FILE: src/libraries/SafeTransferLib.sol
TYPE: library
NAME: SafeTransferLib
DESC: Library to manage transfers of tokens, even if calls to the transfer or transferFrom functions are not returning a boolean.
IMPORTS:
- ../interfaces/IERC20.sol (IERC20)
- ../libraries/ErrorsLib.sol (ErrorsLib)
INHERITS: [none]
USES: [none]
CONSTRUCTOR: [none]
IMMUTABLES: [none]
MODIFIERS: [none]
STATE: [none]
INTERNAL_INTERFACE:
- IERC20Internal: { transfer(address to, uint256 value) returns (bool); transferFrom(address from, address to, uint256 value) returns (bool); }

FUNC: safeTransfer
SIG: function safeTransfer(IERC20 token, address to, uint256 value) internal
VISIBILITY: internal
MODIFIERS: none
NATSPEC: @dev Safely transfers ERC20 tokens from this contract to `to`.
REQUIRES:
- require(address(token).code.length > 0, ErrorsLib.NO_CODE)
- require(success, ErrorsLib.TRANSFER_REVERTED)
- require(returndata.length == 0 || abi.decode(returndata, (bool)), ErrorsLib.TRANSFER_RETURNED_FALSE)
READS: [none]
WRITES: [none]
EVENTS: [none]
INTERNAL_CALLS: [none]
EXTERNAL_CALLS:
- [low-level] address(token).call(abi.encodeCall(IERC20Internal.transfer, (to, value)))
---

FUNC: safeTransferFrom
SIG: function safeTransferFrom(IERC20 token, address from, address to, uint256 value) internal
VISIBILITY: internal
MODIFIERS: none
NATSPEC: @dev Safely transfers ERC20 tokens from `from` to `to` (requires approval).
REQUIRES:
- require(address(token).code.length > 0, ErrorsLib.NO_CODE)
- require(success, ErrorsLib.TRANSFER_FROM_REVERTED)
- require(returndata.length == 0 || abi.decode(returndata, (bool)), ErrorsLib.TRANSFER_FROM_RETURNED_FALSE)
READS: [none]
WRITES: [none]
EVENTS: [none]
INTERNAL_CALLS: [none]
EXTERNAL_CALLS:
- [low-level] address(token).call(abi.encodeCall(IERC20Internal.transferFrom, (from, to, value)))
---

FILE: src/libraries/MarketParamsLib.sol
TYPE: library
NAME: MarketParamsLib
DESC: Library to convert a market to its id.
IMPORTS:
- ../interfaces/IMorpho.sol (Id, MarketParams)
INHERITS: [none]
USES: [none]
CONSTRUCTOR: [none]
IMMUTABLES: [none]
MODIFIERS: [none]
STATE: [none]
CONSTANTS:
- MARKET_PARAMS_BYTES_LENGTH: uint256 = 5 * 32

FUNC: id
SIG: function id(MarketParams memory marketParams) internal pure returns (Id marketParamsId)
VISIBILITY: internal
MODIFIERS: none
NATSPEC: @notice Returns the id of the market `marketParams`.
REQUIRES: [none]
READS: [none]
WRITES: [none]
EVENTS: [none]
INTERNAL_CALLS: [none]
EXTERNAL_CALLS: [none]
---

FILE: src/libraries/ErrorsLib.sol
TYPE: library
NAME: ErrorsLib
DESC: Library exposing error messages.
IMPORTS: [none]
INHERITS: [none]
USES: [none]
CONSTRUCTOR: [none]
IMMUTABLES: [none]
MODIFIERS: [none]
STATE: [none]
CONSTANTS:
- NOT_OWNER: string = "not owner"
- MAX_LLTV_EXCEEDED: string = "max LLTV exceeded"
- MAX_FEE_EXCEEDED: string = "max fee exceeded"
- ALREADY_SET: string = "already set"
- IRM_NOT_ENABLED: string = "IRM not enabled"
- LLTV_NOT_ENABLED: string = "LLTV not enabled"
- MARKET_ALREADY_CREATED: string = "market already created"
- NO_CODE: string = "no code"
- MARKET_NOT_CREATED: string = "market not created"
- INCONSISTENT_INPUT: string = "inconsistent input"
- ZERO_ASSETS: string = "zero assets"
- ZERO_ADDRESS: string = "zero address"
- UNAUTHORIZED: string = "unauthorized"
- INSUFFICIENT_COLLATERAL: string = "insufficient collateral"
- INSUFFICIENT_LIQUIDITY: string = "insufficient liquidity"
- HEALTHY_POSITION: string = "position is healthy"
- INVALID_SIGNATURE: string = "invalid signature"
- SIGNATURE_EXPIRED: string = "signature expired"
- INVALID_NONCE: string = "invalid nonce"
- TRANSFER_REVERTED: string = "transfer reverted"
- TRANSFER_RETURNED_FALSE: string = "transfer returned false"
- TRANSFER_FROM_REVERTED: string = "transferFrom reverted"
- TRANSFER_FROM_RETURNED_FALSE: string = "transferFrom returned false"
- MAX_UINT128_EXCEEDED: string = "max uint128 exceeded"
---

FILE: src/libraries/EventsLib.sol
TYPE: library
NAME: EventsLib
DESC: Library exposing events.
IMPORTS:
- ../interfaces/IMorpho.sol (Id, MarketParams)
INHERITS: [none]
USES: [none]
CONSTRUCTOR: [none]
IMMUTABLES: [none]
MODIFIERS: [none]
STATE: [none]
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

FILE: src/libraries/ConstantsLib.sol
TYPE: library (file-level constants)
NAME: ConstantsLib
DESC: [none]
IMPORTS: [none]
INHERITS: [none]
USES: [none]
CONSTRUCTOR: [none]
IMMUTABLES: [none]
MODIFIERS: [none]
STATE: [none]
CONSTANTS:
- MAX_FEE: uint256 = 0.25e18
- ORACLE_PRICE_SCALE: uint256 = 1e36
- LIQUIDATION_CURSOR: uint256 = 0.3e18
- MAX_LIQUIDATION_INCENTIVE_FACTOR: uint256 = 1.15e18
- DOMAIN_TYPEHASH: bytes32 = keccak256("EIP712Domain(uint256 chainId,address verifyingContract)")
- AUTHORIZATION_TYPEHASH: bytes32 = keccak256("Authorization(address authorizer,address authorized,bool isAuthorized,uint256 nonce,uint256 deadline)")
---

FILE: src/libraries/periphery/MorphoLib.sol
TYPE: library
NAME: MorphoLib
DESC: Helper library to access Morpho storage variables.
IMPORTS:
- ../../interfaces/IMorpho.sol (IMorpho, Id)
- ./MorphoStorageLib.sol (MorphoStorageLib)
INHERITS: [none]
USES: [none]
CONSTRUCTOR: [none]
IMMUTABLES: [none]
MODIFIERS: [none]
STATE: [none]

FUNC: supplyShares
SIG: function supplyShares(IMorpho morpho, Id id, address user) internal view returns (uint256)
VISIBILITY: internal
MODIFIERS: none
NATSPEC: @dev Returns user's supply shares in a market.
REQUIRES: [none]
READS: [none]
WRITES: [none]
EVENTS: [none]
INTERNAL_CALLS: MorphoStorageLib.positionSupplySharesSlot(id, user), _array(slot)
EXTERNAL_CALLS:
- [typed] morpho.extSloads(slot)
---

FUNC: borrowShares
SIG: function borrowShares(IMorpho morpho, Id id, address user) internal view returns (uint256)
VISIBILITY: internal
MODIFIERS: none
NATSPEC: @dev Returns user's borrow shares in a market.
REQUIRES: [none]
READS: [none]
WRITES: [none]
EVENTS: [none]
INTERNAL_CALLS: MorphoStorageLib.positionBorrowSharesAndCollateralSlot(id, user), _array(slot)
EXTERNAL_CALLS:
- [typed] morpho.extSloads(slot)
---

FUNC: collateral
SIG: function collateral(IMorpho morpho, Id id, address user) internal view returns (uint256)
VISIBILITY: internal
MODIFIERS: none
NATSPEC: @dev Returns user's collateral amount in a market.
REQUIRES: [none]
READS: [none]
WRITES: [none]
EVENTS: [none]
INTERNAL_CALLS: MorphoStorageLib.positionBorrowSharesAndCollateralSlot(id, user), _array(slot)
EXTERNAL_CALLS:
- [typed] morpho.extSloads(slot)
---

FUNC: totalSupplyAssets
SIG: function totalSupplyAssets(IMorpho morpho, Id id) internal view returns (uint256)
VISIBILITY: internal
MODIFIERS: none
NATSPEC: @dev Returns total supply assets in a market.
REQUIRES: [none]
READS: [none]
WRITES: [none]
EVENTS: [none]
INTERNAL_CALLS: MorphoStorageLib.marketTotalSupplyAssetsAndSharesSlot(id), _array(slot)
EXTERNAL_CALLS:
- [typed] morpho.extSloads(slot)
---

FUNC: totalSupplyShares
SIG: function totalSupplyShares(IMorpho morpho, Id id) internal view returns (uint256)
VISIBILITY: internal
MODIFIERS: none
NATSPEC: @dev Returns total supply shares in a market.
REQUIRES: [none]
READS: [none]
WRITES: [none]
EVENTS: [none]
INTERNAL_CALLS: MorphoStorageLib.marketTotalSupplyAssetsAndSharesSlot(id), _array(slot)
EXTERNAL_CALLS:
- [typed] morpho.extSloads(slot)
---

FUNC: totalBorrowAssets
SIG: function totalBorrowAssets(IMorpho morpho, Id id) internal view returns (uint256)
VISIBILITY: internal
MODIFIERS: none
NATSPEC: @dev Returns total borrow assets in a market.
REQUIRES: [none]
READS: [none]
WRITES: [none]
EVENTS: [none]
INTERNAL_CALLS: MorphoStorageLib.marketTotalBorrowAssetsAndSharesSlot(id), _array(slot)
EXTERNAL_CALLS:
- [typed] morpho.extSloads(slot)
---

FUNC: totalBorrowShares
SIG: function totalBorrowShares(IMorpho morpho, Id id) internal view returns (uint256)
VISIBILITY: internal
MODIFIERS: none
NATSPEC: @dev Returns total borrow shares in a market.
REQUIRES: [none]
READS: [none]
WRITES: [none]
EVENTS: [none]
INTERNAL_CALLS: MorphoStorageLib.marketTotalBorrowAssetsAndSharesSlot(id), _array(slot)
EXTERNAL_CALLS:
- [typed] morpho.extSloads(slot)
---

FUNC: lastUpdate
SIG: function lastUpdate(IMorpho morpho, Id id) internal view returns (uint256)
VISIBILITY: internal
MODIFIERS: none
NATSPEC: @dev Returns the timestamp of last interest accrual for a market.
REQUIRES: [none]
READS: [none]
WRITES: [none]
EVENTS: [none]
INTERNAL_CALLS: MorphoStorageLib.marketLastUpdateAndFeeSlot(id), _array(slot)
EXTERNAL_CALLS:
- [typed] morpho.extSloads(slot)
---

FUNC: fee
SIG: function fee(IMorpho morpho, Id id) internal view returns (uint256)
VISIBILITY: internal
MODIFIERS: none
NATSPEC: @dev Returns the protocol fee for a market.
REQUIRES: [none]
READS: [none]
WRITES: [none]
EVENTS: [none]
INTERNAL_CALLS: MorphoStorageLib.marketLastUpdateAndFeeSlot(id), _array(slot)
EXTERNAL_CALLS:
- [typed] morpho.extSloads(slot)
---

FUNC: _array
SIG: function _array(bytes32 x) private pure returns (bytes32[] memory)
VISIBILITY: private
MODIFIERS: none
NATSPEC: @dev Helper to create single-element array for extSloads call.
REQUIRES: [none]
READS: [none]
WRITES: [none]
EVENTS: [none]
INTERNAL_CALLS: [none]
EXTERNAL_CALLS: [none]
---

FILE: src/libraries/periphery/MorphoBalancesLib.sol
TYPE: library
NAME: MorphoBalancesLib
DESC: Helper library exposing getters with the expected value after interest accrual.
IMPORTS:
- ../../interfaces/IMorpho.sol (Id, MarketParams, Market, IMorpho)
- ../../interfaces/IIrm.sol (IIrm)
- ../MathLib.sol (MathLib)
- ../UtilsLib.sol (UtilsLib)
- ./MorphoLib.sol (MorphoLib)
- ../SharesMathLib.sol (SharesMathLib)
- ../MarketParamsLib.sol (MarketParamsLib)
INHERITS: [none]
USES:
- MathLib for uint256
- MathLib for uint128
- UtilsLib for uint256
- MorphoLib for IMorpho
- SharesMathLib for uint256
- MarketParamsLib for MarketParams
CONSTRUCTOR: [none]
IMMUTABLES: [none]
MODIFIERS: [none]
STATE: [none]

FUNC: expectedMarketBalances
SIG: function expectedMarketBalances(IMorpho morpho, MarketParams memory marketParams) internal view returns (uint256, uint256, uint256, uint256)
VISIBILITY: internal
MODIFIERS: none
NATSPEC: @notice Returns the expected market balances of a market after having accrued interest.
REQUIRES: [none]
READS: [none]
WRITES: [none]
EVENTS: [none]
INTERNAL_CALLS: marketParams.id(), morpho.market(id)
EXTERNAL_CALLS:
- [typed] IIrm(marketParams.irm).borrowRateView(marketParams, market) (conditional: if elapsed != 0 && totalBorrowAssets != 0 && irm != address(0))
---

FUNC: expectedTotalSupplyAssets
SIG: function expectedTotalSupplyAssets(IMorpho morpho, MarketParams memory marketParams) internal view returns (uint256 totalSupplyAssets)
VISIBILITY: internal
MODIFIERS: none
NATSPEC: @notice Returns the expected total supply assets of a market after having accrued interest.
REQUIRES: [none]
READS: [none]
WRITES: [none]
EVENTS: [none]
INTERNAL_CALLS: expectedMarketBalances(morpho, marketParams)
EXTERNAL_CALLS: [none]
---

FUNC: expectedTotalBorrowAssets
SIG: function expectedTotalBorrowAssets(IMorpho morpho, MarketParams memory marketParams) internal view returns (uint256 totalBorrowAssets)
VISIBILITY: internal
MODIFIERS: none
NATSPEC: @notice Returns the expected total borrow assets of a market after having accrued interest.
REQUIRES: [none]
READS: [none]
WRITES: [none]
EVENTS: [none]
INTERNAL_CALLS: expectedMarketBalances(morpho, marketParams)
EXTERNAL_CALLS: [none]
---

FUNC: expectedTotalSupplyShares
SIG: function expectedTotalSupplyShares(IMorpho morpho, MarketParams memory marketParams) internal view returns (uint256 totalSupplyShares)
VISIBILITY: internal
MODIFIERS: none
NATSPEC: @notice Returns the expected total supply shares of a market after having accrued interest.
REQUIRES: [none]
READS: [none]
WRITES: [none]
EVENTS: [none]
INTERNAL_CALLS: expectedMarketBalances(morpho, marketParams)
EXTERNAL_CALLS: [none]
---

FUNC: expectedSupplyAssets
SIG: function expectedSupplyAssets(IMorpho morpho, MarketParams memory marketParams, address user) internal view returns (uint256)
VISIBILITY: internal
MODIFIERS: none
NATSPEC: @notice Returns the expected supply assets balance of `user` on a market after having accrued interest.
REQUIRES: [none]
READS: [none]
WRITES: [none]
EVENTS: [none]
INTERNAL_CALLS: morpho.supplyShares(id, user), expectedMarketBalances(morpho, marketParams), toAssetsDown(supplyShares, totalSupplyAssets, totalSupplyShares)
EXTERNAL_CALLS: [none]
---

FUNC: expectedBorrowAssets
SIG: function expectedBorrowAssets(IMorpho morpho, MarketParams memory marketParams, address user) internal view returns (uint256)
VISIBILITY: internal
MODIFIERS: none
NATSPEC: @notice Returns the expected borrow assets balance of `user` on a market after having accrued interest.
REQUIRES: [none]
READS: [none]
WRITES: [none]
EVENTS: [none]
INTERNAL_CALLS: morpho.borrowShares(id, user), expectedMarketBalances(morpho, marketParams), toAssetsUp(borrowShares, totalBorrowAssets, totalBorrowShares)
EXTERNAL_CALLS: [none]
---

FILE: src/libraries/periphery/MorphoStorageLib.sol
TYPE: library
NAME: MorphoStorageLib
DESC: Helper library exposing getters to access Morpho storage variables' slot.
IMPORTS:
- ../../interfaces/IMorpho.sol (Id)
INHERITS: [none]
USES: [none]
CONSTRUCTOR: [none]
IMMUTABLES: [none]
MODIFIERS: [none]
STATE: [none]
CONSTANTS:
- OWNER_SLOT: uint256 = 0
- FEE_RECIPIENT_SLOT: uint256 = 1
- POSITION_SLOT: uint256 = 2
- MARKET_SLOT: uint256 = 3
- IS_IRM_ENABLED_SLOT: uint256 = 4
- IS_LLTV_ENABLED_SLOT: uint256 = 5
- IS_AUTHORIZED_SLOT: uint256 = 6
- NONCE_SLOT: uint256 = 7
- ID_TO_MARKET_PARAMS_SLOT: uint256 = 8
- LOAN_TOKEN_OFFSET: uint256 = 0
- COLLATERAL_TOKEN_OFFSET: uint256 = 1
- ORACLE_OFFSET: uint256 = 2
- IRM_OFFSET: uint256 = 3
- LLTV_OFFSET: uint256 = 4
- SUPPLY_SHARES_OFFSET: uint256 = 0
- BORROW_SHARES_AND_COLLATERAL_OFFSET: uint256 = 1
- TOTAL_SUPPLY_ASSETS_AND_SHARES_OFFSET: uint256 = 0
- TOTAL_BORROW_ASSETS_AND_SHARES_OFFSET: uint256 = 1
- LAST_UPDATE_AND_FEE_OFFSET: uint256 = 2

FUNC: ownerSlot
SIG: function ownerSlot() internal pure returns (bytes32)
VISIBILITY: internal
MODIFIERS: none
NATSPEC: [none]
REQUIRES: [none]
READS: [none]
WRITES: [none]
EVENTS: [none]
INTERNAL_CALLS: [none]
EXTERNAL_CALLS: [none]
---

FUNC: feeRecipientSlot
SIG: function feeRecipientSlot() internal pure returns (bytes32)
VISIBILITY: internal
MODIFIERS: none
NATSPEC: [none]
REQUIRES: [none]
READS: [none]
WRITES: [none]
EVENTS: [none]
INTERNAL_CALLS: [none]
EXTERNAL_CALLS: [none]
---

FUNC: positionSupplySharesSlot
SIG: function positionSupplySharesSlot(Id id, address user) internal pure returns (bytes32)
VISIBILITY: internal
MODIFIERS: none
NATSPEC: [none]
REQUIRES: [none]
READS: [none]
WRITES: [none]
EVENTS: [none]
INTERNAL_CALLS: [none]
EXTERNAL_CALLS: [none]
---

FUNC: positionBorrowSharesAndCollateralSlot
SIG: function positionBorrowSharesAndCollateralSlot(Id id, address user) internal pure returns (bytes32)
VISIBILITY: internal
MODIFIERS: none
NATSPEC: [none]
REQUIRES: [none]
READS: [none]
WRITES: [none]
EVENTS: [none]
INTERNAL_CALLS: [none]
EXTERNAL_CALLS: [none]
---

FUNC: marketTotalSupplyAssetsAndSharesSlot
SIG: function marketTotalSupplyAssetsAndSharesSlot(Id id) internal pure returns (bytes32)
VISIBILITY: internal
MODIFIERS: none
NATSPEC: [none]
REQUIRES: [none]
READS: [none]
WRITES: [none]
EVENTS: [none]
INTERNAL_CALLS: [none]
EXTERNAL_CALLS: [none]
---

FUNC: marketTotalBorrowAssetsAndSharesSlot
SIG: function marketTotalBorrowAssetsAndSharesSlot(Id id) internal pure returns (bytes32)
VISIBILITY: internal
MODIFIERS: none
NATSPEC: [none]
REQUIRES: [none]
READS: [none]
WRITES: [none]
EVENTS: [none]
INTERNAL_CALLS: [none]
EXTERNAL_CALLS: [none]
---

FUNC: marketLastUpdateAndFeeSlot
SIG: function marketLastUpdateAndFeeSlot(Id id) internal pure returns (bytes32)
VISIBILITY: internal
MODIFIERS: none
NATSPEC: [none]
REQUIRES: [none]
READS: [none]
WRITES: [none]
EVENTS: [none]
INTERNAL_CALLS: [none]
EXTERNAL_CALLS: [none]
---

FUNC: isIrmEnabledSlot
SIG: function isIrmEnabledSlot(address irm) internal pure returns (bytes32)
VISIBILITY: internal
MODIFIERS: none
NATSPEC: [none]
REQUIRES: [none]
READS: [none]
WRITES: [none]
EVENTS: [none]
INTERNAL_CALLS: [none]
EXTERNAL_CALLS: [none]
---

FUNC: isLltvEnabledSlot
SIG: function isLltvEnabledSlot(uint256 lltv) internal pure returns (bytes32)
VISIBILITY: internal
MODIFIERS: none
NATSPEC: [none]
REQUIRES: [none]
READS: [none]
WRITES: [none]
EVENTS: [none]
INTERNAL_CALLS: [none]
EXTERNAL_CALLS: [none]
---

FUNC: isAuthorizedSlot
SIG: function isAuthorizedSlot(address authorizer, address authorizee) internal pure returns (bytes32)
VISIBILITY: internal
MODIFIERS: none
NATSPEC: [none]
REQUIRES: [none]
READS: [none]
WRITES: [none]
EVENTS: [none]
INTERNAL_CALLS: [none]
EXTERNAL_CALLS: [none]
---

FUNC: nonceSlot
SIG: function nonceSlot(address authorizer) internal pure returns (bytes32)
VISIBILITY: internal
MODIFIERS: none
NATSPEC: [none]
REQUIRES: [none]
READS: [none]
WRITES: [none]
EVENTS: [none]
INTERNAL_CALLS: [none]
EXTERNAL_CALLS: [none]
---

FUNC: idToLoanTokenSlot
SIG: function idToLoanTokenSlot(Id id) internal pure returns (bytes32)
VISIBILITY: internal
MODIFIERS: none
NATSPEC: [none]
REQUIRES: [none]
READS: [none]
WRITES: [none]
EVENTS: [none]
INTERNAL_CALLS: [none]
EXTERNAL_CALLS: [none]
---

FUNC: idToCollateralTokenSlot
SIG: function idToCollateralTokenSlot(Id id) internal pure returns (bytes32)
VISIBILITY: internal
MODIFIERS: none
NATSPEC: [none]
REQUIRES: [none]
READS: [none]
WRITES: [none]
EVENTS: [none]
INTERNAL_CALLS: [none]
EXTERNAL_CALLS: [none]
---

FUNC: idToOracleSlot
SIG: function idToOracleSlot(Id id) internal pure returns (bytes32)
VISIBILITY: internal
MODIFIERS: none
NATSPEC: [none]
REQUIRES: [none]
READS: [none]
WRITES: [none]
EVENTS: [none]
INTERNAL_CALLS: [none]
EXTERNAL_CALLS: [none]
---

FUNC: idToIrmSlot
SIG: function idToIrmSlot(Id id) internal pure returns (bytes32)
VISIBILITY: internal
MODIFIERS: none
NATSPEC: [none]
REQUIRES: [none]
READS: [none]
WRITES: [none]
EVENTS: [none]
INTERNAL_CALLS: [none]
EXTERNAL_CALLS: [none]
---

FUNC: idToLltvSlot
SIG: function idToLltvSlot(Id id) internal pure returns (bytes32)
VISIBILITY: internal
MODIFIERS: none
NATSPEC: [none]
REQUIRES: [none]
READS: [none]
WRITES: [none]
EVENTS: [none]
INTERNAL_CALLS: [none]
EXTERNAL_CALLS: [none]
---

FILE: test/recon/Setup.sol
SETUP:
```
// Inherits: BaseSetup, ActorManager, AssetManager, Utils
// Imports mocks: FlashBorrowerMock, IrmMock, OracleMock
// State: Morpho morpho, FlashBorrowerMock flashBorrower, IrmMock irm, OracleMock oracle, IMorpho iMorpho, MarketParams marketParams

function setup() internal virtual override {
    morpho = new Morpho(_getActor());
    irm = new IrmMock();
    oracle = new OracleMock();
    iMorpho = IMorpho(address(morpho));
    flashBorrower = new FlashBorrowerMock(iMorpho);

    //set oracle price
    oracle.setPrice(1e36);

    // Add 3 actors
    _addActor(address(0x411c3));
    _addActor(address(0x411c4));
    _addActor(address(0x411c5));

    // Deploy assets
    _newAsset(18); // collateral token
    _newAsset(18); // loan token

    // Mint tokens and approve to morpho for all actors
    address[] memory approvalArray = new address[](1);
    approvalArray[0] = address(morpho);
    _finalizeAssetDeployment(_getActors(), approvalArray, type(uint88).max);

    // Create the market
    morpho.enableIrm(address(irm));
    morpho.enableLltv(8e17);

    address[] memory assets = _getAssets();
    marketParams = MarketParams({
        loanToken: assets[1], collateralToken: assets[0], oracle: address(oracle), irm: address(irm), lltv: 8e17
    });
    morpho.createMarket(marketParams);
}

// Modifiers:
modifier asAdmin() {
    vm.startPrank(address(this));
    _;
    vm.stopPrank();
}

modifier asActor() {
    vm.startPrank(address(_getActor()));
    _;
    vm.stopPrank();
}
```
---

README:
# AI-Powered Protocol Knowledge Base Generator

This repository contains an AI-driven system for generating comprehensive knowledge bases from Solidity smart contract codebases. It automatically analyzes protocol code and produces structured documentation optimized for security auditors and developers.

## What This Does

The KB generator reads a Solidity codebase and produces:

1. **Structured data extraction** - Parses all contracts, interfaces, libraries, functions, state variables, modifiers, and their relationships
2. **Dependency analysis** - Maps imports, inheritance, library usage, and runtime external calls
3. **Deployment documentation** - Constructor parameters, deployment order, post-deployment setup
4. **Visual diagrams** - Mermaid charts for setup flows, role hierarchies, and user journeys
5. **Security-focused overview** - Trust assumptions, invariants, attack surface, edge cases
6. **Function-level documentation** - Detailed docs for every function with validation, state changes, and security notes
7. **Inline source comments** - Adds auditor-friendly annotations directly to source files

## Quick Start

### Run Full KB Generation (Recommended)

Copy this prompt into Claude Code:

```
Read kb/prompts.md and execute ALL steps (1-7) in order.

For each step:
1. Read the step's instructions from prompts.md
2. Execute the step following its TRY cache / FALLBACK pattern
3. Create the output file(s) in kb/ folder (Steps 1-6) or modify source files (Step 7)
4. Move to next step

Start with Step 1 (Information Gathering) which creates the cache, then Steps 2-7 will use that cache.

Execute now.
```

### Run KB Only (No Source Modification)

If you don't want inline comments added to source files:

```
Read kb/prompts.md and execute Steps 1-6 in order.
Do NOT execute Step 7 (which modifies source files).

Execute now.
```

### Run Single Step

```
Read kb/prompts.md. Execute only Step [N].
```

Replace `[N]` with step number (1-7).

## Output Files

After execution, the `kb/` folder contains:

| File | Description |
|------|-------------|
| `1-informationNeededForSteps.md` | Raw extracted data cache (used by subsequent steps) |
| `2-contractsList.md` | Categorized list of all contracts, interfaces, libraries |
| `3a-dependencyList.md` | Import/inheritance/library dependencies with mermaid graph |
| `3b-deploymentPattern.md` | Deployment order, constructor params, post-deploy setup |
| `4a-setupCharts.md` | Deployment sequence diagrams, state machines |
| `4b-roleCharts.md` | Roles, permission matrix, authorization flows |
| `4c-usageFlows.md` | User journey sequence diagrams (supply, borrow, liquidate, etc.) |
| `5-overview.md` | Single-page auditor digest with architecture, invariants, attack surface |
| `6-codeDocumentation.md` | Function-by-function documentation |

Step 7 modifies source files in `src/` by adding inline comments.

## Step Details

### Step 1: Information Gathering (Cache)
Extracts ALL data needed by subsequent steps:
- Project type detection (Foundry/Hardhat)
- Contract/interface/library metadata
- Function signatures, modifiers, state variables
- Import relationships, inheritance chains
- Constructor parameters, events, errors
- Test setUp() functions for deployment patterns

### Step 2: Contract Discovery
Categorizes all `.sol` files into:
- Core contracts
- Interfaces
- Libraries (core and periphery)
- Mocks

### Step 3: Dependencies & Deployment
- **3a**: Dependency graph showing imports, inheritance, library usage, runtime calls
- **3b**: Deployment pattern with constructor params, deployment order, post-deploy configuration

### Step 4: Charts & Flows
- **4a**: Setup charts (deployment sequence, configuration state machine)
- **4b**: Role charts (permission matrix, role hierarchy, authorization flow)
- **4c**: Usage flows (supply, withdraw, borrow, repay, liquidate, flash loan sequences)

### Step 5: System Overview
Single-page security digest containing:
- Protocol description and core mechanics
- Architecture diagram
- Entry points with risk levels
- Trust assumptions
- External dependencies
- Critical state variables
- Value flows
- Privileged roles
- Key invariants
- Attack surface analysis
- Known edge cases
- Quick reference (constants, limits)

### Step 6: Code Documentation
Comprehensive function-by-function documentation:
- Full signatures with parameters and returns
- Access control requirements
- Validation logic (all require/revert conditions)
- State changes (reads and writes)
- Internal and external calls
- Events emitted
- Security notes

### Step 7: Inline Documentation
Adds comments directly to source files:
- `BOUNDS:` - Parameter limits, overflow considerations
- `MATH:` - Formula explanations, rounding directions
- `SECURITY:` - Reentrancy points, CEI pattern, access control
- `STATE:` - What changes and why
- `EXTERNAL:` - External call risks
- `INVARIANT:` - What this function maintains
- `EDGE CASE:` - Special handling notes

## Architecture

```
kb/
+-- prompts.md              # Step definitions with TRY cache / FALLBACK patterns
+-- RUN.md                  # Execution prompts (copy-paste into Claude Code)
+-- 1-informationNeededForSteps.md   # Cache (generated)
+-- 2-contractsList.md               # (generated)
+-- 3a-dependencyList.md             # (generated)
+-- 3b-deploymentPattern.md          # (generated)
+-- 4a-setupCharts.md                # (generated)
+-- 4b-roleCharts.md                 # (generated)
+-- 4c-usageFlows.md                 # (generated)
+-- 5-overview.md                    # (generated)
+-- 6-codeDocumentation.md           # (generated)
```

## Customization

### Adapting for Other Protocols

The prompts in `kb/prompts.md` are designed to work with any Foundry or Hardhat Solidity project:

1. Copy the `kb/` folder to your target repository
2. Delete all generated files (keep only `prompts.md` and `RUN.md`)
3. Run the execution prompt

The system automatically:
- Detects project type (Foundry vs Hardhat)
- Finds source directory (`src/`, `contracts/`, or `source/`)
- Excludes `lib/`, `node_modules/`, and mock files
- Reads test files for deployment patterns

### Modifying Steps

Edit `kb/prompts.md` to:
- Add new output files
- Change documentation format
- Add protocol-specific sections
- Modify what data is extracted

## Expected Execution Time

- Steps 1-6: ~2-5 minutes depending on codebase size
- Step 7: ~1-3 minutes (reads and modifies source files)
- Total: ~3-8 minutes for complete KB generation

## Use Cases

1. **Security Audits**: Generate comprehensive protocol documentation before starting an audit
2. **Onboarding**: Help new developers understand complex codebases quickly
3. **Documentation**: Auto-generate technical documentation from code
4. **Code Review**: Understand dependencies, roles, and flows before reviewing PRs
5. **Due Diligence**: Quickly assess protocol architecture and trust assumptions

## Requirements

- [Claude Code](https://claude.ai/claude-code) CLI
- Solidity codebase (Foundry or Hardhat project)

## License

The KB generation system (prompts and scripts) is provided as-is for any use.
---
