# Tasks: Worktree Lifecycle v2

## Review Workload Forecast

| Field | Value |
|-------|-------|
| Estimated changed lines | 750–950 |
| 400-line budget risk | High |
| Chained PRs recommended | Yes |
| Suggested split | PR 1: shared layer + tests → PR 2: MCP tools + envelope → PR 3: Go observer + orchestrator + skill |
| Delivery strategy | single-pr |
| Chain strategy | pending |

Decision needed before apply: No
Chained PRs recommended: Yes
Chain strategy: pending
400-line budget risk: High

### Suggested Work Units

| Unit | Goal | Likely PR | Focused test command | Runtime harness | Rollback boundary |
|------|------|-----------|----------------------|-----------------|-------------------|
| 1 | Shared pure layer + Python tests | PR 1 | `pytest srv/gh-mcp-server/tests/test_worktree_state.py -v` | N/A — pure functions, no MCP server needed | Revert `worktree_state.py` + `test_worktree_state.py` |
| 2 | MCP tools (acquire/release wrappers, enriched list) + envelope | PR 2 | `pytest srv/gh-mcp-server/tests/test_worktree_state.py -v` + manual MCP tool call test | Start gh-git-mcp-server, call acquire/release/list | Revert `worktree_mutation.py`, `local_read.py`, `envelope.py` |
| 3 | Go observer + orchestrator + skill + spec-delta note | PR 3 | `go test ./srv/sdd-tool/internal/worktree/...` + `./sync-skills.sh --check` | N/A — read-only Go + static wiring | Revert `lock.go`, `lock_test.go`, `worktree.go`, `orchestrator.md`, `SKILL.md` |

## Phase 1: Shared Pure Layer

- [x] 1.1 Create `srv/gh-mcp-server/src/worktree_state.py`: lock v2 schema (version, pid, session, owner, change, repo_root, repo_name, branch, store, created_at, last_seen), constants (LOCK_FILENAME, SERVER_OWNED, SAFE_SLUG regex)
- [x] 1.2 Add repo-name derivation: `derive_repo_name(executor, repo_path) -> str` using `git rev-parse --show-toplevel` basename; add `canonical_worktree_path(executor, repo_path, change) -> str`
- [x] 1.3 Add lock helpers: `read_lock_v2(worktree) -> (dict|None, status)` (ok/missing/corrupt), `write_lock_v2(worktree, *, owner, session, change, repo_root, repo_name, branch, store)`, `remove_lock(worktree)`, `lock_has_live_pid(lock) -> bool` (kill -0, ESRCH→False, EPERM→True, unparsable→False)
- [x] 1.4 Add dirty check: `status_dirty(executor, target) -> (bool, error)` excluding `.codegraph/` and `.sdd-agent-lock`; git failure → fail-closed dirty
- [x] 1.5 Add 9-row classifier: `classify_worktree(executor, repo_path, change, owner, session) -> (state, signals_dict)` ordered per design table (corrupt→absent→absent_branch_exists→exists_inactive→v1+dead→v1+alive→v2+dead→v2+owner+session→v2+other)
- [x] 1.6 Add index read/write: `read_index(repo_name) -> dict`, `write_index(repo_name, worktrees)`, `append_index(repo_name, entry)`, `remove_index_entry(repo_name, change)` — version:1 schema; corrupt/missing → empty; write failure warn-only
- [x] 1.7 Add acquire transitions: `acquire_worktree(executor, repo_path, change, owner, session, store="hybrid") -> Envelope` — creates worktree+lock+index on absent; attaches on exists_inactive; claims on exists_stale; already_mine on exists_active_mine; deny on owned_by_other/locked_unreadable/corrupt_worktree; add codegraph init best-effort on created
- [x] 1.8 Add release transitions: `release_worktree(executor, repo_path, change, owner) -> Envelope` — owner-match → delete lock + index entry; no-lock/non-owner → ok no-op; corrupt → locked_unreadable; never destroy, dirty OK
- [x] 1.9 Add `enriched_worktree_list(executor, repo_path) -> Envelope` — parse porcelain, classify each, merge index hints, include main worktree with `is_main: true`

## Phase 2: Python Tests (RED first)

