# Initializer Functions

## Summary

None of the Morpho Blue contracts use initializer patterns. The protocol is **not upgradeable** by design.

## Contract Analysis

### Morpho
- **Initializer**: None
- **Pattern**: Immutable, non-upgradeable
- **Rationale**: The protocol is designed to be trustless and immutable

### ERC20Mock
- **Initializer**: None
- **Pattern**: Standard constructor

### OracleMock
- **Initializer**: None
- **Pattern**: Standard constructor

### IrmMock
- **Initializer**: None
- **Pattern**: Standard constructor

### FlashBorrowerMock
- **Initializer**: None
- **Pattern**: Standard constructor

## Design Philosophy

Morpho Blue intentionally avoids:
- Proxy patterns
- Upgradeable contracts
- Initializer functions
- Admin upgrade capabilities

This design ensures:
- Complete immutability after deployment
- Trustless operation
- Full auditability
- No governance risk for upgrades
