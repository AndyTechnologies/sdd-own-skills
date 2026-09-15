# Architecture Plan: arch-principles-quest-linter

## Approval: approved

Verdict from the architecture-plan phase: the acta is complete and resolvable against its inputs, ready for the user gate. The orchestrator presents the approval gate; design MUST NOT start until the user approves. A rejection re-enters this phase with findings (bounded correction, max 2 rounds; a 3rd rejection stops with a report).

## Inputs Consumed

| Input | Locator | Status |
|---|---|---|
| Architecture RFC | `openspec/changes/arch-principles-quest-linter/arch-rfc.md` | read in full (Approval: approved) |
| Spec delta — catalog | `specs/architecture-principles/spec.md` | read in full |
| Spec delta — quest branch | `specs/architecture-quest-branch/spec.md` | read in full |
| Spec delta — lint axis 3 | `specs/architecture-lint-axis3/spec.md` | read in full |
| Spec delta — plan checklist | `specs/architecture-plan-checklist/spec.md` | read in full |
| Spec delta — baseline import | `specs/baseline-import/spec.md` | read in full |
| Proposal (scope context) | `proposal.md` | read in full |
| Explore findings | inline summary from orchestrator (deployed baseline facts) | consumed |

Baseline facts verified directly in this phase (not assumed): deployed `~/.config/sdd-own/` runs quest v4.0 and lint v2.0; the deployed plan prompt (`sdd-architecture-plan.md` v3.0) contains **no** `## Principios no verificables` anchor and no axis-3 content (checklist and axis 3 are pure deltas); the shared catalog exists **nowhere** yet (not in `skills/_shared/`, not in the deployed `~/.config/sdd-own/skills/_shared/`); the worktree `wiring/prompts/sdd/` holds only `orchestrator.md`, `sdd-council.md`, `sdd-rfc-author.md`; `wiring/opencode.sdd.json` has no `sdd-architecture-plan` key; `sync-skills.sh` owns the SHARED loop (`for f in "${SHARED_BOOTSTRAP[@]}" codegraph.md`, two destinations) and `OWN_PROMPTS=(orchestrator.md sdd-rfc-author.md sdd-council.md)`; `tests/run_red_checks.sh` pins T34 (OWN_PROMPTS), T35 (lint strings), T37 (fragment allow-list `["$schema","agent","default_agent","subagent_depth"]`), and the suite runs through T48 with no `tests/fixtures/` yet.

## Pattern Research

**No pattern gap detected — no research lane launched.** Every structural decision below resolves from the arch-rfc, the five spec deltas, the proposal, and the verified baseline artifacts. These are internal pipeline contracts (skills/shell/wiring/tests), not third-party technology choices; no external pattern evidence is required. Per the phase contract, research stays optional and is only opened on a real evidence gap.

## Decision

### Decision: Single shared catalog as the integration seam

**Decision**: The verifiable corpus lives in exactly one file, `skills/_shared/architecture-principles.md`, consumed by path by exactly three consumers — quest, architecture plan, lint — with **no** per-skill duplication and **no** parallel JSON store in this cycle. The file joins the existing `sync-skills.sh` shared loop with copy-only-if-missing semantics at BOTH destinations (canonical `~/.config/sdd-own/skills/_shared/` and the real shared agents directory), exactly like `codegraph.md` today; `sync-skills.sh --check` must report zero desyncs after deployment and must never overwrite an existing installed copy.

**Rationale**: The RFC fixes the catalog as the integration seam — one source of truth, three consumers, no duplication — and the spec binds the deployment mechanism (copy-only-if-missing, zero-desync `--check`). Reusing the existing `SHARED_BOOTSTRAP[@] + codegraph.md` loops avoids a new deploy mechanism. The catalog is a data module, not a skill: it stays a plain Markdown file in the shared directory, never a `SKILL.md`.

**Citations**: arch-rfc § System Boundaries & Modules (catalog module; no per-skill duplication), § Integration Architecture (one source, three consumers); spec `architecture-principles` S1, S2, S3, S5 + "Single Source of Truth" + "Safe Shared-Loop Deployment"; proposal Affected Areas (`sync-skills.sh` Mod); verified: `sync-skills.sh` lines 541–618 (both copy-only-if-missing loop destinations).

### Decision: Catalog schema pin — the fixture-authoring contract

**Decision**: The catalog implements the fixed schema below, byte-deterministic so fixtures and RED greps can be authored against it:

