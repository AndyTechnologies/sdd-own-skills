---
name: sdd-architecture-plan
description: "Run the Architecture Plan phase: consume arch-rfc.md + explore/research + the change's spec deltas, optionally launch a pattern-research lane, and produce the binding architecture plan acta arch-plan.md with titled decisions, each resolvable against the inputs. Verdict: approved | rejected (bounded correction, max 2 rounds). Trigger: orchestrator launches architecture-plan after spec, before design."
disable-model-invocation: true
user-invocable: false
license: MIT
metadata:
  author: gentleman-programming (adapted)
  version: "3.0"
  delegate_only: true
---

## Execution Role

Confirm your role before acting. You are the dedicated `sdd-architecture-plan` SDD sub-agent. You are the executor, NOT the orchestrator — do NOT delegate and do NOT call task. Your phase resolves the structural decisions (including optional pattern research) and produces the binding architecture plan acta. Design MUST NOT start until the user approves your plan.

> Follow the **Language Domain Contract** in `skills/_shared/sdd-phase-common.md`.

## Purpose

The Architecture Plan phase runs AFTER spec and BEFORE design. It consumes:

1. `arch-rfc.md` (the approved architecture RFC — the architecture/constraint mandate),
2. the explore/research evidence (the arch-side evidence),
3. the change's spec deltas (the per-capability requirements).

It resolves structural decisions — boundaries, modules, interfaces, data, non-functional envelope — and produces a **binding architecture plan acta** at `openspec/changes/{change-name}/arch-plan.md` with titled decisions, each resolvable against the inputs. The user approves the plan (explicitly in interactive mode; recorded without interruption in auto mode) before design starts; a rejection returns control to this phase with the findings (bounded correction, max 2 rounds).

## What You Receive

From the orchestrator:

- Change name
- Artifact store mode (`engram | openspec | hybrid | none`)
- Input paths (required, fail-closed): `arch-rfc.md`, `explore`, `research` (when a lane exists), spec deltas
- Prior-context retro precis when available (fail-open — zero retros → no injection, no block)
- The change's worktree path (`--cwd <worktree>` is binding)

## Hard constraints

1. **Inputs gate (fail-closed):** all three input classes SHALL exist before you start — `arch-rfc.md`, explore/research evidence, and the spec deltas. Missing any → STOP with `blocked` reporting the missing input; never invent evidence to proceed. The phase never runs before all inputs exist.
2. **Resolvable decisions only:** every titled decision in the acta SHALL be resolvable against the inputs. A decision with no input grounding is a failure.
3. **Optional pattern research only when needed:** if a structural decision needs pattern evidence not resolvable from the inputs, request the pattern-research lane (orchestrator launches `sdd-research`; if your runtime permits task delegation you may launch it yourself). Findings SHALL be passed to you and cited in the acta. No pattern gap → no research is forced.
4. **No design, no implementation:** you produce the PLAN (structure/decisions), not the design, not code.
5. **User gate:** you return the acta; the orchestrator presents the approval gate. A rejection returns control to you with the findings (max 2 rounds); a 3rd rejection stops with a report. Never self-approve.

## Execution and Persistence Contract

> Follow **Section B** (retrieval), **Section C** (persistence), and **Section D** (return envelope) from `skills/_shared/sdd-phase-common.md`.

Artifact: you persist the **architecture plan acta** with titled decisions:

- **engram**: save as `sdd/{change-name}/arch-plan`, type `architecture`, `capture_prompt: false`.
- **openspec**: write `openspec/changes/{change-name}/arch-plan.md`. (Additive file within the change folder; it does not create a new native artifact token.)
- **hybrid**: do BOTH (file + engram save).
- **none**: return the acta inline only.

## What to Do

### Step 1: Load Skills

Follow **Section A** from `skills/_shared/sdd-phase-common.md`.

### Step 2: Read the Inputs (verbatim from the backend)

Read `arch-rfc.md` in full (required), the explore/research evidence (required — resolved paths), and every spec delta (required). Do not summarize: read the actual artifacts. Missing input → `blocked` with the missing input named.

### Step 3: Detect Pattern Gaps

Walk the structural decisions you must make (boundaries, modules, interfaces, data, non-functional envelope). Wherever the inputs cannot resolve a decision and pattern evidence would help, open the pattern-research lane and wait for its findings before finalizing that decision. No gap → proceed from the inputs alone.

### Step 4: Author the Acta

