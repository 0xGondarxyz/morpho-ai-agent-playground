# Protocol Contracts

## Project Type
Foundry

## Source Directory
src/

## Core Contracts
- `src/Morpho.sol` - Singleton contract managing isolated lending markets with permissionless market creation, share-based accounting, and EIP-712 authorization

## Interfaces
- `src/interfaces/IMorpho.sol` - Core interfaces (IMorphoBase, IMorphoStaticTyping, IMorpho) defining the protocol's public API with MarketParams, Position, Market structs
- `src/interfaces/IIrm.sol` - Interface for Interest Rate Models with borrowRate and borrowRateView functions
- `src/interfaces/IERC20.sol` - Empty interface to prevent calling transfer/transferFrom instead of safeTransfer/safeTransferFrom
- `src/interfaces/IMorphoCallbacks.sol` - Callback interfaces for liquidate, repay, supply, supplyCollateral, and flashLoan operations
- `src/interfaces/IOracle.sol` - Interface for oracles returning collateral price scaled by 1e36

## Libraries
- `src/libraries/ConstantsLib.sol` - Protocol constants (MAX_FEE, ORACLE_PRICE_SCALE, LIQUIDATION_CURSOR, EIP-712 typehashes)
- `src/libraries/MathLib.sol` - Fixed-point arithmetic with WAD (1e18) precision including wMulDown, wDivUp, wTaylorCompounded
- `src/libraries/SharesMathLib.sol` - Shares management with virtual shares (1e6) to prevent inflation attacks
- `src/libraries/UtilsLib.sol` - Utility helpers (exactlyOneZero, min, toUint128, zeroFloorSub)
- `src/libraries/ErrorsLib.sol` - Error messages as string constants for all protocol errors
- `src/libraries/EventsLib.sol` - All events emitted by the Morpho contract
- `src/libraries/SafeTransferLib.sol` - Safe token transfer handling for non-standard ERC20s
- `src/libraries/MarketParamsLib.sol` - Converts MarketParams to market ID via keccak256 hash

## Periphery
- `src/libraries/periphery/MorphoLib.sol` - Helper library to access Morpho storage via extSloads (supply/borrow shares, collateral, market totals)
- `src/libraries/periphery/MorphoBalancesLib.sol` - Getters with expected values after interest accrual for integrators
- `src/libraries/periphery/MorphoStorageLib.sol` - Storage slot position helpers for direct storage access

## Mocks (Test Only)
- `src/mocks/OracleMock.sol` - Mock oracle with settable price for testing
- `src/mocks/IrmMock.sol` - Mock IRM where x% utilization = x% APR
- `src/mocks/ERC20Mock.sol` - Mock ERC20 token with setBalance function
- `src/mocks/FlashBorrowerMock.sol` - Mock flash loan borrower for testing
- `src/mocks/interfaces/IERC20.sol` - Full ERC20 interface for mock contracts

---
Total: 20 contracts/libraries/interfaces
