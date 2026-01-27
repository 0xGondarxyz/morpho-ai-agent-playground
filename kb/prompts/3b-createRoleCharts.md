# Create Role Charts

Render visual diagrams from role knowledge base.

---

## Input Files Required

All files must exist before running this prompt:
- `kb/roles/actors.md`
- `kb/roles/permissions.md`
- `kb/roles/role-summaries.md`

---

## Step 1: Create Access Control Diagram

### Task
Visualize permission hierarchy.

### Input
- `kb/roles/actors.md`
- `kb/roles/permissions.md`

### Instructions

Create Mermaid diagram showing:
1. Role hierarchy (protocol → user → permissionless)
2. What each role controls
3. Delegation relationships

### Output
Create: `charts/access-control.md`

Example structure:

    # Access Control Diagram

    ```mermaid
    graph TD
        subgraph Protocol["Protocol Level"]
            Owner["Owner<br/>- enableIrm()<br/>- setFee()"]
        end

        subgraph Users["User Level"]
            Lender["Lender<br/>- supply()<br/>- withdraw()"]
            Borrower["Borrower<br/>- borrow()<br/>- repay()"]
        end

        subgraph Delegation["Delegation"]
            Authorized["Authorized Operator"]
        end

        subgraph Permissionless["Anyone"]
            Anyone["- createMarket()<br/>- liquidate()<br/>- accrueInterest()"]
        end

        Lender -->|authorizes| Authorized
        Borrower -->|authorizes| Authorized
        Authorized -->|acts as| Lender
        Authorized -->|acts as| Borrower
    ```

---

## Step 2: Create Permission Matrix Chart

### Task
Create visual permission matrix.

### Input
- `kb/roles/permissions.md`

### Instructions

Create a consolidated table showing all functions vs all roles.

### Output
Create: `charts/role-matrix.md`

Example structure:

    # Role Permission Matrix

    | Function | Owner | Lender | Borrower | Liquidator | Anyone |
    |----------|:-----:|:------:|:--------:|:----------:|:------:|
    | setFee | ✓ | | | | |
    | enableIrm | ✓ | | | | |
    | supply | | ✓ | | | ✓* |
    | withdraw | | ✓ | | | |
    | supplyCollateral | | | ✓ | | ✓* |
    | borrow | | | ✓ | | |
    | repay | | | ✓ | | ✓* |
    | liquidate | | | | ✓ | ✓ |
    | createMarket | | | | | ✓ |
    | flashLoan | | | | | ✓ |

    Legend:
    - ✓ = can call for self
    - ✓* = can call for onBehalf

---

## Step 3: Create Authorization Flow Diagram

### Task
Document how authorization/delegation works.

### Input
- `kb/roles/actors.md`

### Instructions

Create sequence diagram showing authorization mechanism.

### Output
Create: `charts/authorization-flow.md`

Example structure:

    # Authorization Flow

    ```mermaid
    sequenceDiagram
        actor User
        actor Operator
        participant Contract

        User->>Contract: setAuthorization(operator, true)
        Note over Contract: isAuthorized[user][operator] = true

        Operator->>Contract: withdraw(params, user, operator)
        Contract->>Contract: require(caller == onBehalf OR isAuthorized)
        Contract-->>Operator: success
    ```

---

## Summary

| Step | Input | Output |
|------|-------|--------|
| 1 | actors.md + permissions.md | charts/access-control.md |
| 2 | permissions.md | charts/role-matrix.md |
| 3 | actors.md | charts/authorization-flow.md |

## Folder Structure

```
charts/
├── access-control.md
├── role-matrix.md
└── authorization-flow.md
```
