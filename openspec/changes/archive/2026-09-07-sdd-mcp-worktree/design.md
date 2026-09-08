# Design: sdd-mcp-worktree

## Technical Approach

Three coordinated surfaces plus two install-contract surfaces. F5 hardens `setup.sh` against transient network loss (degrade→[aviso]+continue) and adds an interactive runtime selector step (5g). F6 extends the local `gh-git-mcp-server` with three worktree tools reusing the existing `destructive_flow` two-phase + `_validate_worktree` machinery, plus a `.sdd-agent-lock` process-liveness check, under the multi-agent worktree convention adopted in council: root `~/.agent_worktrees/<repo-name>/<change-name>` (HOME-relative, portable across machines; outside any git tree; no .gitignore needed; 2+ agents per repo each with its own worktree as `--cwd`). The sync deploys per-runtime file-access permission for `~/agent_worktrees/**` so agents work organically without manual config; the MCP server is the sanctioned worktree-mutation surface (no-git-crudo) and enforces the cross-repo boundary: `remove` only ever targets worktrees under the caller's repo basename. Skill 6c appends an additive extension section documenting the multi-agent flow. Two install-contract files flip to match the adopted convention: `wiring/prompts/sdd/orchestrator.md` (clause 5 "Worktree lifecycle" path + Phase 0 exception text) and `overlays/shared/sdd-phase-common.md` (`shared-worktree-binding` block) both pin `~/.agent_worktrees/<repo-name>/<change-name>`. The echo-contract discoverability gap found in `git_commit` (confirmed=true without confirmed_data → infinite `confirm_required`) is in scope: all two-phase tool descriptions document the echo protocol and the `confirm_required` message becomes actionable. Traced to proposal D1–D5, delta specs, council decision C1 (worktree location/naming + permission deployment) and finding E1 (echo contract).

## Architecture Decisions

| # | Decision | Choice | Alternatives | Rationale |
|---|----------|--------|--------------|-----------|
| D-F5-1 | Degrade guard | One `degrade()` bash fn: prints `[aviso]`, records a flag, overrides fatal exit-path | Inline if/continue per site | Single code path (exploration [F5-guard]); keeps 401 fatal by branching on `network*` vs `invalid*`; no OOP, plain functions |
| D-F5-2 | Exit mapping | Network degrade sets `network_degraded=1`; if `network_degraded=1` and no 401 occurred → continue without persisting the token; all-invalid (3× invalid tokens) → `exit 2`; ≤1 otherwise | — | Spec: degrade must be exit ≤1 while 401/316-318 stays 2 (AC1/AC2) |
| D-F5-3 | Selector (5g) | Step after 5e (merge) and before 5f; reads top-level `selectors` (default ALL); TTY→pty space/Enter; no-TTY/`--check`/`--dry-run`→ALL | Persisted selection | Non-goal no-persistence; non-interactive always-ALL is zero-config |
| D-F5-4 | Skip mechanics | Build `SELECTED_RUNTIMES[]`; merge loop (898-939) `continue`s on runtime not selected | Touching `block`/`merge` | Skip happens before merge call; `merge_*` and `wiring/opencode.sdd.json` untouched |
| D-F6-1 | Tool placement | `worktree_mutation.py` (add/remove) + `git_worktree_list` in `local_read.py` | New family file | Mirrors existing layout: 2 local mutation currently; list is idempotent read sibling (spec Surface) |
| D-F6-2 | Shared helper | `_validate_worktree` copied into `worktree_mutation.py` (matches `local_mutation.py`/`local_read.py` duplication pattern) | Extraction to shared module | Server already duplicates `_validate_worktree` per handler; follow existing pattern, don't refactor |
| D-F6-3 | active_agents | Lock file written by `git_worktree_add`; `remove` reads it; `kill -0` live→deny | Agent registry | Simplest, no cross-process coordination; TOCTOU accepted advisory (risk) |
| D-F6-4 | Catalog | `envelope.py` catalog + `gh-git-mcp-server/spec.md` grow `worktree_exists`,`active_agents`; emit `dirty_worktree` | New catalog | A12 closed-set lockstep in one change |
| D-F6-5 | Skill 6c | Additive append only; all existing content byte-identical | — | Non-regression spec; no-git-crudo preserved |
| C1 | Worktree root | `~/.agent_worktrees/<repo-name>/<change-name>` (HOME-relative) | `<repo-parent>/...`, sibling-derived, absolute paths | Portable across machines/OS (HOME exists everywhere); outside any git tree so no repo contamination (verified: inner repo dirs show as untracked); MCP resolves `~` via `Path.home()`; never hardcoded machine paths |
| C2 | Permission deployment | Sync writes per-runtime file-access allow for `~/agent_worktrees/**`. opencode: `permission.external_directory` glob; claude: `permissions.additionalDirectories` + allow tool-specs; codex: `sandbox_workspace_write.writable_roots`; pi: `pi-permission-modes` external_directory | Ask user to hand-edit config | User requirement: organic, zero manual config; per-runtime mechanics live in setup.sh envelopes (`wiring/mcp.d/*.json` contract extended), never in the SDD wiring fragment. Permission deploy step SHALL respect `SELECTED_RUNTIMES` — a runtime deselected in the 5g selector does NOT get its `~/agent_worktrees/**` allow deployed. Roots beyond opencode are literal-dir, so MCP C3 boundary is the actual safety layer |
| C3 | Cross-repo AND cross-worktree boundary | MCP is the only worktree-mutation surface. `remove` takes `(repo_path, change, owner)`, never a raw path: server derives canonical `~/.agent_worktrees/<basename(repo_path)>/<change>` and validates `change` is a safe slug. `.sdd-agent-lock` gains `owner` (identity of the session that ran `add`; caller-asserted, advisory — real gates are canonical derivation + `kill -0`); `remove` requires lock owner == caller owner, else `owned_by_other` deny. Live pid → `active_agents` deny | Broad fs perms / trusting agents / path-arg remove | no-git-crudo already enforced. Same-repo agents A(C) and B(D): A's remove of D is structurally impossible (D is not derivable from A's change name) AND denied by owner+lock even if change name known. Live-lock also protects in-progress work. `force`/recovery path (cross-session cleanup) is explicit and two-phase, never default |
| E1 | Echo-contract discoverability | Tool descriptions of ALL two-phase tools (5 existing + 2 new) document the exact echo protocol; `confirm_required` message names the required field | Weaken fingerprint gate | Root cause of git_commit re-confirm loop (llm-proxy): caller passed confirmed=true with no confirmed_data; the fail-closed fingerprint gate is correct and stays |

