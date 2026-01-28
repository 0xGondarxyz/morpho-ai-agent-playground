---
META
project_type: Foundry
source_dir: src/
test_dir: test/
---

FILE: src/Morpho.sol
TYPE: contract
NAME: Morpho
DESC: The Morpho contract - noncustodial lending protocol
IMPORTS:
- ./interfaces/IMorpho.sol
- ./interfaces/IMorphoCallbacks.sol
- ./interfaces/IIrm.sol
- ./interfaces/IERC20.sol
- ./interfaces/IOracle.sol
- ./libraries/ConstantsLib.sol
- ./libraries/UtilsLib.sol
- ./libraries/EventsLib.sol
- ./libraries/ErrorsLib.sol
- ./libraries/MathLib.sol
- ./libraries/SharesMathLib.sol
- ./libraries/MarketParamsLib.sol
- ./libraries/SafeTransferLib.sol
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

FUNC: setOwner
SIG: function setOwner(address newOwner) external onlyOwner
VISIBILITY: external
MODIFIERS: onlyOwner
NATSPEC: Sets newOwner as owner of the contract
REQUIRES:
- require(newOwner != owner, ErrorsLib.ALREADY_SET)
READS: owner
WRITES: owner
EVENTS: EventsLib.SetOwner(newOwner)
INTERNAL_CALLS: none
EXTERNAL_CALLS: none
---

FUNC: enableIrm
SIG: function enableIrm(address irm) external onlyOwner
VISIBILITY: external
MODIFIERS: onlyOwner
NATSPEC: Enables irm as a possible IRM for market creation
REQUIRES:
- require(!isIrmEnabled[irm], ErrorsLib.ALREADY_SET)
READS: isIrmEnabled[irm]
WRITES: isIrmEnabled[irm]
EVENTS: EventsLib.EnableIrm(irm)
INTERNAL_CALLS: none
EXTERNAL_CALLS: none
---

FUNC: enableLltv
SIG: function enableLltv(uint256 lltv) external onlyOwner
VISIBILITY: external
MODIFIERS: onlyOwner
NATSPEC: Enables lltv as a possible LLTV for market creation
REQUIRES:
- require(!isLltvEnabled[lltv], ErrorsLib.ALREADY_SET)
- require(lltv < WAD, ErrorsLib.MAX_LLTV_EXCEEDED)
READS: isLltvEnabled[lltv]
WRITES: isLltvEnabled[lltv]
EVENTS: EventsLib.EnableLltv(lltv)
INTERNAL_CALLS: none
EXTERNAL_CALLS: none
---

FUNC: setFee
SIG: function setFee(MarketParams memory marketParams, uint256 newFee) external onlyOwner
VISIBILITY: external
MODIFIERS: onlyOwner
NATSPEC: Sets the newFee for the given market marketParams
REQUIRES:
- require(market[id].lastUpdate != 0, ErrorsLib.MARKET_NOT_CREATED)
- require(newFee != market[id].fee, ErrorsLib.ALREADY_SET)
- require(newFee <= MAX_FEE, ErrorsLib.MAX_FEE_EXCEEDED)
READS: market[id].lastUpdate, market[id].fee
WRITES: market[id].fee
EVENTS: EventsLib.SetFee(id, newFee)
INTERNAL_CALLS: _accrueInterest(marketParams, id)
EXTERNAL_CALLS: none
---

FUNC: setFeeRecipient
SIG: function setFeeRecipient(address newFeeRecipient) external onlyOwner
VISIBILITY: external
MODIFIERS: onlyOwner
NATSPEC: Sets newFeeRecipient as feeRecipient of the fee
REQUIRES:
- require(newFeeRecipient != feeRecipient, ErrorsLib.ALREADY_SET)
READS: feeRecipient
WRITES: feeRecipient
EVENTS: EventsLib.SetFeeRecipient(newFeeRecipient)
INTERNAL_CALLS: none
EXTERNAL_CALLS: none
---

