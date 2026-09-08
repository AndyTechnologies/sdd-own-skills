# Exploration: sdd-mcp-worktree

## Current State

### 1. setup.sh flow (F5)
- 1019 lines; steps 0 (delegates sync), 5a detect runtimes + resolve targets, 5b/5c token gate, 5d sync local MCP server, 5e merges per runtime, 5f env snippets, final report.
- Modes via `MCP_MODE`: `real`/`check`/`dry-run`. Flags parsed at lines 642-660; `--check`∧`--dry-run` → exit 1 (line 657).
- `--check`/`--dry-run` never prompt (already true; token gate at 5b branches on mode).
- Network-degrade points (CURRENT line numbers; RFC cited stale ~856-line numbers):
  - **308-310** `prompt_new_token` `network*` → `[ERROR] fallo de red ... no se persiste nada` → `exit 2`. **F5 target → warning + continue.**
  - **316-318** invalid-token after 3 tries → `[ERROR] token no validado` → `exit 2`. **This is the invalid/401-fatal path — keep fatal per RFC.**
  - **829-832** `--check` real: `network*` → `token_status="no verificable (red)"`; `[ERROR] ... estado estructural` → `mcp_exit=2`. **F5 target → degrade to warning.**
  - Existing-token real path at **758-761** already degrades: `[aviso] sin red al validar el token existente; se conserva el env file sin reescribir` (RFC "existing-token path already degrades" — confirmed).
- The RFC's "729-732 exit 2" maps to the current **729-738 create_target** region (line 730 `if real create_target`), NOT a network point — so the RFC's third cited line is out of date; the actual third network-fatal is the `--check` structural point (829-832). **Naming/line drift to resolve in proposal.**

### 2. gh-mcp-server structure (F6)
- `server.py` = composition root: wraps `mcp.tool` with safety net (`SubprocessError`→`network_error`, unexpected→`invalid_parameter`), calls `register_all(mcp, executor)`, restores decorator.
- `tool_handlers/__init__.py` `register_all` wires 4 families: remote_read, remote_mutation, local_read, local_mutation.
- `tool_handlers/local_mutation.py` = the pattern to extend: `git_commit` + `git_delete_branch`, both two-phase via `destructive_flow`: `_validate_worktree(executor, path)` helper + `compute_dry_run` closure (sets `data["safe"]`) + `execute` closure. Registration = `@server.tool()` decorator with typed args.
- `dryrun.py` `destructive_flow(...)`: recompute → build display payload `{"dry_run": True, **effect.data}` → `dry_run`/not-confirmed returns effect → fail-closed gate (`safe is not True` → `not_safe`, NEVER mutate) → echo-back fingerprint match → execute once. Same helper applicable to `git_worktree_remove`.
- `envelope.py` closed error catalog already lists **`dirty_worktree`** (not yet emitted by any handler) — natural error type for the remove safety check; may need a new `active_agents` type (NOT in catalog → catalog + spec must grow).
- `local_read.py` provides `git_status/diff/log/branch` with the same `_validate_worktree` — `git_worktree_list` is a natural read sibling (idempotent, no `destructive_flow`).
- Registration of 3 new tools: add a `worktree_mutation.py` (or extend `local_mutation.py`) and wire into `register_all`; `git_worktree_add`/`list`/`remove`.
- Safety-check semantics for remove need definition: "uncommitted changes" (`git status --porcelain` + `git worktree` linked), "active agents" — no existing probe; must be defined in proposal (likely advisory: detect via a marker file / PID convention in the worktree).

### 3. Test harness (`tests/run_red_checks.sh`)
- T01-T22, exit 0 all-green/skips, 1 failures. ToC at lines 8-16.
- **T09** (line 149-158): real-mode network failure → currently asserts `exit 2` + "no se persiste nada" + no env file. **To re-spec: network now warns + continues** (no exit 2).
- **T20** (line 365-375): `--check` + API unreachable → asserts `exit 2` + "estado estructural". **To re-spec: degrade to warning (exit ≤1).**
- Helpers in `tests/helpers/`: `sandbox.sh` (init/add_bin/start_fake_api/api_dead_port for deterministic network failure/seed_env_file/set_seam_exit/run_setup/run_setup_pty/snapshot_tree), `fake_api.py`, `pty_run.py`. New tests: selector (pty toggle), network degrades, worktree tools slot into new `t` blocks; order/exit-0 logic is copy-extensible.

### 4. using-git-worktrees SKILL.md (vendored)
- Jesse Vincent/obra/superpowers, 178 lines. Steps: 0 detect isolation, 1a native tools, 1b git fallback (`.worktrees/`), 2 project setup, 3 baseline, quick-ref + rationalizations + provenance. Extension (6c) is additive: keep existing content, append the repo-native worktree lifecycle (location `<repo-parent>/<repo-name>-worktrees/<change-name>`, branch `sdd/<change>`, per-worktree `.codegraph/`, removal safety check). No rewrite.

