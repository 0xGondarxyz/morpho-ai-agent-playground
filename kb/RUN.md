# Knowledge Base Generation - Execution Commands

## Agent Files

```
kb/agent/
├── pre-audit-phase-0.md   (Information Gathering)
├── pre-audit-phase-1.md   (Contract Discovery)
├── pre-audit-phase-2.md   (Deployment Dependencies)
├── pre-audit-phase-3.md   (Deployment Pattern)
├── pre-audit-phase-4.md   (Setup Charts)
├── pre-audit-phase-5.md   (Role Charts)
├── pre-audit-phase-6.md   (Usage Flows)
├── pre-audit-phase-7.md   (System Overview)
├── pre-audit-phase-8.md   (Code Documentation)
├── pre-audit-phase-9.md   (Inline Docs - Modifies Source)
├── pre-audit-phase-10.md  (Simplification Suggestions)
└── pre-audit-phase-11.md  (Formal Verification Suggestions)
```

---

## Total Execution (All Steps 0-11)

```
Execute all Knowledge Base generation agents in order.

Read and execute each file in kb/agent/ following this order:
0. pre-audit-phase-0.md
1. pre-audit-phase-1.md
2. pre-audit-phase-2.md
3. pre-audit-phase-3.md
4. pre-audit-phase-4.md
5. pre-audit-phase-5.md
6. pre-audit-phase-6.md
7. pre-audit-phase-7.md
8. pre-audit-phase-8.md
9. pre-audit-phase-9.md
10. pre-audit-phase-10.md
11. pre-audit-phase-11.md

Execute now.
```

---

## Total Execution (Knowledge Base Only, No Source Modification)

```
Execute Knowledge Base generation agents for Steps 0-8, 10-11 only.

Read and execute each file in kb/agent/ following this order:
0. pre-audit-phase-0.md
1. pre-audit-phase-1.md
2. pre-audit-phase-2.md
3. pre-audit-phase-3.md
4. pre-audit-phase-4.md
5. pre-audit-phase-5.md
6. pre-audit-phase-6.md
7. pre-audit-phase-7.md
8. pre-audit-phase-8.md
10. pre-audit-phase-10.md
11. pre-audit-phase-11.md

Do NOT execute Step 9 (pre-audit-phase-9.md) which modifies source files.

Execute now.
```

---

## Parallel Execution (After Cache)

```
Execute Knowledge Base generation with parallel agents where possible.

Phase 1 (Sequential - Required First):
- Execute pre-audit-phase-0.md

Phase 2 (Parallel - All can run simultaneously):
Spawn parallel agents for:
- pre-audit-phase-1.md
- pre-audit-phase-2.md
- pre-audit-phase-4.md
- pre-audit-phase-5.md
- pre-audit-phase-6.md
- pre-audit-phase-7.md
- pre-audit-phase-8.md
- pre-audit-phase-10.md
- pre-audit-phase-11.md

Phase 3 (Sequential - After Phase 2):
- Execute pre-audit-phase-3.md (depends on pre-audit-phase-2.md output)

Phase 4 (Optional - Source Modification):
- Execute pre-audit-phase-9.md

Execute now.
```

---

## Separate Execution - Individual Steps

### Phase 0: Information Gathering
```
Read and execute kb/agent/pre-audit-phase-0.md
```

### Phase 1: Contract Discovery
```
Read and execute kb/agent/pre-audit-phase-1.md
```

### Phase 2: Deployment Dependencies
```
Read and execute kb/agent/pre-audit-phase-2.md
```

### Phase 3: Deployment Pattern
```
Read and execute kb/agent/pre-audit-phase-3.md
```

### Phase 4: Setup Charts
```
Read and execute kb/agent/pre-audit-phase-4.md
```

### Phase 5: Role Charts
```
Read and execute kb/agent/pre-audit-phase-5.md
```

### Phase 6: Usage Flows
```
Read and execute kb/agent/pre-audit-phase-6.md
```

### Phase 7: System Overview
```
Read and execute kb/agent/pre-audit-phase-7.md
```

### Phase 8: Code Documentation
```
Read and execute kb/agent/pre-audit-phase-8.md
```

### Phase 9: Inline Documentation (Modifies Source)
```
Read and execute kb/agent/pre-audit-phase-9.md

WARNING: This step modifies source files by adding inline comments.
```

### Phase 10: Code Simplification Suggestions
```
Read and execute kb/agent/pre-audit-phase-10.md
```

### Phase 11: Formal Verification Suggestions
```
Read and execute kb/agent/pre-audit-phase-11.md
```

---

## Output Files

| Phase | Agent File | Output |
|-------|------------|--------|
| 0 | pre-audit-phase-0.md | `magic/pre-audit/information-needed.md` |
| 1 | pre-audit-phase-1.md | `magic/pre-audit/contracts-list.md` |
| 2 | pre-audit-phase-2.md | `magic/pre-audit/deployment-dependencies.md` |
| 3 | pre-audit-phase-3.md | `magic/pre-audit/deployment-pattern.md` |
| 4 | pre-audit-phase-4.md | `magic/pre-audit/charts-setup.md` |
| 5 | pre-audit-phase-5.md | `magic/pre-audit/charts-roles.md` |
| 6 | pre-audit-phase-6.md | `magic/pre-audit/charts-flows.md` |
| 7 | pre-audit-phase-7.md | `magic/pre-audit/overview.md` |
| 8 | pre-audit-phase-8.md | `magic/pre-audit/code-documentation.md` |
| 9 | pre-audit-phase-9.md | `src/*.sol` (modified) + `magic/pre-audit/inline-docs-summary.md` |
| 10 | pre-audit-phase-10.md | `magic/pre-audit/simplification-suggestions.md` |
| 11 | pre-audit-phase-11.md | `magic/pre-audit/formal-verification-spec.md` |

---

## Run Range of Steps

```
Execute Knowledge Base generation agents for Steps [X] through [Y].

Read and execute files in kb/agent/ for steps [X] to [Y] in order.

Execute now.
```

Replace `[X]` and `[Y]` with step numbers (0-11).
