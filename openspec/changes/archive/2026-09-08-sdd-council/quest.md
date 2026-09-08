# Quest: sdd-council

## Approval: approved

## RFC

### Goals / Non-goals

**Goals**

1. **Convert deployed orchestrator rule 4 text into real machinery.** Replace the prose-only post-design council rule in `orchestrator.md` with executable components: skill `sdd-council`, agent `sdd-council`, 3 dedicated lens agents, post-design delegation hooks, and `sdd-architecture-lint` extension.
2. **3 dedicated lens agents — independent voices, parallel execution.** Three new agents (`sdd-council-arch`, `sdd-council-product`, `sdd-council-risk`), each with a dedicated lens skill or lens section inside `sdd-council`, registered in `wiring/opencode.sdd.json` with `__managed_by` absent (ours, not Alan's). Each receives `design.md` + `proposal.md` + its own lens definition. They run in parallel via `task()`.
3. **Council fires ALWAYS after `design` is done and BEFORE `sdd-tasks`**, for every SDD change. No exceptions, no opt-out.
4. **Max 2 re-framing rounds** with fresh voices per round. If the 2nd round still cannot resolve, orchestrator STOPs with a report — tasks stay blocked. No infinite loop.
5. **No-fork fast path.** When the 3 voices converge on a single viable option (no real forks), the council records the acta with the converged decision and does NOT interrupt the user. Saves an interruption on the happy path.
6. **Real forks require the human.** When 2+ divergent options exist, the orchestrator presents framed options to the user and waits for explicit decision before archiving the acta. The model never decides forks alone.
7. **Acta is the binding trace document.** Persisted at the change store (`openspec/changes/{change-name}/council.md` + Engram mirror topic `sdd/{change-name}/council`) with titled decisions. The acta is a MANDATORY input of `sdd-architecture-lint` (axis 2): arch-lint verifies title-by-title that each council decision made it into the design.
8. **Council never relaunches design on its own.** Only the orchestrator relaunches design — specifically when arch-lint fails and the acta shows decisions were not applied.
9. **Auto mode rhythm.** In auto mode, after design is done, the orchestrator launches the council without asking. With real forks, it interrupts ONCE for the user's decision; then arch-lint; then tasks. No-fork happy path = zero interruptions (acta records convergence). Auto mode allows max 1 retry of the full council → arch-lint chain; 2nd failure = STOP with report.
10. **Council is an organic hook — never alters `nextRecommended`.** It is a support phase wired through the orchestrator contract's `Organic Support Phase Hooks`, not a pipeline token.

**Non-goals**

1. No change to the existing post-design chain structure: arch-lint always fires. Council inserts between design and arch-lint but does not remove or replace arch-lint.
2. No automatic voting or autonomous fork resolution. The council never decides forks alone when options diverge.
3. Does not touch `nextRecommended`. Council is a support phase, not a pipeline token.
4. No reuse of the gentle-ai 4R review agents (`review-risk`, `review-readability`, `review-reliability`, `review-resilience`). These are `__managed_by: "gentle-ai/sdd"`, require `GENTLE_AI_REVIEW_BINDING` + host-injected frozen candidate context, have `permission: {"*": "deny"}` (no tools, cannot read `design.md`), are `hidden: true`, and only operate inside the `gentle-ai review` RDD lifecycle. Only the lens labeling concept (risk/resilience/readability/reliability) is borrowed for our own agent lens names.
5. No new `nextRecommended` tokens introduced.

### Domain Terminology & Business Rules

| Term | Definition |
|---|---|
| **Council** | A bounded review round where 3 dedicated lens agents independently evaluate `design.md` + `proposal.md` through their assigned lens, producing convergent or divergent assessments. |
| **Lens agent** | One of 3 dedicated agents (`sdd-council-arch`, `sdd-council-product`, `sdd-council-risk`), each scoped to a specific review dimension. Runs as a `task()` sub-agent with its own skill or skill section. |
| **Acta** | The persisted council output: titled decisions, convergence status, and (if forks existed) which option was selected. Lives at the change store and is the mandatory input for arch-lint axis 2. |
| **Convergence (no-fork)** | All 3 lens agents agree on a single viable option. Acta records convergence; user is NOT interrupted. |
| **Fork (real fork)** | 2+ divergent options from the lens agents. Orchestrator frames options for the user; user decides. |
| **Re-framing round** | After the initial council round, if the orchestrator judges the voices need re-framing (not re-voting), it launches a fresh set of 3 voices with refined prompt/framing. Max 2 rounds total (including initial). |
| **Arch-lint axis 2** | The `sdd-architecture-lint` verification axis that checks council acta decisions against the design, title-by-title. Axis 1 (requirements/scope) is unchanged. |
| **Auto mode** | Orchestrator mode where council fires automatically after design without user prompting; forks interrupt once; no-fork = zero interruptions. Max 1 retry of the full chain. |

**Business rules:**

1. Council ALWAYS fires after design is done and before `sdd-tasks`. There is no opt-out.
2. The council NEVER decides forks alone — when options diverge, the human decides.
3. Convergence does NOT require user confirmation — the acta records the decision and the chain continues.
4. The acta is MANDATORY for arch-lint. Arch-lint cannot run without an acta (or must report it as missing).
5. Council never relaunches design. Only the orchestrator can relaunch design (after arch-lint failure).
6. Fresh voices per re-framing round (no re-use of the same lens agent prompt/config in a re-frame).
7. The 4R review agents from gentle-ai are NOT reused or wrapped — only their lens categorization concept is borrowed.

### Contracts (Inputs / Outputs / Events / External)

**Inputs:**

| Input | Source | When |
|---|---|---|
| `design.md` (completed) | Design phase output | Design phase marks done |
| `proposal.md` | Proposal phase output | Available from proposal |
| Lens definition (per agent) | Skill `sdd-council` or dedicated skill per lens | Loaded at agent init |
| Acta (on retry) | Previous council run's acta | On 2nd attempt of the chain |

**Outputs:**

| Output | Destination | Persistence |
|---|---|---|
| Council acta (`council.md`) | `openspec/changes/{change-name}/council.md` + Engram mirror topic `sdd/{change-name}/council` | Change store + Engram |
| Convergence verdict | Orchestrator (decides whether to interrupt user) | In-memory flow control |
| Framed fork options (if fork) | Orchestrator → user via `question` tool | Interactive |
| Arch-lint pass/fail | `sdd-architecture-lint` → orchestrator | Change store |

**Events / Flow:**

```
design done
  → orchestrator detects (artifact state)
  → orchestrator launches sdd-council (auto mode: no ask; manual: may ask)
    → sdd-council orchestrates 3 lens agents in parallel via task()
      → sdd-council-arch: design.md + proposal.md + arch lens
      → sdd-council-product: design.md + proposal.md + product/UX lens
      → sdd-council-risk: design.md + proposal.md + risk/resilience lens
    → sdd-council consolidates results
      → CONVERGENCE: acta recorded, chain continues (no user interruption)
      → FORK: orchestrator presents options to user, waits for decision
      → 2nd ROUND NEEDED: fresh voices launched (max 2 total rounds)
      → 2nd ROUND STILL UNRESOLVED: STOP with report, tasks blocked
  → arch-lint fires (ALWAYS)
    → axis 1: requirements/scope of design (unchanged)
    → axis 2: acta decisions title-by-title (NEW, mandatory acta input)
    → PASS: orchestrator proceeds to tasks
    → FAIL: orchestrator relaunches design (max 1 retry in auto mode; 2nd failure = STOP)
  → sdd-tasks
```

**External contracts:**

- `sdd-council` does NOT alter `nextRecommended`. It is a support phase wired through `Organic Support Phase Hooks` in the orchestrator contract.
- `sdd-architecture-lint` is extended to accept the acta as a mandatory input for axis 2. The acta is not optional — arch-lint must either receive it or fail-closed.
- The 3 lens agents are registered in `wiring/opencode.sdd.json` as SDD agents with `__managed_by` absent (owned by this repo, not by gentle-ai).

### Invariants & Validation

1. **Council fires after every design completion.** No SDD change proceeds to tasks without the council having run.
2. **Acta is always persisted before arch-lint runs.** Arch-lint axis 2 cannot execute without the acta file existing at the expected path.
3. **Max 2 rounds.** The council never runs more than 2 rounds (initial + 1 re-frame). A 2nd unresolved round halts the chain.
4. **Fresh voices per round.** Each re-framing round uses fresh lens agent invocations, not cached or re-run results from a prior round.
5. **Convergence = no user interruption.** When all 3 voices agree, the user is never asked to confirm. The acta records the converged decision.
6. **Fork = user decides.** When options diverge, the model never resolves the fork autonomously. The human must decide.
7. **Council never relaunches design.** The council itself is read-only with respect to design.md. Only the orchestrator triggers a design re-launch.
8. **Arch-lint always fires after council.** The existing arch-lint gate is not removed or bypassed. Council inserts between design and arch-lint; it does not replace arch-lint.
9. **Organic opt-out: N/A is valid.** If design.md is empty/trivial (no decisions to review), council returns N/A and arch-lint skips axis 2.
10. **Auto mode: max 1 retry.** The full council → arch-lint chain can retry at most once on arch-lint failure. A 2nd failure stops with a report.

### Failure Cases & Edge Cases

| Case | Behavior |
|---|---|
| 3 voices diverge after initial round | Re-frame (round 2). If still diverge after round 2 → STOP, report generated, tasks blocked. |
| 2 voices converge, 1 dissents (real fork) | Treated as fork. Orchestrator frames options for user. User decides. |
| Acta file missing when arch-lint runs | Arch-lint axis 2 fails-closed (reports acta missing, chain halts). |
| Design.md is empty/trivial | Council returns N/A. Arch-lint skips axis 2 (no decisions to verify). Chain continues. |
| Orchestrator cannot reach user for fork decision (auto mode, timeout) | STOP with report. Tasks blocked. No autonomous resolution. |
| Arch-lint fails after council (1st attempt) | Orchestrator relaunches design. Council re-runs on new design. Max 1 retry. |
| Arch-lint fails after council (2nd attempt, auto mode) | STOP with report. No further retries. Tasks blocked. |
| Lens agent task() fails or times out | Council treats as dissent/absence. The other 2 voices are used; if no majority → fork or re-frame per normal rules. |
| Council fires but proposal.md is missing | Council proceeds with design.md only; acta notes proposal.md was absent. Arch-lint still runs. |
| User rejects all framed fork options | STOP with report. User must revise design or proposal externally before re-triggering. |

### Security / Privacy / Performance / Operational

**Security:**

- Lens agents run via `task()` sub-agents with the same permission model as other SDD sub-agents. No elevated permissions.
- The acta is a plain-text decision document; no secrets or tokens in council output.
- Council does not execute code or modify files — it is a read-only review that produces advisory output consumed by arch-lint.

**Performance:**

- 3 lens agents run in parallel via `task()`, not sequentially. Council latency ≈ slowest agent, not sum of agents.
- Max 2 rounds bounds total council cost to 2× the initial round.
- Acta persistence is lightweight (markdown file + Engram entry).

**Operational:**

- Council is an organic hook wired in 3 homes: orchestrator contract (`Organic Support Phase Hooks`), command overlays (`SUPPORT-CONDITIONAL`), and the skill itself.
- Acta is the ONLY gate between council and arch-lint for axis 2. If acta is missing, arch-lint axis 2 fails closed — not silently skipped.
- Auto mode: council launches without user prompt. The single interruption budget (fork decision) is enforced by the orchestrator flow control.
- Retry budget (max 1) is tracked by the orchestrator state, not by the council skill. The council skill is stateless across invocations.

### Alternatives & Trade-offs

| Alternative considered | Why not chosen |
|---|---|
| Reuse gentle-ai 4R review agents | Rejected: they require `GENTLE_AI_REVIEW_BINDING`, host-injected frozen context, have `permission: {"*": "deny"}` (no tools, cannot read design.md), are `hidden: true`, and only operate inside the `gentle-ai review` RDD lifecycle. The integration surface is incompatible. Only the lens categorization idea is borrowed. |
| Single council agent with 3 internal lenses | Rejected: loses the "independent voices" property. Separate agents enforce true independence — they cannot see each other's assessments during the parallel run. |
| 3+ lenses (more granular) | Rejected for now: 3 lenses (arch/product/risk) cover the identified dimensions. More lenses increase coordination cost without proportional value. The lens set can grow later if the arch-lint reports reveal coverage gaps. |
| Automatic fork resolution via voting | Rejected: violates the principle that the human decides forks. Automatic voting would let the model decide autonomously on divergent design options, which is out of scope for this change. |
| Council as pipeline phase (touching `nextRecommended`) | Rejected: council is a support phase. Adding it as a pipeline token would expand the native contract unnecessarily. The organic hook model is sufficient and consistent with the sdd-skill-blueprint guidance. |
| 3+ re-framing rounds | Rejected: 2 rounds is sufficient. A 3rd round rarely resolves disagreement that 2 didn't; the STOP-with-report path is the correct escalation. |

### Acceptance Criteria (measurable)

1. **Skill exists:** `skills/sdd-council/SKILL.md` is present and contains the council orchestration contract, lens definitions, convergence/fork rules, acta format, and the 2-round limit.
2. **Agents registered:** `wiring/opencode.sdd.json` includes `sdd-council`, `sdd-council-arch`, `sdd-council-product`, and `sdd-council-risk` — all with `__managed_by` absent (ours, not Alan's).
3. **Orchestrator contract updated:** `wiring/prompts/sdd/orchestrator.md` has the post-design → council → arch-lint(acta) → gate hook with auto mode max 1 retry.
4. **Arch-lint extended:** `sdd-architecture-lint` verifies acta decisions title-by-title (axis 2). Acta is a mandatory input; missing acta = axis 2 fail-closed.
5. **Red checks pass:** New RED checks (T32+) cover: hook pins (council always fires after design), acta-as-lint-input (mandatory), convergence fast-path (no interruption on agreement), forks → user decides (model never decides alone), 2-rounds STOP (max rounds enforced).
6. **Full red suite green:** `./tests/run_red_checks.sh` reports green with >= 31 original + new checks.
7. **Sync clean:** `./sync-skills.sh --check` reports 0 desyncs post-rollout.
8. **Acta persisted correctly:** Acta file exists at `openspec/changes/{change-name}/council.md` and Engram mirror topic `sdd/{change-name}/council` with titled decisions, convergence/fork status, and round count.
9. **No `nextRecommended` changes:** The council does not add, remove, or modify any `nextRecommended` token. Verified by red check or existing status-contract checks.
10. **Organic hook in 3 homes:** Council trigger present in (a) orchestrator contract `Organic Support Phase Hooks`, (b) command overlay `SUPPORT-CONDITIONAL`, (c) skill itself.

### Unresolved Questions (blocking)

None. All 6 decision branches were resolved during the interview (Q1 through Q6). The user approved the RFC as binding mandate (Q7).