FUNC: createMarket
SIG: function createMarket(MarketParams memory marketParams) external
VISIBILITY: external
MODIFIERS: none
NATSPEC: Creates the market marketParams
REQUIRES:
- require(isIrmEnabled[marketParams.irm], ErrorsLib.IRM_NOT_ENABLED)
- require(isLltvEnabled[marketParams.lltv], ErrorsLib.LLTV_NOT_ENABLED)
- require(market[id].lastUpdate == 0, ErrorsLib.MARKET_ALREADY_CREATED)
READS: isIrmEnabled[marketParams.irm], isLltvEnabled[marketParams.lltv], market[id].lastUpdate
WRITES: market[id].lastUpdate, idToMarketParams[id]
EVENTS: EventsLib.CreateMarket(id, marketParams)
INTERNAL_CALLS: none
EXTERNAL_CALLS: IIrm(marketParams.irm).borrowRate(marketParams, market[id]) - if irm != address(0)
---

FUNC: supply
SIG: function supply(MarketParams memory marketParams, uint256 assets, uint256 shares, address onBehalf, bytes calldata data) external returns (uint256, uint256)
VISIBILITY: external
MODIFIERS: none
NATSPEC: Supplies assets or shares on behalf of onBehalf, optionally calling back the caller's onMorphoSupply function
REQUIRES:
- require(market[id].lastUpdate != 0, ErrorsLib.MARKET_NOT_CREATED)
- require(UtilsLib.exactlyOneZero(assets, shares), ErrorsLib.INCONSISTENT_INPUT)
- require(onBehalf != address(0), ErrorsLib.ZERO_ADDRESS)
READS: market[id].lastUpdate, market[id].totalSupplyAssets, market[id].totalSupplyShares
WRITES: position[id][onBehalf].supplyShares, market[id].totalSupplyShares, market[id].totalSupplyAssets
EVENTS: EventsLib.Supply(id, msg.sender, onBehalf, assets, shares)
INTERNAL_CALLS: _accrueInterest(marketParams, id)
EXTERNAL_CALLS: IMorphoSupplyCallback(msg.sender).onMorphoSupply(assets, data), IERC20(marketParams.loanToken).safeTransferFrom(msg.sender, address(this), assets)
---

FUNC: withdraw
SIG: function withdraw(MarketParams memory marketParams, uint256 assets, uint256 shares, address onBehalf, address receiver) external returns (uint256, uint256)
VISIBILITY: external
MODIFIERS: none
NATSPEC: Withdraws assets or shares on behalf of onBehalf and sends the assets to receiver
REQUIRES:
- require(market[id].lastUpdate != 0, ErrorsLib.MARKET_NOT_CREATED)
- require(UtilsLib.exactlyOneZero(assets, shares), ErrorsLib.INCONSISTENT_INPUT)
- require(receiver != address(0), ErrorsLib.ZERO_ADDRESS)
- require(_isSenderAuthorized(onBehalf), ErrorsLib.UNAUTHORIZED)
- require(market[id].totalBorrowAssets <= market[id].totalSupplyAssets, ErrorsLib.INSUFFICIENT_LIQUIDITY)
READS: market[id].lastUpdate, market[id].totalSupplyAssets, market[id].totalSupplyShares, market[id].totalBorrowAssets, position[id][onBehalf].supplyShares
WRITES: position[id][onBehalf].supplyShares, market[id].totalSupplyShares, market[id].totalSupplyAssets
EVENTS: EventsLib.Withdraw(id, msg.sender, onBehalf, receiver, assets, shares)
INTERNAL_CALLS: _accrueInterest(marketParams, id), _isSenderAuthorized(onBehalf)
EXTERNAL_CALLS: IERC20(marketParams.loanToken).safeTransfer(receiver, assets)
---

