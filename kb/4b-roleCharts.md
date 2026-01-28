# Role Charts

## Roles Identified

| Role | Description | How Assigned | Can Be Revoked |
|------|-------------|--------------|----------------|
| Owner | Protocol administrator | constructor, setOwner() | Yes (transfer only) |
| Authorized | Delegated manager for specific user | setAuthorization(), setAuthorizationWithSig() | Yes |
| Anyone | Permissionless access | N/A | N/A |

## Permission Matrix

| Function | Owner | Authorized | Self | Anyone |
|----------|-------|------------|------|--------|
| **Admin Functions** |
| setOwner | ✅ | ❌ | ❌ | ❌ |
| enableIrm | ✅ | ❌ | ❌ | ❌ |
| enableLltv | ✅ | ❌ | ❌ | ❌ |
| setFee | ✅ | ❌ | ❌ | ❌ |
| setFeeRecipient | ✅ | ❌ | ❌ | ❌ |
| **Market Functions** |
| createMarket | ✅ | ✅ | ✅ | ✅ |
| supply | ✅ | ✅ | ✅ | ✅ |
| withdraw | ✅ | ✅ (for authorizer) | ✅ | ❌ |
| borrow | ✅ | ✅ (for authorizer) | ✅ | ❌ |
| repay | ✅ | ✅ | ✅ | ✅ |
| supplyCollateral | ✅ | ✅ | ✅ | ✅ |
| withdrawCollateral | ✅ | ✅ (for authorizer) | ✅ | ❌ |
| liquidate | ✅ | ✅ | ✅ | ✅ |
| flashLoan | ✅ | ✅ | ✅ | ✅ |
| **Authorization** |
| setAuthorization | ✅ | ✅ | ✅ | ✅ |
| setAuthorizationWithSig | ✅ | ✅ | ✅ | ✅ |
| **View** |
| accrueInterest | ✅ | ✅ | ✅ | ✅ |
| extSloads | ✅ | ✅ | ✅ | ✅ |

## Authorization Logic

```solidity
function _isSenderAuthorized(address onBehalf) internal view returns (bool) {
    return msg.sender == onBehalf || isAuthorized[onBehalf][msg.sender];
}
```

Functions requiring authorization for `onBehalf`:
- `withdraw(onBehalf)` - withdraw from another's supply position
- `borrow(onBehalf)` - borrow against another's collateral
- `withdrawCollateral(onBehalf)` - withdraw another's collateral

## Role Hierarchy

```mermaid
graph TD
    Owner["Owner<br/>(Single Address)"]
    Authorized["Authorized<br/>(Per-User Delegation)"]
    Self["Self<br/>(msg.sender == onBehalf)"]
    Anyone["Anyone<br/>(Permissionless)"]

    Owner -->|"onlyOwner modifier"| AdminFunctions["Admin Functions<br/>setOwner, enableIrm, enableLltv,<br/>setFee, setFeeRecipient"]

    Authorized -->|"_isSenderAuthorized"| AuthFunctions["Authorized Functions<br/>withdraw, borrow,<br/>withdrawCollateral<br/>(on behalf of authorizer)"]

    Self -->|"msg.sender == onBehalf"| AuthFunctions

    Anyone -->|"No restriction"| PublicFunctions["Public Functions<br/>createMarket, supply, repay,<br/>supplyCollateral, liquidate,<br/>flashLoan, accrueInterest"]
```

## Authorization Flow

```mermaid
sequenceDiagram
    participant User
    participant Authorized as Authorized Address
    participant Morpho

    Note over User,Morpho: Method 1: Direct Authorization
    User->>Morpho: setAuthorization(authorized, true)
    Morpho->>Morpho: isAuthorized[user][authorized] = true
    Morpho-->>User: emit SetAuthorization

    Note over Authorized,Morpho: Authorized can now act on behalf of User
    Authorized->>Morpho: withdraw(params, assets, shares, user, receiver)
    Morpho->>Morpho: _isSenderAuthorized(user)?
    Note over Morpho: user == authorized? NO<br/>isAuthorized[user][authorized]? YES
    Morpho->>Morpho: Process withdrawal
    Morpho-->>Authorized: (assets, shares)

    Note over User,Morpho: Method 2: Signature-Based Authorization
    User->>User: Sign EIP-712 Authorization
    Authorized->>Morpho: setAuthorizationWithSig(auth, sig)
    Morpho->>Morpho: Verify signature
    Morpho->>Morpho: Check nonce, deadline
    Morpho->>Morpho: isAuthorized[authorizer][authorized] = isAuthorized
    Morpho-->>Authorized: emit SetAuthorization
```

## Access Control Summary

```mermaid
flowchart TD
    subgraph Checks["Access Control Checks"]
        Check1["onlyOwner modifier"]
        Check2["_isSenderAuthorized()"]
        Check3["No check (permissionless)"]
    end

    subgraph Functions["Protected Functions"]
        F1["setOwner<br/>enableIrm<br/>enableLltv<br/>setFee<br/>setFeeRecipient"]
        F2["withdraw<br/>borrow<br/>withdrawCollateral"]
        F3["createMarket<br/>supply<br/>repay<br/>supplyCollateral<br/>liquidate<br/>flashLoan"]
    end

    Check1 --> F1
    Check2 --> F2
    Check3 --> F3
```

## EIP-712 Authorization Struct

```solidity
struct Authorization {
    address authorizer;    // The address granting authorization
    address authorized;    // The address receiving authorization
    bool isAuthorized;     // True to grant, false to revoke
    uint256 nonce;         // Prevents replay attacks
    uint256 deadline;      // Signature expiration timestamp
}
```

## Key Security Notes

1. **Owner Powers:**
   - Can enable IRMs and LLTVs (cannot disable)
   - Can set fees up to 25%
   - Can transfer ownership (no two-step)
   - Cannot steal user funds directly

2. **Authorization Risks:**
   - Authorized address can drain authorizer's positions
   - Revocation is immediate via `setAuthorization(addr, false)`
   - Signatures have deadlines for time-limited authorization

3. **Permissionless Functions:**
   - Anyone can supply on behalf of any address
   - Anyone can repay on behalf of any address
   - Anyone can liquidate unhealthy positions
