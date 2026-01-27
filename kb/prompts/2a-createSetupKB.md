# Create Setup Knowledge Base

Extract deployment information and identify protocol actors.

---

## Step 1: List Deployable Contracts

### Task
Identify which contracts can be deployed.

### Input
- `kb/contracts.md`

### Instructions

For each contract in `kb/contracts.md`:
1. Read the contract's .sol file (path is in contracts.md)
2. Check declaration:
   - `interface` → NOT deployable
   - `library` → NOT deployable
   - `abstract contract` → NOT deployable
   - `contract` → DEPLOYABLE

### Output
Create: `kb/setup/deployable-contracts.md`

Example structure:

    # Deployable Contracts

    ## Full Classification
    | Contract | File Path | Deployable |
    |----------|-----------|------------|
    | Vault | src/Vault.sol | Yes |
    | IVault | src/interfaces/IVault.sol | No (interface) |

    ## Deployable Only
    - Vault (`src/Vault.sol`)
    - Token (`src/Token.sol`)

---

## Step 2: Extract Constructors

### Task
Extract constructor parameters for each deployable contract.

### Input
- `kb/setup/deployable-contracts.md`

### Instructions

For each deployable contract listed:
1. Open the .sol file path from deployable-contracts.md
2. Find `constructor` function
3. Extract signature and parameters

### Output
Create: `kb/setup/constructors.md`

Example structure:

    # Constructor Parameters

    ## Vault
    - File: `src/Vault.sol`
    - Signature: `constructor(address _token, address _oracle)`
    - Parameters:
      | Name | Type |
      |------|------|
      | _token | address |
      | _oracle | address |

    ## Token
    - File: `src/Token.sol`
    - Signature: none (uses defaults)

---

## Step 3: Extract Initializers

### Task
Extract initializer functions for upgradeable contracts.

### Input
- `kb/setup/deployable-contracts.md`

### Instructions

For each deployable contract:
1. Open the .sol file path from deployable-contracts.md
2. Search for: `initialize`, `init`, `initializer` modifier
3. If found, extract signature and parameters

### Output
Create: `kb/setup/initializers.md`

Example structure:

    # Initializer Functions

    ## Vault
    - Initializer: `function initialize(address _admin) initializer`
    - Parameters:
      | Name | Type |
      |------|------|
      | _admin | address |

    ## Token
    - Initializer: none (not upgradeable)

---

## Step 4: Classify Parameters

### Task
Classify each constructor/initializer parameter.

### Input
- `kb/setup/deployable-contracts.md`
- `kb/setup/constructors.md`
- `kb/setup/initializers.md`

### Instructions

For each parameter:
- `address` + contract name in deployable-contracts.md → **internal dependency**
- `address` + admin/owner/governance name → **admin address**
- `address` + other → **external address**
- Non-address types → **config value**

### Output
Create: `kb/setup/params-classified.md`

Example structure:

    # Parameter Classification

    ## Vault Constructor
    | Parameter | Type | Classification | Resolves To |
    |-----------|------|----------------|-------------|
    | _token | address | internal dependency | Token.sol |
    | _admin | address | admin address | deployer sets |
    | _fee | uint256 | config value | deployer sets |

---

## Step 5: Build Dependency Graph

### Task
Map contract deployment dependencies.

### Input
- `kb/setup/params-classified.md`

### Instructions

1. For each contract, find "internal dependency" parameters
2. Create edge: dependent → required
3. List contracts with no dependencies

### Output
Create: `kb/setup/dependency-graph.md`

Example structure:

    # Dependency Graph

    ## Dependencies Table
    | Contract | Depends On |
    |----------|------------|
    | Token | (none) |
    | Vault | Token, Oracle |

    ## No Dependencies
    - Token
    - Oracle

    ## Has Dependencies
    - Vault (needs: Token, Oracle)

---

## Step 6: Determine Deployment Order

### Task
Topological sort for deployment sequence.

### Input
- `kb/setup/dependency-graph.md`

### Instructions

1. Level 1: Contracts with no dependencies
2. Level 2: Contracts depending only on Level 1
3. Continue until all assigned

### Output
Create: `kb/setup/deployment-order.md`

Example structure:

    # Deployment Order

    ## Level 1 (No Dependencies)
    1. Token
    2. Oracle

    ## Level 2 (Depends on Level 1)
    3. Vault
       - Requires: Token, Oracle

    ## Summary
    - Total contracts: 3
    - Deployment levels: 2

---

## Step 7: Find Post-Deploy Calls

### Task
Identify required and optional configuration calls.

### Input
- `kb/setup/deployable-contracts.md`

### Instructions

For each deployable contract (read .sol from deployable-contracts.md):
1. Find `set*`, `add*`, `register*`, `enable*` functions
2. Check for access control modifiers
3. Classify as required vs optional

### Output
Create: `kb/setup/post-deploy-calls.md`

Example structure:

    # Post-Deployment Configuration

    ## Vault

    ### Required Calls
    | Function | Parameters | Why Required |
    |----------|------------|--------------|
    | setFeeRecipient | address | Fees fail without |

    ### Optional Calls
    | Function | Parameters | Purpose |
    |----------|------------|---------|
    | pause | none | Emergency only |

---

## Step 8: Extract Protocol Actors

### Task
Identify all actors/roles from access control patterns.

### Input
- `kb/setup/deployable-contracts.md`
- `kb/setup/post-deploy-calls.md`

### Instructions

For each deployable contract (read .sol from deployable-contracts.md):
1. Find all external/public functions
2. Check access control:
   - `onlyOwner`, `onlyAdmin` → Protocol role
   - `msg.sender == owner` → Protocol role
   - Self-or-authorized checks → User role
   - No access control → Permissionless
3. Group callers into roles

### Output
Create: `kb/roles/actors.md`

Example structure:

    # Protocol Actors

    ## Protocol Roles (Privileged)
    | Role | How Identified | Trust Level |
    |------|----------------|-------------|
    | Owner | `onlyOwner` modifier | Highest |

    ## User Roles
    | Role | Description | Key Actions |
    |------|-------------|-------------|
    | Lender | Supplies liquidity | supply, withdraw |
    | Borrower | Takes loans | borrow, repay |

    ## System Roles
    | Role | Description | How Granted |
    |------|-------------|-------------|
    | Authorized | Acts for user | setAuthorization() |

    ## Permissionless Actions
    | Action | Restrictions |
    |--------|--------------|
    | createMarket | Params must be valid |

---

## Summary

| Step | Input | Output |
|------|-------|--------|
| 1 | kb/contracts.md | kb/setup/deployable-contracts.md |
| 2 | kb/setup/deployable-contracts.md | kb/setup/constructors.md |
| 3 | kb/setup/deployable-contracts.md | kb/setup/initializers.md |
| 4 | steps 1-3 outputs | kb/setup/params-classified.md |
| 5 | kb/setup/params-classified.md | kb/setup/dependency-graph.md |
| 6 | kb/setup/dependency-graph.md | kb/setup/deployment-order.md |
| 7 | kb/setup/deployable-contracts.md | kb/setup/post-deploy-calls.md |
| 8 | kb/setup/deployable-contracts.md + post-deploy-calls.md | kb/roles/actors.md |

## Folder Structure

```
kb/
├── setup/
│   ├── deployable-contracts.md
│   ├── constructors.md
│   ├── initializers.md
│   ├── params-classified.md
│   ├── dependency-graph.md
│   ├── deployment-order.md
│   └── post-deploy-calls.md
└── roles/
    └── actors.md
```