FUNC: borrow
SIG: function borrow(MarketParams memory marketParams, uint256 assets, uint256 shares, address onBehalf, address receiver) external returns (uint256, uint256)
VISIBILITY: external
MODIFIERS: none
NATSPEC: Borrows assets or shares on behalf of onBehalf and sends the assets to receiver
REQUIRES:
- require(market[id].lastUpdate != 0, ErrorsLib.MARKET_NOT_CREATED)
- require(UtilsLib.exactlyOneZero(assets, shares), ErrorsLib.INCONSISTENT_INPUT)
- require(receiver != address(0), ErrorsLib.ZERO_ADDRESS)
- require(_isSenderAuthorized(onBehalf), ErrorsLib.UNAUTHORIZED)
- require(_isHealthy(marketParams, id, onBehalf), ErrorsLib.INSUFFICIENT_COLLATERAL)
- require(market[id].totalBorrowAssets <= market[id].totalSupplyAssets, ErrorsLib.INSUFFICIENT_LIQUIDITY)
READS: market[id].lastUpdate, market[id].totalBorrowAssets, market[id].totalBorrowShares, market[id].totalSupplyAssets, position[id][onBehalf].borrowShares, position[id][onBehalf].collateral
WRITES: position[id][onBehalf].borrowShares, market[id].totalBorrowShares, market[id].totalBorrowAssets
EVENTS: EventsLib.Borrow(id, msg.sender, onBehalf, receiver, assets, shares)
INTERNAL_CALLS: _accrueInterest(marketParams, id), _isSenderAuthorized(onBehalf), _isHealthy(marketParams, id, onBehalf)
EXTERNAL_CALLS: IERC20(marketParams.loanToken).safeTransfer(receiver, assets)
---

FUNC: repay
SIG: function repay(MarketParams memory marketParams, uint256 assets, uint256 shares, address onBehalf, bytes calldata data) external returns (uint256, uint256)
VISIBILITY: external
MODIFIERS: none
NATSPEC: Repays assets or shares on behalf of onBehalf, optionally calling back the caller's onMorphoRepay function
REQUIRES:
- require(market[id].lastUpdate != 0, ErrorsLib.MARKET_NOT_CREATED)
- require(UtilsLib.exactlyOneZero(assets, shares), ErrorsLib.INCONSISTENT_INPUT)
- require(onBehalf != address(0), ErrorsLib.ZERO_ADDRESS)
READS: market[id].lastUpdate, market[id].totalBorrowAssets, market[id].totalBorrowShares
WRITES: position[id][onBehalf].borrowShares, market[id].totalBorrowShares, market[id].totalBorrowAssets
EVENTS: EventsLib.Repay(id, msg.sender, onBehalf, assets, shares)
INTERNAL_CALLS: _accrueInterest(marketParams, id)
EXTERNAL_CALLS: IMorphoRepayCallback(msg.sender).onMorphoRepay(assets, data), IERC20(marketParams.loanToken).safeTransferFrom(msg.sender, address(this), assets)
---

FUNC: supplyCollateral
SIG: function supplyCollateral(MarketParams memory marketParams, uint256 assets, address onBehalf, bytes calldata data) external
VISIBILITY: external
MODIFIERS: none
NATSPEC: Supplies assets of collateral on behalf of onBehalf
REQUIRES:
- require(market[id].lastUpdate != 0, ErrorsLib.MARKET_NOT_CREATED)
- require(assets != 0, ErrorsLib.ZERO_ASSETS)
- require(onBehalf != address(0), ErrorsLib.ZERO_ADDRESS)
READS: market[id].lastUpdate
WRITES: position[id][onBehalf].collateral
EVENTS: EventsLib.SupplyCollateral(id, msg.sender, onBehalf, assets)
INTERNAL_CALLS: none
EXTERNAL_CALLS: IMorphoSupplyCollateralCallback(msg.sender).onMorphoSupplyCollateral(assets, data), IERC20(marketParams.collateralToken).safeTransferFrom(msg.sender, address(this), assets)
---