## Data Flow

```
setup.sh 5g ── TTY? ──yes──> pty runtimes toggle (space) ──Enter──> SELECTED_RUNTIMES[]
                └──no / check|dry-run──> ALL (no prompt)
merge loop ── SELECTED_RUNTIMES? ── skip ──continue
sync permission deploy ── per-runtime config key (opencode external_directory) ──> allow ~/agent_worktrees/**
git_worktree_add [{repo_path, change}]: root = ~/.agent_worktrees/<basename(repo_path)>/<change>;
                    change MUST match safe-slug ^[A-Za-z0-9][A-Za-z0-9._-]*$ (reject / \ .. empty);
                    canonical = Path.home()/".agent_worktrees"/basename(repo_path)/<change> (basename stripped of trailing /);
                    dry_run? → data{path,branch,dry_run:true,safe:true iff slug valid AND target absent} ──confirm──> create worktree,
                    write .sdd-agent-lock IMMEDIATELY after creation (BEFORE deps/.codegraph),
                    git -C add --no-track default b sdd/<c>, init .codegraph;
                    pre-checks (typed denies, outside destructive_flow): dirty_worktree → deny; active_agents (kill -0) → deny
git_worktree_remove [{repo_path, change, owner}]: canonical = ~/.agent_worktrees/<basename(repo_path)>/<change>
                    (change = safe slug; NO raw path arg accepted; raw path / traversal attempt → invalid_parameter)
                    pre-checks (typed denies, OUTSIDE the two-phase destructive_flow path — same pattern as _validate_worktree in local_mutation.py):
                      dirty (git status --porcelain) → dirty_worktree deny;
                      live PID (kill -0) → active_agents deny;
                      lock owner != caller owner → owned_by_other deny;
                    safe: true iff clean AND no live agents AND owner match;
                    dry_run ──> safe=true → data{path,safe:true,dry_run:true};
                    confirm──> git worktree remove + rm lock
```

## File Changes

