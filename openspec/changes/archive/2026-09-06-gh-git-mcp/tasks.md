# Tasks: gh-git-mcp — Local FastMCP Server for gh/git Operations

## Review Workload Forecast

| Field | Value |
|-------|-------|
| Estimated changed lines | 1,400–1,700 (additions + deletions) |
| 400-line budget risk | High |
| Chained PRs recommended | No (delivery_strategy: single-pr) |
| Suggested split | N/A (single-pr by mandate) |
| Delivery strategy | single-pr |
| Chain strategy | size-exception |

Decision needed before apply: Yes
Chained PRs recommended: No
Chain strategy: size-exception
400-line budget risk: High

**Budget exception required**: Estimated 1,400–1,700 changed lines against 800-line budget. The change creates a new Python server (~1,200 LOC across 13 files in `srv/gh-mcp-server/`) plus wiring/skill/gitignore modifications (~200–400 LOC). This is a greenfield server with 23 tools across 4 handler families — splitting into chained PRs would break the atomic safety invariant (envelope + dry-run + handlers + wiring must land together for the server to function). A `size:exception` approval is needed before `sdd-apply` proceeds.

### Suggested Work Units

| Unit | Goal | Likely PR | Focused test command | Runtime harness | Rollback boundary |
|------|------|-----------|----------------------|-----------------|-------------------|
| 1 | Foundation + core + server scaffold | PR 1 | `uv run --directory srv/gh-mcp-server python src/server.py` (starts without error) | `uv run` start probe; no live gh needed for scaffold validation | `srv/gh-mcp-server/` directory, `.gitignore` lines |
| 2 | Handler families (23 tools) | PR 1 | `uv run --directory srv/gh-mcp-server python src/server.py` + MCP tools/list → 23 tools | `tools/list` probe after compose root wires handlers; live gh auth probe for remote tools | `src/tool_handlers/*.py` files |
| 3 | Wiring + skill adaptation | PR 1 | `./setup.sh --check && ./sync-skills.sh --check` → zero desyncs | `opencode mcp list` shows gh-git-mcp connected | `wiring/mcp.d/opencode.json`, `skills/github-automation/SKILL.md`, `.gitignore` |

## Phase 1: Foundation — Scaffold + Core Types

- [ ] 1.1 Create `srv/gh-mcp-server/pyproject.toml` with `[project]` name `gh-git-mcp-server`, `version = "0.1.0"`, `requires-python = ">=3.12"`, `dependencies = ["fastmcp>=2"]`; create `.python-version` with `3.14`
- [ ] 1.2 Create `srv/gh-mcp-server/README.md` — surface overview (23 tools, 4 families), safety contract (two-phase, echo-back, token-free), startup command
- [ ] 1.3 Create `srv/gh-mcp-server/src/envelope.py` — `Envelope` type alias (TypedDict), `ok(data, summary)` builder, `err(error_type, message, hint)` builder, typed error catalog (8 error types from spec §4.1)
- [ ] 1.4 Create `srv/gh-mcp-server/src/executor.py` — `ProcResult(NamedTuple)`, `ExecutorProto(Protocol)` with `run(argv, *, cwd, text, timeout_s)`, `SubprocessRunner` concrete adapter: prompt-disable env (`GH_PROMPT_DISABLED=1`, `GIT_TERMINAL_PROMPT=0`, `--nocolor`), inherited env, hard timeout, `SubprocessError` on timeout/OSError
- [ ] 1.5 Add `.venv/` to root `.gitignore` (additive, after existing `__pycache__/`/`*.pyc`)

## Phase 2: Core — Auth Gate + Dry-Run Template + Handler Families

