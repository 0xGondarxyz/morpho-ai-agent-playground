# KB Generation - Master Prompts

## Run All Steps (1-7)

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

---

## Run KB Only (Steps 1-6, No Source Modification)

```
Read kb/prompts.md and execute Steps 1-6 in order.
Do NOT execute Step 7 (which modifies source files).

Execute now.
```

---

## Run Single Step

```
Read kb/prompts.md. Execute only Step [N].
```

Replace `[N]` with:
- 1 = Information Gathering (cache)
- 2 = Contract Discovery
- 3 = Dependencies & Deployment
- 4 = Charts & Flows
- 5 = System Overview
- 6 = Code Documentation (KB file)
- 7 = Inline Documentation (modifies source files)

---

## Run Steps Range

```
Read kb/prompts.md. Execute Steps [X] through [Y].
```

---

## Output Files Created

| Step | Output | Type |
|------|--------|------|
| 1 | 1-informationNeededForSteps.md | KB file |
| 2 | 2-contractsList.md | KB file |
| 3 | 3a-dependencyList.md, 3b-deploymentPattern.md | KB file |
| 4 | 4a-setupCharts.md, 4b-roleCharts.md, 4c-usageFlows.md | KB file |
| 5 | 5-overview.md | KB file |
| 6 | 6-codeDocumentation.md | KB file |
| 7 | {src}/*.sol (modified with inline docs) | Source modification |

---

## Alternative Prompt (Agentic Workflow)

This approach uses the Task tool to spawn separate agents for each step, allowing parallel execution where possible.

```
You are provided a Solidity protocol codebase in the current directory and KB generation instructions at kb/prompts.md.

1. Read kb/prompts.md to understand all steps (1-7)
2. Use the current directory as your working directory
3. Run each KB generation step as a separate agent using the Task tool:

   - First, run kb-step-1 (Information Gathering) and wait for completion
   - Then run kb-step-2 through kb-step-6 in parallel using the Task tool (KB file generation)
   - Finally, run kb-step-7 (Inline Documentation) after Steps 2-6 complete

For each step, the agent should:
- Read the step's instructions from kb/prompts.md
- Follow the TRY cache / FALLBACK pattern
- Create output file(s) in kb/ folder OR modify source files (Step 7)
- Return summary of what was created/modified

Execute now.
```

---

## Alternative Prompt (Parallel Agents After Cache)

```
Read kb/prompts.md.

Phase 1: Run Step 1 (Information Gathering) to create the cache.

Phase 2: Once Step 1 completes, spawn 5 agents in parallel using the Task tool:
- Agent for Step 2: Contract Discovery
- Agent for Step 3: Dependencies & Deployment
- Agent for Step 4: Charts & Flows
- Agent for Step 5: System Overview
- Agent for Step 6: Code Documentation

Phase 3: After Phase 2 completes, run Step 7 (Inline Documentation).

Each agent reads kb/prompts.md for its step instructions and uses kb/1-informationNeededForSteps.md as cache.

Execute now.
```

---

## Run Step 7 Only (Inline Documentation)

```
Read kb/prompts.md. Execute only Step 7 (Inline Code Documentation).

This will add inline comments to source files documenting:
- Bounds and limits
- Complex math explanations
- Security considerations
- State transitions
- Edge cases

No logic will be changed - only comments added.

Execute now.
```
