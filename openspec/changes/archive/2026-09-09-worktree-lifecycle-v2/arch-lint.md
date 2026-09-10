# Architecture Conformance: worktree-lifecycle-v2

## Verdict: pass

No CRITICAL findings. Three WARNINGs and three SUGGESTIONS identified — all advisory; the council already flagged the underlying tensions and the design is architecturally sound. The WARNINGs should be resolved or explicitly acknowledged before tasks freeze.

## Axis 2 — Council Acta (title-by-title)

| # | Acta Decision | Verdict | Rationale |
|---|---|---|---|
| 1 | Classifier as pure decision function + table (reject State/Strategy) | ✅ Incorporated | Design Decision table row "Classifier structure" selects pure decision function + table. Rationale matches acta: one-shot mapping, no swappable algorithms. |
| 2 | One shared contract in worktree_state.py — Python writes, Go reads | ✅ Incorporated | File Changes creates `worktree_state.py` as shared layer imported by both handler modules. `lock.go` is read-only observer (D2 fail-open). Dependency direction inward. |
| 3 | Lock pid = server pid (os.getpid()) at acquire | ✅ Incorporated | Design Decision table "Lock pid semantics" — server pid at acquire; concurrent sessions share server → both pids alive → conflicts surface via owner match. |
| 4 | `reclaimed` reserved, unreachable with current signals (no expiry TTL) | ✅ Incorporated | Design Decision table "Active-other reclaim (`reclaimed`)" — reserved, unreachable. Open Questions lists confirmation at tasks freeze. Orchestrator block includes `reclaimed` in route set. |
| 5 | Corrupt evidence never overwritten — typed denials `corrupt_worktree` / `locked_unreadable` | ✅ Incorporated | Design Decision table "Corrupt-lock classification" + classifier table deny rows. File Changes adds `corrupt_worktree` to envelope catalog, formalizes `locked_unreadable`. |
| 6 | `add`/`remove` remain thin retrocompat wrappers over acquire/release | ✅ Incorporated | File Changes: worktree_mutation.py modification — "add/remove → wrappers delegating to acquire/release (safe-slug kept; two-phase kept for remove; classifier logic NOT duplicated)." |
| 7 | Acquire gate — acquire-before-verify, route only on created\|attached\|claimed\|reclaimed\|already_mine, prompt only on real conflicts | ✅ Incorporated | Technical Approach, Data Flow, and orchestrator block all specify the exact routing set. Blocking prompt ONLY on `owned_by_other`/`locked_unreadable`/`corrupt_worktree`. |
| 8 | Volume-based continuation (1 direct / 2–5 one question / >5 table + validated input / 0 propose) | ✅ Incorporated | Orchestrator block specifies exact volume thresholds and routing. Data Flow section references continuation. |
| 9 | Hint index never truth — porcelain wins, rebuild on corrupt/missing, write failure warn-only | ✅ Incorporated | Interfaces/Contracts: "never truth (porcelain wins); corrupt/missing → empty, rebuilt; write failure warn-only." Index schema specified with version:1. |
| 10 | Release never destroys — owner-match required, dirty OK | ✅ Incorporated | Interfaces/Contracts: "Release: owner-match → delete lock + index entry; no lock/non-owner → ok no-op; corrupt lock → locked_unreadable; never destroys, dirty OK." |

**Acta convergence verdict**: The acta records convergence (all 3 lenses agree on the design as written). The design's option choices in the Architecture Decisions table are consistent with the converged decisions — no contradictions detected.

## Axis 1 — Boundaries Reviewed

**Boundaries reviewed**: New module boundary (`worktree_state.py` pure layer), dependency direction (Python-writes/Go-reads), lock v2 schema guard (version==2), envelope/denial contract, wrapper design, threat matrix completeness.