Produce `arch-plan.md` with **titled decisions**, each carrying: the decision title, the decision, the rationale, and the input citations that resolve it (arch-rfc section, explore/research finding, spec scenario). Mark any decision that depends on the pattern-research findings with its citation. Every title SHALL be resolvable against the inputs; unresolved items SHALL be listed explicitly as open decisions with the evidence needed to close them — never silently assumed.

**Mandatory checklist section — `## Principios no verificables`.** Every acta SHALL include a section anchored at the literal, byte-exact Spanish heading `## Principios no verificables` (user-approved; a translated or paraphrased variant NEVER satisfies the axis-2 presence gate — the lint matches the literal title only, and a missing heading fails axis 2 closed, C2). The section is a table with one row per stable catalog ID — all 21: the principles P01..P10 and the anti-patterns A01..A11, whose authoritative names and definitions are resolved by path from the single source `skills/_shared/architecture-principles.md` (never copied inline). Each row declares EXACTLY one state of the closed enum `applicable | direction-evidence | n-a-justified`, with its evidence or justification MANDATORY in the row and never omitted:

| ID | State (exactly one) | Evidence or justification (MANDATORY) |
| P01 |  |  |
| P02 |  |  |
| P03 |  |  |
| P04 |  |  |
| P05 |  |  |
| P06 |  |  |
| P07 |  |  |
| P08 |  |  |
| P09 |  |  |
| P10 |  |  |
| A01 |  |  |
| A02 |  |  |
| A03 |  |  |
| A04 |  |  |
| A05 |  |  |
| A06 |  |  |
| A07 |  |  |
| A08 |  |  |
| A09 |  |  |
| A10 |  |  |
| A11 |  |  |

State semantics (normative):

- `applicable` — the principle constrains this change as a MUST. Direction evidence is REQUIRED in the row. Axis 3 runs the check at the catalog default severity; contradicted evidence produces the dual signal.
- `direction-evidence` — the principle informs this change as recorded direction (commitment, not hard MUST). Direction evidence is REQUIRED. The check RUNS (only `n-a-justified` suppresses); contradicted evidence produces the SAME dual signal as `applicable`.
- `n-a-justified` — the check is SUPPRESSED, and the justification is REQUIRED and visible in the lint findings. An N/A row without justification emits an axis-2 warning requiring it (C5). The section exists with n-a-justified rows even when no principle applies; the section is NEVER omitted (C6).

**Dual signal (one rule, shared with the lint).** When an `applicable` or `direction-evidence` row's declared evidence is contradicted by the implementation, axis 2 flags the unmet mandate AND axis 3 emits a blocker finding at the catalog severity, on the SAME check ID (C7).

### Step 5: Verify Resolvability

Check the acta title by title against the spec deltas and the arch-side evidence. A title without resolvable grounding is a defect — fix it before returning.

### Step 6: Return the Envelope

Return the structured envelope per **Section D** from `skills/_shared/sdd-phase-common.md`:

- `status`: `success` (acta produced) | `blocked` (missing input)
- `executive_summary`: the structural decisions resolved and any open decisions
- `artifacts`: the acta locator (`arch-plan.md` / engram topic)
- `verdict`: `approved` — the acta is complete and resolvable, ready for the user gate | `rejected` — findings returned for correction (bounded, max 2 rounds)
- `next_recommended`: `design` ONLY when the user gate passes on the acta; otherwise `architecture-plan` (re-run on findings) or `none`
- `risks`: open decisions / unresolved items
- `skill_resolution`: from Section A

## Rules

- **Never invent evidence.** The acta resolves against the inputs or names the open decision.
- **Pattern research is optional and cited.** Launched only on a real evidence gap; findings always cited.
- **The acta is the binding input to design and to post-apply architecture lint.** `arch-plan.md` is mandatory for design; the lint fails closed when it is missing.
- **The user gate belongs to the orchestrator.** You never self-approve the plan.
- Return envelope per **Section D**.

<!-- gentle-ai:agent-language-contract -->
## Artifact Language Contract

Generated artifacts (code, comments, UI copy, docs, specs, tests, commit messages, memory entries) default to English. If an artifact is explicitly requested in Spanish, use neutral/professional Spanish. Never use regional slang or dialect-specific grammar in any artifact, regardless of the conversation language in your prompt context.

Before any Write/Edit whose content is an artifact, re-verify these artifact language rules.
<!-- /gentle-ai:agent-language-contract -->