# Proposal: sdd-mcp-worktree

## Intent

Make `setup.sh` resilient to transient network failures (degrade to warning, never abort) and add a runtime-selector step, while extending the local MCP server with three worktree lifecycle tools (`git_worktree_add`, `git_worktree_list`, `git_worktree_remove`) under the existing two-phase destructive-flow pattern.

## Scope

### In Scope
- **F5 degrade**: convert 2 network-fatal points to warning+continue; keep 401/invalid fatal
- **F5 selector**: interactive runtime picker after step 5e, before 5f
- **F6 tools**: 3 worktree MCP tools mirroring `destructive_flow`
- **active_agents safety check**: new error type + detection mechanism for remove
- **Test re-spec**: T09/T20 flip to degrade expectations; new test cases
- **Skill extension 6c**: additive append to `using-git-worktrees/SKILL.md`

### Out of Scope
- `wiring/opencode.sdd.json` (Lane B)
- `permission` additions to any config
- sync merge mechanics or Alan base edits
- Selector persistence between runs

## Capabilities

### New Capabilities
- `worktree-tools`: MCP worktree lifecycle (`add`/`list`/`remove`) with two-phase destructive flow, safety checks, and error-catalog additions

### Modified Capabilities
- `github-mcp-setup`: degrade-on-network semantics (F5), runtime selector step (F5)
- `gh-git-mcp-server`: error catalog grows `active_agents`; tool surface grows 3 tools
- `git-worktrees-skill`: additive 6c extension for MCP-driven lifecycle
- `mcp-definitions`: `selectors` field outside block envelope

## Approach

### Decision 1 — Re-pinned insertion points (current lines)
| Point | Lines | Current behavior | Change |
|-------|-------|------------------|--------|
| `prompt_new_token` network | 308–310 | `exit 2` | warning + continue |
| invalid after 3 tries | 316–318 | `exit 2` (fatal) | **Keep fatal** — 401 discrimination |
| `--check` structural network | 829–832 | `mcp_exit=2` | degrade to warning |
| existing-token real | 758–761 | already degrades | **Keep as-is** |
| `validate_token` 401 | 401 | fatal | **Keep fatal** |

### Decision 2 — active_agents detection
Mechanism: each worktree tool writes a `.sdd-agent-lock` file (JSON: PID + session + timestamp) at worktree root on add; remove checks for absence of the file OR that the PID is dead (`kill -0`). Absence = no agents, stale PID = no agents, live PID = deny with `active_agents` error. The `dirty_worktree` error type (already in envelope catalog, currently unemitted) handles uncommitted-changes check. New `active_agents` type added to `envelope.py` catalog + `gh-git-mcp-server/spec.md` closed-set list in lockstep.

### Decision 3 — Selector step
New step `5g` after `5e`/before `5f`: reads `selectors` field (outside `block` envelope; default = ALL). TTY → pty toggle (space) + Enter; no-TTY or `--check`/`--dry-run` → all. Unselected runtimes are skipped in the merge loop without disturbing `block`/`merge` mechanics or `wiring/opencode.sdd.json`. `--skip-opencode`/`--skip-mcp` remain intact.

### Decision 4 — F6 tool pattern
`worktree_mutation.py`: `git_worktree_add`/`remove` via `destructive_flow` + `_validate_worktree`; `git_worktree_list` as idempotent read sibling in `local_read.py`. Location: `<repo-parent>/<repo-name>-worktrees/<change-name>`, branch `sdd/<change>`, own `.codegraph/`.

## Affected Areas

| Area | Impact | Description |
|------|--------|-------------|
| `setup.sh` L308–310, L829–832 | Modified | Network-fatal → degrade |
| `setup.sh` new L~5g | New | Selector step |
| `srv/gh-mcp-server/src/tool_handlers/` | Modified | 3 new tools + `active_agents` catalog |
| `tests/run_red_checks.sh` | Modified | T09/T20 re-spec + new test blocks |
| `skills/using-git-worktrees/SKILL.md` | Modified | Additive 6c append |
| `wiring/mcp.d/*.json` | Modified | `selectors` field (outside block) |

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| Line-number drift during implementation | High | Exploration re-pinned all points; design MUST verify before code |
| active_agents race condition (agent starts between check and remove) | Medium | Lock file written before worktree content; PID stale-check is advisory, not absolute |
| T09/T20 contract flip breaks downstream exit-code consumers | Medium | README/design exit table updated in same change |
| Selector UX confusion on first use | Low | Default ALL means zero-config always works |

## Rejected Alternative: no-server-git
Rejected because it doesn't match the envelope contract and lacks native two-phase destructive flow with safety checks. Our MCP server already has the machinery (`destructive_flow`, `_validate_worktree`, typed errors).

## Rollback Plan
Remove the 3 new tool files + registration; revert setup.sh to original line-range patterns; remove `selectors` from envelopes; revert T09/T20 to original assertions. `./sync-skills.sh --check` → zero desyncs confirms clean rollback.

## Dependencies
- `envelope.py` closed error catalog extension (internal, no external dep)

## Success Criteria
- [ ] AC1: simulate network failure at L308–310 and L829–832 → exit ≤1 with warning
- [ ] AC2: simulate 401 at L316–318 → fatal, no config mutation
- [ ] AC3: selector TTY toggle works; no-TTY → all; `--check`/`--dry-run` → no prompt
- [ ] AC4: `git_worktree_add` creates correct location/branch; dry-run first
- [ ] AC5: `git_worktree_remove` denies on uncommitted changes or active agents
- [ ] AC6: `git_worktree_list` returns existing worktrees
- [ ] AC7: T09/T20 green with new expectations; new test cases pass; `bash -n` on setup.sh + srv
