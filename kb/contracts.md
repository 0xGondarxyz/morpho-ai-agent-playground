# Morpho Blue Contracts

## Contract Classification

| Contract | File Path | Type | Purpose |
|----------|-----------|------|---------|
| Morpho | `src/Morpho.sol` | Concrete | Main lending protocol singleton |
| IMorpho | `src/interfaces/IMorpho.sol` | Interface | Main interface with struct return types |
| IMorphoBase | `src/interfaces/IMorpho.sol` | Interface | Base interface with all function signatures |
| IMorphoStaticTyping | `src/interfaces/IMorpho.sol` | Interface | Interface with static return types |
| IIrm | `src/interfaces/IIrm.sol` | Interface | Interest Rate Model interface |
| IOracle | `src/interfaces/IOracle.sol` | Interface | Price oracle interface |
| IMorphoLiquidateCallback | `src/interfaces/IMorphoCallbacks.sol` | Interface | Liquidation callback |
| IMorphoRepayCallback | `src/interfaces/IMorphoCallbacks.sol` | Interface | Repay callback |
| IMorphoSupplyCallback | `src/interfaces/IMorphoCallbacks.sol` | Interface | Supply callback |
| IMorphoSupplyCollateralCallback | `src/interfaces/IMorphoCallbacks.sol` | Interface | Supply collateral callback |
| IMorphoFlashLoanCallback | `src/interfaces/IMorphoCallbacks.sol` | Interface | Flash loan callback |
| IERC20 | `src/interfaces/IERC20.sol` | Interface | Empty ERC20 interface (for SafeTransferLib) |
| MathLib | `src/libraries/MathLib.sol` | Library | Fixed-point arithmetic |
| SharesMathLib | `src/libraries/SharesMathLib.sol` | Library | Share/asset conversions with virtual shares |
| UtilsLib | `src/libraries/UtilsLib.sol` | Library | Utility functions (min, toUint128, etc.) |
| ErrorsLib | `src/libraries/ErrorsLib.sol` | Library | Error message constants |
| EventsLib | `src/libraries/EventsLib.sol` | Library | Event definitions |
| SafeTransferLib | `src/libraries/SafeTransferLib.sol` | Library | Safe ERC20 transfer wrappers |
| MarketParamsLib | `src/libraries/MarketParamsLib.sol` | Library | Market params to ID conversion |
| ConstantsLib | `src/libraries/ConstantsLib.sol` | Library | Protocol constants |
| MorphoLib | `src/libraries/periphery/MorphoLib.sol` | Library | Storage access helpers (periphery) |
| MorphoBalancesLib | `src/libraries/periphery/MorphoBalancesLib.sol` | Library | Expected balance getters (periphery) |
| MorphoStorageLib | `src/libraries/periphery/MorphoStorageLib.sol` | Library | Storage slot calculations (periphery) |
| ERC20Mock | `src/mocks/ERC20Mock.sol` | Concrete (Mock) | Test ERC20 token |
| OracleMock | `src/mocks/OracleMock.sol` | Concrete (Mock) | Test oracle with setable price |
| IrmMock | `src/mocks/IrmMock.sol` | Concrete (Mock) | Test IRM (utilization-based) |
| FlashBorrowerMock | `src/mocks/FlashBorrowerMock.sol` | Concrete (Mock) | Test flash loan borrower |

## Contract Categories

### Core Protocol
- **Morpho** - The single deployable production contract

### Interfaces
- **IMorpho/IMorphoBase/IMorphoStaticTyping** - Main protocol interfaces
- **IIrm** - Interest rate model interface
- **IOracle** - Price oracle interface
- **IMorphoCallbacks** - 5 callback interfaces for supply, repay, liquidate operations

### Internal Libraries (used by Morpho.sol)
- **MathLib** - WAD math operations
- **SharesMathLib** - Virtual shares for inflation attack protection
- **UtilsLib** - Helper functions
- **ErrorsLib** - Revert strings
- **EventsLib** - Event definitions
- **SafeTransferLib** - Safe ERC20 transfers
- **MarketParamsLib** - Market ID generation
- **ConstantsLib** - Protocol constants (MAX_FEE, LIQUIDATION_CURSOR, etc.)

### Periphery Libraries (for integrators)
- **MorphoLib** - Read storage via extSloads
- **MorphoBalancesLib** - Expected balances with accrued interest
- **MorphoStorageLib** - Storage slot calculations

### Mocks (testing only)
- **ERC20Mock** - Simple ERC20 for testing
- **OracleMock** - Oracle with setPrice function
- **IrmMock** - Simple utilization-based IRM
- **FlashBorrowerMock** - Flash loan consumer example
