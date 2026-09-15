# Product RFC: arch-principles-quest-linter

## Approval: approved

Approval gate: RFC gate 1 (Product branch), explicitly approved by the user. Source: quest Q&A product branch — all decision branches resolved; no classified gaps carried forward.

## RFC

### Goals / Non-goals

**Goals**

- Rework the architecture branch of the SDD Quest into context-driven question selection: 8 base context questions + adaptive branching + early-stop, with the hard budget of 20 questions fixed (NOT raised).
- Add axis 3 of verifiable architecture principles to the architecture-lint as a SEPARATE axis with its own verdict and severities: blocker for core violations and anti-patterns, warning for suspicions.
- Add a mandatory non-verifiable principles checklist to the architecture-plan acta (arch-plan.md), with direction evidence per applicable principle; N/A with justification allowed.
- Establish the core axis 3 corpus: ~10 verifiable principles plus an anti-patterns catalog.
- Ship the full anti-patterns catalog (11) in the first cycle: monolith distributed, premature microservices, shared DB as integration, over-engineering, mutable global state, excessive sync, god object, mud ball, framework addiction, copy/paste, excessive chain of responsibility.
- Centralize the catalog in a single shared file `skills/_shared/architecture-principles.md` — the single source of truth consumed by quest, plan and lint by path (no duplication per skill).
- Verify with fixtures + RED suite: SDD change fixtures (one clean, one violating each principle/anti-pattern) on which the suite runs the linter and compares against expected results; the suite also tests the quest budget/branching behavior and the plan's mandatory section.

**Non-goals**

- The Product Quest is untouched: it keeps its budget of 50 and its current structure.
- No external refactor: the catalog documents and enables checks without forcing new technology or refactoring other skills outside this change's scope.

### Users & Outcome

Users (per the approved decisions): the human whose architecture intent the Quest interviews; the orchestrator that walks the declarative quest branch table; the plan author writing the mandatory checklist in the arch-plan.md acta; the architecture-lint executing axis 3.

Outcome: the architecture Quest produces context-selected questions within the fixed 20-question budget with early-stop and explicit gap classification; the lint produces a separate axis-3 verdict from per-check findings; the arch-plan.md acta carries a mandatory, anchored non-verifiable principles checklist.

### Domain Terminology & Business Rules

- **Context-driven question selection**: the architecture Quest asks 8 base context questions, then follows adaptive branching until an early-stop condition.
- **Adaptive branching**: branches are declared in an explicit declarative branch table in the sdd-quest skill; each branch declares its trigger, the principles/anti-patterns it loads, its branch questions, and its early-stop condition.
- **Stack trigger**: one of the 8 base questions asks whether stack/technology is a driver of the change. Yes → the technology branch is enabled; No → it is skipped (the default language-agnostic stance is preserved).
- **No principle-by-principle interview**: the Quest never interviews principle-by-principle; each context branch loads the relevant principles/anti-patterns. Applicability validation happens in the plan with justified N/A.
- **Axis 3**: the architecture-lint axis of verifiable architecture principles — a separate axis with its own verdict (`axis_3 pass|fail`), stable check IDs P01..P10 (principles) and A01..A11 (anti-patterns), per-check severity and per-check findings (full structural detail in the Architecture RFC).
- **Severity model**: blocker for core violations and anti-patterns; warning for suspicions.
- **Non-verifiable principles checklist**: mandatory section in the arch-plan.md acta; each applicable principle declares direction evidence; N/A with justification is allowed.
- **Checklist anchor**: the fixed canonical title `## Principios no verificables` in arch-plan.md with a table per principle; a missing title fails axis 2 closed.
- **Gap classification on early-stop**: a decision gap → a targeted question outside the questionnaire; a knowledge gap → a research lane; a blocking gap → Unresolved Questions in the RFC. No gap disappears silently.
- **Catalog single source of truth**: `skills/_shared/architecture-principles.md`, consumed by quest, plan and lint by path; no per-skill duplication.

### Contracts (Inputs / Outputs / Events / External)

**Inputs**