FUNC: withdrawCollateral
SIG: function withdrawCollateral(MarketParams memory marketParams, uint256 assets, address onBehalf, address receiver) external
VISIBILITY: external
MODIFIERS: none
NATSPEC: Withdraws assets of collateral on behalf of onBehalf and sends the assets to receiver
REQUIRES:
- require(market[id].lastUpdate != 0, ErrorsLib.MARKET_NOT_CREATED)
- require(assets != 0, ErrorsLib.ZERO_ASSETS)
- require(receiver != address(0), ErrorsLib.ZERO_ADDRESS)
- require(_isSenderAuthorized(onBehalf), ErrorsLib.UNAUTHORIZED)
- require(_isHealthy(marketParams, id, onBehalf), ErrorsLib.INSUFFICIENT_COLLATERAL)
READS: market[id].lastUpdate, position[id][onBehalf].collateral, position[id][onBehalf].borrowShares
WRITES: position[id][onBehalf].collateral
EVENTS: EventsLib.WithdrawCollateral(id, msg.sender, onBehalf, receiver, assets)
INTERNAL_CALLS: _accrueInterest(marketParams, id), _isSenderAuthorized(onBehalf), _isHealthy(marketParams, id, onBehalf)
EXTERNAL_CALLS: IERC20(marketParams.collateralToken).safeTransfer(receiver, assets)
---

FUNC: liquidate
SIG: function liquidate(MarketParams memory marketParams, address borrower, uint256 seizedAssets, uint256 repaidShares, bytes calldata data) external returns (uint256, uint256)
VISIBILITY: external
MODIFIERS: none
NATSPEC: Liquidates the given repaidShares of debt asset or seize the given seizedAssets of collateral
REQUIRES:
- require(market[id].lastUpdate != 0, ErrorsLib.MARKET_NOT_CREATED)
- require(UtilsLib.exactlyOneZero(seizedAssets, repaidShares), ErrorsLib.INCONSISTENT_INPUT)
- require(!_isHealthy(marketParams, id, borrower, collateralPrice), ErrorsLib.HEALTHY_POSITION)
READS: market[id].lastUpdate, market[id].totalBorrowAssets, market[id].totalBorrowShares, market[id].totalSupplyAssets, position[id][borrower].borrowShares, position[id][borrower].collateral
WRITES: position[id][borrower].borrowShares, market[id].totalBorrowShares, market[id].totalBorrowAssets, position[id][borrower].collateral, market[id].totalSupplyAssets
EVENTS: EventsLib.Liquidate(id, msg.sender, borrower, repaidAssets, repaidShares, seizedAssets, badDebtAssets, badDebtShares)
INTERNAL_CALLS: _accrueInterest(marketParams, id), _isHealthy(marketParams, id, borrower, collateralPrice)
EXTERNAL_CALLS: IOracle(marketParams.oracle).price(), IERC20(marketParams.collateralToken).safeTransfer(msg.sender, seizedAssets), IMorphoLiquidateCallback(msg.sender).onMorphoLiquidate(repaidAssets, data), IERC20(marketParams.loanToken).safeTransferFrom(msg.sender, address(this), repaidAssets)
---

FUNC: flashLoan
SIG: function flashLoan(address token, uint256 assets, bytes calldata data) external
VISIBILITY: external
MODIFIERS: none
NATSPEC: Executes a flash loan
REQUIRES:
- require(assets != 0, ErrorsLib.ZERO_ASSETS)
READS: none
WRITES: none
EVENTS: EventsLib.FlashLoan(msg.sender, token, assets)
INTERNAL_CALLS: none
EXTERNAL_CALLS: IERC20(token).safeTransfer(msg.sender, assets), IMorphoFlashLoanCallback(msg.sender).onMorphoFlashLoan(assets, data), IERC20(token).safeTransferFrom(msg.sender, address(this), assets)
---

FUNC: setAuthorization
SIG: function setAuthorization(address authorized, bool newIsAuthorized) external
VISIBILITY: external
MODIFIERS: none
NATSPEC: Sets the authorization for authorized to manage msg.sender's positions
REQUIRES:
- require(newIsAuthorized != isAuthorized[msg.sender][authorized], ErrorsLib.ALREADY_SET)
READS: isAuthorized[msg.sender][authorized]
WRITES: isAuthorized[msg.sender][authorized]
EVENTS: EventsLib.SetAuthorization(msg.sender, msg.sender, authorized, newIsAuthorized)
INTERNAL_CALLS: none
EXTERNAL_CALLS: none
---

