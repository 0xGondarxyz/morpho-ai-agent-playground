# Deployable Contracts

## Full Classification

| Contract | File Path | Deployable | Reason |
|----------|-----------|------------|--------|
| Morpho | `src/Morpho.sol` | Yes | Concrete contract |
| IMorpho | `src/interfaces/IMorpho.sol` | No | Interface |
| IMorphoBase | `src/interfaces/IMorpho.sol` | No | Interface |
| IMorphoStaticTyping | `src/interfaces/IMorpho.sol` | No | Interface |
| IIrm | `src/interfaces/IIrm.sol` | No | Interface |
| IOracle | `src/interfaces/IOracle.sol` | No | Interface |
| IMorphoLiquidateCallback | `src/interfaces/IMorphoCallbacks.sol` | No | Interface |
| IMorphoRepayCallback | `src/interfaces/IMorphoCallbacks.sol` | No | Interface |
| IMorphoSupplyCallback | `src/interfaces/IMorphoCallbacks.sol` | No | Interface |
| IMorphoSupplyCollateralCallback | `src/interfaces/IMorphoCallbacks.sol` | No | Interface |
| IMorphoFlashLoanCallback | `src/interfaces/IMorphoCallbacks.sol` | No | Interface |
| IERC20 | `src/interfaces/IERC20.sol` | No | Interface |
| MathLib | `src/libraries/MathLib.sol` | No | Library |
| SharesMathLib | `src/libraries/SharesMathLib.sol` | No | Library |
| UtilsLib | `src/libraries/UtilsLib.sol` | No | Library |
| ErrorsLib | `src/libraries/ErrorsLib.sol` | No | Library |
| EventsLib | `src/libraries/EventsLib.sol` | No | Library |
| SafeTransferLib | `src/libraries/SafeTransferLib.sol` | No | Library |
| MarketParamsLib | `src/libraries/MarketParamsLib.sol` | No | Library |
| ConstantsLib | `src/libraries/ConstantsLib.sol` | No | Library (file-level) |
| MorphoLib | `src/libraries/periphery/MorphoLib.sol` | No | Library |
| MorphoBalancesLib | `src/libraries/periphery/MorphoBalancesLib.sol` | No | Library |
| MorphoStorageLib | `src/libraries/periphery/MorphoStorageLib.sol` | No | Library |
| ERC20Mock | `src/mocks/ERC20Mock.sol` | Yes (Mock) | Concrete contract |
| OracleMock | `src/mocks/OracleMock.sol` | Yes (Mock) | Concrete contract |
| IrmMock | `src/mocks/IrmMock.sol` | Yes (Mock) | Concrete contract |
| FlashBorrowerMock | `src/mocks/FlashBorrowerMock.sol` | Yes (Mock) | Concrete contract |

## Production Deployable
- **Morpho** (`src/Morpho.sol`) - The only production contract

## Mock Deployable (Testing Only)
- ERC20Mock (`src/mocks/ERC20Mock.sol`)
- OracleMock (`src/mocks/OracleMock.sol`)
- IrmMock (`src/mocks/IrmMock.sol`)
- FlashBorrowerMock (`src/mocks/FlashBorrowerMock.sol`)
