# Role Summaries

## Owner

### Actions Available

| Action | Function | Prerequisites |
|--------|----------|---------------|
| Transfer Ownership | `setOwner(address)` | Be owner, new owner != current |
| Enable IRM | `enableIrm(address)` | Be owner, IRM not already enabled |
| Enable LLTV | `enableLltv(uint256)` | Be owner, LLTV not enabled, LLTV < 100% |
| Set Market Fee | `setFee(MarketParams, uint256)` | Be owner, market exists, fee <= 25% |
| Set Fee Recipient | `setFeeRecipient(address)` | Be owner, different from current |

### Purpose
Configure protocol-wide parameters and manage market fees.

### Trust Requirements
- **Highest trust level** - controls protocol configuration
- Cannot access user funds directly
- Cannot modify existing market parameters (oracle, IRM, LLTV)
- Cannot pause or upgrade the protocol

### Risks
- Can enable malicious IRMs (but users choose markets)
- Can set fee recipient to address(0) (losing fees)
- Can transfer ownership to address(0) (bricking owner functions)
- Single point of failure (no multisig requirement at protocol level)

---

## Lender

### Actions Available

| Action | Function | Prerequisites |
|--------|----------|---------------|
| Supply | `supply(params, assets, shares, onBehalf, data)` | Market exists, approved tokens |
| Withdraw | `withdraw(params, assets, shares, onBehalf, receiver)` | Has shares, sufficient liquidity |

### Purpose
Earn interest by providing liquidity to borrowers.

### Value Proposition
- Earn interest on supplied assets
- Interest compounds automatically via share price increase
- No lockup - can withdraw if liquidity available
- Can supply for other addresses

### Prerequisites
- Market must exist
- Must approve Morpho to spend loan tokens (or use callback)
- For withdraw: must have supply shares or be authorized

### Risks
- **Smart contract risk**: Protocol bugs
- **Bad debt socialization**: If liquidations fail to cover debt, lenders share losses
- **Liquidity risk**: May not withdraw if utilization is high
- **Oracle risk**: Manipulated prices could lead to bad debt
- **IRM risk**: Poor IRM could lead to suboptimal rates

---

## Borrower

### Actions Available

| Action | Function | Prerequisites |
|--------|----------|---------------|
| Supply Collateral | `supplyCollateral(params, assets, onBehalf, data)` | Market exists, approved collateral |
| Borrow | `borrow(params, assets, shares, onBehalf, receiver)` | Sufficient collateral, healthy after |
| Repay | `repay(params, assets, shares, onBehalf, data)` | Has debt, approved loan tokens |
| Withdraw Collateral | `withdrawCollateral(params, assets, onBehalf, receiver)` | Healthy after withdrawal |

### Purpose
Access liquidity by depositing collateral and borrowing.

### Value Proposition
- Leverage positions without selling assets
- Isolated markets - choose your risk exposure
- No forced liquidation timing (as long as healthy)

### Prerequisites
- Market must exist
- Must have collateral to deposit
- Must maintain LTV < LLTV to avoid liquidation

### Risks
- **Liquidation risk**: If LTV >= LLTV, position can be liquidated
- **Interest accumulation**: Debt grows over time
- **Oracle risk**: Price movements affect health
- **No grace period**: Liquidation happens instantly when unhealthy

### Health Calculation
```
LTV = borrowedValue / collateralValue
Healthy = LTV < LLTV
```

---

## Liquidator

### Actions Available

| Action | Function | Prerequisites |
|--------|----------|---------------|
| Liquidate | `liquidate(params, borrower, seizedAssets, repaidShares, data)` | Position unhealthy |

### Purpose
Maintain protocol solvency by liquidating underwater positions.

### Value Proposition
- Earn liquidation incentive (up to 15%)
- No close factor - can liquidate entire position
- Callback support for flash loan-like execution

### Prerequisites
- Target position must have LTV >= LLTV
- Must have/acquire loan tokens to repay debt

### Mechanics
1. Position becomes unhealthy (LTV >= LLTV)
2. Liquidator calls `liquidate()`
3. Morpho transfers collateral to liquidator
4. Callback executes (if data provided)
5. Liquidator repays debt to Morpho

### Liquidation Incentive Factor (LIF)
```
LIF = min(1.15, 1 / (1 - 0.3 * (1 - LLTV)))
```
- Higher LLTV = lower incentive
- Maximum incentive = 15%

### Risks
- **Competition**: MEV and other liquidators
- **Bad debt**: If collateral < debt, liquidator takes loss or partial liquidation
- **Price movement**: Oracle update before execution

---

## Authorized Operator

### Actions Available

| Action | Function | Prerequisites |
|--------|----------|---------------|
| Withdraw for User | `withdraw(...)` | Authorized by user |
| Borrow for User | `borrow(...)` | Authorized by user |
| Withdraw Collateral for User | `withdrawCollateral(...)` | Authorized by user |

### Purpose
Manage positions on behalf of another address (e.g., smart contract wallets, bundlers).

### How to Grant
```solidity
// Direct call
morpho.setAuthorization(operator, true);

// Via signature (EIP-712)
morpho.setAuthorizationWithSig(authorization, signature);
```

### How to Revoke
```solidity
morpho.setAuthorization(operator, false);
```

### Trust Requirements
- **High trust** - can withdraw user's assets
- Should only authorize trusted contracts
- Useful for bundler contracts, meta-transactions

### Risks
- Authorized operator can drain position
- No partial authorization (all or nothing)
- Must trust operator implementation

---

## Flash Borrower

### Actions Available

| Action | Function | Prerequisites |
|--------|----------|---------------|
| Flash Loan | `flashLoan(token, assets, data)` | Implement callback, repay in same tx |

### Purpose
Borrow assets without collateral for single-transaction operations.

### Value Proposition
- **Free** - no fee
- Access to all liquidity + collateral in contract
- Useful for liquidations, arbitrage, position management

### Prerequisites
- Must implement `IMorphoFlashLoanCallback`
- Must repay exact amount borrowed in callback
- Amount must be > 0

### Mechanics
1. Call `flashLoan(token, assets, data)`
2. Morpho transfers `assets` to caller
3. Morpho calls `onMorphoFlashLoan(assets, data)` on caller
4. Callback must approve/transfer tokens back
5. Morpho pulls tokens from caller

### Risks
- **Reentrancy safety**: Morpho is reentrancy-safe by design
- **Callback failure**: Transaction reverts if callback fails

---

## Fee Recipient

### Actions Available

| Action | Function | Prerequisites |
|--------|----------|---------------|
| (passive) | Receives supply shares | Set by owner |

### Purpose
Receive protocol fees as supply shares in each market.

### Mechanics
- On interest accrual, if `market.fee > 0`:
  - Fee amount = interest * fee rate
  - Fee shares minted to feeRecipient
- Shares accumulate across all markets with fees

### To Claim Fees
- Call `withdraw()` with own address as `onBehalf`
- Same as any other lender withdrawal

### Risks
- If set to address(0), fees are permanently lost
- If set to wrong address, fees go to wrong recipient
- No retroactive recovery of fees
