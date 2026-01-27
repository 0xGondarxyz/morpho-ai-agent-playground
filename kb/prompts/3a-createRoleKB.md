# Create Role Knowledge Base

Document role permissions and summaries.

---

## Input Files Required

- `kb/roles/actors.md` (created by 2a-createSetupKB.md)
- `kb/setup/deployable-contracts.md`

---

## Step 1: Map Role Permissions

### Task
Create function-to-role permission matrix.

### Input
- `kb/roles/actors.md`
- `kb/setup/deployable-contracts.md`

### Instructions

For each deployable contract (read .sol from deployable-contracts.md):
1. List every external/public function
2. For each function, determine which role(s) can call it:
   - Check access control modifiers
   - Check msg.sender requirements
   - No restriction = permissionless
3. Categorize:
   - **Exclusive**: Only one role
   - **Self-or-Authorized**: User or their operator
   - **Permissionless**: Anyone

### Output
Create: `kb/roles/permissions.md`

Example structure:

    # Role Permissions

    ## Owner-Only Functions
    | Function | Signature | Purpose |
    |----------|-----------|---------|
    | setFee | `setFee(Id, uint256)` | Set protocol fee |
    | enableIrm | `enableIrm(address)` | Whitelist IRM |

    ## User Functions (Self or Authorized)
    | Function | Signature | Who Can Call |
    |----------|-----------|--------------|
    | withdraw | `withdraw(...)` | Owner or authorized |
    | repay | `repay(...)` | Anyone for onBehalf |

    ## Permissionless Functions
    | Function | Signature | Restrictions |
    |----------|-----------|--------------|
    | createMarket | `createMarket(...)` | IRM/LLTV must be enabled |
    | liquidate | `liquidate(...)` | Position must be unhealthy |

    ## Permission Summary
    | Role | Function Count |
    |------|----------------|
    | Owner | X exclusive |
    | Lender | Y functions |
    | Anyone | Z permissionless |

---

## Step 2: Create Role Summaries

### Task
Create per-role action guides.

### Input
- `kb/roles/actors.md`
- `kb/roles/permissions.md`

### Instructions

For each role in actors.md:
1. List actions available (from permissions.md)
2. Document prerequisites
3. Document value proposition
4. Document risks

### Output
Create: `kb/roles/role-summaries.md`

Example structure:

    # Role Summaries

    ## Owner

    ### Actions Available
    | Action | Function | Prerequisites |
    |--------|----------|---------------|
    | Enable IRM | enableIrm() | Be owner |
    | Set Fee | setFee() | Be owner |

    ### Purpose
    Configure protocol parameters.

    ### Trust Requirements
    Highest trust - can configure all protocol settings.

    ---

    ## Lender

    ### Actions Available
    | Action | Function | Prerequisites |
    |--------|----------|---------------|
    | Supply | supply() | Approved tokens |
    | Withdraw | withdraw() | Has shares |

    ### Value Proposition
    Earns interest on supplied assets.

    ### Risks
    - Smart contract risk
    - Bad debt socialization
    - Liquidity risk

    ---

    ## Borrower
    [Similar format...]

    ## Liquidator
    [Similar format...]

---

## Summary

| Step | Input | Output |
|------|-------|--------|
| 1 | actors.md + deployable-contracts.md | kb/roles/permissions.md |
| 2 | actors.md + permissions.md | kb/roles/role-summaries.md |

## Folder Structure

```
kb/roles/
├── actors.md          (from 2a-createSetupKB)
├── permissions.md     (this prompt)
└── role-summaries.md  (this prompt)
```
