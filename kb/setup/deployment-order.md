# Deployment Order

## Production Deployment

### Level 1 (No Dependencies)
1. **Morpho**
   - Requires: owner address
   - Constructor: `new Morpho(ownerAddress)`

That's it for production. Morpho Blue is a single contract deployment.

---

## Test Environment Deployment

### Level 1 (No Dependencies)
Deploy in any order:
1. **Morpho** - `new Morpho(owner)`
2. **ERC20Mock** (loan token) - `new ERC20Mock()`
3. **ERC20Mock** (collateral token) - `new ERC20Mock()`
4. **OracleMock** - `new OracleMock()`
5. **IrmMock** - `new IrmMock()`

### Level 2 (Depends on Level 1)
6. **FlashBorrowerMock**
   - Requires: Morpho address
   - Constructor: `new FlashBorrowerMock(morpho)`

---

## Post-Deployment Setup (Required)

After deploying Morpho, the owner must:

### Step 1: Enable IRMs
```solidity
morpho.enableIrm(irmAddress);
// or for zero-interest markets:
morpho.enableIrm(address(0));
```

### Step 2: Enable LLTVs
```solidity
morpho.enableLltv(0.8e18);  // 80% LLTV
morpho.enableLltv(0.9e18);  // 90% LLTV
// etc.
```

### Step 3: (Optional) Set Fee Recipient
```solidity
morpho.setFeeRecipient(feeRecipientAddress);
```

### Step 4: Create Markets
```solidity
MarketParams memory params = MarketParams({
    loanToken: loanTokenAddress,
    collateralToken: collateralTokenAddress,
    oracle: oracleAddress,
    irm: irmAddress,
    lltv: 0.8e18
});
morpho.createMarket(params);
```

### Step 5: (Optional) Set Fees on Markets
```solidity
morpho.setFee(params, 0.1e18);  // 10% fee
```

---

## Summary

| Phase | Contract | Dependencies | Constructor Args |
|-------|----------|--------------|------------------|
| 1 | Morpho | None | owner address |
| Post | enableIrm | Morpho deployed | IRM address |
| Post | enableLltv | Morpho deployed | LLTV value |
| Post | createMarket | IRMs & LLTVs enabled | MarketParams |

**Total Production Contracts**: 1
**Deployment Levels**: 1