- Architecture Quest branch: answers to the 8 base context questions plus any adaptive branch questions; the stack/technology base answer (yes/no) that enables or skips the technology branch.
- arch-plan.md acta: the mandatory non-verifiable principles checklist section (fixed title `## Principios no verificables`).
- Architecture-lint: the implemented change, the design, and the arch-plan.md acta (axis 3 checks + checklist).

**Outputs**

- Quest: context-selected Q&A plus classified gaps (decision / knowledge / blocking); blocking gaps surface as Unresolved Questions in the RFC.
- Lint axis 3: per-check findings with stable IDs (P01..P10, A01..A11), per-check severity, and an aggregated verdict `axis_3 pass|fail`.
- Plan acta: per-principle declaration (applicable | direction evidence | N-A justified). N-A suppresses the check with visible justification; an applicable principle violated against evidence produces a dual signal (axis 2 + axis 3).

**Events**

- Early-stop of a quest branch (branch tree resolved or budget reached).
- Stack-trigger branch enable/skip derived from the base context answer.

**External**

- `skills/_shared/architecture-principles.md` — the shared catalog file, external to each consuming skill and consumed by quest, plan and lint by path.

### Invariants & Validation

- Architecture Quest hard budget = 20 questions; it is NOT raised by this change.
- The Quest asks only the 8 base context questions plus adaptive branch questions — never principle-by-principle interviews.
- Early-stop gaps never disappear silently: each gap is classified into exactly one of decision / knowledge / blocking.
- N/A in the plan checklist is valid only WITH justification.
- The checklist anchor title is fixed (`## Principios no verificables`); its absence fails axis 2 closed.
- The catalog is single-sourced at `skills/_shared/architecture-principles.md` — no per-skill duplication.
- Axis 3 has its own verdict, independent of axis 2; a violated applicable principle signals both axis 2 and axis 3.

### Failure Cases & Edge Cases

- Early-stop / budget exhaustion (20 reached with branches unresolved): the covered branches consolidate and pending ones are classified per the gap taxonomy; never a silent extension.
- Missing checklist title in arch-plan.md → axis 2 fail-closed.
- N/A declared without justification → invalid use of the N/A allowance.
- Suspicion-level findings vs core violations → differentiated severity (warning vs blocker).
- Anti-patterns present in the codebase → blocker severity, per the approved severity model.

### Security / Privacy / Performance / Operational

None decided in the approved product branch: the change carries no user-data handling, and no security, privacy, performance, or operational requirements were stated beyond the quest budget, the lint verdict mechanics, and the RED-suite verification described under Acceptance Criteria.

### Alternatives & Trade-offs

The approved product branch resolved these trade-offs:

- Richer adaptive branching inside the SAME fixed 20-question architecture budget instead of raising the budget (explicit: budget NOT raised).
- Full 11-anti-pattern catalog in the first cycle instead of a smaller first slice (completeness now).
- Single shared catalog file consumed by path instead of per-skill copies (no duplication).
- No external refactor: the catalog documents and enables checks without forcing new technology or refactoring other skills outside scope.
- No parallel JSON catalog in the first cycle (single structured Markdown source of truth).

### Acceptance Criteria (measurable)

- The architecture Quest presents 8 base context questions, follows the declarative branch table, supports early-stop, and never exceeds the budget of 20 questions; the stack trigger gates the technology branch per the base answer.
- The architecture-lint exposes axis 3 as a separate axis with stable IDs P01..P10 and A01..A11, per-check severity (blocker for core violations and anti-patterns, warning for suspicions), per-check findings, and an aggregated verdict `axis_3 pass|fail`.
- The catalog exists at `skills/_shared/architecture-principles.md` with per-principle name, definition, concrete evidence and default severity plus the 11-entry anti-pattern table; no parallel JSON in the first cycle; quest, plan and lint consume it by path.
- arch-plan.md contains the mandatory checklist at the fixed title `## Principios no verificables` with a table per principle; per-principle state is one of applicable | direction evidence | N-A justified; missing title fails axis 2 closed.
- The RED suite runs the linter against SDD change fixtures (one clean, one violating each principle/anti-pattern) and matches expected results; it also tests the quest budget/branching behavior and the plan's mandatory section.

### Unresolved Questions (blocking)

None — the product branch resolved fully at RFC gate 1 with explicit user approval; no decision, knowledge, or blocking gaps were carried forward.