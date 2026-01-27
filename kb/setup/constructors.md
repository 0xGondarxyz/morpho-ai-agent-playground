# Constructor Parameters

## Morpho
- **File**: `src/Morpho.sol`
- **Signature**: `constructor(address newOwner)`
- **Parameters**:

| Name | Type | Description |
|------|------|-------------|
| newOwner | address | Initial owner of the protocol |

- **Constructor Logic**:
  1. Requires `newOwner != address(0)`
  2. Computes `DOMAIN_SEPARATOR` for EIP-712 signatures
  3. Sets `owner = newOwner`
  4. Emits `SetOwner(newOwner)`

---

## ERC20Mock (Testing)
- **File**: `src/mocks/ERC20Mock.sol`
- **Signature**: none (default constructor)
- **Parameters**: none

---

## OracleMock (Testing)
- **File**: `src/mocks/OracleMock.sol`
- **Signature**: none (default constructor)
- **Parameters**: none
- **Note**: Price must be set via `setPrice()` after deployment

---

## IrmMock (Testing)
- **File**: `src/mocks/IrmMock.sol`
- **Signature**: none (default constructor)
- **Parameters**: none

---

## FlashBorrowerMock (Testing)
- **File**: `src/mocks/FlashBorrowerMock.sol`
- **Signature**: `constructor(IMorpho newMorpho)`
- **Parameters**:

| Name | Type | Description |
|------|------|-------------|
| newMorpho | IMorpho | Address of Morpho contract |

- **Constructor Logic**:
  - Sets `MORPHO = newMorpho` as immutable
