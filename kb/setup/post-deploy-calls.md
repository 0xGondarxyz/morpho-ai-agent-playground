# Post-Deployment Configuration

## Morpho

### Required Calls (Owner Only)

| Function | Signature | Why Required |
|----------|-----------|--------------|
| enableIrm | `enableIrm(address irm)` | Markets cannot be created without enabled IRMs |
| enableLltv | `enableLltv(uint256 lltv)` | Markets cannot be created without enabled LLTVs |

### Optional Calls (Owner Only)

| Function | Signature | Purpose |
|----------|-----------|---------|
| setFeeRecipient | `setFeeRecipient(address newFeeRecipient)` | Set where fees accumulate (default: address(0)) |
| setFee | `setFee(MarketParams memory marketParams, uint256 newFee)` | Set protocol fee on a market (default: 0) |
| setOwner | `setOwner(address newOwner)` | Transfer ownership |

### Permissionless Calls (Anyone)

| Function | Signature | Purpose |
|----------|-----------|---------|
| createMarket | `createMarket(MarketParams memory marketParams)` | Create a new lending market |
| accrueInterest | `accrueInterest(MarketParams memory marketParams)` | Force interest accrual |

---

## Function Details

### enableIrm(address irm)
- **Access**: onlyOwner
- **Restrictions**:
  - IRM must not already be enabled
  - Can enable address(0) for zero-interest markets
- **Irreversible**: Cannot disable once enabled
- **Events**: `EnableIrm(irm)`

### enableLltv(uint256 lltv)
- **Access**: onlyOwner
- **Restrictions**:
  - LLTV must not already be enabled
  - LLTV must be < WAD (100%)
- **Irreversible**: Cannot disable once enabled
- **Events**: `EnableLltv(lltv)`

### setFeeRecipient(address newFeeRecipient)
- **Access**: onlyOwner
- **Restrictions**: Must be different from current
- **Warning**: If set to address(0), fees are lost
- **Events**: `SetFeeRecipient(newFeeRecipient)`

### setFee(MarketParams, uint256 newFee)
- **Access**: onlyOwner
- **Restrictions**:
  - Market must exist
  - Fee must be different from current
  - Fee must be <= MAX_FEE (25%)
- **Side Effect**: Accrues interest before changing fee
- **Events**: `SetFee(id, newFee)`

### setOwner(address newOwner)
- **Access**: onlyOwner
- **Restrictions**: Must be different from current
- **Warning**: No two-step transfer, owner can be set to address(0)
- **Events**: `SetOwner(newOwner)`

### createMarket(MarketParams)
- **Access**: Anyone
- **Restrictions**:
  - IRM must be enabled
  - LLTV must be enabled
  - Market must not already exist
- **Side Effect**: Calls IRM.borrowRate() to initialize stateful IRMs
- **Events**: `CreateMarket(id, marketParams)`

---

## Recommended Setup Sequence

```
1. Deploy Morpho(owner)
2. owner.enableIrm(irmAddress)           // Enable IRM(s)
3. owner.enableIrm(address(0))           // Optional: enable zero-interest
4. owner.enableLltv(0.80e18)             // Enable 80% LLTV
5. owner.enableLltv(0.90e18)             // Enable 90% LLTV
6. owner.enableLltv(0.945e18)            // Enable 94.5% LLTV (for stables)
7. owner.setFeeRecipient(treasury)       // Optional: set fee recipient
8. anyone.createMarket(params)           // Create market(s)
9. owner.setFee(params, fee)             // Optional: set fees
```

---

## OracleMock (Testing)

### Required Calls

| Function | Signature | Why Required |
|----------|-----------|--------------|
| setPrice | `setPrice(uint256 newPrice)` | Price is 0 by default, must be set for markets to function |

---

## ERC20Mock (Testing)

### Optional Calls

| Function | Signature | Purpose |
|----------|-----------|---------|
| setBalance | `setBalance(address account, uint256 amount)` | Mint/set tokens for testing |
| approve | `approve(address spender, uint256 amount)` | Standard ERC20 approve |
