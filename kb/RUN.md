# KB Generation - Execution Commands

## Agent Files

```
kb/agent/
├── 1-information-gathering-phase.md
├── 2-contract-discovery-phase.md
├── 3-deployment-phase-0.md
├── 3-deployment-phase-1.md
├── 4-charts-phase-0.md
├── 4-charts-phase-1.md
├── 4-charts-phase-2.md
├── 5-overview-phase.md
├── 6-documentation-phase.md
└── 7-inline-docs-phase.md
```

---

## Total Execution (All Steps 1-7)

```
Execute all KB generation agents in order.

Read and execute each file in kb/agent/ following this order:
1. 1-information-gathering-phase.md
2. 2-contract-discovery-phase.md
3. 3-deployment-phase-0.md, then 3-deployment-phase-1.md
4. 4-charts-phase-0.md, then 4-charts-phase-1.md, then 4-charts-phase-2.md
5. 5-overview-phase.md
6. 6-documentation-phase.md
7. 7-inline-docs-phase.md

For steps with multiple phases (3, 4), execute phase-0 first, then phase-1, then phase-2.

Execute now.
```

---

## Total Execution (KB Only, No Source Modification)

```
Execute KB generation agents for Steps 1-6 only.

Read and execute each file in kb/agent/ following this order:
1. 1-information-gathering-phase.md
2. 2-contract-discovery-phase.md
3. 3-deployment-phase-0.md, then 3-deployment-phase-1.md
4. 4-charts-phase-0.md, then 4-charts-phase-1.md, then 4-charts-phase-2.md
5. 5-overview-phase.md
6. 6-documentation-phase.md

Do NOT execute Step 7 (7-inline-docs-phase.md) which modifies source files.

Execute now.
```

---

## Parallel Execution (After Cache)

```
Execute KB generation with parallel agents where possible.

Phase 1 (Sequential - Required First):
- Execute 1-information-gathering-phase.md

Phase 2 (Parallel - All can run simultaneously):
Spawn parallel agents for:
- 2-contract-discovery-phase.md
- 3-deployment-phase-0.md
- 4-charts-phase-0.md
- 4-charts-phase-1.md
- 4-charts-phase-2.md
- 5-overview-phase.md
- 6-documentation-phase.md

Phase 3 (Sequential - After Phase 2):
- Execute 3-deployment-phase-1.md (depends on 3-deployment-phase-0.md output)

Phase 4 (Optional - Source Modification):
- Execute 7-inline-docs-phase.md

Execute now.
```

---

## Separate Execution - Individual Steps

### Step 1: Information Gathering
```
Read and execute kb/agent/1-information-gathering-phase.md
```

### Step 2: Contract Discovery
```
Read and execute kb/agent/2-contract-discovery-phase.md
```

### Step 3: Deployment (Both Phases)
```
Read and execute kb/agent/3-deployment-phase-0.md
Then read and execute kb/agent/3-deployment-phase-1.md
```

### Step 3 Phase 0 Only: Dependencies
```
Read and execute kb/agent/3-deployment-phase-0.md
```

### Step 3 Phase 1 Only: Deployment Pattern
```
Read and execute kb/agent/3-deployment-phase-1.md
```

### Step 4: Charts (All Phases)
```
Read and execute kb/agent/4-charts-phase-0.md
Then read and execute kb/agent/4-charts-phase-1.md
Then read and execute kb/agent/4-charts-phase-2.md
```

### Step 4 Phase 0 Only: Setup Charts
```
Read and execute kb/agent/4-charts-phase-0.md
```

### Step 4 Phase 1 Only: Role Charts
```
Read and execute kb/agent/4-charts-phase-1.md
```

### Step 4 Phase 2 Only: Usage Flows
```
Read and execute kb/agent/4-charts-phase-2.md
```

### Step 5: System Overview
```
Read and execute kb/agent/5-overview-phase.md
```

### Step 6: Code Documentation
```
Read and execute kb/agent/6-documentation-phase.md
```

### Step 7: Inline Documentation (Modifies Source)
```
Read and execute kb/agent/7-inline-docs-phase.md

WARNING: This step modifies source files by adding inline comments.
```

---

## Output Files

| Step | Phase | Agent File | Output |
|------|-------|------------|--------|
| 1 | - | 1-information-gathering-phase.md | `kb/output/1-informationNeededForSteps.md` |
| 2 | - | 2-contract-discovery-phase.md | `kb/output/2-contractsList.md` |
| 3 | 0 | 3-deployment-phase-0.md | `kb/output/deployment-0-dependencyList.md` |
| 3 | 1 | 3-deployment-phase-1.md | `kb/output/deployment-1-pattern.md` |
| 4 | 0 | 4-charts-phase-0.md | `kb/output/charts-0-setup.md` |
| 4 | 1 | 4-charts-phase-1.md | `kb/output/charts-1-roles.md` |
| 4 | 2 | 4-charts-phase-2.md | `kb/output/charts-2-flows.md` |
| 5 | - | 5-overview-phase.md | `kb/output/5-overview.md` |
| 6 | - | 6-documentation-phase.md | `kb/output/6-codeDocumentation.md` |
| 7 | - | 7-inline-docs-phase.md | `src/*.sol` (modified) + `kb/output/7-inline-docs-summary.md` |

---

## Run Range of Steps

```
Execute KB generation agents for Steps [X] through [Y].

Read and execute files in kb/agent/ for steps [X] to [Y] in order.
For multi-phase steps, execute all phases (phase-0, phase-1, phase-2) in order.

Execute now.
```

Replace `[X]` and `[Y]` with step numbers (1-7).
