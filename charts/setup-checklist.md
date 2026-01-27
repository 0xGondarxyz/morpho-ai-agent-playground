# Deployment Checklist

## Phase 1: Deploy Core Contract

| Step | Contract | Constructor Call | Notes |
|------|----------|------------------|-------|
| 1 | Morpho | `new Morpho(ownerAddress)` | Owner cannot be address(0) |

## Phase 2: Owner Configuration

| Step | Call | Required | Purpose |
|------|------|----------|---------|
| 2 | `morpho.enableIrm(irmAddress)` | Yes | Enable at least one IRM |
| 3 | `morpho.enableIrm(address(0))` | Optional | Enable zero-interest markets |
| 4 | `morpho.enableLltv(0.80e18)` | Yes | Enable at least one LLTV |
| 5 | `morpho.enableLltv(0.90e18)` | Optional | Enable high LLTV |
| 6 | `morpho.enableLltv(0.945e18)` | Optional | Enable stable-pair LLTV |
| 7 | `morpho.setFeeRecipient(treasury)` | Optional | Set fee recipient |

## Phase 3: Market Creation

| Step | Call | Required | Purpose |
|------|------|----------|---------|
| 8 | `morpho.createMarket(params)` | Yes | Create lending market |
| 9 | `morpho.setFee(params, fee)` | Optional | Set protocol fee (max 25%) |

---

## Pre-Deployment Checklist

### External Contracts Required
- [ ] Loan token address (ERC20 compliant)
- [ ] Collateral token address (ERC20 compliant)
- [ ] Oracle address (implements IOracle)
- [ ] IRM address (implements IIrm) or use address(0)

### Oracle Requirements
- [ ] Returns price scaled by 1e36
- [ ] Price = collateral value / loan value
- [ ] Does not revert on price()
- [ ] Not manipulable in single block

### Token Requirements
- [ ] ERC20 compliant (can omit return values)
- [ ] No fee-on-transfer
- [ ] No rebasing
- [ ] No burn functions that decrease balance externally
- [ ] No reentrancy on transfer

### IRM Requirements
- [ ] Returns rate per second scaled by WAD
- [ ] Does not revert on borrowRate()
- [ ] Does not return extremely high rates
- [ ] No reentrancy

---

## Post-Deployment Verification

### Verify Deployment
```solidity
// Check owner
assert(morpho.owner() == expectedOwner);

// Check DOMAIN_SEPARATOR
assert(morpho.DOMAIN_SEPARATOR() != bytes32(0));
```

### Verify Configuration
```solidity
// Check IRM enabled
assert(morpho.isIrmEnabled(irmAddress) == true);

// Check LLTV enabled
assert(morpho.isLltvEnabled(lltv) == true);

// Check fee recipient (if set)
assert(morpho.feeRecipient() == expectedRecipient);
```

### Verify Market
```solidity
Id id = MarketParamsLib.id(params);

// Check market exists
(,,,, uint128 lastUpdate,) = morpho.market(id);
assert(lastUpdate != 0);

// Check market params stored
MarketParams memory stored = morpho.idToMarketParams(id);
assert(stored.loanToken == params.loanToken);
```

---

## Test Environment Checklist

| Step | Contract | Constructor Call |
|------|----------|------------------|
| 1 | Morpho | `new Morpho(owner)` |
| 2 | ERC20Mock (loan) | `new ERC20Mock()` |
| 3 | ERC20Mock (collateral) | `new ERC20Mock()` |
| 4 | OracleMock | `new OracleMock()` |
| 5 | IrmMock | `new IrmMock()` |
| 6 | FlashBorrowerMock | `new FlashBorrowerMock(morpho)` |

### Test Configuration
| Step | Call |
|------|------|
| 7 | `oracle.setPrice(1e36)` |
| 8 | `morpho.enableIrm(irm)` |
| 9 | `morpho.enableLltv(0.8e18)` |
| 10 | `loanToken.setBalance(user, amount)` |
| 11 | `collateralToken.setBalance(user, amount)` |
| 12 | `morpho.createMarket(params)` |
