# Council Acta: worktree-lifecycle-v2

## Round

1

## Lens Verdicts

### sdd-council-arch
- Viable option: pure-decision-function-python-writes-go-reads
- Verdict: converge on pure decision function + table; Python writes locks/index, Go reads (observer, D2 fail-open)
- Concerns:
  - PID liveness via kill(0) is liveness-of-process, not liveness-of-work; design acknowledges this but `lock_has_live_pid` remains a placeholder for future session-liveness beacon.
  - Concurrent separate opencode instances (distinct server PIDs) correctly yield `owned_by_other` via owner match, but this is implicit — the threat matrix does not document it as a row.
  - Index rebuild-from-porcelain path adds continuation complexity that deserves explicit RED test coverage.
  - `reclaimed` is reserved and unreachable; the orchestrator route list references it before any session-liveness beacon exists — dead code that could confuse maintainers.

### sdd-council-product
- Viable option: design-as-written — volume-based acquire gate with 7-state classifier, enriched list, and typed denials
- Verdict: converge
- Concerns:
  - Open question: `store` param is required by lock v2 but absent from the proposal's acquire signature; must be resolved before tasks freeze (recommended default `"hybrid"`).
  - Orchestrator block wording "replaces §5 acquire semantics" is inaccurate: there is no §5 acquire semantics today; it is an appended section. Wording could confuse the strip+append sync machinery.
  - `reclaimed` in the routing set is a dead path; one sentence of "intentionally kept reserved" context prevents confusion.
  - Continuation >5 table assumes the orchestrator question surface can render markdown tables; if not, UX degrades to plain list.

### sdd-council-risk
- Viable option: lock-v2-classifier with hint-index and wrapper retrocompat
- Verdict: converge
- Concerns:
  - Highest severity: the classifier declares ALL lock v1/≠2 as `exists_stale` → auto `claimed` unconditionally, ignoring PID liveness — yet v1 locks carry a pid (`write_lock` uses `os.getpid()`). A live pre-v2 session can be silently double-claimed mid-rollout, contradicting the spec's "never silently take over" and the design's own PID-liveness row.
  - `already_mine` keys on owner only; `session` is stored but never compared. Two concurrent sessions with the default owner (`"default"`) both see `already_mine` and proceed into one worktree — silent shared write; the never-silent-takeover guarantee is owner-scoped only.
  - PID reuse window: a dead server's recycled PID makes a lock appear alive forever; recovery is manual lock deletion only (undocumented in tasks).
  - Appended block claims to replace §5 but orchestrator §5 (line 495) stays verbatim naming `git_worktree_add`/`remove` as supervised tools; true today only because wrappers exist — future isolated edits to 6c/§5 will diverge.
  - A future `gentle-ai sync` could reset `orchestrator.md` and drop or double-apply the appended block; relies on idempotent strip+append and `./sync-skills.sh --check` discipline.

## Convergence

convergence — all 3 lenses converge on the design as written. No divergent options; no user interruption required. The chain continues to `sdd-architecture-lint`.

## Risks after Consolidation (feed into tasks)

1. **v1-live-lock double-claim during migration** (risk lens, high): classifier row `lock v1/≠2 → exists_stale → claimed` ignores PID liveness that v1 locks carry. Recommended mitigation: classify `lock v1/≠2 ∧ pid dead → claimed`; `lock v1/≠2 ∧ pid alive → deny owned_by_other` — aligns with the spec's never-silently-take-over and the design's own liveness row. Tasks MUST decide before implementation; if kept unconditional, the acta records it as an accepted divergence.
2. **already_mine owner-only matching** (risk lens, med): same owner, different session → both `already_mine`, silent shared write. Recommended mitigation: `already_mine` requires owner AND session match; same owner/different session → `owned_by_other`; or explicitly document the guarantee as owner-scoped.
3. **`store` param divergence** (product lens, med): lock v2 requires `store`; proposal acquire signature omits it. Resolve before tasks freeze (recommended default `"hybrid"` per preflight).
4. **Orchestrator block wording**: "replaces §5 acquire semantics" is inaccurate — it is an appended section. Reword to "appended acquire-gate section" to match the idempotent strip+append mechanism.
5. **Rollout ordering** (risk lens): strip the orchestrator block BEFORE reverting server code so phases stop calling acquire before the tool disappears.
6. **Double-apply hardening** (risk lens): add `./sync-skills.sh --check` assertion of exactly one `sdd-own:worktree-lifecycle-v2` block.
7. **Go parser schema guard** (arch lens): `lock.go` must check `version == 2` explicitly; version 1/missing/other → treat as corrupt/old, never silently trust a future schema change. Add `lock_test.go` rows for version=1, version=2, version=missing.
8. **Threat-matrix row** (arch lens): document "concurrent separate opencode instances → distinct server PIDs → `owned_by_other` via owner match".
9. **RED test gaps**: continuation volume selection (0/1/3/>5) routing per enriched list; stale-index entry pointing at a removed worktree → attach path with re-classification via acquire (index display-only).
10. **PID-reuse manual recovery** (risk lens): document manual `.sdd-agent-lock` deletion as recovery; optionally record server start-time in lock v2 for future hardening.