FUNC: setAuthorizationWithSig
SIG: function setAuthorizationWithSig(Authorization memory authorization, Signature calldata signature) external
VISIBILITY: external
MODIFIERS: none
NATSPEC: Sets the authorization for authorization.authorized to manage authorization.authorizer's positions via EIP-712 signature
REQUIRES:
- require(block.timestamp <= authorization.deadline, ErrorsLib.SIGNATURE_EXPIRED)
- require(authorization.nonce == nonce[authorization.authorizer]++, ErrorsLib.INVALID_NONCE)
- require(signatory != address(0) && authorization.authorizer == signatory, ErrorsLib.INVALID_SIGNATURE)
READS: nonce[authorization.authorizer], DOMAIN_SEPARATOR
WRITES: nonce[authorization.authorizer], isAuthorized[authorization.authorizer][authorization.authorized]
EVENTS: EventsLib.IncrementNonce(msg.sender, authorization.authorizer, authorization.nonce), EventsLib.SetAuthorization(msg.sender, authorization.authorizer, authorization.authorized, authorization.isAuthorized)
INTERNAL_CALLS: none
EXTERNAL_CALLS: none
---

FUNC: accrueInterest
SIG: function accrueInterest(MarketParams memory marketParams) external
VISIBILITY: external
MODIFIERS: none
NATSPEC: Accrues interest for the given market marketParams
REQUIRES:
- require(market[id].lastUpdate != 0, ErrorsLib.MARKET_NOT_CREATED)
READS: market[id].lastUpdate
WRITES: (via _accrueInterest)
EVENTS: (via _accrueInterest)
INTERNAL_CALLS: _accrueInterest(marketParams, id)
EXTERNAL_CALLS: none
---

FUNC: _accrueInterest
SIG: function _accrueInterest(MarketParams memory marketParams, Id id) internal
VISIBILITY: internal
MODIFIERS: none
NATSPEC: Accrues interest for the given market marketParams
REQUIRES: none (early returns if elapsed == 0)
READS: market[id].lastUpdate, market[id].totalBorrowAssets, market[id].totalSupplyAssets, market[id].totalSupplyShares, market[id].fee, feeRecipient
WRITES: market[id].totalBorrowAssets, market[id].totalSupplyAssets, market[id].lastUpdate, position[id][feeRecipient].supplyShares, market[id].totalSupplyShares
EVENTS: EventsLib.AccrueInterest(id, borrowRate, interest, feeShares)
INTERNAL_CALLS: none
EXTERNAL_CALLS: IIrm(marketParams.irm).borrowRate(marketParams, market[id])
---

FUNC: _isSenderAuthorized
SIG: function _isSenderAuthorized(address onBehalf) internal view returns (bool)
VISIBILITY: internal
MODIFIERS: none
NATSPEC: Returns whether the sender is authorized to manage onBehalf's positions
REQUIRES: none
READS: isAuthorized[onBehalf][msg.sender]
WRITES: none
EVENTS: none
INTERNAL_CALLS: none
EXTERNAL_CALLS: none
---

FUNC: _isHealthy
SIG: function _isHealthy(MarketParams memory marketParams, Id id, address borrower) internal view returns (bool)
VISIBILITY: internal
MODIFIERS: none
NATSPEC: Returns whether the position of borrower in the given market is healthy
REQUIRES: none
READS: position[id][borrower].borrowShares, market[id].totalBorrowAssets, market[id].totalBorrowShares, position[id][borrower].collateral
WRITES: none
EVENTS: none
INTERNAL_CALLS: _isHealthy(marketParams, id, borrower, collateralPrice)
EXTERNAL_CALLS: IOracle(marketParams.oracle).price()
---

FUNC: _isHealthy (overload)
SIG: function _isHealthy(MarketParams memory marketParams, Id id, address borrower, uint256 collateralPrice) internal view returns (bool)
VISIBILITY: internal
MODIFIERS: none
NATSPEC: Returns whether the position of borrower with the given collateralPrice is healthy
REQUIRES: none
READS: position[id][borrower].borrowShares, market[id].totalBorrowAssets, market[id].totalBorrowShares, position[id][borrower].collateral
WRITES: none
EVENTS: none
INTERNAL_CALLS: none
EXTERNAL_CALLS: none
---

