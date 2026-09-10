# Design: Worktree Lifecycle v2

## Technical Approach

Extract the lifecycle into one shared pure layer — `worktree_state.py` (Python, authoritative: writes locks/index) — consumed by mutation and read handlers. Expose `git_worktree_acquire`/`release` as primary tools; demote `add`/`remove` to thin retrocompat wrappers over them (destructive_flow envelope retained for both). Add a read-only lock parser + repo-name fix to sdd-tool (observer, fail-open). Wire acquire-before-verify and volume-based continuation into the orchestrator via an appended `sdd-own` block. One contract (schema + decision table below) drives both implementations. Out of scope: real `flock()`, automatic prune, TUI goroutine verification, multi-machine.

## Architecture Decisions

| Decision | Options | Choice / Rationale |
|---|---|---|
| Classifier structure | State / Strategy / pure function | **Pure decision function + table.** Signals→state is a one-shot mapping; no runtime transitions or swappable algorithms. State/Strategy add classes without payoff (design-patterns: rejection is valid; no Golden Hammer). |
| Active-other reclaim (`reclaimed`) | Expiry TTL vs deny always | **`reclaimed` reserved, unreachable with current signals.** PID alive cannot prove abandonment; `exists_active_other` always denies `owned_by_other` (spec: never silently take over). Status kept in the closed set; a future session-liveness beacon activates it. |
| `exists_inactive` vs `exists_stale` | Spec gloss conflict | **inactive = worktree, no lock; stale = lock (v1/≠2) + dead PID.** Classifier scenarios are authoritative; the acquire scenario's gloss ("inactive = v2 + dead PID") is corrected. inactive→`attached`; stale→`claimed`. |
| Corrupt-lock classification | stale vs corrupt | **corrupt** (tree OR lock untrustworthy). Never overwrite unreadable evidence. Acquire denies `corrupt_worktree` (tree) / `locked_unreadable` (lock). |
| Helper placement | Duplicate vs one contract | **One contract here; Python writes, Go reads.** Languages forbid sharing; Go stays observer (D2 fail-open, write nothing). |
| Lock `pid` semantics | agent pid vs server pid | **Server pid (`os.getpid()`) at acquire.** Server death == power loss ⇒ dead pid ⇒ stale ⇒ auto re-claim. Concurrent sessions share one server ⇒ both pids alive ⇒ conflicts surface as `owned_by_other`, never silent. |
| `add` on branch-exists | Deny (v1) vs attach | **`absent_branch_exists` → `created`**: `git worktree add <path> sdd/<change>` without `-b`; branch reuse noted. |
| Release representation | delete lock vs mark released | **Delete lock file + index entry**; worktree becomes `exists_inactive`. |

## Data Flow

```
phase start ─► git_worktree_acquire(repo, change, owner, session, store="hybrid")
   │             classifier: porcelain + disk + lock + kill(0)
   │             created|attached|claimed → lock v2 + index write
   │             already_mine → no mutation
   ▼             owned_by_other|locked_unreadable|corrupt_worktree → typed denial
sdd-tool worktree verify (observer: root/branch/scanner) → phase --cwd <worktree>
   ▼
apply-progress (durable) ───► next phase: acquire again (already_mine)
```

Continuation (no change name): `git_worktree_list` (truth) + index (hint, rebuild from porcelain when corrupt/missing) + apply-progress cross-ref → present by volume → acquire → verify binding signals → resume.

## File Changes

