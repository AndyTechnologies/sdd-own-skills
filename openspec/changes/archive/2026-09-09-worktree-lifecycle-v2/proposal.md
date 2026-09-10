# Proposal: Worktree Lifecycle v2

## Intent

Current lifecycle (advisory `.sdd-agent-lock` v1 + `git_worktree_add`/`remove`) fails three ways: (1) power loss forces remembering the exact change name for `/sdd-continue`; (2) `sdd-tool worktree list|verify` hardcodes `"sdd-own-skills"` in `worktree.go:~L77`, breaking in other repos; (3) add/remove lack acquire/release semantics — claim/re-claim/attach/conflict detection inexpressible.

## Scope

### In Scope

- 7-state model: `absent` / `absent_branch_exists` / `exists_inactive` / `exists_stale` / `exists_active_mine` / `exists_active_other` / `corrupt`
- `git_worktree_acquire(repo_path, change, owner, session)`: create/attach/claim/re-claim/no-op → `{status, path, branch}`; typed denials (`owned_by_other`, `locked_unreadable`)
- `git_worktree_release(repo_path, change, owner)`: releases claim, never destroys (dirty fine)
- Enriched `git_worktree_list`: state, owner, session, last_seen, dirty
- Lock v2: `{version:2, pid, session, owner, change, repo_root, repo_name, branch, store, created_at, last_seen}`; `repo_name` always from toplevel basename; stale = dead pid → auto re-claim
- Hint index `~/.agent_worktrees/<repo>/.agent-index.json` (never truth)
- Orchestrator: `acquire` before `sdd-tool worktree verify`; auto re-claim on objective stale evidence; prompt only on real conflicts
- Organic continuation: list + apply-progress cross-ref → 1=direct; 2–5=Quest; >5=table + validated input; 0=nothing, propose `/sdd-new`
- Retrocompat: add/remove preserved

### Out of Scope

Real `flock()`; automatic prune; TUI goroutine verification; multi-machine support.

## Capabilities

### New Capabilities

- `worktree-lifecycle`: 7-state model, acquire/release, lock v2, index, error catalog
- `crash-recovery`: organic continuation, volume-based selection, apply-progress cross-reference

### Modified Capabilities

- `gh-git-mcp-server`: acquire/release tools, enriched list, error catalog expansion
- `git-worktrees-skill`: tool refs add/remove → acquire/release; documents states

## Approach

1. 7-state classifier in gh-mcp-server handlers (porcelain + lock + disk + PID)
2. New acquire/release; add/remove as thin wrappers; lock v2 in `sdd-tool`+MCP; fix `worktree.go:~L77`
3. Index write-through on acquire/release
4. Orchestrator prompt wiring; skill/spec updates in lockstep

## Affected Areas

| Area | Impact |
|------|--------|
| `worktree_mutation.py` | Modified — acquire/release, classifier |
| `local_read.py` | Modified — enriched list |
| `envelope.py` | Modified — error catalog |
| `srv/sdd-tool/internal/worktree/worktree.go` | Modified — lock v2, repo-name fix |
| `wiring/prompts/sdd/orchestrator.md` | Modified — §Worktree Lifecycle |
| `skills/using-git-worktrees/SKILL.md` | Modified — tool refs |
| `~/.agent_worktrees/<repo>/.agent-index.json` | New (runtime) — hint index |

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| v2 migration breaks v1 locks | Low | v1 → `exists_stale`, auto re-claim |
| Index drifts from truth | Low | hint-only, never authoritative |
| acquire false-positive concurrent session | Med | typed denial, no silent takeover |
| >5-change selection UX errors | Low | validated input, re-present on ambiguity |

## Rollback Plan

- add/remove preserved throughout → immediate revert
- Orchestrator: remove acquire block, restore direct phase entry
- Delete v2 locks / `.agent-index.json` (rebuilt from git+disk)
- Worktrees never destroyed by acquire/release → no data-loss risk

## Dependencies

`src/gh-mcp-server` (FastMCP/uv), `src/sdd-tool` (Go), `wiring/prompts/sdd/orchestrator.md`

## Success Criteria

- [ ] acquire: new→create+lock v2+index; mine→`already_mine`; stale→auto re-claim; other→`owned_by_other`
- [ ] release removes claim, keeps dirty state; list reports full state; continuation UX correct for all volumes (incl. 0)
- [ ] `repo_name` always from toplevel basename; v1 locks handled as stale