FUNC: extSloads
SIG: function extSloads(bytes32[] calldata slots) external view returns (bytes32[] memory res)
VISIBILITY: external
MODIFIERS: none
NATSPEC: Returns the data stored on the different slots
REQUIRES: none
READS: arbitrary storage slots
WRITES: none
EVENTS: none
INTERNAL_CALLS: none
EXTERNAL_CALLS: none
---

FILE: src/interfaces/IMorpho.sol
TYPE: interface
NAME: IMorphoBase, IMorphoStaticTyping, IMorpho
DESC: Interface for Morpho contract with all function signatures

STRUCTS:
- Id: type Id is bytes32
- MarketParams: (loanToken, collateralToken, oracle, irm, lltv)
- Position: (supplyShares, borrowShares, collateral)
- Market: (totalSupplyAssets, totalSupplyShares, totalBorrowAssets, totalBorrowShares, lastUpdate, fee)
- Authorization: (authorizer, authorized, isAuthorized, nonce, deadline)
- Signature: (v, r, s)
---

FILE: src/interfaces/IMorphoCallbacks.sol
TYPE: interface
NAME: IMorphoLiquidateCallback, IMorphoRepayCallback, IMorphoSupplyCallback, IMorphoSupplyCollateralCallback, IMorphoFlashLoanCallback
DESC: Callback interfaces for Morpho operations

FUNC: onMorphoLiquidate
SIG: function onMorphoLiquidate(uint256 repaidAssets, bytes calldata data) external
---

FUNC: onMorphoRepay
SIG: function onMorphoRepay(uint256 assets, bytes calldata data) external
---

FUNC: onMorphoSupply
SIG: function onMorphoSupply(uint256 assets, bytes calldata data) external
---

FUNC: onMorphoSupplyCollateral
SIG: function onMorphoSupplyCollateral(uint256 assets, bytes calldata data) external
---

FUNC: onMorphoFlashLoan
SIG: function onMorphoFlashLoan(uint256 assets, bytes calldata data) external
---

FILE: src/interfaces/IIrm.sol
TYPE: interface
NAME: IIrm
DESC: Interface that Interest Rate Models (IRMs) used by Morpho must implement

FUNC: borrowRate
SIG: function borrowRate(MarketParams memory marketParams, Market memory market) external returns (uint256)
---

FUNC: borrowRateView
SIG: function borrowRateView(MarketParams memory marketParams, Market memory market) external view returns (uint256)
---

FILE: src/interfaces/IOracle.sol
TYPE: interface
NAME: IOracle
DESC: Interface that oracles used by Morpho must implement

FUNC: price
SIG: function price() external view returns (uint256)
NATSPEC: Returns the price of 1 asset of collateral token quoted in 1 asset of loan token, scaled by 1e36
---

FILE: src/interfaces/IERC20.sol
TYPE: interface
NAME: IERC20
DESC: Empty interface - only call library functions to prevent calling transfer instead of safeTransfer
---

FILE: src/libraries/SharesMathLib.sol
TYPE: library
NAME: SharesMathLib
DESC: Shares management library using virtual shares to mitigate share price manipulations
IMPORTS:
- ./MathLib.sol
USES:
- MathLib for uint256

CONSTANTS:
- VIRTUAL_SHARES: uint256 = 1e6
- VIRTUAL_ASSETS: uint256 = 1

FUNC: toSharesDown
SIG: function toSharesDown(uint256 assets, uint256 totalAssets, uint256 totalShares) internal pure returns (uint256)
NATSPEC: Calculates the value of assets quoted in shares, rounding down
---

FUNC: toAssetsDown
SIG: function toAssetsDown(uint256 shares, uint256 totalAssets, uint256 totalShares) internal pure returns (uint256)
NATSPEC: Calculates the value of shares quoted in assets, rounding down
---