### 5. mcp.d envelope contract
- mcp.d/README.md tables the contract: `runtime, target_mode, target, merge, root_key, server_key, presence, block, alt_docker` + deps (README doesn't list deps but code + envelopes use it). `selectors` is NOT part of the envelope contract — the RFC's F5 `selectors` field lives OUTSIDE the block (a top-level array of runtime names to configure, default TODOS). Confirmed: no existing `selectors` reference anywhere.

### 6. Constraints verified
- `bash -n setup.sh && sync-skills.sh` → OK; `python3 -c "import ast; ..."` all src files → OK (build check).
- Test seam `MCP_DEBUG_SYNC_ARGS` + `MCP_DEBUG_SYNC_ARGS_EXIT` used to simulate sync exit without running it.
- Bases de Alan never touched: changes are overlay strip+append (sync-skills.sh) + full-install of own skills (`skills/using-git-worktrees` is the vendored base but it's OUR copy; 6c goes in the vendored file directly, not an overlay of Alan).

## Affected Areas
- `setup.sh` — F5 degrades (308-310, 829-832) + selector (new step, after 5e/before 5f) + `selectors` in envelopes.
- `wiring/mcp.d/*.json` + `wiring/mcp.d/README.md` — add top-level `selectors` field (outside `block`).
- `srv/gh-mcp-server/src/tool_handlers/local_mutation.py` (or new worktree module) + `__init__.py` + `envelope.py` catalog — 3 worktree tools.
- `tests/run_red_checks.sh` — re-spec T09/T20, add selector/degrade/worktree tests.
- `skills/using-git-worktrees/SKILL.md` — additive 6c extension.
- `wiring/prompts/sdd/orchestrator.md` §5 — already documents the target lifecycle (source of truth for safety-check semantics).
- `openspec/specs/gh-git-mcp-server/spec.md` — new tools re-spec the closed-set behavior.

## Impact
- **T09 + T20 are the regression net**: they now assert the OLD fatal-on-network behavior. Re-speccing flips their expected exit codes — this is an intentional contract change, not a regression, but the tests gate on it.
- `envelope.py` closed error catalog: adding a new error type (active_agents) is additive but spec.md's closed-set list must be updated in lockstep (A12/typed-envelope contract).
- `destructive_flow` fail-closed semantics are unchanged — worktree remove reuses it; no risk to existing two-phase tools.
- Base de Alan (overlays) untouched — additive to our own vendored skill; `./sync-skills.sh --check` must stay zero (already verified).
- `selectors` outside `block` means setup.sh's merge loop must skip unselected runtimes WITHOUT changing the envelope shape the merge consumes.

## Approaches
1. **F5: guard-based degrade helper + selector step** — wrap the two network-fatal points in a single `degrade_or_fatal` that warns + records a flag instead of `exit 2`; add a new `5g selected runtimes` step reading `selectors` (default todos) after 5e. Pros: single code path, matches RFC. Cons: touches hot token-gate path; careful that 401 stays fatal (distinguish `network*` from `invalid*`).
2. **F6: new `worktree_mutation.py` + read in `local_read.py`** — `git_worktree_add`/`remove` via `destructive_flow` + `_validate_worktree`; `git_worktree_list` as read. Pros: mirrors existing pattern exactly, zero new machinery. Cons: needs error-catalog + spec additions.
3. **Selector: persist vs always-TODOS** — RFC already chose always-TODOS default; simplest, no state. Adopt as-is.

## Recommendation
Follow the RFC as written. F5: convert network-fatal to warning+continue only at the two real network points (308-310, 829-832), keep 401/invalid fatal (316-318, check `invalid*`) per RFC; add the selector as a new step consuming `selectors` (default all), non-interactive modes skip it. F6: add worktree tools mirroring `git_delete_branch`'s two-phase pattern, reusing `_validate_worktree` + `destructive_flow`, list as a read sibling. Reuse the existing `dirty_worktree` error type for the uncommitted-changes safety check; define "active agents" detection explicitly in proposal. Re-spec T09/T20 to the new degrade expectations and add new tests using the existing sandbox seams.

## Risks
- **High — RFC line-number drift**: cited lines (306-309/314-317/729-732/401/658-662/601/603-639/748-786) are stale vs the current 1019-line file; the third network-fatal is actually `--check` structural at 829-832, not "729-732". Proposal must re-pin every insertion point to current lines and re-validate T09/T20.
- **High — safety-check semantics for remove**: "active agents" has no existing probe anywhere in the repo. Must define (marker/pid/`git worktree list` linkedness) in proposal or removal safety is vacuous. Reuse `dirty_worktree` for uncommitted; add `active_agents` to the closed catalog + spec in lockstep.
- **Medium — 401-vs-network discrimination**: current `validate_token` returns `invalid <code>` vs `network` distinctly; F5 must preserve that 401 stays fatal while `network*` degrades. Test surface must prove both.
- **Medium — T09/T20 contract flip**: re-speccing them changes exit-code contract; any downstream reader of exit semantics must be updated (README/design exit table).
- **Low — envelope `selectors`**: not part of the merge envelope; setup.sh must skip unselected runtimes without disturbing `block`/`merge` logic or opencode.sdd.json (Lane B) — `--skip-opencode`/`--skip-mcp` interplay must remain intact.

## Ready for Proposal
**Yes.** All RFC assumptions validated against real code; the only blockers are (a) re-pinning stale line numbers and (b) defining the `active_agents` detection semantics for the removal safety check — both belong to the proposal, not a quest return.
