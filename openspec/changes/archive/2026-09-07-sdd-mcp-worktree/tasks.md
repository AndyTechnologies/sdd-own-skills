# Tasks: sdd-mcp-worktree

## Review Workload Forecast

Decision needed before apply: Yes
Chained PRs recommended: No
Chain strategy: pending
400-line budget risk: Medium

Session budget = `review_budget_lines 800`; est. ~700-800; over 800 → `size:exception`. One PR, 4 units.

### Suggested Work Units

| Unit | Goal | Focused test | Runtime | Rollback |
|------|------|--------------|---------|----------|
| 1 | F6 server + catalog | server tests | temp-repo add→list→remove | drop mutation/list/reg/envelope+3 |
| 2 | E1 echo docs + dryrun | grep-E1 check | echo dry→confirm→deny | revert 7 descriptions + dryrun |
| 3 | F5 setup + C2 + envelopes | `bash -n setup.sh` + T09/T20 | fake-API/`api_dead_port` degrade | revert setup.sh, envelope, T09/T20 |
| 4 | Lockstep + skill 6c | `./sync-skills.sh --check` | real sync + byte-diff | revert orchestrator/phase-common, 6c |

**Tokens**: start `ls <files>` · finish `<test> exit 0` · verify `bash -n` + `--check` → 0 desyncs · rollback `git checkout -- <files>`

## Phase 1: Server F6 core + catalog

- [x] 1.1 Catalog += `worktree_exists`,`active_agents`,`owned_by_other` in `srv/gh-mcp-server/src/envelope.py` + `specs/gh-git-mcp-server/spec.md`
- [x] 1.2 Create `worktree_mutation.py`: `_validate_worktree` + add/remove via `destructive_flow`, pre-checks outside it (dirty_worktree, `kill -0`, owned_by_other)
- [x] 1.3 Safe-slug `^[A-Za-z0-9][A-Za-z0-9._-]*$` + canonical `Path.home()/".agent_worktrees"/basename(repo_path)/<change>`; never raw path (→`invalid_parameter`); C3 remove basename boundary
- [x] 1.4 add writes `.sdd-agent-lock` (`pid`,`session`,`owner`,`timestamp`) pre-deps/.codegraph; `safe` = slug+absent (add), clean+live+owner (remove); fail-closed `data["safe"] is True`
- [x] 1.5 `git_worktree_list` in `local_read.py`; register `worktree_mutation` in `__init__.py` (26 tools / 5 families)
- [x] 1.6 RED: add→list→remove; dirty/live/owned_by_other denies; stale allowed; A(C) can't remove D; non-repo → `not_a_repo`

## Phase 2: E1 echo-contract

- [x] 2.1 Echo protocol in all two-phase descriptions (7): dry_run→display_data; confirmed=true + confirmed_data=EXACT
- [x] 2.2 Actionable `confirm_required` (name field) in `dryrun.py`; fingerprint gate unweakened
- [x] 2.3 RED: grep — 7 descriptions echo `confirmed_data`; `confirm_required` ok() marker, never err

## Phase 3: F5 setup.sh + C2 + envelopes

- [x] 3.1 `degrade()` (`[aviso]`+`network_degraded=1`+return 0); L308-310/L829-832 degrade+continue; L316-318+401 fatal
- [x] 3.2 `network_degraded=1` and no 401 → continue, no token persisted; all-invalid → exit 2
- [x] 3.3 Step 5g (after 5e before 5f): `selectors` (default ALL); TTY→pty toggle; no-TTY/`--check`/`--dry-run`→ALL; no persistence
- [x] 3.4 `SELECTED_RUNTIMES[]`; merge loop skips unselected; `wiring/opencode.sdd.json` untouched
- [x] 3.5 C2: `selectors`+`permission_roots` ["~/agent_worktrees/**"] in `wiring/mcp.d/*.json`; never add `permission`/`mcp` to `wiring/opencode.sdd.json`
- [x] 3.6 permission-deploy step for `~/agent_worktrees/**`, respects `SELECTED_RUNTIMES`
- [x] 3.7 RED: T09/T20 (exit ≤1, `[aviso]`, no mutation) + readback

## Phase 4: Lockstep (B1)

- [x] 4.1 `wiring/prompts/sdd/orchestrator.md` clause 5 → `~/.agent_worktrees/<repo-name>/<change-name>` + Phase 0 exception text
- [x] 4.2 `overlays/shared/sdd-phase-common.md` `shared-worktree-binding` flip
- [x] 4.3 `./sync-skills.sh --check` → 0 desyncs

## Phase 5: Skill 6c append

- [x] 5.1 Append 6c to `skills/using-git-worktrees/SKILL.md`: MCP-native lifecycle, `sdd/<change>` branch, per-worktree deps/.codegraph, removal safety, 3 MCP tools, no raw `git worktree`; existing byte-identical
- [x] 5.2 RED: `--check` 0 desyncs + byte-diff

## Phase 6: Verification

- [x] 6.1 `tests/run_red_checks.sh` (worktree/E1/permission blocks) green
- [x] 6.2 `bash -n setup.sh sync-skills.sh srv/gh-mcp-server/src/*.py` → 0
- [x] 6.3 `./sync-skills.sh --check` → 0 desyncs; no Alan base edits