| Concern | Verdict | Rationale |
|---------|---------|-----------|
| New module boundary (`worktree_state.py`) | ✅ Conforms | Pure functions + data; no framework imports. Both handler modules depend on it; it depends on nothing. Dependency direction inward. |
| Python-writes / Go-reads dependency direction | ✅ Conforms | Python (worktree_state.py) is the single authoritative writer of locks/index. Go (lock.go) is read-only observer — D2 fail-open. No cross-language write drift. |
| Envelope / denial contract | ✅ Conforms | Closed error set extended correctly: `corrupt_worktree` added, `locked_unreadable` formalized. `confirm_required` correctly stays a summary marker, never an error type. |
| Wrapper design (add/remove) | ✅ Conforms | Thin wrappers over acquire/release; `destructive_flow` envelope retained; safe-slug and two-phase remove preserved; classifier logic not duplicated. |
| Lock v2 schema guard (version==2 explicit) | ⚠️ Risk | Classifier table handles `lock v1/≠2` → stale on the Python side. Go parser (`lock.go`) described as "Read-only lock v2 parser" but the version==2 explicit check is not called out in its contract. Council risk #7 requires this guard with version=1, version=2, version=missing test rows. The concept is implied but should be explicit. |
| Threat matrix completeness | ⚠️ Risk | Council risk #8 explicitly requests: "concurrent separate opencode instances → distinct server PIDs → owned_by_other via owner match." The design's threat matrix has 4 rows and none covers this scenario. |

### Requirements / Scope (proposal alignment)

| Check | Verdict | Evidence |
|-------|---------|----------|
| 7-state model | ✅ In scope | Design classifier has exactly 7 states matching proposal |
| `git_worktree_acquire` | ✅ In scope | New tool, signature matches |
| `git_worktree_release` | ✅ In scope | New tool, release semantics match proposal |
| Enriched `git_worktree_list` | ✅ In scope | local_read.py modification specified |
| Lock v2 schema | ✅ In scope | Schema includes all proposal fields plus `store` |
| Hint index | ✅ In scope | Write-through index, never truth |
| Orchestrator acquire gate | ✅ In scope | Block specified with routing rules |
| Volume-based continuation | ✅ In scope | Volume thresholds match proposal |
| Retrocompat add/remove | ✅ In scope | Wrappers preserve envelope |
| Out-of-scope items | ✅ Confirmed OOS | flock(), automatic prune, TUI goroutine, multi-machine — design confirms OOS |
| No invented requirements | ✅ Clean | No requirements outside proposal scope |
| No scope creep | ✅ Clean | Design stays within proposal boundaries |
| Council risk 1: v1-live-lock double-claim | ⚠️ Not addressed | Design classifier unconditionally claims v1 locks without PID liveness check. Council called this "highest severity" and recommended splitting into `v1 ∧ pid dead → claimed` / `v1 ∧ pid alive → deny owned_by_other`. Design is silent on this tension. |
| Council risk 2: already_mine owner-only matching | ⚠️ Not addressed | Design classifier keys `already_mine` on owner only; same owner/different session both see `already_mine`. Council recommended either session match or documented owner-scope. Design is silent. |
| Council risk 3: store param divergence | ⚠️ Partially addressed | Design includes `store` in lock v2 schema and acquire signature — but default value unresolved (open question tracks this). |

## Findings

### F1 — WARNING — Axis 1 — v1-live-lock double-claim risk unacknowledged

**Finding**: The classifier table declares `lock v1/≠2 → exists_stale → claimed` unconditionally, ignoring PID liveness that v1 locks carry (current `write_lock` uses `os.getpid()`). The council called this the highest-severity risk: a live pre-v2 session can be silently double-claimed mid-rollout, contradicting the spec's "never silently take over." The recommended mitigation is `v1 ∧ pid dead → claimed` / `v1 ∧ pid alive → deny owned_by_other`. The design is silent on this divergence.

**Evidence**: Classifier table row: `lock v1/≠2 | exists_stale | claimed`. Council risk #1: "highest severity." Proposal: "stale = dead pid → auto re-claim."

