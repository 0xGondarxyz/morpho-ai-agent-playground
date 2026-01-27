# Create Setup Charts

Render visual diagrams from setup knowledge base.

---

## Input Files Required

All files must exist before running this prompt:
- `kb/setup/deployment-order.md`
- `kb/setup/dependency-graph.md`
- `kb/setup/constructors.md`
- `kb/setup/post-deploy-calls.md`

---

## Step 1: Create Deployment Flow Chart

### Task
Create Mermaid diagram showing deployment sequence.

### Instructions

From the input files, create a flowchart showing:
1. Each contract as a node with constructor params
2. Arrows showing dependencies
3. Subgraphs for deployment levels
4. Post-deploy calls as separate nodes

### Output
Create: `charts/setup-flow.md`

Example structure:

    # Setup Flow Chart

    ```mermaid
    graph TD
        subgraph Level1["Level 1: No Dependencies"]
            Token["Token<br/>constructor(name, symbol)"]
            Oracle["Oracle<br/>constructor()"]
        end

        subgraph Level2["Level 2: Core"]
            Vault["Vault<br/>constructor(token, oracle)"]
        end

        Token --> Vault
        Oracle --> Vault

        subgraph PostDeploy["Post-Deploy Config"]
            Config1["vault.setFeeRecipient()"]
        end

        Vault -.-> Config1
    ```

---

## Step 2: Create Dependency Diagram

### Task
Create focused dependency-only diagram.

### Instructions

From `kb/setup/dependency-graph.md`, create a clean dependency diagram without deployment details.

### Output
Create: `charts/dependency-diagram.md`

Example structure:

    # Contract Dependencies

    ```mermaid
    graph LR
        Token
        Oracle
        Vault --> Token
        Vault --> Oracle
        Router --> Vault
    ```

---

## Step 3: Create Setup Checklist

### Task
Create human-readable deployment checklist.

### Instructions

Combine deployment-order.md and post-deploy-calls.md into a step-by-step checklist.

### Output
Create: `charts/setup-checklist.md`

Example structure:

    # Deployment Checklist

    ## Phase 1: Deploy Base Contracts
    | Contract | Constructor Call |
    |----------|------------------|
    | Token | `new Token("Name", "SYM")` |
    | Oracle | `new Oracle()` |

    ## Phase 2: Deploy Core Contracts
    | Contract | Constructor Call |
    |----------|------------------|
    | Vault | `new Vault(token, oracle)` |

    ## Phase 3: Post-Deployment Configuration
    | Call | Required | Purpose |
    |------|----------|---------|
    | vault.setFeeRecipient(addr) | Yes | Enable fees |
    | vault.pause() | No | Emergency |

---

## Summary

| Step | Input | Output |
|------|-------|--------|
| 1 | all setup KB files | charts/setup-flow.md |
| 2 | kb/setup/dependency-graph.md | charts/dependency-diagram.md |
| 3 | deployment-order + post-deploy-calls | charts/setup-checklist.md |

## Folder Structure

```
charts/
├── setup-flow.md
├── dependency-diagram.md
└── setup-checklist.md
```
