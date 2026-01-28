# Protocol Contracts

## Project Type
Foundry

## Source Directory
src/

## Core Contracts
- `src/Morpho.sol` - The Morpho contract - noncustodial lending protocol (singleton)

## Interfaces
- `src/interfaces/IMorpho.sol` - Main interface defining Morpho functions, structs (MarketParams, Position, Market, Authorization, Signature)
- `src/interfaces/IMorphoCallbacks.sol` - Callback interfaces for supply, repay, liquidate, supplyCollateral, flashLoan
- `src/interfaces/IIrm.sol` - Interface for Interest Rate Models (borrowRate, borrowRateView)
- `src/interfaces/IOracle.sol` - Interface for oracles (price function, scaled by 1e36)
- `src/interfaces/IERC20.sol` - Empty ERC20 interface (forces use of SafeTransferLib)

## Core Libraries
- `src/libraries/SharesMathLib.sol` - Share/asset conversion with virtual shares (1e6) to prevent inflation attacks
- `src/libraries/MathLib.sol` - Fixed-point arithmetic (WAD = 1e18), Taylor expansion for compound interest
- `src/libraries/UtilsLib.sol` - Helpers: exactlyOneZero, min, toUint128, zeroFloorSub
- `src/libraries/ConstantsLib.sol` - Protocol constants (MAX_FEE, ORACLE_PRICE_SCALE, LIQUIDATION_CURSOR, etc.)
- `src/libraries/ErrorsLib.sol` - Error message strings
- `src/libraries/EventsLib.sol` - Event definitions
- `src/libraries/SafeTransferLib.sol` - Safe ERC20 transfer wrappers
- `src/libraries/MarketParamsLib.sol` - Market ID computation (keccak256 of MarketParams)

## Periphery Libraries
- `src/libraries/periphery/MorphoLib.sol` - Helper to access Morpho storage via extSloads
- `src/libraries/periphery/MorphoBalancesLib.sol` - Getters with expected values after interest accrual
- `src/libraries/periphery/MorphoStorageLib.sol` - Storage slot computation helpers

## Mocks (Test Only)
- `src/mocks/OracleMock.sol` - Mock oracle for testing
- `src/mocks/IrmMock.sol` - Mock IRM for testing
- `src/mocks/ERC20Mock.sol` - Mock ERC20 for testing
- `src/mocks/FlashBorrowerMock.sol` - Mock flash loan borrower for testing

---
Total: 17 contracts (1 core + 5 interfaces + 8 core libraries + 3 periphery libraries)