- [ ] 2.1 Create `srv/gh-mcp-server/src/gh_auth.py` — `require_auth(executor: ExecutorProto) -> Envelope | None`: runs `gh auth status --exit-code`, returns `auth_required` envelope on failure, `None` on success
- [ ] 2.2 Create `srv/gh-mcp-server/src/dryrun.py` — `DryRunResult(data, summary, fingerprint)` dataclass, `fingerprint(data)` pure helper (SHA-256 sorted JSON), `classify_mergeability()`, `classify_merged()`, `safe_to_delete()` pure helpers, `destructive_flow()` Template Method with echo-back evidence comparison (§4.4–4.5)
- [ ] 2.3 Create `srv/gh-mcp-server/src/tool_handlers/__init__.py` — exports `register_all(server, executor)` entry that delegates to each family's `register()`
- [ ] 2.4 Create `srv/gh-mcp-server/src/tool_handlers/remote_read.py` — 14 `gh_*` read tools: `require_auth` gate, `executor.run()` with `gh --json`, parse structured output into `ok(data, summary)`. Timeout: 30s default, 120s for `gh_get_run_logs`
- [ ] 2.5 Create `srv/gh-mcp-server/src/tool_handlers/remote_mutation.py` — 3 tools via `destructive_flow`: `gh_merge_pull_request` (handler gathers PR state + checks, `classify_mergeability()`), `gh_delete_branch` (handler runs compare, `classify_merged()`), `gh_rerun_workflow` (handler gathers run status, `safe_to_rerun()`)
- [ ] 2.6 Create `srv/gh-mcp-server/src/tool_handlers/local_read.py` — 4 `git_*` read tools: validate path is worktree (`not_a_repo` on fail), `executor.run()` with `git -C path ...`, prefer `--porcelain=v1 -b` for status
- [ ] 2.7 Create `srv/gh-mcp-server/src/tool_handlers/local_mutation.py` — 2 tools: `git_commit` (dry-run = staged summary; confirm = two sequential executor calls: `add -A` then `commit -m`; documents staged-index-on-failed-commit), `git_delete_branch` (two-phase via `destructive_flow`, `--merged` guard)

## Phase 3: Transport — Composition Root

- [ ] 3.1 Create `srv/gh-mcp-server/src/server.py` — FastMCP composition root: construct `SubprocessRunner()`, call `register_all(mcp, executor)`, `mcp.run()` via stdio. Outer try/except wrapping unexpected `Exception` as `invalid_parameter`. No token env, no import of concrete runner in handlers
- [ ] 3.2 Run `uv sync` in `srv/gh-mcp-server/` to generate `uv.lock`; verify `uv run python src/server.py` starts without error

## Phase 4: Wiring + Skill Adaptation

- [ ] 4.1 Update `wiring/mcp.d/opencode.json` — add `"gh-git-mcp"` entry to `block`: `{"type": "local", "command": ["uv", "run", "--directory", "/home/andy/Proyectos/sdd-own-skills/srv/gh-mcp-server", "python", "src/server.py"]}`; preserve `github` entry byte-for-byte
- [ ] 4.2 Update `wiring/mcp.d/README.md` — document multi-entry block contract: `server_key` = primary presence entry; additional entries additive, non-blocking; docker-mode drops local entry
- [ ] 4.3 Update `skills/github-automation/SKILL.md` — add runtime-selection rule subsection under Prerequisites; add dual-surface mapping table (own `gh_*`/`git_*` ↔ official `github_*`, per-family coverage from §8.1); add fallback note in Pitfalls; preserve all workflow sections verbatim
- [ ] 4.4 Verify `./setup.sh --check` and `./sync-skills.sh --check` report zero desyncs

## Phase 5: Verify Smoke-Test Hooks

- [ ] 5.1 Runtime probe: `uv run --directory srv/gh-mcp-server python src/server.py` + MCP `tools/list` → 23 `gh_*`/`git_*` tools listed, no token env var in process
- [ ] 5.2 Destructive dry-run+echo-back: call `gh_merge_pull_request` with `dry_run:true` → returns `data.dry_run:true`, no mutation; call with `confirmed:true, confirmed_data:<echo>` → executes once; call with `confirmed:true, confirmed_data:<wrong>` → refused with drift
- [ ] 5.3 Auth fail-closed: with `gh` logged out, every remote tool returns `auth_required`, nothing mutates
- [ ] 5.4 Wire check: `opencode mcp list` shows `gh-git-mcp` server connected; `./setup.sh --check` + `./sync-skills.sh --check` → zero desyncs