FUNC: toSharesUp
SIG: function toSharesUp(uint256 assets, uint256 totalAssets, uint256 totalShares) internal pure returns (uint256)
NATSPEC: Calculates the value of assets quoted in shares, rounding up
---

FUNC: toAssetsUp
SIG: function toAssetsUp(uint256 shares, uint256 totalAssets, uint256 totalShares) internal pure returns (uint256)
NATSPEC: Calculates the value of shares quoted in assets, rounding up
---

FILE: src/libraries/MathLib.sol
TYPE: library
NAME: MathLib
DESC: Library to manage fixed-point arithmetic

CONSTANTS:
- WAD: uint256 = 1e18

FUNC: wMulDown
SIG: function wMulDown(uint256 x, uint256 y) internal pure returns (uint256)
NATSPEC: Returns (x * y) / WAD rounded down
---

FUNC: wDivDown
SIG: function wDivDown(uint256 x, uint256 y) internal pure returns (uint256)
NATSPEC: Returns (x * WAD) / y rounded down
---

FUNC: wDivUp
SIG: function wDivUp(uint256 x, uint256 y) internal pure returns (uint256)
NATSPEC: Returns (x * WAD) / y rounded up
---

FUNC: mulDivDown
SIG: function mulDivDown(uint256 x, uint256 y, uint256 d) internal pure returns (uint256)
NATSPEC: Returns (x * y) / d rounded down
---

FUNC: mulDivUp
SIG: function mulDivUp(uint256 x, uint256 y, uint256 d) internal pure returns (uint256)
NATSPEC: Returns (x * y) / d rounded up
---

FUNC: wTaylorCompounded
SIG: function wTaylorCompounded(uint256 x, uint256 n) internal pure returns (uint256)
NATSPEC: Returns the sum of the first three non-zero terms of a Taylor expansion of e^(nx) - 1, to approximate continuous compound interest rate
---

FILE: src/libraries/UtilsLib.sol
TYPE: library
NAME: UtilsLib
DESC: Library exposing helpers
IMPORTS:
- ./ErrorsLib.sol

FUNC: exactlyOneZero
SIG: function exactlyOneZero(uint256 x, uint256 y) internal pure returns (bool z)
NATSPEC: Returns true if there is exactly one zero among x and y
---

FUNC: min
SIG: function min(uint256 x, uint256 y) internal pure returns (uint256 z)
NATSPEC: Returns the min of x and y
---

FUNC: toUint128
SIG: function toUint128(uint256 x) internal pure returns (uint128)
NATSPEC: Returns x safely cast to uint128
REQUIRES:
- require(x <= type(uint128).max, ErrorsLib.MAX_UINT128_EXCEEDED)
---

FUNC: zeroFloorSub
SIG: function zeroFloorSub(uint256 x, uint256 y) internal pure returns (uint256 z)
NATSPEC: Returns max(0, x - y)
---

FILE: src/libraries/ConstantsLib.sol
TYPE: library (constants only)
NAME: ConstantsLib
DESC: Protocol constants

CONSTANTS:
- MAX_FEE: uint256 = 0.25e18 (25%)
- ORACLE_PRICE_SCALE: uint256 = 1e36
- LIQUIDATION_CURSOR: uint256 = 0.3e18 (30%)
- MAX_LIQUIDATION_INCENTIVE_FACTOR: uint256 = 1.15e18 (15%)
- DOMAIN_TYPEHASH: bytes32 = keccak256("EIP712Domain(uint256 chainId,address verifyingContract)")
- AUTHORIZATION_TYPEHASH: bytes32 = keccak256("Authorization(address authorizer,address authorized,bool isAuthorized,uint256 nonce,uint256 deadline)")
---

FILE: src/libraries/ErrorsLib.sol
TYPE: library
NAME: ErrorsLib
DESC: Library exposing error messages

ERRORS:
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

FILE: src/libraries/EventsLib.sol
TYPE: library
NAME: EventsLib
DESC: Library exposing events
IMPORTS:
- ../interfaces/IMorpho.sol

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

