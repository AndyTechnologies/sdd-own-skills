# Architecture Plan: P04-violation-change

## Principios no verificables

| ID | State | Evidence / Justification |
|----|-------|--------------------------|
| P01 | applicable | Single catalog path consumed by quest, plan, lint — no cross-layer imports |
| P02 | applicable | Schema headers, stable P/A IDs, fixed verdict form `axis_3 pass|fail` |
| P03 | applicable | Catalog lives in `skills/_shared/architecture-principles.md` — zero copies |
| P04 | applicable | Change diff bounded to declared files only — no dogma |
| P05 | applicable | Missing mandatory section triggers axis 2 fail-closed — gate never skipped |
| P06 | applicable | clean/dirty/multi fixtures with expected findings; RED suite cross-checks by ID |
| P07 | applicable | Quest owns questioning, plan owns applicability, lint owns verification |
| P08 | applicable | Orchestrator never fires council automatically (D8 retained) |
| P09 | applicable | Stable IDs: P01–P10, A01–A11; name changes require catalog + lint co-update |
| P10 | applicable | Verdict form pinned `axis_3 pass|fail`; no mixed enum states |
| A01 | applicable | No distributed monolith patterns — single-process shell |
| A02 | applicable | No premature microservice decomposition — single deployable |
| A03 | applicable | Single shared DB for catalog — no polyglot persistence needed |
| A04 | applicable | No over-engineered abstractions — table-driven selection, no state machine |
| A05 | applicable | No mutable global state — variables scoped per test function |
| A06 | applicable | No excessive synchronous coordination — sequential test execution |
| A07 | applicable | No god-object orchestration — single orchestrator prompt, clear delegation |
| A08 | applicable | No mud-ball coupling — each skill owns one concern, catalog is shared data |
| A09 | applicable | No framework lock-in — POSIX shell, no external dependencies |
| A10 | applicable | No copy-paste duplication — catalog consumed by path, single source |
| A11 | applicable | No excessive chain-of-responsibility — linear pipeline, bounded delegation |