## Decision

### Decision: Classifier as pure decision function + table (reject State/Strategy)
Verdict: converged (3/3).
Rationale: Signals→state is a one-shot mapping with no runtime transitions and no swappable algorithms; State/Strategy add classes without payoff. Smallest correct abstraction.

### Decision: One shared contract in worktree_state.py — Python writes, Go reads
Verdict: converged (3/3).
Rationale: Languages forbid code sharing; Python is the single authoritative writer of locks/index; Go stays a read-only observer (D2 fail-open) consuming the same lock v2 schema. Dependency direction inward, no cross-language write drift.

### Decision: Lock pid = server pid (os.getpid()) at acquire
Verdict: converged (3/3).
Rationale: Server death == power loss ⇒ dead pid ⇒ stale ⇒ auto re-claim. Concurrent sessions share one server ⇒ both pids alive ⇒ conflicts surface as `owned_by_other` via owner match, never silent. liveness-of-process is accepted (session-liveness beacon is the future `reclaimed` activation path).

### Decision: `reclaimed` reserved, unreachable with current signals (no expiry TTL)
Verdict: converged (3/3).
Rationale: PID-alive cannot prove abandonment; `exists_active_other` always denies `owned_by_other` (spec: never silently take over). Status stays in the closed set; a future session-liveness beacon activates it. Routing list may keep it; add an "intentionally reserved" comment.

### Decision: Corrupt evidence never overwritten — typed denials `corrupt_worktree` / `locked_unreadable`
Verdict: converged (3/3).
Rationale: Unreadable tree or lock evidence is never trusted or destroyed; acquire denies with the typed envelope. Fail-closed asymmetry (Python classifier) vs fail-open observer (Go D2) is intentional.

### Decision: `add`/`remove` remain thin retrocompat wrappers over acquire/release
Verdict: converged (3/3).
Rationale: `destructive_flow` envelope retained for both; classifier logic NOT duplicated in the wrappers; safe-slug and two-phase remove kept. Rollback can revert any layer independently.

### Decision: Acquire gate — acquire-before-verify, route only on created|attached|claimed|reclaimed|already_mine, prompt only on real conflicts
Verdict: converged (3/3).
Rationale: Phases needing a worktree SHALL call `git_worktree_acquire` before `sdd-tool worktree verify`. `exists_stale` (dead PID / v1 lock) → auto re-claim without prompt; `already_mine` → proceed, no mutation. Blocking prompt ONLY on `owned_by_other` / `locked_unreadable` / `corrupt_worktree`, relaying the typed envelope. Release only at archive-close or explicit abandon, non-owner no-op.

### Decision: Volume-based continuation (1 direct / 2–5 one question / >5 table + validated input / 0 propose)
Verdict: converged (3/3).
Rationale: `git_worktree_list` (truth) + index (hint) + apply-progress cross-ref. 1 → direct resume + notice; 2–5 → one question (change+phase+dirty); >5 → table (index|change|branch|state|last_seen|dirty|phase) + validated input (number/name/alias, unambiguous match else re-present); 0 → informative + propose `/sdd-new`. Selection → acquire → verify binding signals → resume apply-progress.

### Decision: Hint index never truth — porcelain wins, rebuild on corrupt/missing, write failure warn-only
Verdict: converged (3/3).
Rationale: `~/.agent_worktrees/<repo>/.agent-index.json` is display/suggestion only; `git worktree list --porcelain` is authoritative; corrupt/missing index → empty and rebuilt; write through on acquire/release; write failure warn-only. Selection always re-classifies via acquire.

### Decision: Release never destroys — owner-match required, dirty OK
Verdict: converged (3/3).
Rationale: Release deletes lock + index entry only; no lock / non-owner → ok no-op; corrupt lock → `locked_unreadable`; dirty worktrees are never destroyed by acquire/release ⇒ no data-loss surface. Removal remains gated by dirty + owner checks with git's own clean check as backstop.