- Corpus: exactly 10 principles (`P01`..`P10`) and exactly 11 anti-patterns (`A01`..`A11`), stable IDs.
- Two top-level sections: `## Principles` (one `### P## — <name>` subsection per principle) and `## Anti-patterns` (a single Markdown table).
- Each principle subsection MUST contain exactly the labeled fields, in this order: `- Definition:`, `- Concrete evidence:`, `- Default severity:`.
- The anti-pattern table MUST have exactly the columns `| ID | Name | Definition | Concrete evidence | Default severity |`.
- Severity domain is exactly `blocker | warning`: `blocker` for core-principle violations and detected anti-patterns, `warning` for unconfirmed suspicions.
- The catalog remains the single source; consumers hold no copies.

The exact `name` and `definition` contents are design-owned (see Open Decisions — delegated content). Fixtures, axis-3 checks, and the checklist in THIS acta all key on the stable IDs, so schema byte-completion is the compatibility contract: the RED cross-check (S4) resolves catalog entries ↔ lint checks by ID in both directions.

**Rationale**: The spec names the four fields and the anti-pattern table; the RFC names the severity domain. Fixing field labels, section shape, and severity vocabulary in the acta pins what fixtures may assert and what the RED cross-check can grep — this closes the "axis-3 expectations depend on catalog byte-completion" risk.

**Citations**: arch-rfc § Interfaces (catalog contract: "per principle — name, definition, concrete evidence, default severity; plus an anti-pattern table"), § Scalability & Performance Envelope (fixed corpus 10+11); spec `architecture-principles` S4, S5 + "Fixed Catalog Schema"; orchestrator mandate (pin the catalog schema).

### Decision: Checklist contract — one dual-signal / N-A-suppress mechanism

**Decision**: The two skills (plan-checklist and lint-axis3) implement ONE shared mechanism, defined here and normative for design — the acta definitions MUST NOT be re-derived or drifted between the two skills:

- **Container**: the checklist is a section inside `arch-plan.md` (never a separate file) anchored at the literal, byte-exact title `## Principios no verificables`. A missing title fails axis 2 closed.
- **Per-row state**: each of the 21 rows declares EXACTLY one state of the closed enum `applicable | direction-evidence | n-a-justified`.
- `applicable` — the principle constrains this change as a MUST. Direction evidence is REQUIRED in the row. Axis 3 runs the check at the catalog default severity; contradicted evidence produces the dual signal.
- `direction-evidence` — the principle informs this change as recorded direction (SHOULD/commitment, not hard MUST). Direction evidence is REQUIRED. The check RUNS (only `n-a-justified` suppresses); contradicted evidence produces the SAME dual signal as `applicable`. The design-side difference is binding force: `applicable` rows require demonstrated conformance; `direction-evidence` rows require the recorded direction to hold.
- `n-a-justified` — the check is SUPPRESSED with the justification visible in the lint findings. An N/A row WITHOUT justification emits an axis 2 warning requiring the justification. The section exists with N-A justified rows even when no principle applies; the section is NEVER omitted.
- **Dual signal** (one rule, both skills): an applicable or direction-evidence row whose declared evidence is contradicted by the implementation ⇒ axis 2 flags the unmet mandate AND axis 3 emits a blocker finding at the catalog severity, on the same check ID.
- **Signal table** (normative):

| Row state | Evidence required | Axis-3 check | Contradiction signal |
|---|---|---|---|
| `applicable` | yes (direction evidence) | runs at catalog severity | axis 2 unmet mandate + axis 3 blocker |
| `direction-evidence` | yes (direction evidence) | runs at catalog severity | axis 2 unmet mandate + axis 3 blocker |
| `n-a-justified` | justification (mandatory) | suppressed, justification visible | none (axis 2 warning if justification missing) |

**Rationale**: The checklist spec and the lint-axis3 spec independently describe the same three-state model, the warning rule, and the dual signal; the orchestrator mandate makes them ONE contract so design cannot drift them. The state enum and signal table above are the single normative definition; both skills reference it and the lint's pinned strings (T35) cover both sides of the contract.

**Citations**: arch-rfc § Interfaces (checklist contract, axis 3 contract), § Data & Persistence; spec `architecture-plan-checklist` C1–C7 + "Mandatory Anchored Section" + "Per-Principle Applicability Declaration" + "Dual Signal on Contradicted Evidence"; spec `architecture-lint-axis3` L5, L6 + "Acta Interplay"; orchestrator mandate (one contract, canonical anchor, N/A warning).