| File | Action | Description |
|---|---|---|
| `srv/gh-mcp-server/src/worktree_state.py` | Create | Lock v2 read/write/parse, repo-name derivation, 7-state classifier, dirty check, index read/write. Imported by both handler modules; no duplication. |
| `.../tool_handlers/worktree_mutation.py` | Modify | acquire/release tools; add/remove → wrappers delegating to acquire/release (safe-slug kept; two-phase kept for remove; classifier logic NOT duplicated). |
| `.../tool_handlers/local_read.py` | Modify | Enriched `git_worktree_list(repo_path)`: change, path, branch, state, owner, session, last_seen, dirty; main included (`is_main: true`). |
| `.../envelope.py` | Modify | Catalog grows `corrupt_worktree`; `locked_unreadable` formalized. |
| `srv/sdd-tool/internal/worktree/worktree.go` | Modify | Replace hardcoded `"sdd-own-skills"` (~L77) with toplevel-basename derivation; List/Verify consume lock state. |
| `srv/sdd-tool/internal/worktree/lock.go` | Create | Read-only lock v2 parser + stale semantics (observer). MUST validate `version == 2` before trusting a lock; version 1/missing/other → treated as v1/old (stale semantics per classifier), never silently trusted. |
| `wiring/prompts/sdd/orchestrator.md` | Modify | Append sdd-own block below; amend our own `sdd-tool-integration` block's sdd-propose line. Idempotent strip+append by unique id; Alan's base never overwritten. |
| `skills/using-git-worktrees/SKILL.md` | Modify | 6c rewritten (ours: vendored-6c): acquire/release/list primary, add/remove wrappers, 7 states, denials, no-git-crudo. Pre-6c (Alan's) untouched. |
| `srv/gh-mcp-server/tests/test_worktree_state.py` | Create | RED tests per Threat Matrix + acquire/release matrix. |
| `srv/sdd-tool/internal/worktree/lock_test.go` | Create | Go parser + repo-name derivation tests. |

Orchestrator block (exact, appended at end of file):

```markdown
<!-- sdd-own:worktree-lifecycle-v2:start -->
### Worktree Lifecycle v2 — appended acquire-gate section

Phases needing a worktree SHALL call `git_worktree_acquire(repo_path, change, owner, session, store="hybrid")` BEFORE `sdd-tool worktree verify`; route only on `{created|attached|claimed|reclaimed|already_mine}`. Note: `reclaimed` is intentionally reserved — unreachable with current signals (PID-alive cannot prove abandonment); a future session-liveness beacon activates it. Route set kept intact for forward compatibility.
- `exists_stale` (dead PID — lock v1/≠2 or v2) → auto re-claim (`claimed`), no prompt; `already_mine` (owner+session match) → proceed, no mutation. Live-PID v1/≠2 or same-owner-different-session locks are real conflicts → blocking prompt, never silent.
- Blocking prompt ONLY on real conflicts (`owned_by_other`, `locked_unreadable`, `corrupt_worktree`): relay the typed envelope and wait — never silently take over.
- Release: archive-close or explicit abandon only, never between phases; dirty OK; non-owner = no-op.
- Continuation without a change name: `git_worktree_list` + apply-progress cross-ref → 1 direct+notice; 2–5 one `question` (change+phase+dirty); >5 table (index|change|branch|state|last_seen|dirty|phase) + validated input (number/name/alias; unambiguous single match, else re-present); 0 informative + propose `/sdd-new`. Selection → acquire → verify binding signals → resume apply-progress.
<!-- sdd-own:worktree-lifecycle-v2:end -->
```

## Interfaces / Contracts

Lock v2: `{version:2, pid:int, session, owner, change, repo_root, repo_name, branch, store, created_at, last_seen}`; `repo_name` ≡ basename(`git rev-parse --show-toplevel`). `last_seen` updated on every acquire transition (created/attached/claimed), not on `already_mine`. Acquire signature: `git_worktree_acquire(repo_path, change, owner, session, store="hybrid")` — `store` defaults to `"hybrid"` per this change's preflight; callers may override. The `session` field is load-bearing for concurrency: `already_mine` requires owner AND session match; same owner with a different session is a real conflict (`owned_by_other`).

Classifier (ordered, first match):

Go observer contract: `lock.go` MUST validate `version == 2` before trusting a lock; version 1/missing/other → treated as v1/old (stale semantics per corrected rows), never silently trusted.

| Signals (porcelain·disk·lock·pid·branch) | State | acquire → status |
|---|---|---|
| dir ∧ ¬porcelain (or lock unparsable) | corrupt | deny `corrupt_worktree` / `locked_unreadable` |
| ¬dir ∧ ¬porcelain ∧ ¬branch | absent | `created` |
| ¬dir ∧ ¬porcelain ∧ branch | absent_branch_exists | `created` (attach, no `-b`) |
| lock missing | exists_inactive | `attached` |
| lock v1/≠2 ∧ pid dead | exists_stale | `claimed` |
| lock v1/≠2 ∧ pid alive | exists_active_other | deny `owned_by_other` |
| lock v2 ∧ pid dead | exists_stale | `claimed` |
| v2 ∧ pid alive ∧ owner==caller ∧ session==caller | exists_active_mine | `already_mine` |
| v2 ∧ pid alive ∧ (owner≠caller ∨ session≠caller) | exists_active_other | deny `owned_by_other` |

Release: owner-match → delete lock + index entry; no lock/non-owner → ok no-op; corrupt lock → `locked_unreadable`; never destroys, dirty OK. Errors: closed set + `corrupt_worktree`; `confirm_required` stays a summary marker. Index (`~/.agent_worktrees/<repo>/.agent-index.json`): `{version:1, repo_name, updated_at, worktrees:[{change,path,branch,owner,session,last_seen,state}]}` — write-through on acquire/release; never truth (porcelain wins); corrupt/missing → empty, rebuilt; write failure warn-only.

## Testing Strategy

| Layer | What | Approach |
|---|---|---|
| Unit (py) | 9 classifier rows (incl. v1 pid-dead/pid-alive split; `already_mine` owner+session match; same-owner/diff-session → `owned_by_other`); acquire transitions; release matrix; denials | `tests/test_worktree_state.py` (pytest, new) |
| Unit (go) | lock parse + `version==2` guard rows (version=1, version=2, version=missing), stale, repo-name | `lock_test.go` (go test) |
| Wiring | orchestrator block, 6c additive, double-apply assertion (exactly one `sdd-own:worktree-lifecycle-v2` block) | `./sync-skills.sh --check` == 0 desyncs |

## Threat Matrix

Applicable — process integration (kill -0), subprocess (`git -C`), dirty classification. N/A rows carry no tasks.

| Boundary | Applicability | Safe / Failure | RED tests |
|---|---|---|---|
| Git repo selection (`-C`, rel/abs) | Applicable | Root always from `--show-toplevel`; failure → `not_a_repo` | subdir/`./` → same namespace; non-repo → denial |
| Commit state (dirty) | Applicable | Staged/untracked user entries → dirty; `.codegraph`/`.sdd-agent-lock` excluded; git failure → fail-closed dirty | staged-only → dirty; server-owned-only → clean |
| Process liveness | Applicable | ESRCH/dead → stale; EPERM → alive; unparsable pid → stale | dead pid → stale; bad pid → stale |
| Concurrent separate opencode instances | Applicable | Distinct server PIDs both alive → not PID-liveness-stale; classified `exists_active_other` → deny `owned_by_other` via owner/session match (never silent takeover) | same-owner different-session → denial; different-owner → denial |
| Doc-like paths / Push / PR | N/A — no doc-exec classification, no push/PR ops | — | — |

## Migration / Rollout

v1 locks with dead PID → `exists_stale` → auto re-claim; v1 locks with live PID → `exists_active_other` → deny `owned_by_other` (prevents silent double-claim of a live pre-v2 session mid-rollout). Index rebuilds from git+disk. No feature flags. Rollback: wrappers keep `add`/`remove` working; revert any layer independently; delete v2 locks/index harmless. Acquire/release never destroy worktrees ⇒ no data-loss risk.

## Open Questions

Resolved by council consensus (no open questions at tasks freeze):
- `reclaimed` stays reserved (no expiry TTL); unreachable with current signals, route set kept with "intentionally reserved" comment for forward compatibility. ✓
- `store` is an optional acquire parameter defaulting to `"hybrid"` per this change's preflight (lock v2 requires it; callers may override). ✓ → tasks