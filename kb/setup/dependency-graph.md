# Dependency Graph

## Contract Dependencies Table

| Contract | Depends On |
|----------|------------|
| Morpho | (none - standalone) |
| ERC20Mock | (none) |
| OracleMock | (none) |
| IrmMock | (none) |
| FlashBorrowerMock | Morpho |

## No Dependencies (Can Deploy First)
- **Morpho** - Main protocol, no constructor dependencies
- **ERC20Mock** - Test token, no dependencies
- **OracleMock** - Test oracle, no dependencies
- **IrmMock** - Test IRM, no dependencies

## Has Dependencies (Deploy After)
- **FlashBorrowerMock** - Requires Morpho address

## Runtime Dependencies

While Morpho has no constructor dependencies, it has runtime dependencies through market creation:

```
Market Creation requires:
├── loanToken (ERC20)
├── collateralToken (ERC20)
├── oracle (IOracle)
├── irm (IIrm or address(0))
└── lltv (must be enabled by owner)
```

## Dependency Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                    DEPLOYMENT TIME                          │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌──────────┐   ┌───────────┐   ┌──────────┐   ┌─────────┐ │
│  │  Morpho  │   │ ERC20Mock │   │OracleMock│   │ IrmMock │ │
│  │ (owner)  │   │           │   │          │   │         │ │
│  └────┬─────┘   └───────────┘   └──────────┘   └─────────┘ │
│       │                                                     │
│       │ requires                                            │
│       ▼                                                     │
│  ┌──────────────────┐                                       │
│  │FlashBorrowerMock │                                       │
│  │   (morpho)       │                                       │
│  └──────────────────┘                                       │
│                                                             │
├─────────────────────────────────────────────────────────────┤
│                      RUNTIME                                │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  Morpho.createMarket() requires:                            │
│  ┌──────────┐  ┌──────────────┐  ┌────────┐  ┌────────┐    │
│  │loanToken │  │collateralToken│  │ oracle │  │  irm   │    │
│  │ (ERC20)  │  │   (ERC20)     │  │(IOracle│  │ (IIrm) │    │
│  └──────────┘  └──────────────┘  └────────┘  └────────┘    │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```