| File | Action | Description |
|------|--------|-------------|
| `wiring/prompts/sdd/orchestrator.md` | Modify | clause 5 "Worktree lifecycle": flip path to `~/.agent_worktrees/<repo-name>/<change-name>` (HOME-relative, resolved via Path.home()); update Phase 0 exception text (bootstrap premise dies once MCP tools exist — after THIS change, worktrees are MCP-created) |
| `overlays/shared/sdd-phase-common.md` | Modify | `shared-worktree-binding` block: same convention flip to `~/.agent_worktrees/<repo-name>/<change-name>` |
| `setup.sh` | Modify | F5 degrade at 308-310 (`prompt_new_token` network→[aviso]+continue), 829-832 (`--check` structural→[aviso]+continue, no `mcp_exit=2`); new 5g selector step; skip in merge loop; permission-deploy step for `~/agent_worktrees/**` per C2 |
| `wiring/mcp.d/*.json` | Modify | Add top-level `selectors` (array; outside `block`) + `permission_roots` contract (C2 per-runtime keys) |
| `srv/gh-mcp-server/src/tool_handlers/worktree_mutation.py` | Create | `git_worktree_add`/`git_worktree_remove` via `destructive_flow`; add resolves `~` via `Path.home()`; remove validates basename boundary (C3) |
| `srv/gh-mcp-server/src/tool_handlers/local_read.py` | Modify | Add `git_worktree_list` |
| `srv/gh-mcp-server/src/tool_handlers/__init__.py` | Modify | register `worktree_mutation` |
| `srv/gh-mcp-server/src/envelope.py` | Modify | Catalog + `worktree_exists`,`active_agents`,`owned_by_other` |
| `srv/gh-mcp-server/src/tool_handlers/*.py` (descriptions) | Modify | E1: all two-phase tool docstrings document echo protocol |
| `srv/gh-mcp-server/src/dryrun.py` | Modify | E1: actionable `confirm_required` message (name required field) |
| `skills/using-git-worktrees/SKILL.md` | Modify | Additive 6c append |
| `tests/run_red_checks.sh` | Modify | T09/T20 re-spec + new worktree test blocks + E1 doc-contract check |

## Interfaces / Contracts

```
selectors (envelope top-level): ["opencode","pi","claude","codex"]  # default ALL
permission_roots (envelope top-level): ["~/agent_worktrees/**"]  # per-runtime key mapping in setup.sh
worktree root: ~/.agent_worktrees/<repo-name>/<change-name>   # repo-name = basename(repo_path)
safe-slug grammar: change SHALL match ^[A-Za-z0-9][A-Za-z0-9._-]*$; reject / \ .. empty; canonical = Path.home()/".agent_worktrees"/basename(repo_path)/<change> (basename stripped of trailing /)
.sdd-agent-lock (worktree root, JSON):
  {"pid": <int>, "session": <str>, "owner": <str>, "timestamp": <float>}
  active if kill -0 pid 0; stale/absent → removable only when owner matches caller
  owner is caller-asserted (advisory); real gates are canonical derivation + kill -0 liveness
error catalog (closed set): auth_required, repo_not_found, network_error,
  not_found, not_a_repo, dirty_worktree, not_safe, commit_failed,
  invalid_parameter, worktree_exists, active_agents, owned_by_other
  Note: `confirm_required` is a summary marker on ok() envelopes, NEVER an err() type;
  `not_safe` (from the fingerprint gate) and `commit_failed` (from local_mutation.py) are err() types
two-phase echo protocol (documented in every tool description):
  phase 1 dry_run=true → return display_data {dry_run:true, ...effect.data}
  phase 2 confirmed=true + confirmed_data=EXACT display_data object → fingerprint
  confirmed_data omitted/mismatched → confirm_required (never executes)
  fail-closed gate requires dry-run effect data["safe"] is True for confirm to execute
  safe computation: add → slug valid AND target absent; remove → clean AND no live agents AND owner match
```

`degrade()` bash abstraction: set `network_degraded=1`, print `[aviso]`, return 0. No global mutation of `mcp_exit` — the caller's normal continue path applies.

## Testing Strategy

| Layer | What | Approach |
|-------|------|----------|
| RED (setup.sh) | T09 re-spec → network degrade: real-mode + API dead → exit ≤1 + `[aviso]`, no config mutation | `start_fake_api 200; stop_fake_api; run_setup_pty` (existing seam) |
| RED (setup.sh) | T20 re-spec → `--check` + dead API → exit ≤1, no `estado estructural` error | `api_dead_port` seam (t `T20`) |
| RED (setup.sh) | `bash -n setup.sh && bash -n srv/gh-mcp-server/src/*.py <files>` — syntax validation per quest AC6 | `bash -n` |
| RED (permission deploy) | C2: sync writes per-runtime allow for `~/agent_worktrees/**`; opencode `external_directory` present after real-mode | `--check` before/after + config readback |
| Unit (server) | `_validate_worktree`, lock `kill -0` live/stale, C3 boundaries: remove other-repo denied, remove same-repo-other-change denied (owner mismatch), raw-path arg rejected | direct handler test with `SubprocessRunner`/mock executor |
| Integration (server) | add→list→remove cycle; dirty/active/owned-by-other denies; A(C) cannot remove D | temp repo worktree; fail-inject stale/foreign PID, foreign owner |
| RED (echo contract) | E1: 7 two-phase tool descriptions mention `confirmed_data` echo; `confirm_required` message names required field | grep-based contract check in `run_red_checks.sh` |

**Failure injection for network degrades:** reuse `start_fake_api <code>` + `stop_fake_api` to force `network*` (API unreachable); `api_dead_port()` to force `--check` structural network. 401 stays via `start_fake_api 401`.