### Decision: Axis 3 becomes a third lint axis with an independent verdict

**Decision**: `sdd-architecture-lint` gains axis 3, running after axes 1 and 2 in the post-apply lint, with:
- **Independent verdict** `axis_3 pass|fail`; the verdict is `fail` ONLY when at least one blocker finding exists; warnings never fail it.
- **Stable checks** P01..P10 + A01..A11, resolved against the shared catalog by path (same literal path as the quest and the plan — the single-seam rule). Each finding carries its check ID plus the concrete evidence it resolved.
- **Severity model**: `blocker` for core-principle violations and detected anti-patterns; `warning` for unconfirmed suspicions; ambiguous evidence renders a warning, never a blocker, absent confirmation.
- **Full blocker set**: a fixture with multiple violations produces ALL blocker findings, not only the first.
- **Acta interplay** via the D3 contract: `n-a-justified` suppresses with visible justification; applicable/direction-evidence contradiction emits the dual signal.
- **Persistence and report**: axis 3 findings live in the same `architecture-conformance` report; the envelope exposes `axis_3 pass|fail` as its own field.
- **Regression**: axis 1 (boundaries) keeps its no-dogma rules and opt-outs; axis 2 keeps the mandatory acta gate; existing suite T01–T48/T42b/T47b stays green.

**Rationale**: The lint spec binds the axis separation, the verdict rule, the severity model, the findings contract, the acta interplay, and the fixture/RED verification; the RFC binds severity vocabulary and the stable ID scheme. Keeping axis 3 inside the existing lint skill (not a new skill) preserves the single post-apply second-eye flow.

**Citations**: arch-rfc § System Boundaries & Modules (architecture-lint owns axis 3), § Interfaces (axis 3 contract); spec `architecture-lint-axis3` L1–L7 + all five requirements; verified lint v2.0 baseline (axes 1+2 shape, MANDATORY acta, T35 pins).

### Decision: Quest architecture-branch rework — table-driven, catalog-fed, budget 20