- [x] 2.1 Create `srv/gh-mcp-server/tests/test_worktree_state.py` with pytest fixtures: tmp worktree dirs, mock executor, lock file helpers
- [x] 2.2 RED tests for 9 classifier rows: absent, absent_branch_exists, exists_inactive (lock missing), exists_stale v1+pid_dead, exists_active_other v1+pid_alive, exists_stale v2+pid_dead, exists_active_mine v2+owner+session, exists_active_other v2+diff_session, corrupt (dir but not in porcelain)
- [x] 2.3 RED tests for acquire transitions: created (absent→lock+index), attached (inactive→lock update), claimed (stale→lock update), already_mine (active_mine→no mutation), deny owned_by_other, deny locked_unreadable (corrupt JSON), deny corrupt_worktree
- [x] 2.4 RED tests for release: happy path (owner match→lock+index deleted), no-op non-owner, locked_unreadable corrupt lock, dirty worktree OK
- [x] 2.5 RED tests for index: write-through on acquire/release, corrupt/missing rebuild, write failure warn-only
- [x] 2.6 RED tests for dirty check: staged-only→dirty, server-owned-only→clean, mixed→dirty, git failure→fail-closed
- [x] 2.7 RED tests for repo-name derivation: subrepo/`./` → same basename, non-repo → fallback
- [x] 2.8 RED tests for concurrent instances: same-owner+diff-session→deny, different-owner→deny (threat-matrix row 4)

## Phase 3: MCP Tool Handlers

- [x] 3.1 Modify `srv/gh-mcp-server/src/envelope.py`: add `corrupt_worktree` to error catalog docstring and ensure `locked_unreadable` is listed (already present in code)
- [x] 3.2 Modify `srv/gh-mcp-server/src/tool_handlers/worktree_mutation.py`: add `git_worktree_acquire` tool (import from worktree_state, delegate classify+acquire, validate safe-slug, translate to envelope)
- [x] 3.3 Add `git_worktree_release` tool to same file (import from worktree_state, delegate release, validate safe-slug)
- [x] 3.4 Convert `git_worktree_add` to thin wrapper: keep destructive_flow envelope, safe-slug, two-phase; delegate create+lock+index to `acquire_worktree`; remove inline lock/classifier logic
- [x] 3.5 Convert `git_worktree_remove` to thin wrapper: keep destructive_flow, dirty pre-check, owner pre-check; delegate claim-clearing to `release_worktree`; remove inline read_lock/write_lock calls
- [x] 3.6 Modify `srv/gh-mcp-server/src/tool_handlers/local_read.py`: enrich `git_worktree_list` — import classify from worktree_state, add state/owner/session/last_seen/dirty/is_main per entry, include main worktree

## Phase 4: Go Observer + Tests

- [x] 4.1 Create `srv/sdd-tool/internal/worktree/lock.go`: LockV2 struct, `ParseLockV2(path) (*LockV2, error)` with explicit `version == 2` guard (v1/missing/other → error, never silently trust), `IsStale(lock) bool` (pid dead → stale), `RepoNameFromGitRoot(repoPath) string` via `git rev-parse --show-toplevel` basename
- [x] 4.2 Create `srv/sdd-tool/internal/worktree/lock_test.go`: RED tests for version=1→error, version=2→parsed, version=missing→error, pid dead→stale, repo-name derivation
- [x] 4.3 Modify `srv/sdd-tool/internal/worktree/worktree.go` ~L77: replace hardcoded `"sdd-own-skills"` with `RepoNameFromGitRoot(cwd)` or equivalent dynamic basename; verify `List()` and `Verify()` consume correct paths

## Phase 5: Orchestrator + Skill Wiring

- [x] 5.1 Modify `wiring/prompts/sdd/orchestrator.md`: append `<!-- sdd-own:worktree-lifecycle-v2:start -->` block verbatim from design (acquire gate, continuation volume routing, release contract, reclaimed note, double-apply assertion guidance)
- [x] 5.2 Rewrite section 6c of `skills/using-git-worktrees/SKILL.md`: acquire/release/list as primary tools; add/remove as wrappers; 7-state model; typed denials; no-git-crudo preserved; pre-6c Alan content untouched

## Phase 6: Wiring Verification + Spec-Delta Note

- [x] 6.1 Run `./sync-skills.sh --check` and assert zero desyncs (orchestrator block idempotent, 6c additive)
- [x] 6.2 Add spec-delta note: design corrects spec on three points — (a) v1 lock classification is PID-liveness-aware (spec's unconditional "legacy v1 treated as stale" is superseded), (b) acquire signature includes `store` param (spec's fixed signature is superseded), (c) already_mine requires owner AND session match. These are captured here for the archive/spec-sync phase; do NOT edit spec.md now.
- [x] 6.3 Document PID-reuse manual recovery: manual `.sdd-agent-lock` deletion as recovery path for recycled-PID false-alive locks (council risk 10)

## Spec-Delta Items (for archive phase, NOT to edit now)

1. **v1 lock classification** (design line 78–79): spec says "Legacy v1 lock treated as stale" unconditionally; design splits v1+pid_dead→claimed / v1+pid_alive→deny. Archive must sync spec row.
2. **acquire signature** (design line 66): design adds `store="hybrid"` optional param; spec line 57 lacks it. Archive must sync spec signature.
3. **already_mine session match** (design line 81): design requires owner AND session match; spec line 33–35 has only owner. Archive must sync spec scenario.
