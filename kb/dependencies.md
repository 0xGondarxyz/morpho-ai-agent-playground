# Morpho Blue Dependencies

## Internal Dependencies

### Morpho.sol imports
| Dependency | Type | Purpose |
|------------|------|---------|
| IMorphoStaticTyping | Interface | Inherited interface |
| IMorphoBase | Interface | Base interface definitions |
| IMorpho*Callback | Interfaces | Callback interfaces for operations |
| IIrm | Interface | Interest rate model calls |
| IERC20 | Interface | Token type for SafeTransferLib |
| IOracle | Interface | Oracle price calls |
| ConstantsLib | Library | Protocol constants |
| UtilsLib | Library | Utility functions |
| EventsLib | Library | Event emissions |
| ErrorsLib | Library | Error messages |
| MathLib | Library | Math operations |
| SharesMathLib | Library | Share calculations |
| MarketParamsLib | Library | Market ID generation |
| SafeTransferLib | Library | Safe token transfers |

### Library Dependencies
```
Morpho.sol
├── ConstantsLib (constants)
├── UtilsLib
│   └── ErrorsLib
├── EventsLib
│   └── IMorpho (Id, MarketParams types)
├── ErrorsLib
├── MathLib
├── SharesMathLib
│   └── MathLib
├── MarketParamsLib
│   └── IMorpho (Id, MarketParams types)
└── SafeTransferLib
    ├── IERC20
    └── ErrorsLib
```

## External Dependencies

### Required External Contracts
| Contract Type | Interface | Purpose | Deployer Provides |
|---------------|-----------|---------|-------------------|
| ERC20 Token | (implied by SafeTransferLib) | Loan token | Address at market creation |
| ERC20 Token | (implied by SafeTransferLib) | Collateral token | Address at market creation |
| Oracle | IOracle | Price feed (collateral/loan) | Address at market creation |
| Interest Rate Model | IIrm | Borrow rate calculation | Address at market creation |

### External Contract Requirements

#### ERC20 Tokens (loanToken, collateralToken)
- Must be ERC-20 compliant
- Can omit return values on transfer/transferFrom
- Balance must only decrease on transfer/transferFrom
- NO fee-on-transfer tokens
- NO rebasing tokens
- NO tokens with burn functions
- Must not re-enter Morpho

#### Oracle (IOracle)
- Must implement `price()` returning uint256
- Price scaled by 1e36 (ORACLE_PRICE_SCALE)
- Price = value of 1 collateral token in loan token terms
- Should not return manipulable instant prices
- Must not revert on price()

#### Interest Rate Model (IIrm)
- Must implement `borrowRate(MarketParams, Market)` returning uint256
- Must implement `borrowRateView(MarketParams, Market)` view returning uint256
- Rate is per-second, scaled by WAD (1e18)
- Should not return extremely high rates
- Must not re-enter Morpho
- Can be address(0) for zero-interest markets

## Protocol Constants

| Constant | Value | Purpose |
|----------|-------|---------|
| MAX_FEE | 0.25e18 (25%) | Maximum protocol fee on interest |
| ORACLE_PRICE_SCALE | 1e36 | Oracle price precision |
| LIQUIDATION_CURSOR | 0.3e18 (30%) | LIF calculation parameter |
| MAX_LIQUIDATION_INCENTIVE_FACTOR | 1.15e18 (15%) | Maximum liquidation bonus |
| VIRTUAL_SHARES | 1e6 | Inflation attack protection |
| VIRTUAL_ASSETS | 1 | Inflation attack protection |

## Governance Dependencies

The Morpho owner can:
- Enable new IRMs (cannot disable)
- Enable new LLTVs (cannot disable)
- Set protocol fee per market (0-25%)
- Set fee recipient
- Transfer ownership

The owner CANNOT:
- Modify existing markets
- Access user funds
- Upgrade the contract
- Disable IRMs/LLTVs