**Decision**: The architecture branch of `sdd-quest` reworks into context-driven selection:
- **8 base context questions** asked first, including the mandated stack/technology trigger as one of the 8. The interview never walks principle-by-principle.
- **Declarative branch table** inside `sdd-quest/SKILL.md` (the RFC's "codified" requirement): each row declares trigger, principles/anti-patterns loaded (from the catalog by path), branch questions, early-stop condition, and a declared precedence for ambiguous triggers. The orchestrator walks the table as the ONLY question-selection source; implicit prose branches do not exist; no scripted state machine replaces the table.
- **Stack trigger**: yes → technology branch enabled; no → skipped, language-agnostic default preserved; confirmed-with-no-branch → driver recorded and the branch early-stops with zero questions.
- **Budget 20, FIXED** (never raised). Early-stop when all triggered branches resolve within budget; exhaustion produces a consolidation report with classified gaps, never a silent extension.
- **Gap classification** (exactly one per gap): decision (targeted question outside the questionnaire) | knowledge (research lane) | blocking (RFC Unresolved Questions); no gap disappears silently.
- **Applicability is NOT interviewed**: the catalog feeds branching; the plan (this acta family) validates applicability with justified N/A.
- **Product Quest untouched**: budget 50 and current structure unchanged; its checks keep passing.

**Rationale**: The quest-branch spec binds all of the above scenario-by-scenario (A1–A10); the RFC binds the 8-question start, the table contract, the stack trigger, early-stop, and the fixed 20 budget; the non-goal bounds the mechanism (table only, no state machine).

**Citations**: arch-rfc § Architecture Constraints & Decision Space (context-driven, table, stack trigger, budget 20, catalog feeds branching), § System Boundaries & Modules (quest owns the table); spec `architecture-quest-branch` A1–A10 + all seven requirements; proposal Scope (quest arch branch).

### Decision: Baseline import — deployed bytes as canonical, pins co-updated

**Decision**: The deployed state becomes repo canonical:
- `skills/sdd-quest/SKILL.md` ← deployed quest v4.0 bytes; `skills/sdd-architecture-lint/SKILL.md` ← deployed lint v2.0 bytes — byte-exact, verified by T-pins (B1/B2); the deltas of D4/D5 layer on top of those imported bytes.
- The 4 unversioned prompts — `sdd-architecture-plan.md`, `sdd-hard-gate.md`, `sdd-hard-verify.md`, `sdd-pre-experience.md` — are versioned under `wiring/prompts/sdd/` from the deployed `~/.config/sdd-own/prompts/sdd/` copies.
- The orchestrator contract is updated from the deployed bytes at `wiring/prompts/sdd/orchestrator.md` and referenced by file only, never inline.
- `wiring/opencode.sdd.json` registers the `sdd-architecture-plan` agent (mode `subagent`, hidden, prompt `{file:./prompts/sdd/sdd-architecture-plan.md}` — the council-shaped, file-based pattern already pinned by T33/T37); the fragment keeps ONLY the sanctioned top-level keys (`$schema`, `agent`, `default_agent`, `subagent_depth`) and stays additive over personal config.
- **Pin co-updates**: T34 gains the 4 prompts in OWN_PROMPTS; T35 gains the axis-3 strings (verdict form `axis_3 pass|fail`, ID scheme `P01`/`A01`, severity labels, checklist-contract strings); T37 stays shape-identical (new agent keys live under `agent`, the allow-list already fits).
- `sync-skills.sh --check` gates any install; rollback is a single-PR revert to HEAD f9ec832 with zero residual desyncs and the deployed runtime untouched by repo-local import.

**Rationale**: The baseline-import spec binds every element (byte-exact B1/B2, prompts B4, by-file contract B3, agent B5, pins B6, check gate B7, rollback B8); the exploration confirmed the current worktree staleness and the user-approved import. Byte-exactness plus co-updated pins is what keeps `--check` at zero instead of flagging the newly versioned files.

**Citations**: spec `baseline-import` B1–B8 + all four requirements; explore findings (deployed v4.0/v2.0, 4 unversioned prompts, missing agent key, pin co-updates, f9ec832 stale); verified: worktree `wiring/prompts/sdd/` contents, T37 allow-list shape, T34 OWN_PROMPTS value.

### Decision: Fixture and RED contract for axis 3

**Decision**: New `tests/fixtures/arch-principles/` with:
- ONE clean fixture representing a conforming SDD change → expected `axis_3 pass`, zero blocker findings.
- ONE dirty fixture per principle/anti-pattern family, each violating exactly its family → expected blocker findings on the family's exact check IDs (L2), with severities read from the catalog.
- ONE multi-violation fixture → expected complete blocker set (L3), proving the lint reports all findings, not only the first.
- A missing/renamed-checklist fixture pairing with the plan-checklist contract (missing title → axis 2 fail-closed; translated anchor MUST NOT satisfy presence).
- Expected findings pinned per fixture in a machine-readable form the RED suite compares against; new checks T49+ run axis 3 over the fixtures, cross-check catalog entries ↔ checks by ID (S4), and assert the verdict/severity/suppression rules.
- Suite budget: axis-3 checks stay cheap (structure, dependencies, imports) and the RED suite stays under 2 minutes; existing checks T01–T48/T42b/T47b must not regress (L7).
- Fixture file naming and layout are design-owned within this contract.

**Rationale**: The lint spec binds fixtures (clean + dirty per family, expected findings, cheap checks, suite budget, no regressions); the checklist spec binds the missing-title/translated-anchor edge; the proposal binds the fixture location and the T49+ numbering.

**Citations**: spec `architecture-lint-axis3` L1–L4, L7 + "Fixture-Verified, Cheap Checks"; spec `architecture-plan-checklist` C1, C2; proposal Scope (fixtures + RED); verified: `tests/run_red_checks.sh` T-groups run through T48, no `tests/fixtures/` yet.

### Decision: Non-goals enforcement (approved boundaries)

**Decision**: The change does NOT alter: the Product Quest (budget 50 and structure), any skill beyond the baseline surfaces named in the proposal's affected areas (no external refactor), the persistence model (no new backend), the delivery shape (single PR, accepted size exception). The change MUST NOT introduce a parallel JSON catalog and MUST NOT replace the branch table with a scripted state machine. No language/framework/runtime stack is confirmed as a requirement.

**Rationale**: The RFC and the proposal both state these exclusions explicitly; the spec's Product-Quest-untouched requirement and the no-JSON/no-state-machine constraints bind them; RED and wiring keep them enforced (`--check`, fixture expectations, proposal scope table).

**Citations**: arch-rfc § System Boundaries & Modules (out of scope), § Technology Constraints; spec `architecture-quest-branch` "Product Quest Untouched" (A1/A2); proposal Scope out-of-scope list + rollback; verified T37 keep-list.

### Decision: Artifact language pin — English except the literal anchor

**Decision**: All artifacts of this change (catalog, skills, prompts, fixtures, tests, acta content) are English per the Language Domain Contract, with ONE user-approved exception: the checklist anchor is the literal, byte-exact heading `## Principios no verificables`. A translated or paraphrased variant (e.g. an English rendering) MUST NOT satisfy the axis-2 presence gate — the fail-closed check matches the literal title only.

**Rationale**: The user approved the Spanish anchor for the checklist section; the language contract governs everything else. Pinning the byte-exact title plus its non-translatability keeps the lint deterministic and preserves the user's explicit choice.

**Citations**: orchestrator mandate (canonical anchor section titled exactly `## Principios no verificables`; language-neutral English artifacts EXCEPT the literal anchor); `sdd-phase-common.md` Language Domain Contract; spec `architecture-plan-checklist` C1 (section titled `## Principios no verificables`).

## Principios no verificables

Mandatory anchor section of the architecture-plan acta (byte-exact title, user-approved; translated variants do not satisfy the gate). State legend: `applicable` = the principle constrains this change (direction evidence mandatory, check runs, contradiction → dual signal); `direction-evidence` = the principle informs the change's direction (evidence mandatory, check runs, contradiction → dual signal); `n-a-justified` = not applicable to this change (justification mandatory, check suppressed; missing justification → axis-2 warning).

The `Principle` column entries are the stable catalog IDs P01..P10 / A01..A11 plus a provisional subject seed for readability. The authoritative `name`/`definition` for each ID is authored at design inside the catalog (schema pinned in D2); fixtures, checks, and the RED cross-check key on the IDs, never on the seeds. N/A rows below are all justified; an unjustified N/A in any future acta produces an axis-2 warning per D3.

| Principle | Applicability | Justification / direction evidence |
|---|---|---|
| P01 · Dependency direction (inward) | applicable | Direction evidence: the catalog is the hub (D1); quest, plan, and lint resolve it by exactly one path (S3); checks point at the catalog, never at consumer-held copies; per-skill duplication is a violation (S4). |
| P02 · Explicit interfaces / contracts | applicable | Direction evidence: the catalog schema (D2), the branch-table contract (D5), the axis-3 ID/severity contract, and the checklist contract (D3) are fixed, grep-pinnable interfaces authored in this acta and implemented byte-deterministically. |
| P03 · Single source of truth / no duplication | applicable | Direction evidence: one catalog, three consumers, no copies (RFC integration seam); cross-check S4 fails on drift; the shared-loop deploy is copy-only-if-missing (S2). |
| P04 · Minimal change / no-dogma | applicable | Direction evidence: baseline import + layered deltas only (D6); affected areas bounded by the proposal; external refactor is a non-goal (D8); axis-1 no-manufactured-boundary rules preserved (D4). |
| P05 · Fail-closed gates | applicable | Direction evidence: missing checklist title fails axis 2 closed (C2); N/A without justification is a warning (C5); `--check` gates installs (B7); budget exhaustion never extends silently (A7). |
| P06 · Testability / fixture coverage | applicable | Direction evidence: clean+dirty fixtures per family with expected findings (L1–L3), new T49+, catalog↔check cross-check (S4), byte T-pins (B1/B2). |
| P07 · Separation of concerns (skill boundaries) | applicable | Direction evidence: quest owns questioning (D5), plan owns applicability (D3 checklist), lint owns checks (D4); the branch table lives only in quest, the checklist only in the acta, axis 3 only in lint; one catalog. |
| P08 · Cheap, deterministic verification envelope | applicable | Direction evidence: axis-3 checks restricted to structure/dependencies/imports; RED suite under 2 minutes (L7); quest hard budget 20 with deterministic early-stop and consolidation (A6/A7). |
| P09 · Stable identity (IDs and schema) | direction-evidence | Direction recorded: IDs P01..P10/A01..A11 and the catalog schema are frozen this cycle with no parallel JSON (D2); the corpus is first-cycle, so stability is a commitment to future cycles rather than protection of pre-existing consumers — directional, not a hard gate for this change. |
| P10 · Deterministic execution, no hidden state | direction-evidence | Direction recorded: the sync is idempotent copy-only-if-missing (S2) and `--check`-gated (B7); RED checks are deterministic grep/jq; no scripted state machine (D8). No runtime application code exists in this change to hard-gate determinism against — directional. |
| A01 · Duplication across boundaries | applicable | The change's own deliverable would violate it if a consumer held a copy: S3 pins the single path and S4 cross-checks catalog↔checks, so duplication is a detected blocker for this change's surfaces. |
| A02 · Layer/component skipping or cyclic references | direction-evidence | Direction recorded: the reference graph (prompts → skills → `_shared`) stays acyclic and file-based; wiring references prompts by file (B3); the sync installs shared before consumers. No application layers exist to hard-gate — directional. |
| A03 · God module / monolithic blob | n-a-justified | Justification: every artifact introduced is single-purpose (SKILL.md per skill, one data catalog, one prompt per agent, one fixture per family); the catalog is data, not logic, so no god-module surface exists to detect in this change. |
| A04 · Premature abstraction | direction-evidence | Direction recorded: the catalog is introduced because three real consumers exist today (RFC: one source, three consumers), not speculative reuse; no other abstraction layers are added — directional. |
| A05 · Manufactured architecture / no-dogma violation | applicable | The lint's no-dogma rule (axis 1 N/A when no boundary exists) is preserved (D4); fixtures assert expected results and must not invent findings; this change is precisely about a verifiable-principles loop, so manufacturing findings would defeat it. |
| A06 · Silent skip of mandatory gates | applicable | Fail-closed gates are the change's spine: missing acta/title (C2), `--check` before install (B7), budget exhaustion with classified gaps instead of silent extension (A7), bounded 2-round corrections. |
| A07 · Contract ↔ implementation drift | applicable | S4 cross-check, byte T-pins (B1/B2), and the dual signal (L6/C7) couple declared evidence with the applied implementation; rollback residual check (B8) closes the loop. |
| A08 · Scope creep | applicable | Non-goals are pinned (D8): product quest untouched, no JSON catalog, no state machine, no external refactor; the proposal sizes a single PR with an accepted size exception; T37 guards the wiring fragment surface. |
| A09 · Non-deterministic checks | direction-evidence | Direction recorded: RED checks are deterministic grep/jq byte comparisons; sync is idempotent. No runtime code exists to nondeterministically fail — directional. |
| A10 · Fragile exact-byte pins | direction-evidence | Direction recorded: byte-exact T-pins (B1/B2) are intentional precision, and they are co-updated with the import (B6) so they never cite stale bytes; the residual risk (pins break on intentional rework) is acknowledged and bounded by the co-update rule — directional. |
| A11 · Hidden side effects / silent writes | direction-evidence | Direction recorded: installs only run after `--check` (B7), the sync is idempotent with no hidden writes, and verify evidence claims are shape-validated (untrusted-data contract). No runtime side-effect surface — directional. |

## Open Decisions

None blocking. The following content is delegated to design under the acta constraints above (not silent assumptions, and not resolvable from inputs — the inputs deliberately assign it to the catalog/branch author):

1. Catalog `name` and `definition` text for P01..P10 and A01..A11 (schema pinned in D2; IDs and severities fixed here; the D3 checklist table and S4 cross-check key on IDs).
2. The six base context questions beyond the mandated stack trigger and the microservices-detection question (A3/A4/A5 bind those two; the remaining six dimensions are design-authored within "context-driven, never principle-by-principle").
3. Exact fixture file naming/layout under `tests/fixtures/arch-principles/` (families, clean/dirty/multi-violation content per D7).

## Risks

- **Catalog byte-completion dependency**: axis-3 expectations and fixtures depend on the catalog carrying the exact pinned schema; if design under-fills a field, S4 cross-check and fixture expectations fail. Mitigated by D2 (exact field labels/severity domain), the D3 ID-keyed checklist, and the S4 cross-check itself.
- **Dual-signal drift between the two skills**: plan-checklist and lint-axis3 could diverge on suppression/dual-signal semantics. Mitigated by D3's single normative contract and T35 pins covering both sides' strings.
- **Baseline byte drift**: if the deployed artifacts changed between explore and apply, the import would diverge from the pinned expectations. Mitigated by re-reading the deployed copies at apply and by the byte T-pins (B1/B2) validating the imported state.
- **Unjustified N/A warnings**: any future acta row missing its justification triggers an axis-2 warning. Mitigated by the section's normative table and warning rule (C5).
- **Suite time**: fixtures add RED runtime. Mitigated by the cheap-checks restriction and the < 2 minutes budget (L7).