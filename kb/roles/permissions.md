# Role Permissions

## Owner-Only Functions

| Function | Signature | Purpose |
|----------|-----------|---------|
| setOwner | `setOwner(address newOwner)` | Transfer ownership |
| enableIrm | `enableIrm(address irm)` | Whitelist an IRM for market creation |
| enableLltv | `enableLltv(uint256 lltv)` | Whitelist an LLTV for market creation |
| setFee | `setFee(MarketParams memory marketParams, uint256 newFee)` | Set protocol fee on a market |
| setFeeRecipient | `setFeeRecipient(address newFeeRecipient)` | Set fee recipient address |

---

## User Functions (Self or Authorized)

| Function | Signature | Who Can Call |
|----------|-----------|--------------|
| withdraw | `withdraw(MarketParams, uint256 assets, uint256 shares, address onBehalf, address receiver)` | onBehalf or authorized operator |
| borrow | `borrow(MarketParams, uint256 assets, uint256 shares, address onBehalf, address receiver)` | onBehalf or authorized operator |
| withdrawCollateral | `withdrawCollateral(MarketParams, uint256 assets, address onBehalf, address receiver)` | onBehalf or authorized operator |

### Authorization Check
```solidity
function _isSenderAuthorized(address onBehalf) internal view returns (bool) {
    return msg.sender == onBehalf || isAuthorized[onBehalf][msg.sender];
}
```

---

## Permissionless Functions (Anyone for onBehalf)

| Function | Signature | Restrictions |
|----------|-----------|--------------|
| supply | `supply(MarketParams, uint256 assets, uint256 shares, address onBehalf, bytes data)` | Market must exist, onBehalf != address(0) |
| supplyCollateral | `supplyCollateral(MarketParams, uint256 assets, address onBehalf, bytes data)` | Market must exist, onBehalf != address(0) |
| repay | `repay(MarketParams, uint256 assets, uint256 shares, address onBehalf, bytes data)` | Market must exist, onBehalf != address(0) |

---

## Permissionless Functions (Global)

| Function | Signature | Restrictions |
|----------|-----------|--------------|
| createMarket | `createMarket(MarketParams memory marketParams)` | IRM enabled, LLTV enabled, market not exists |
| liquidate | `liquidate(MarketParams, address borrower, uint256 seizedAssets, uint256 repaidShares, bytes data)` | Position must be unhealthy (LTV >= LLTV) |
| flashLoan | `flashLoan(address token, uint256 assets, bytes data)` | Callback must repay, assets != 0 |
| accrueInterest | `accrueInterest(MarketParams memory marketParams)` | Market must exist |
| setAuthorization | `setAuthorization(address authorized, bool newIsAuthorized)` | Must change state |
| setAuthorizationWithSig | `setAuthorizationWithSig(Authorization memory authorization, Signature calldata signature)` | Valid signature, valid nonce |
| extSloads | `extSloads(bytes32[] calldata slots)` | None (view function) |

---

## Permission Summary

| Role | Function Count | Capabilities |
|------|----------------|--------------|
| Owner | 5 exclusive | Protocol configuration |
| Lender | 2 (supply, withdraw) | Deposit/withdraw loan tokens |
| Borrower | 4 (supplyCollateral, borrow, repay, withdrawCollateral) | Full borrowing lifecycle |
| Liquidator | 1 (liquidate) | Liquidate unhealthy positions |
| Authorized | 3 (withdraw, borrow, withdrawCollateral) | Act on behalf of authorizer |
| Anyone | 7+ | Market creation, supply for others, liquidation |

---

## Function Access Control Matrix

| Function | Owner | Self | Authorized | Anyone |
|----------|:-----:|:----:|:----------:|:------:|
| setOwner | X | | | |
| enableIrm | X | | | |
| enableLltv | X | | | |
| setFee | X | | | |
| setFeeRecipient | X | | | |
| supply | | | | X |
| withdraw | | X | X | |
| borrow | | X | X | |
| repay | | | | X |
| supplyCollateral | | | | X |
| withdrawCollateral | | X | X | |
| liquidate | | | | X |
| flashLoan | | | | X |
| createMarket | | | | X |
| accrueInterest | | | | X |
| setAuthorization | | X | | |
| setAuthorizationWithSig | | | | X |
| extSloads | | | | X |

---

## Callback Permissions

Callbacks are triggered during operations when `data.length > 0`:

| Operation | Callback Interface | Who Receives |
|-----------|-------------------|--------------|
| supply | IMorphoSupplyCallback | msg.sender |
| supplyCollateral | IMorphoSupplyCollateralCallback | msg.sender |
| repay | IMorphoRepayCallback | msg.sender |
| liquidate | IMorphoLiquidateCallback | msg.sender |
| flashLoan | IMorphoFlashLoanCallback | msg.sender |

Callbacks execute **before** the final token transfer to Morpho, allowing for:
- Just-in-time token acquisition
- Flash loan-like behavior without flash loan function
- Complex DeFi integrations
