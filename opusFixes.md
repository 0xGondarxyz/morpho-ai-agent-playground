# Pre-Audit Agent Fixes

All ambiguities and issues identified by reviewing phases 0-9 as a codebase-agnostic AI executor.

---

## Phase 0 — Information Gathering

| # | Issue | Severity | Fix Applied |
|---|-------|----------|-------------|
| 1 | **Exclusion patterns too narrow** — only `lib/`, `node_modules/` listed, but codebases may use `deps/`, `vendor/`, `.deps/`, `dependencies/`, `build/`, `cache/`, `out/`, `artifacts/` | High | Expanded to 10 common dirs + dynamic detection from `foundry.toml` libs key and `remappings.txt` |
| 2 | **NatSpec fallback undefined** — no guidance when neither @notice nor @title exists | Medium | Explicit `DESC: [none]` instruction; phase 1 handles inference |
| 3 | **"Runtime external calls" ambiguous** — unclear if low-level `.call()`, `.delegatecall()`, `.staticcall()`, `transfer/send` are included | High | New "External Call Classification" section with 4 tagged types: `[typed]`, `[low-level]`, `[transfer]`, `[contract]` |
| 4 | **Output size unmanaged** — large codebases (50+ contracts) could produce output exceeding downstream context windows | High | New "Output Size Management" section — split into part files for >20 contracts with PARTS index |
| 5 | **Directory creation platform-specific** — `mkdir -p` fails on Windows | Low | Changed to declarative: "Ensure the output directory exists" |
| 6 | **Test setUp() inheritance ignored** — `super.setUp()` chains are common but only leaf setUp() was captured | Medium | Trace full inheritance chain base-to-derived, note provenance of each part |
| 7 | **Missing fields vs not-extracted indistinguishable** — downstream agents can't tell if a field is absent or just wasn't extracted | Medium | `[none]` convention for empty fields; `PARSE_ERROR` for broken files |
| 8 | **Custom errors not mentioned** — only `require/revert` listed, but modern Solidity uses custom errors | Low | Explicit instruction to include custom errors |

## Phase 1 — Contract Discovery

| # | Issue | Severity | Fix Applied |
|---|-------|----------|-------------|
| 1 | **Core vs Periphery distinction subjective** — path says Periphery but content says Core; no precedence rule | High | "Content first, path second" rule with decision flowchart. When uncertain, default to Core |
| 2 | **"cache" terminology undefined** — phase 0 never calls its output a "cache" but phase 1 references it as such | Low | Replaced all "cache" references with explicit file path `magic/pre-audit/information-needed.md` |
| 3 | **Fallback exclusion patterns too narrow** — same issue as phase 0 | Low | Expanded to match phase 0's exclusion list |

## Phase 2 — Deployment Dependencies

| # | Issue | Severity | Fix |
|---|-------|----------|-----|
| 1 | **Protocol vs third-party code distinction unclear** — "ignore OpenZeppelin, etc." but no reliable heuristic for unknown libraries | Medium | APPLIED — Protocol code = has a FILE section in phase 0 output; external = imported but no FILE section. Fallback: inside {src} = protocol, outside = external. External deps get a separate summary table + dashed style in Mermaid graph |

## Phase 3 — Deployment Pattern

| # | Issue | Severity | Fix |
|---|-------|----------|-----|
| 1 | **Upgradeable proxy patterns not mentioned** — `initialize()` may live in a proxy contract outside src/ | Low | NOT YET APPLIED — Suggested fix: add note to check for proxy patterns (UUPS, Transparent) and initializer modifiers |

## Phase 4 — Charts Setup

No significant ambiguities found. Well-designed for agnosticity.

## Phase 5 — Charts Roles

| # | Issue | Severity | Fix |
|---|-------|----------|-----|
| 1 | **"per-market/vault" is lending-specific language** — confusing on non-lending codebases | Low | APPLIED — Replaced with generic "per-resource / per-instance" language and added instruction to identify whatever the protocol's unit of isolation is. Also expanded role detection patterns (AccessControl, timelocks, allowlists, delegated approvals) and fixed "cache" terminology |

## Phase 6 — Charts Flows