FILE: src/libraries/SafeTransferLib.sol
TYPE: library
NAME: SafeTransferLib
DESC: Library to manage transfers of tokens, even if calls to the transfer or transferFrom functions are not returning a boolean
IMPORTS:
- ../interfaces/IERC20.sol
- ./ErrorsLib.sol

FUNC: safeTransfer
SIG: function safeTransfer(IERC20 token, address to, uint256 value) internal
REQUIRES:
- require(address(token).code.length > 0, ErrorsLib.NO_CODE)
- require(success, ErrorsLib.TRANSFER_REVERTED)
- require(returndata.length == 0 || abi.decode(returndata, (bool)), ErrorsLib.TRANSFER_RETURNED_FALSE)
---

FUNC: safeTransferFrom
SIG: function safeTransferFrom(IERC20 token, address from, address to, uint256 value) internal
REQUIRES:
- require(address(token).code.length > 0, ErrorsLib.NO_CODE)
- require(success, ErrorsLib.TRANSFER_FROM_REVERTED)
- require(returndata.length == 0 || abi.decode(returndata, (bool)), ErrorsLib.TRANSFER_FROM_RETURNED_FALSE)
---

FILE: src/libraries/MarketParamsLib.sol
TYPE: library
NAME: MarketParamsLib
DESC: Library to convert a market to its id
IMPORTS:
- ../interfaces/IMorpho.sol

CONSTANTS:
- MARKET_PARAMS_BYTES_LENGTH: uint256 = 5 * 32

FUNC: id
SIG: function id(MarketParams memory marketParams) internal pure returns (Id marketParamsId)
NATSPEC: Returns the id of the market marketParams
---

FILE: src/libraries/periphery/MorphoLib.sol
TYPE: library
NAME: MorphoLib
DESC: Helper library to access Morpho storage variables
IMPORTS:
- ../../interfaces/IMorpho.sol
- ./MorphoStorageLib.sol

FUNC: supplyShares, borrowShares, collateral, totalSupplyAssets, totalSupplyShares, totalBorrowAssets, totalBorrowShares, lastUpdate, fee
---

FILE: src/libraries/periphery/MorphoBalancesLib.sol
TYPE: library
NAME: MorphoBalancesLib
DESC: Helper library exposing getters with the expected value after interest accrual
IMPORTS:
- ../../interfaces/IMorpho.sol, ../../interfaces/IIrm.sol, ../MathLib.sol, ../UtilsLib.sol, ./MorphoLib.sol, ../SharesMathLib.sol, ../MarketParamsLib.sol

FUNC: expectedMarketBalances, expectedTotalSupplyAssets, expectedTotalBorrowAssets, expectedTotalSupplyShares, expectedSupplyAssets, expectedBorrowAssets
---

FILE: src/libraries/periphery/MorphoStorageLib.sol
TYPE: library
NAME: MorphoStorageLib
DESC: Helper library exposing getters to access Morpho storage variables' slot
IMPORTS:
- ../../interfaces/IMorpho.sol

SLOT_CONSTANTS:
- OWNER_SLOT: 0
- FEE_RECIPIENT_SLOT: 1
- POSITION_SLOT: 2
- MARKET_SLOT: 3
- IS_IRM_ENABLED_SLOT: 4
- IS_LLTV_ENABLED_SLOT: 5
- IS_AUTHORIZED_SLOT: 6
- NONCE_SLOT: 7
- ID_TO_MARKET_PARAMS_SLOT: 8
---

FILE: test/recon/Setup.sol
SETUP:
```
function setup() internal virtual override {
    morpho = new Morpho(); // TODO: Add parameters here
}
```
---

README:
Morpho Blue is a noncustodial lending protocol implemented for the Ethereum Virtual Machine.
Morpho Blue offers a new trustless primitive with increased efficiency and flexibility compared to existing lending platforms.
It provides permissionless risk management and permissionless market creation with oracle agnostic pricing.
It also enables higher collateralization factors, improved interest rates, and lower gas consumption.
The protocol is designed to be a simple, immutable, and governance-minimized base layer that allows for a wide variety of other layers to be built on top.
Morpho Blue also offers a convenient developer experience with a singleton implementation, callbacks, free flash loans, and account management features.
---