T09/T20 re-spec: invert exit expectation from `2` to `≤1`, assert `[aviso]` (not `[ERROR]`/`[DESYNC]`), keep no-mutation assertions.

## Threat Matrix

| Boundary | Applicability | Design response | RED tests |
|----------|---------------|-----------------|-----------|
| Documentation-like paths | N/A — no doc-as-executable classification | — | — |
| Git repo selection | Applicable | `_validate_worktree` on `repo_path` before any git op; reject non-worktree as `not_a_repo` | `git_worktree_add`/`list`/`remove` on non-repo path |
| Commit state | Applicable | `git status --porcelain` → `dirty_worktree`; `git worktree remove` only when clean | T remove-dirty-denied |
| Push state | N/A — no push worktree op | — | — |
| PR commands | N/A — no PR composition | — | — |
| Process integration (NEW) | Applicable | `.sdd-agent-lock` pid `kill -0` liveness; stale→removable, live→`active_agents` deny | T remove-live-denied, T remove-stale-allowed |
| Cross-repo worktree deletion (NEW) | Applicable | C3: remove narrows to `~/.agent_worktrees/<basename(repo_path)>/<change>`; other valid repo → `owned_by_other` (owner mismatch); non-git path → `not_a_repo`/deny | T remove-other-repo-denied |
| Same-repo cross-worktree deletion (NEW — A(C) vs B(D)) | Applicable | C3: remove takes `(repo_path, change)` only (no raw path); canonical path derivation + owner lock match + live-pid deny | T remove-other-change-denied, T remove-live-denied |
| Permission surface (NEW) | Applicable | C2: allow `~/agent_worktrees/**` file access; destructive ops still gated by MCP two-phase (defense in depth) | T permission-deploy, T remove still two-phase under allow |

## Migration / Rollout

No data migration. Envelopes gain `selectors` + `permission_roots` (default ALL / empty = backward compatible). Server gains tools additively. Skill 6c additive. Permission deploy only adds new allow keys per runtime (never removes personal config; merge is additive like the rest of setup.sh). Rollback per proposal (remove tool files+registration, revert setup.sh ranges, remove `selectors`/`permission_roots`, revert T09/T20).

## Open Questions

- Per-runtime permission mechanics for codex/claude/pi (C2): **resolved with web evidence**. opencode → `permission.external_directory` glob `~/agent_worktrees/**`; claude code → `permissions.additionalDirectories` (literal dir) + `permissions.allow` tool-spec globs; codex → `sandbox_mode = "workspace-write"` + `sandbox_workspace_write.writable_roots = ["~/.agent_worktrees"]` (literal); pi → `pi-permission-modes` extension `permission.external_directory` glob + Linux `sandbox.allowWrite` literal. setup.sh holds the per-runtime mapping; envelope `permission_roots` is the single contract list. Note: directory roots are literal paths in claude/codex/pi — user-level expansion only (no per-repo glob), so C3 (MCP basename boundary) is the enforcement layer; file-access allow is operational convenience, never the safety boundary.
- Locations of the two recent `destructive_flow`-handled worktree ops need no new work — pattern is proven. None blocking.

## Risks

| Risk | Sev | Mitigation |
|------|-----|------------|
| **Line-pin drift on re-verify (High spec risk)**: L308-310 ✓, L829-832 ✓, L316-318 ✓, L758-761 ✓ confirmed current; **L401 spec pin STALE** — `validate_token()` lives at L163, 401 branch returns `invalid <code>` there; L401 is now inside the `merge_json_key` python heredoc | High | Recorded corrected pin; ensure disabled Fixed-point. Adequates for RED AC2 via `start_fake_api 401` not line 401 |
| TOCTOU on `active_agents` (agent PID spawns between check and remove) | Medium | Lock written immediately after worktree creation, before deps/.codegraph; `kill -0` advisory, not absolute (accepted) |
| T09/T20 exit flip breaks downstream consumers of old exit-2 contract | Medium | README exit-semantics note updated same change |
| Selector UX first-use confusion | Low | Default ALL = zero-config always works |
| Echo-contract UX (E1) | Medium | Previously: silent infinite `confirm_required` loop (llm-proxy incident). Now documented in all 7 tool descriptions + actionable message + contract check |
| Cross-repo boundary relies on basename match (C3) | Medium | Basename collision (two repos named same) mitigated by `~/.agent_worktrees/<basename>/` namespace; remove still two-phase + lock liveness |
| Owner mismatch on cross-session cleanup (C3) | Low | A worktree created in session S1 can only be removed by owner S1 (or explicit two-phase `force` recovery); documented in skill 6c — never default to bypass |
| Permission root broadness (C2) | Low-Medium | `~/agent_worktrees/**` allow is a directory, not a whole-home grant; destructive ops remain MCP two-phase (never open-ended file perms) |