| # | Issue | Severity | Fix |
|---|-------|----------|-----|
| 1 | **Entire framing is lending-protocol-specific** — "supply, borrow, withdraw, repay, liquidate, flash loan" hardcoded | **Critical** | APPLIED — Full rewrite. All lending-specific terms removed. Agent now discovers operations from code and names them based on what they do. Added "How to Identify Major Operations" prioritization guide. Output format uses generic placeholders |
| 2 | **"Rounding direction" assumed universally relevant** — only applies to protocols with math conversions | Low | APPLIED — Made conditional: "If the protocol involves mathematical conversions..." with explicit "omit sections that don't apply" instruction |
| 3 | **"Interest accrual" is lending-specific** — should say "shared pre-computation or state updates" | Medium | APPLIED — Replaced with "shared pre-computation or state updates" and elevated shared internal functions to their own section (high audit-impact targets) |

## Phase 7 — Overview

| # | Issue | Severity | Fix |
|---|-------|----------|-----|
| 1 | **Risk Level rubric undefined** — no criteria for Low/Medium/High on entry points | Medium | APPLIED — Added "Risk Level Rubric" section: High = value transfers + external calls + reentrancy surface; Medium = state changes behind access control; Low = view/simple setters. Default to rating higher when uncertain |
| 2 | **"Key Invariants" relies on inference** — AI may guess wrong without documentation | Low | APPLIED — Added "Invariant Labeling" section: `[DOCUMENTED]` for NatSpec/README-stated invariants with source quoted, `[INFERRED]` for code-deduced invariants with reasoning |
| 3 | **Lending-specific examples in output template** — supply/liquidate, Supplier→Borrower, Chainlink/bad debt | Medium | APPLIED — All examples replaced with generic placeholders. Added note: "Do NOT use domain-specific terminology unless the codebase itself uses it" |
| 4 | **"cache" terminology** | Low | APPLIED — Replaced with explicit file path |

## Phase 8 — Documentation

| # | Issue | Severity | Fix |
|---|-------|----------|-----|
| 1 | **No output format template** — every other phase shows expected format, this one doesn't | High | APPLIED — Full output template added: per-function sections (signature, purpose, params, returns, access control, validations, state changes, internal/external calls, events, security notes) + Security Summary with three tables (reentrancy vectors, privileged functions, critical invariants) |
| 2 | **Security notes depth undefined** — no guidance on how verbose | Medium | APPLIED — Explicit instruction: "state the concern AND whether the code handles it" with example of good vs bad annotation |
| 3 | **"cache file" terminology** | Low | APPLIED — Replaced with explicit file path |
| 4 | **Rounding direction assumed universal** — not all protocols have conversions | Low | APPLIED — Made conditional: "If the protocol involves mathematical conversions... otherwise omit" |

## Phase 9 — Inline Docs

| # | Issue | Severity | Fix |
|---|-------|----------|-----|
| 1 | **"Complex" library threshold undefined** — "not interfaces/libraries unless complex" with no definition | Medium | APPLIED — New "Which Files to Document" section with concrete criteria: non-trivial math, bit manipulation, assembly, or >10 functions. When unsure, document it |
| 2 | **No compilation check after source modification** — riskiest phase, modifies actual code | High | APPLIED — Pre-flight compilation check before any changes + post-modification verification + rollback-or-fix instruction if build fails. Also added to fallback behavior |
| 3 | **Contradictory language in step 3** — says "identify where to add inline comments" (implying inside bodies) but critical rule says above-only | Low | APPLIED — Reworded to "determine if it needs a documentation header" and "Add `///` NatSpec lines ABOVE each function" |
| 4 | **Rounding direction assumed universal** | Low | APPLIED — Made conditional: "If a function involves mathematical conversions... otherwise omit MATH: tags" |
| 5 | **"cache files" terminology** | Low | APPLIED — Replaced with explicit file path |

## Cross-Phase Concerns

| # | Issue | Severity | Fix |
|---|-------|----------|-----|
| 1 | **No parallelization guidance** — phases 1+2 are independent, phases 4+5+6 are independent, but nothing says they can run in parallel | Medium | NOT APPLIED — decided unnecessary |
| 2 | **Terminology inconsistency** — phase 0 output called "cache", "information-needed.md", "raw data" interchangeably | Low | APPLIED — All "cache" references replaced with explicit file paths across all phases (1-9). Phases 3 and 4 were the last remaining |
| 3 | **No edge-case guidance** — syntax errors, zero test files, no README, auto-generated files | Medium | APPLIED — Phase 0 emits `PARSE_ERROR` and `[none]` markers. All downstream phases (1-9) now have handling instructions: skip PARSE_ERROR files (log in output), treat `[none]` as absent. Phase 9 specifically won't attempt to modify files with parse errors |
| 4 | **Context window risk** — phase 0 output for large codebases could exceed downstream agent limits | High | APPLIED — Phase 0 splits into part files with PARTS index. All downstream phases (1-9) now check for PARTS index and read all listed part files |
