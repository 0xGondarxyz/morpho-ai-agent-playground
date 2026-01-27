# Read Codebase

Initial codebase analysis to create foundational KB files.

Execute these steps in order. Do not skip any steps, if you encounter an error on any step, go back and try again.

If you encounter error more than once on a step, log/record the error and move on to the next one.

Save the errors in kb/errorsLog.md

---

## Step 1: Find the Source Contracts

### Task
Locate all Solidity source files.

### Instructions

Look for Solidity files in this order:
1. If `src/` exists → list all .sol files in src/
2. Else if `contracts/` exists → list all .sol files in contracts/
3.  Else if `source/` exists → list all .sol files in contracts/
4. Else → search the entire codebase and list all .sol files

### Output
List of source file paths.

---

## Step 2: Get Project Context

### Task
Extract project metadata from documentation files.

### Instructions

2a. If `README.md` exists → read it. Extract:
- Project name
- One-line description
- Any mentioned external dependencies

2b. If `foundry.toml` exists → read it. Extract:
- Solidity version
- Remappings (what external libs are used)

2c. If any `.pdf` file exists in root → read it for protocol context.

### Output
Context summary (or "No context files found").

---

## Step 3: Identify Contract Types

### Task
Categorize each contract by type.

### Instructions

For each .sol file found in Step 1, determine:
- Is it an interface? (filename starts with I, or only has function signatures)
- Is it a library? (uses `library` keyword)
- Is it abstract? (uses `abstract` keyword)
- Is it a concrete contract?

### Output
Categorized list of contracts.

---

## Step 4: Find Entry Points

### Task
Identify main user-facing contracts.

### Instructions

From the concrete contracts, identify which are entry points:
- Has external/public functions that users would call
- Not inherited by other contracts in the codebase
- Likely candidates: names like Vault, Pool, Router, Manager, Controller

### Output
List of entry point contracts.

---

## Step 5: Map Dependencies

### Task
Document contract relationships.

### Instructions

For each entry point contract:
- What other contracts does it import from src/?
- What external contracts does it interact with? (interfaces, calls to addresses)

### Output
Dependency map.

---

## Step 6: Compile KB

### Task
Create the foundational KB files.

### Instructions

Using the above, write:

**kb/overview.md**
- Project name (from README or infer from folder name)
- What it does (from README/whitepaper or infer from contract names)
- Entry points identified

**kb/contracts.md**

    | Contract | Type | Purpose |
    |----------|------|---------|
    | (from steps 3-4) |

**kb/dependencies.md**
- Internal dependencies (contract → contract)
- External dependencies (what external protocols/tokens)

---

## Summary

| Step | Input | Output |
|------|-------|--------|
| 1 | source folders | list of .sol files |
| 2 | README, foundry.toml, PDFs | context summary |
| 3 | .sol files | categorized contracts |
| 4 | concrete contracts | entry points |
| 5 | entry points | dependency map |
| 6 | all above | kb/overview.md, kb/contracts.md, kb/dependencies.md |

## Folder Structure

```
kb/
├── overview.md
├── contracts.md
└── dependencies.md
```
