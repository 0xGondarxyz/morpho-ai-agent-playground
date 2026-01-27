# Role Permission Matrix

## Function Permission Matrix

| Function | Owner | Lender | Borrower | Liquidator | Authorized | Anyone |
|----------|:-----:|:------:|:--------:|:----------:|:----------:|:------:|
| **Protocol Config** |
| setOwner | X | | | | | |
| enableIrm | X | | | | | |
| enableLltv | X | | | | | |
| setFee | X | | | | | |
| setFeeRecipient | X | | | | | |
| **Supply/Lending** |
| supply | | X | | | | X* |
| withdraw | | X | | | X | |
| **Borrowing** |
| supplyCollateral | | | X | | | X* |
| borrow | | | X | | X | |
| repay | | | X | | | X* |
| withdrawCollateral | | | X | | X | |
| **Liquidation** |
| liquidate | | | | X | | X |
| **Flash Loans** |
| flashLoan | | | | | | X |
| **Market Management** |
| createMarket | | | | | | X |
| accrueInterest | | | | | | X |
| **Authorization** |
| setAuthorization | | X | X | | | |
| setAuthorizationWithSig | | | | | | X |
| **View** |
| extSloads | | | | | | X |

**Legend:**
- X = can call for self
- X* = can call for onBehalf (supplying/repaying for someone else)

---

## Detailed Permission Breakdown

### Owner (5 functions)
| Function | Modifier | Restrictions |
|----------|----------|--------------|
| setOwner | onlyOwner | newOwner != owner |
| enableIrm | onlyOwner | !isIrmEnabled[irm] |
| enableLltv | onlyOwner | !isLltvEnabled[lltv], lltv < WAD |
| setFee | onlyOwner | market exists, newFee != fee, newFee <= MAX_FEE |
| setFeeRecipient | onlyOwner | newFeeRecipient != feeRecipient |

### Self or Authorized (3 functions)
| Function | Check | Can Act For |
|----------|-------|-------------|
| withdraw | _isSenderAuthorized(onBehalf) | self, authorized users |
| borrow | _isSenderAuthorized(onBehalf) | self, authorized users |
| withdrawCollateral | _isSenderAuthorized(onBehalf) | self, authorized users |

### Anyone for OnBehalf (3 functions)
| Function | Restriction | Use Case |
|----------|-------------|----------|
| supply | onBehalf != address(0) | Gift supply, bundlers |
| supplyCollateral | onBehalf != address(0) | Help collateralize, bundlers |
| repay | onBehalf != address(0) | Help repay, liquidation bots |

### Global Permissionless (5 functions)
| Function | Restrictions |
|----------|--------------|
| createMarket | IRM enabled, LLTV enabled, market not exists |
| liquidate | LTV >= LLTV |
| flashLoan | assets != 0, callback repays |
| accrueInterest | market exists |
| extSloads | none |

---

## Callback Permissions

| Callback | Triggered By | Executed On |
|----------|--------------|-------------|
| onMorphoSupply | supply() with data | msg.sender |
| onMorphoSupplyCollateral | supplyCollateral() with data | msg.sender |
| onMorphoRepay | repay() with data | msg.sender |
| onMorphoLiquidate | liquidate() with data | msg.sender |
| onMorphoFlashLoan | flashLoan() always | msg.sender |

---

## Authorization Scope

| Authorized Can | Authorized Cannot |
|----------------|-------------------|
| withdraw(onBehalf=authorizer) | supply (no auth needed) |
| borrow(onBehalf=authorizer) | supplyCollateral (no auth needed) |
| withdrawCollateral(onBehalf=authorizer) | repay (no auth needed) |
| | setAuthorization (only self) |
| | any owner function |