**Required fix**: Either adopt the council's recommended split (PID-liveness check on v1 locks) or add an explicit note acknowledging the unconditional claim as an accepted divergence that tasks must decide. The design must not silently ship the risk.

### F2 — WARNING — Axis 1 — `already_mine` owner-only matching undocumented

**Finding**: The classifier keys `already_mine` on `owner==caller` only. Two concurrent sessions with the same default owner both see `already_mine` and proceed into one worktree — silent shared write. The council recommended either adding session match or explicitly documenting the guarantee as owner-scoped. The design is silent on this tradeoff.

**Evidence**: Classifier table: `v2 ∧ pid alive ∧ owner==caller | exists_active_mine | already_mine`. Lock v2 schema stores `session` but the classifier never compares it. Council risk #2.

**Required fix**: Document the guarantee scope (owner-level) or adopt session-aware matching. Either is acceptable; silence is not.

### F3 — WARNING — Axis 2 — Threat matrix missing concurrent-instances row

**Finding**: Council risk #8 explicitly requests: "concurrent separate opencode instances → distinct server PIDs → owned_by_other via owner match." The design's threat matrix has 4 rows and none covers this scenario.

**Evidence**: Threat matrix rows: git-repo-selection, commit-state, process-liveness, doc-like-paths. Council risk #8.

**Required fix**: Add a row: `| Concurrent opencode instances | Applicable | Distinct server PIDs → owner match → owned_by_other (not PID liveness) | same-owner diff-PID → denial |`.

### F4 — SUGGESTION — Axis 1 — `store` param default not resolved

**Finding**: The design includes `store` in the lock v2 schema and acquire signature, but the default value is listed as an open question. The council recommended `"hybrid"` as default per the change's preflight. This is tracked in Open Questions.

**Evidence**: Open Questions: "Confirm `store` optional param on acquire (lock v2 requires `store` — recommended default `"hybrid"`)." Council risk #3.

**Required fix**: Resolve the default before tasks freeze — adopt `"hybrid"` per council recommendation or document the chosen default.

### F5 — SUGGESTION — Axis 1 — Go parser version guard should be explicit

**Finding**: Council risk #7 requires `lock.go` to check `version == 2` explicitly; version 1/missing/other → treat as corrupt/old. The design mentions lock.go as "Read-only lock v2 parser + stale semantics" but does not explicitly call out the version guard in its contract. The concept is implied by the classifier but should be stated for the Go parser independently.

**Evidence**: File Changes: `lock.go` = "Read-only lock v2 parser + stale semantics (observer)." Council risk #7: "lock.go must check version == 2 explicitly."

**Required fix**: Add to the lock.go description: "Must check `version == 2`; version 1/missing/other → error (never silently trust a future schema change)."

### F6 — SUGGESTION — Axis 2 — Orchestrator block wording

**Finding**: The orchestrator block header says "replaces §5 acquire semantics" but §5 currently names `git_worktree_add`/`git_worktree_remove` as supervised tools — it has no acquire semantics today. The council product lens noted this is inaccurate: it is an appended section, not a replacement. The wording could confuse the strip+append sync machinery.

**Evidence**: Orchestrator block: "### Worktree Lifecycle v2 — acquire gate (replaces §5 acquire semantics)." Council risk #4: "reword to 'appended acquire-gate section'."

**Required fix**: Rephrase to "appended acquire-gate section" or similar to match the idempotent strip+append mechanism.

## Risks

1. **v1 migration silent double-claim** (F1): If the unconditional v1→stale→claimed path ships without mitigation, a live pre-v2 session can be silently taken over during rollout. Tasks must decide; design must acknowledge.
2. **Same-owner session collision** (F2): Default owner `"default"` means any two concurrent sessions silently share a worktree via `already_mine`. The never-silent-takeover guarantee is weaker than it appears.
3. **Threat matrix gap** (F3): Concurrent opencode instances are a real scenario (common for multi-terminal users) and should be documented for completeness.
