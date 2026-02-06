# Contract Discovery

## Project Type

Foundry

## Source Directory

src/

---

## Core Contracts

| # | File | Contract | Description |
|---|------|----------|-------------|
| 1 | src/Morpho.sol | Morpho | The singleton lending protocol contract; manages markets, positions, supply/borrow/repay/liquidate flows, authorization, flash loans, and interest accrual |

---

## Interfaces

| # | File | Interface(s) | Description |
|---|------|--------------|-------------|
| 1 | src/interfaces/IMorpho.sol | IMorphoBase, IMorphoStaticTyping, IMorpho | Main interface with type definitions; IMorphoBase defines core functions, IMorphoStaticTyping adds static return types, IMorpho adds struct return types |
| 2 | src/interfaces/IIrm.sol | IIrm | Interface that Interest Rate Models (IRMs) used by Morpho must implement |
| 3 | src/interfaces/IERC20.sol | IERC20 | Empty interface used to prevent calling transfer/transferFrom instead of safeTransfer/safeTransferFrom |
| 4 | src/interfaces/IMorphoCallbacks.sol | IMorphoLiquidateCallback, IMorphoRepayCallback, IMorphoSupplyCallback, IMorphoSupplyCollateralCallback, IMorphoFlashLoanCallback | Callback interfaces for users of liquidate, repay, supply, supplyCollateral, and flashLoan |
| 5 | src/interfaces/IOracle.sol | IOracle | Interface that oracles used by Morpho must implement |

---

## Libraries

### Core Libraries

| # | File | Library | Description |
|---|------|---------|-------------|
| 1 | src/libraries/MathLib.sol | MathLib | Fixed-point arithmetic library (WAD math, mulDiv, Taylor expansion) |
| 2 | src/libraries/SharesMathLib.sol | SharesMathLib | Shares management library for asset-to-share conversions with virtual shares/assets |
| 3 | src/libraries/UtilsLib.sol | UtilsLib | Utility helpers (exactlyOneZero, min, toUint128, zeroFloorSub) |
| 4 | src/libraries/SafeTransferLib.sol | SafeTransferLib | Safe ERC20 transfer/transferFrom with low-level call and return validation |
| 5 | src/libraries/MarketParamsLib.sol | MarketParamsLib | Converts MarketParams struct to its keccak256 Id |
| 6 | src/libraries/ErrorsLib.sol | ErrorsLib | Library exposing all protocol error message string constants |
| 7 | src/libraries/EventsLib.sol | EventsLib | Library exposing all protocol event definitions |
| 8 | src/libraries/ConstantsLib.sol | ConstantsLib | File-level constants (MAX_FEE, ORACLE_PRICE_SCALE, LIQUIDATION_CURSOR, EIP-712 typehashes) |

### Periphery Libraries

| # | File | Library | Description |
|---|------|---------|-------------|
| 9 | src/libraries/periphery/MorphoLib.sol | MorphoLib | View helper to read Morpho storage variables via extSloads |
| 10 | src/libraries/periphery/MorphoBalancesLib.sol | MorphoBalancesLib | View helper exposing getters with expected values after interest accrual |
| 11 | src/libraries/periphery/MorphoStorageLib.sol | MorphoStorageLib | Pure helper to compute Morpho storage slot offsets for direct sload access |

---

## Periphery

No non-library periphery contracts found.

---

## Summary

| Category | Count |
|----------|-------|
| Core Contracts | 1 |
| Interfaces | 5 files (12 interface declarations) |
| Libraries (Core) | 8 |
| Libraries (Periphery) | 3 |
| **Total files** | **17** |
