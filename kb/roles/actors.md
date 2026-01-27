# Protocol Actors

## Protocol Roles (Privileged)

| Role | How Identified | Trust Level | Functions |
|------|----------------|-------------|-----------|
| Owner | `onlyOwner` modifier, `msg.sender == owner` | Highest | setOwner, enableIrm, enableLltv, setFee, setFeeRecipient |

### Owner Capabilities
- Enable new IRMs (cannot disable)
- Enable new LLTVs (cannot disable)
- Set protocol fee (0-25%) per market
- Set fee recipient
- Transfer ownership

### Owner Limitations
- Cannot modify existing market parameters
- Cannot access user funds
- Cannot pause/unpause
- Cannot upgrade contract
- Cannot disable IRMs/LLTVs

---

## User Roles

| Role | Description | Key Actions |
|------|-------------|-------------|
| Lender | Supplies loan tokens to earn interest | supply, withdraw |
| Borrower | Deposits collateral and borrows | supplyCollateral, borrow, repay, withdrawCollateral |
| Liquidator | Liquidates unhealthy positions | liquidate |
| Flash Borrower | Takes uncollateralized flash loans | flashLoan |

### Lender
- **Entry**: Call `supply()` with loan tokens
- **Exit**: Call `withdraw()` to retrieve assets
- **Earning**: Accrues interest proportional to supply shares
- **Risk**: Bad debt socialization, smart contract risk

### Borrower
- **Entry**: Call `supplyCollateral()` then `borrow()`
- **Exit**: Call `repay()` then `withdrawCollateral()`
- **Cost**: Pays interest on borrowed amount
- **Risk**: Liquidation if LTV >= LLTV

### Liquidator
- **Trigger**: When borrower's LTV >= LLTV
- **Action**: Repay debt, seize collateral + incentive
- **Profit**: Liquidation incentive factor (up to 15%)
- **No close factor**: Can liquidate entire position

### Flash Borrower
- **Action**: Borrow any token amount, repay in same tx
- **Cost**: Free (no fee)
- **Access**: All contract liquidity + collateral

---

## System Roles

| Role | Description | How Granted |
|------|-------------|-------------|
| Authorized | Can act on behalf of another user | `setAuthorization()` or `setAuthorizationWithSig()` |
| Fee Recipient | Receives protocol fees as supply shares | `setFeeRecipient()` by owner |

### Authorized Operator
- **Grant**: User calls `setAuthorization(operator, true)` or signs EIP-712 message
- **Capabilities**:
  - `withdraw()` on behalf of authorizer
  - `borrow()` on behalf of authorizer
  - `withdrawCollateral()` on behalf of authorizer
- **Cannot**:
  - `supply()` on behalf (no authorization needed, anyone can supply for anyone)
  - `supplyCollateral()` on behalf (no authorization needed)
  - `repay()` on behalf (no authorization needed)
- **Revoke**: User calls `setAuthorization(operator, false)`

### Fee Recipient
- **Set by**: Owner via `setFeeRecipient()`
- **Receives**: Portion of interest as supply shares
- **Mechanism**: On interest accrual, feeShares minted to feeRecipient
- **Warning**: If address(0), fees are lost

---

## Permissionless Actions

| Action | Function | Restrictions |
|--------|----------|--------------|
| Create Market | `createMarket(MarketParams)` | IRM and LLTV must be enabled |
| Supply | `supply(...)` | Market must exist |
| Supply Collateral | `supplyCollateral(...)` | Market must exist |
| Repay | `repay(...)` | Market must exist, debt must exist |
| Liquidate | `liquidate(...)` | Position must be unhealthy |
| Flash Loan | `flashLoan(...)` | Callback must repay |
| Accrue Interest | `accrueInterest(...)` | Market must exist |
| Read Storage | `extSloads(...)` | None |

---

## Authorization Matrix

| Function | Self | Authorized | Anyone |
|----------|:----:|:----------:|:------:|
| supply | - | - | Yes (onBehalf) |
| withdraw | Yes | Yes | No |
| borrow | Yes | Yes | No |
| repay | - | - | Yes (onBehalf) |
| supplyCollateral | - | - | Yes (onBehalf) |
| withdrawCollateral | Yes | Yes | No |
| liquidate | - | - | Yes |
| flashLoan | - | - | Yes |
| setAuthorization | Yes | - | No |
| createMarket | - | - | Yes |
| accrueInterest | - | - | Yes |
