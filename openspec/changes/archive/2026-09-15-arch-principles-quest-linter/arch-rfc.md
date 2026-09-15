# Architecture RFC: arch-principles-quest-linter

## Approval: approved

Approval gate: RFC gate 2 (Architecture branch), explicitly approved by the user. Source: quest Q&A architecture branch — all decision branches resolved; no blocking gaps for design.

## RFC

### Architecture Constraints & Decision Space

- Quest architecture branch: context-driven question selection — 8 base context questions + adaptive branching + early-stop, within a FIXED hard budget of 20 questions (not raised).
- Branching is codified as an explicit declarative branch table in the sdd-quest skill: each branch declares its trigger (the context that activates it), the principles/anti-patterns it loads, its branch questions, and its early-stop condition; the orchestrator walks the table.
- The catalog feeds branching, never the interviews: the Quest never interviews principle-by-principle; each context branch loads the relevant principles/anti-patterns; applicability validation happens in the plan with justified N/A.
- Stack trigger: one of the 8 base questions asks whether stack/technology is a driver of the change; yes → enables the technology branch; no → skips it (default language-agnostic stance preserved).
- Axis 3 is a separate architecture-lint axis with its own verdict and severities: blocker for core violations and anti-patterns, warning for suspicions.
- Catalog is single-sourced at `skills/_shared/architecture-principles.md` (no per-skill duplication); no parallel JSON in the first cycle.
- Applicability lives in the acta, not the linter: the mandatory checklist section declares, per principle, applicable | direction evidence | N-A justified; N-A suppresses the check with a visible justification.

### System Boundaries & Modules

- **sdd-quest skill** — owns the 8 base context questions, the declarative branch table (trigger / loaded principles-anti-patterns / branch questions / early-stop), the stack trigger, and early-stop gap classification; consumes the catalog by path.
- **architecture-plan acta (arch-plan.md)** — owns the mandatory non-verifiable checklist at the fixed title, with per-principle applicability declarations and direction evidence; N/A with justification.
- **architecture-lint** — owns axis 3: stable checks P01..P10 + A01..A11, per-check severity and findings, aggregated verdict `axis_3 pass|fail`; also fails axis 2 closed when the checklist title is missing.
- **`skills/_shared/architecture-principles.md`** — the shared catalog module: single source of truth consumed by quest, plan and lint by path; no duplication per skill.
- Out of scope: the Product Quest (budget 50 and current structure untouched) and all other skills (no external refactor).

### Interfaces (internal contracts)

- **Catalog contract** (`skills/_shared/architecture-principles.md`): structured Markdown; per principle — name, definition, concrete evidence, default severity; plus an anti-pattern table; NO parallel JSON in the first cycle.
- **Branch table contract** (sdd-quest skill): declarative rows, each declaring trigger (activating context), principles/anti-patterns loaded, branch questions, early-stop condition; walked by the orchestrator.
- **Axis 3 contract** (architecture-lint): individual checks with stable IDs P01..P10 (principles) and A01..A11 (anti-patterns); per-check severity; per-check findings; aggregated verdict `axis_3 pass|fail`.
- **Checklist contract** (arch-plan.md): fixed canonical title `## Principios no verificables`; table per principle; per-principle state applicable | direction evidence | N-A justified; N-A suppresses the check with a visible justification; an applicable principle violated against evidence emits a dual signal (axis 2 + axis 3); missing title → axis 2 fail-closed.
- **Gap handoff contract** (quest → RFC): early-stop gaps classify as decision gap (→ targeted question outside the questionnaire), knowledge gap (→ research lane), or blocking gap (→ Unresolved Questions in the RFC); no gap disappears silently.

### Data & Persistence

- The catalog is the persisted shared data: a structured Markdown document at `skills/_shared/architecture-principles.md`; no parallel JSON store in the first cycle.
- arch-plan.md acta persists the non-verifiable checklist and per-principle declarations.
- Quest Q&A persistence follows the existing quest artifact flow (unchanged for this change; the Product Quest structure is untouched).
- No new persistence backend is introduced by this change.

### Security / Privacy / Operational Architecture

None stated in the approved architecture branch. Operationally, the change adds verification via SDD change fixtures and the RED suite (one clean fixture, one violating fixture per principle/anti-pattern, with expected lint results; plus quest budget/branching and plan-mandatory-section coverage), and a fail-closed gate: a missing checklist title fails axis 2.

### Scalability & Performance Envelope

No scalability or performance targets were decided. The only bounded-resource constraints resolved are: the fixed architecture Quest budget of 20 questions with early-stop, and the fixed first-cycle corpus size — 10 verifiable principles (P01..P10) plus 11 anti-patterns (A01..A11).

### Integration Architecture

- quest ↔ catalog: by path (branch table loads the relevant principles/anti-patterns; never principle-by-principle interviews).
- plan ↔ catalog: by path (the checklist applicability declarations reference the catalog principles).
- lint ↔ catalog: by path (axis 3 checks resolve against the catalog's principles, evidence and severities).
- lint ↔ plan acta: axis 2 fail-closed when the checklist title is missing; axis 3 honors the acta's applicability declarations (N-A justified suppresses the check); an applicable, violated principle against evidence produces the dual signal axis 2 + axis 3.
- The shared catalog is the integration seam: one source of truth, three consumers, no duplication.

### Technology Constraints (user-confirmed only)

- No language, framework, or runtime stack was confirmed as a requirement for this change.
- User-confirmed format constraints: the catalog is a structured Markdown document (`skills/_shared/architecture-principles.md`), with NO parallel JSON in the first cycle.
- The stack/technology trigger inside the Quest is quest behavior (a base context question gating the technology branch), not a stack choice for this change.

### Unresolved Questions (blocking for design)

None — the architecture branch resolved fully at RFC gate 2 with explicit user approval; no blocking questions were carried forward for design.