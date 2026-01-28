# AI-Powered Protocol Knowledge Base Generator

This repository contains an AI-driven system for generating comprehensive knowledge bases from Solidity smart contract codebases. It automatically analyzes protocol code and produces structured documentation optimized for security auditors and developers.

## What This Does

The KB generator reads a Solidity codebase and produces:

1. **Structured data extraction** - Parses all contracts, interfaces, libraries, functions, state variables, modifiers, and their relationships
2. **Dependency analysis** - Maps imports, inheritance, library usage, and runtime external calls
3. **Deployment documentation** - Constructor parameters, deployment order, post-deployment setup
4. **Visual diagrams** - Mermaid charts for setup flows, role hierarchies, and user journeys
5. **Security-focused overview** - Trust assumptions, invariants, attack surface, edge cases
6. **Function-level documentation** - Detailed docs for every function with validation, state changes, and security notes
7. **Inline source comments** - Adds auditor-friendly annotations directly to source files

## Quick Start

### Run Full KB Generation (Recommended)

Copy this prompt into Claude Code:

```
Read kb/prompts.md and execute ALL steps (1-7) in order.

For each step:
1. Read the step's instructions from prompts.md
2. Execute the step following its TRY cache / FALLBACK pattern
3. Create the output file(s) in kb/ folder (Steps 1-6) or modify source files (Step 7)
4. Move to next step

Start with Step 1 (Information Gathering) which creates the cache, then Steps 2-7 will use that cache.

Execute now.
```

### Run KB Only (No Source Modification)

If you don't want inline comments added to source files:

```
Read kb/prompts.md and execute Steps 1-6 in order.
Do NOT execute Step 7 (which modifies source files).

Execute now.
```

### Run Single Step

```
Read kb/prompts.md. Execute only Step [N].
```

Replace `[N]` with step number (1-7).

## Output Files

After execution, the `kb/` folder contains:

| File | Description |
|------|-------------|
| `1-informationNeededForSteps.md` | Raw extracted data cache (used by subsequent steps) |
| `2-contractsList.md` | Categorized list of all contracts, interfaces, libraries |
| `3a-dependencyList.md` | Import/inheritance/library dependencies with mermaid graph |
| `3b-deploymentPattern.md` | Deployment order, constructor params, post-deploy setup |
| `4a-setupCharts.md` | Deployment sequence diagrams, state machines |
| `4b-roleCharts.md` | Roles, permission matrix, authorization flows |
| `4c-usageFlows.md` | User journey sequence diagrams (supply, borrow, liquidate, etc.) |
| `5-overview.md` | Single-page auditor digest with architecture, invariants, attack surface |
| `6-codeDocumentation.md` | Function-by-function documentation |

Step 7 modifies source files in `src/` by adding inline comments.

## Step Details

### Step 1: Information Gathering (Cache)
Extracts ALL data needed by subsequent steps:
- Project type detection (Foundry/Hardhat)
- Contract/interface/library metadata
- Function signatures, modifiers, state variables
- Import relationships, inheritance chains
- Constructor parameters, events, errors
- Test setUp() functions for deployment patterns

### Step 2: Contract Discovery
Categorizes all `.sol` files into:
- Core contracts
- Interfaces
- Libraries (core and periphery)
- Mocks

### Step 3: Dependencies & Deployment
- **3a**: Dependency graph showing imports, inheritance, library usage, runtime calls
- **3b**: Deployment pattern with constructor params, deployment order, post-deploy configuration

### Step 4: Charts & Flows
- **4a**: Setup charts (deployment sequence, configuration state machine)
- **4b**: Role charts (permission matrix, role hierarchy, authorization flow)
- **4c**: Usage flows (supply, withdraw, borrow, repay, liquidate, flash loan sequences)

### Step 5: System Overview
Single-page security digest containing:
- Protocol description and core mechanics
- Architecture diagram
- Entry points with risk levels
- Trust assumptions
- External dependencies
- Critical state variables
- Value flows
- Privileged roles
- Key invariants
- Attack surface analysis
- Known edge cases
- Quick reference (constants, limits)

### Step 6: Code Documentation
Comprehensive function-by-function documentation:
- Full signatures with parameters and returns
- Access control requirements
- Validation logic (all require/revert conditions)
- State changes (reads and writes)
- Internal and external calls
- Events emitted
- Security notes

### Step 7: Inline Documentation
Adds comments directly to source files:
- `BOUNDS:` - Parameter limits, overflow considerations
- `MATH:` - Formula explanations, rounding directions
- `SECURITY:` - Reentrancy points, CEI pattern, access control
- `STATE:` - What changes and why
- `EXTERNAL:` - External call risks
- `INVARIANT:` - What this function maintains
- `EDGE CASE:` - Special handling notes

## Architecture

```
kb/
├── prompts.md              # Step definitions with TRY cache / FALLBACK patterns
├── RUN.md                  # Execution prompts (copy-paste into Claude Code)
├── 1-informationNeededForSteps.md   # Cache (generated)
├── 2-contractsList.md               # (generated)
├── 3a-dependencyList.md             # (generated)
├── 3b-deploymentPattern.md          # (generated)
├── 4a-setupCharts.md                # (generated)
├── 4b-roleCharts.md                 # (generated)
├── 4c-usageFlows.md                 # (generated)
├── 5-overview.md                    # (generated)
└── 6-codeDocumentation.md           # (generated)
```

## Customization

### Adapting for Other Protocols

The prompts in `kb/prompts.md` are designed to work with any Foundry or Hardhat Solidity project:

1. Copy the `kb/` folder to your target repository
2. Delete all generated files (keep only `prompts.md` and `RUN.md`)
3. Run the execution prompt

The system automatically:
- Detects project type (Foundry vs Hardhat)
- Finds source directory (`src/`, `contracts/`, or `source/`)
- Excludes `lib/`, `node_modules/`, and mock files
- Reads test files for deployment patterns

### Modifying Steps

Edit `kb/prompts.md` to:
- Add new output files
- Change documentation format
- Add protocol-specific sections
- Modify what data is extracted

## Expected Execution Time

- Steps 1-6: ~2-5 minutes depending on codebase size
- Step 7: ~1-3 minutes (reads and modifies source files)
- Total: ~3-8 minutes for complete KB generation

## Use Cases

1. **Security Audits**: Generate comprehensive protocol documentation before starting an audit
2. **Onboarding**: Help new developers understand complex codebases quickly
3. **Documentation**: Auto-generate technical documentation from code
4. **Code Review**: Understand dependencies, roles, and flows before reviewing PRs
5. **Due Diligence**: Quickly assess protocol architecture and trust assumptions

## Requirements

- [Claude Code](https://claude.ai/claude-code) CLI
- Solidity codebase (Foundry or Hardhat project)

## License

The KB generation system (prompts and scripts) is provided as-is for any use.
