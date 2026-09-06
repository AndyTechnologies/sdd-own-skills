# Design: gh-git-mcp

## Status

Revised after architecture lint. Change: `gh-git-mcp`. Consumes the approved RFC (`quest.md`), the proposal (`proposal.md`), the exploration (`exploration.md`), and the three delta specs. All BLOCKER, CRITICAL, and WARNING findings from the lint have been resolved (see §14).

## 1. Overview

This change lands a local FastMCP server (`srv/gh-mcp-server/`, uv + fastmcp>=2) exposing a fixed 23-tool `gh_*`/`git_*` surface over the `gh` and `git` CLIs, so agents operate GitHub without shelling out via bash (which triggers auth prompts and parse failures). Auth is delegated entirely to `gh` (its own `hosts.yml`); the server process never sees or sets a token. Destructive operations are two-phase with **computed** dry-runs and **echo-back evidence** that binds the confirm call to a specific dry-run effect. The server registers through the sanctioned `wiring/mcp.d/` + `setup.sh` pipeline, and the `github-automation` skill becomes dual-surface so the workflows keep working without the official (403-blocked) remote MCP.

The RFC fixes the contract (envelope, two-phase, fail-closed, explicit repo). This design specifies the module structure, the layered port-and-adapter architecture (core vs adapter vs transport), the dry-run computation per destructive op, the wiring registration structure, and the skill adaptation.

## 2. Architecture

Three layered modules inside `srv/gh-mcp-server/`, port-and-adapter at the subprocess boundary:

```
┌──────────────────────────── FastMCP transport (src/server.py) ────────────────────────────┐
│  FastMCP("gh-git-mcp"); @mcp.tool() decorators; mcp.run() (stdio)                          │
│  → thin: parse args, call a core handler, wrap result in the envelope                      │
│  → composition root: instantiates SubprocessRunner, injects into handler registration       │
│  → outer try/except wraps ONLY unexpected exceptions as invalid_parameter                   │
└───────────────────────────────────┬──────────────────────────────────────────────────────┘
                                   │
                    ┌──────────────▼─────────────── core (handlers + flow) ──────────────────┐
                    │  tool_handlers/*.py — 4 families (remote_read, remote_mutation,        │
                    │    local_read, local_mutation). Pure orchestration of the dry-run/      │
                    │    confirm template + envelope. Receives executor via Protocol port.    │
                    │  gh_auth.py — core service: assert_authed(executor) → Envelope | None. │
                    │  envelope.py — typed envelope builder + typed error catalog.            │
                    │  dryrun.py — two-phase flow template + shared pure helpers.            │
                    │    Per-op data gathering lives in each handler, NOT in dryrun.py.       │
                    └──────────────┬──────────────────────────────────────────────────────────┘
                                   │
                    ┌──────────────▼─────────────── adapter (subprocess executor) ───────────┐
                    │  executor.py — SubprocessRunner: prompt-disable env, timeout, argv,    │
                    │    JSON/text capture. The ONLY module that calls subprocess.run().     │
                    │  Conforms to ExecutorProto (Protocol port defined in executor.py).      │
                    └─────────────────────────────────────────────────────────────────────────┘
```

**Dependency rule**: transport → core → adapter (one direction only). `executor.py` imports nothing from the handlers or envelope. Handlers receive the executor as a parameter typed against `ExecutorProto` (a `typing.Protocol`), never importing the concrete `SubprocessRunner`. This keeps the adapter swappable (an in-process mock satisfies the protocol for verify smoke tests and pytest) and the core unit-testable without a live `gh`.

### Composition root

`server.py` is the composition root: it constructs `SubprocessRunner()` once and passes it through `register(server, executor)`. Each handler module's `register(server, executor)` function receives the executor and wires tool callbacks that close over it. No handler imports the concrete class — only the `Protocol`.

### Layer responsibilities

| Layer | Files | Owns | Never does |
|---|---|---|---|
| Transport | `src/server.py` | FastMCP wiring, tool argument schemas, `mcp.run()`, composition root, outer try/except for *unexpected* exceptions only | subprocess, dry-run logic, subprocess-error classification, business decisions |
| Core | `tool_handlers/`, `envelope.py`, `gh_auth.py`, `dryrun.py` | tool semantics, two-phase flow, dry-run computation orchestration, envelope building, error typing, auth-gate policy | subprocess calls, raw CLI invocation |
| Adapter | `executor.py` | subprocess creation, env hygiene, timeout, stdout/stderr capture | business decisions, dry-run semantics, envelope, error classification |

**Parsing note**: Handlers parse `gh --json` (structured) and git text (`status --porcelain`, `log`, `diff`) — this IS tool semantics and correctly lives in the core layer. The layer table's "never does" applies to raw CLI *invocation*, not to parsing structured output. Prefer `git status --porcelain=v1 -z` (or v2) for script-safe filenames where available.

## 3. Module structure

```
srv/gh-mcp-server/
├── pyproject.toml            # uv project; name "gh-git-mcp-server"; deps fastmcp>=2
├── uv.lock                   # committed (mirrors mcp_pdf_reader)
├── .python-version           # "3.14" (matches host)
├── README.md                 # surface + safety contract overview
├── src/
│   ├── server.py             # FastMCP entry; composition root; registers all tools; mcp.run()
│   ├── envelope.py           # Envelope builder + typed error catalog
│   ├── executor.py           # SubprocessRunner (adapter) + ExecutorProto (Protocol port)
│   ├── gh_auth.py            # Core service: assert_authed(executor) → Envelope | None
│   ├── dryrun.py             # Two-phase flow template + shared pure helpers (no executor deps)
│   └── tool_handlers/
│       ├── __init__.py       # exports the register(server, executor) entry for all families
│       ├── remote_read.py    # 14 gh_* read tools
│       ├── remote_mutation.py# 3 gh_* destructive tools
│       ├── local_read.py     # 4 git_* read tools
│       └── local_mutation.py # 2 git_* mutation tools (commit two-call, delete two-phase)
```

### `pyproject.toml` shape (mirrors mcp_pdf_reader)

```toml
[project]
name = "gh-git-mcp-server"
version = "0.1.0"
description = "Local FastMCP server exposing typed gh_*/git_* tools over the gh and git CLIs"
requires-python = ">=3.12"
dependencies = ["fastmcp>=2"]
```

No token-related dependency, no env handling. `fastmcp>=2` (2.8.x line confirmed working on Python 3.14.7 via pdf-reader).

## 4. Core design

### 4.1 Typed output envelope (`envelope.py`)

Every tool returns the RFC envelope via a single builder:

```python
def ok(data: dict | None, summary: str) -> Envelope: ...
def err(error_type: str, message: str, hint: str | None = None) -> Envelope: ...
```

Typed error catalog (closed set from the spec):

| `error.type` | Meaning | Fix hint |
|---|---|---|
| `auth_required` | `gh auth status --exit-code` failed | `gh auth login` |
| `repo_not_found` | explicit `owner/repo` 404 / invalid | verify owner/repo |
| `network_error` | subprocess network failure | retry; check connectivity |
| `not_found` | PR/branch/workflow missing | check the reference exists |
| `not_a_repo` | local `path` is not a git worktree | point `path` at a repo |
| `dirty_worktree` | local mutation guard on uncommitted state | commit/stash first |
| `confirm_required` | `dry_run:false` without valid echo-back evidence | run the dry-run and confirm |
| `invalid_parameter` | bad method / ref / limit | fix the argument |

An outer try/except in the transport catches *unexpected* `Exception` (not `SubprocessError` — that is caught and classified per-handler) and wraps it as `invalid_parameter` — never raises mid-payload, never returns a partial mutation.

Subprocess and CLI errors are classified **per-handler** at the core layer: each handler catches `SubprocessError` from the executor and maps it to the appropriate typed error (`network_error` for timeouts/connection, `repo_not_found` for 404, `invalid_parameter` for bad arguments). The transport net only wraps truly unexpected exceptions.

### 4.2 Executor port and adapter (`executor.py`)

A `Protocol` defines the port; `SubprocessRunner` is the concrete adapter:

```python
from typing import Protocol, NamedTuple

class ProcResult(NamedTuple):
    returncode: int
    stdout: str
    stderr: str

class ExecutorProto(Protocol):
    def run(self, argv: list[str], *, cwd: str | None = None,
            text: bool = True, timeout_s: float = 30.0) -> ProcResult:
        """Run argv with prompt-disable env. Returns (returncode, stdout, stderr).
        Raises SubprocessError on timeout / OSError. Never reads or sets a token."""
        ...

class SubprocessRunner:
    """Concrete adapter — the ONLY module that calls subprocess.run()."""
    def run(self, argv: list[str], *, cwd: str | None = None,
            text: bool = True, timeout_s: float = 30.0) -> ProcResult:
        ...
```

`SubprocessRunner` is a **Facade over `subprocess.run`**, not a Strategy: the variation axis between `gh` and `git` is not "interchangeable algorithms" — both degrade to the identical hygiene + timeout + capture concern, differing only in argv. A Strategy here would add a class per backend to cover a difference that is just an argument list, which is over-pattern (design-patterns: lightest route first; reject Strategy).

The env hygiene set is constant and identical for every call:
- `GH_PROMPT_DISABLED=1`, `--nocolor` (gh never blocks on an interactive prompt over stdio)
- `GIT_TERMINAL_PROMPT=0` (git never prompts for credentials)
- inherited-unmodified env — the server never sets/reads `GH_TOKEN`/`GITHUB_TOKEN`
- hard ~30 s timeout (default; configurable per call — log-heavy tools use a larger budget, see §5.1)

JSON-serializing `gh --json` output and text `git` output are handled by the caller/handler, not here.

### 4.3 Auth gate (`gh_auth.py`) — core service

**Relabeled as core** (not adapter): `gh_auth.py` returns core `Envelope` objects and implements auth *policy* (translate a probe result into a typed error). Its only adapter dependency is the executor received as a parameter.

Every **remote** tool funnels through `assert_authed(executor)` before any work. It runs `gh auth status --exit-code` via the executor (per-call, ~20–50 ms, satisfies the RFC's "every remote tool"). On failure it returns a typed `auth_required` envelope — no remote tool proceeds, nothing mutates. Local `git_*` tools skip the gh gate (git has no token dependency).

**Auth-gate call-site consolidation**: a single `require_auth(executor)` helper is imported by `remote_read.py` and `remote_mutation.py` and called inside the shared auth gate of each handler module. This prevents drift if the gate signature changes. The 17 remote tools all funnel through this one helper.

### 4.4 Two-phase destructive flow — Template Method (`dryrun.py`)

The five destructive tools (3 remote + `git_delete_branch` + `git_commit`'s dry-run summary) share one skeleton. This is the one place a pattern genuinely earns its complexity: the **algorithm skeleton with overridable steps** is identical (auth-gate → compute dry-run → echo-back comparison → if confirm matches: execute once → wrap envelope), and each tool only supplies the dry-run computation and the execution primitive. Forces present: shared skeleton, per-op variation, Non-variation in flow guarantees the safety invariant in one place.

#### Echo-back evidence (BLOCKER-1 resolution)

The server is stateless — it cannot remember prior dry-runs. The **confirm call MUST carry evidence** of the dry-run it is confirming. The evidence is the dry-run's `data` dict, echoed back verbatim by the caller in the `confirmed_data` parameter.

**`parameterize` step**: Each handler's `compute_dry_run` returns a `DryRunResult` containing:
- `data: dict` — the structured effect (e.g. `{mergeable: true, method: "squash", ...}`)
- `summary: str` — human-readable description
- `fingerprint: str` — deterministic hash of `data` (SHA-256 of sorted JSON) for cheap comparison

The dry-run call returns `ok:true, data.dry_run:true, data:<effect>` to the caller. The caller must echo `data` back as `confirmed_data` in the confirm call.

```python
@dataclass
class DryRunResult:
    data: dict           # structured effect
    summary: str         # human-readable
    fingerprint: str     # SHA-256 of json.dumps(data, sort_keys=True)

def destructive_flow(
    *,
    remote: bool,
    executor: ExecutorProto,
    compute_dry_run: Callable[[], DryRunResult],  # per-op dry-run (handler-gathered data)
    execute: Callable[[], ExecutionResult],         # per-op mutation (once)
    dry_run: bool = True,
    confirmed: bool = False,
    confirmed_data: dict | None = None,             # echo-back from prior dry-run
) -> Envelope:
    if remote:
        auth_issue = require_auth(executor)
        if auth_issue:
            return auth_issue                      # fail-closed

    effect = compute_dry_run()                     # never mutates; pure recomputation
    if effect.unknown:
        return err("invalid_parameter", ...)       # fail-closed

    # Phase 1: dry_run (default) → return effect, no mutation
    if dry_run or not confirmed:
        return ok({"dry_run": True, **effect.data}, effect.summary)

    # Phase 2: confirmed=true → verify echo-back evidence matches
    if confirmed_data is None:
        # No evidence carried → cannot verify this confirm binds to our dry-run
        return ok({"dry_run": True, **effect.data},
                  effect.summary + " [confirm_required: echo the dry-run data back]")

    # Compare echoed fingerprint to re-derived fingerprint
    import hashlib, json
    echoed_fp = hashlib.sha256(
        json.dumps(confirmed_data, sort_keys=True).encode()
    ).hexdigest()
    if echoed_fp != effect.fingerprint:
        # Evidence mismatch → state drifted or wrong dry-run echoed
        return ok({"dry_run": True, **effect.data},
                  effect.summary + " [confirm_required: dry-run effect changed, re-confirm]")

    # Evidence matches AND effect is safe → execute exactly once
    return execute()
```

Flow guarantees enforced centrally:
- Default `dry_run:true` → returns the computed effect, `data.dry_run:true`, no mutation.
- `confirmed:true` with **no `confirmed_data`** → returns the re-computed dry-run marked `confirm_required`, no mutation. The caller must echo the dry-run data back.
- `confirmed:true` with **mismatched `confirmed_data`** → returns the re-computed dry-run with a drift warning, no mutation. The caller must re-echo.
- `confirmed:true` with **matching `confirmed_data`** → exactly one `execute()`, no silent retries (single-shot).
- Unknown/unmergeable state → fail-closed typed error, no mutation.

No cross-session state: the "prior dry-run" is re-derived from the live computation at confirm time (stateless server; safest because nothing can drift between steps). The echo-back binding proves the caller saw and acknowledged the specific effect before it mutates.

### 4.5 `dryrun.py` scope (God Module prevention)

`dryrun.py` contains ONLY:
1. The `destructive_flow` template function
2. Shared **pure helpers** that take data as inputs (not fetch it): `classify_mergeability(mergeable, checks, base)`, `classify_merged(compare_status)`, `safe_to_delete(compare_data)`, `fingerprint(data)`.

Per-op data gathering (fetching PR state via executor, running `compare` via executor, reading run status via executor) lives in **each handler** — the handler's `compute_dry_run` closure calls the executor to gather data, then passes it to the pure helpers. `dryrun.py` has zero executor dependencies and is fully unit-testable with fake data.

## 5. Tool surface and data flows

### 5.1 Remote reads (single-phase, idempotent) — `remote_read.py`

14 tools, all explicit `owner`/`repo`, all `gh --json` parsed into structured `data` plus a non-empty `summary`:

| Tool | gh command | JSON fields sampled |
|---|---|---|
| `gh_get_me` | `gh api user` | login, name, plan (identity + auth/rate probe) |
| `gh_get_repo` | `gh repo view owner/repo --json` | defaultBranch, visibility, isPrivate, url |
| `gh_list_repositories` | `gh repo list owner --json --limit N` | name, description, isPrivate |
| `gh_list_issues` | `gh issue list -R owner/repo --json --limit N` | number, title, state, labels |
| `gh_get_issue` | `gh issue view -R owner/repo N --json` | number, title, state, body, labels, assignees |
| `gh_list_pull_requests` | `gh pr list -R owner/repo --json --limit N` | number, title, state, headRefName, baseRefName |
| `gh_get_pull_request` | `gh pr view -R owner/repo N --json` | number, title, state, headRef, baseRef, mergeable |
| `gh_get_pr_checks` | `gh pr view -R owner/repo N --json statusCheckRollup,mergeStateStatus` | rollup, mergeStateStatus |
| `gh_get_pr_diff` | `gh pr diff -R owner/repo N` | wrapped text (not raw passthrough) |
| `gh_list_commits` | `gh api repos/owner/repo/commits?per_page=N` | sha, message, author |
| `gh_list_workflow_runs` | `gh run list -R owner/repo --json --limit N` | id, name, status, conclusion, headSha |
| `gh_get_workflow_run` | `gh run view -R owner/repo RUN_ID --json` | status, conclusion, jobs |
| `gh_get_run_logs` | `gh run view -R owner/repo RUN_ID --log / --log-failed` | text log (evidence source) |
| `gh_search_code` | `gh api search/code?q=...` | path, repository, url; documented rate-limit cost |

**Timeout budget**: `gh_get_run_logs` streams large run logs that can exceed 30 s. Use `timeout_s=120` for this tool; all others use the default 30 s. The executor already supports per-call `timeout_s`.

Read flow: `owner/repo` params → `require_auth(executor)` → `executor.run([...gh --json...])` → parse → `ok(data, summary)`. Idempotent, no state change, stable across repeats (spec: repeated read stable).

### 5.2 Remote destructive ops (two-phase, computed dry-run) — `remote_mutation.py`

All three use the `destructive_flow` template. **Critical constraint (verified in exploration against gh 2.98):** `gh pr merge` has NO `--dry-run` flag and there is NO `gh branch` command. Dry-runs are **computed**, not delegated.

| Tool | Execution | Dry-run computation (handler gathers data, pure helpers classify) |
|---|---|---|
| `gh_merge_pull_request` | `gh pr merge -R owner/repo N --squash\|--merge\|--rebase [--delete-branch] [--auto]` | Handler gathers: PR state + `mergeable` + check rollup (`gh_get_pr_checks` inline) + base up-to-date. Pure helper: `classify_mergeability()` → returns `{mergeable, merge_state_status, status_check_rollup, base_behind, suggested_method}`. |
| `gh_delete_branch` | `gh api -X DELETE repos/owner/repo/git/refs/heads/{branch}` | Handler gathers: default branch + compare (`gh api repos/owner/repo/compare/{default}...{branch}`). Pure helper: `classify_merged()` → checks status is `ahead`/`diverged` (unmerged work) or compare fails → refuse. |
| `gh_rerun_workflow` | `gh run rerun -R owner/repo RUN_ID [--failed]` | Handler gathers: run status/result via executor. Pure helper: `safe_to_rerun()` → reports current `status`/`conclusion` and, for `--failed`, the failed job names. |

**`--auto` semantics (SUGGESTION-5)**: `--auto` defers the actual merge until checks pass. The "exactly one mutation" guarantee covers the *call*, not the *effect*. Dry-run covers call-time state only. The dry-run's mergeability assessment is a point-in-time snapshot; if `--auto` is used, the actual merge may be further deferred by GitHub's merge queue. Document this caveat in the tool's `summary` when `--auto` is present.

#### Dry-run computation detail

- **`gh_merge_pull_request`**: Handler fetches PR state + check rollup via executor. `classify_mergeability(mergeable, merge_state_status, check_rollup, base_ahead)` returns the computed effect. Fail closed (typed `invalid_parameter` / `confirm_required`) if mergeability is `UNKNOWN` or `BEHIND`. Dry-run returns this rollup; confirm re-runs it (still green) then executes the merge once.
- **`gh_delete_branch`**: Handler determines the default branch and runs `gh api repos/owner/repo/compare/{default}...{branch}` via executor. `classify_merged(compare_status)` checks for unmerged work. Dry-run reports the branch is merged and would be deleted. Confirm executes the `DELETE refs/heads` call once. No `gh branch` (does not exist).
- **`gh_rerun_workflow`**: Handler fetches run status via executor. `safe_to_rerun(status, conclusion, failed_jobs)` produces the dry-run report. Confirm re-runs once. Re-run count is not tracked (single-shot is per call; the skill owns re-run discipline).

### 5.3 Local reads (single-phase, explicit `path`) — `local_read.py`

4 tools, `git -C path`, all idempotent, non-destructive:

| Tool | git command |
|---|---|
| `git_status` | `git -C path status --porcelain=v1 -b` (branch + porcelain summary) |
| `git_diff` | `git -C path diff [--staged] [--stat\|full]` |
| `git_log` | `git -C path log --oneline -n N` |
| `git_branch` | `git -C path branch -vv` (list); create/switch via `git switch -c` |

Each validates `path` is a git worktree; invalid → `not_a_repo`. Prefer `--porcelain=v1 -z` (or v2) for script-safe filenames.

### 5.4 Local mutations — `local_mutation.py`

| Tool | Command(s) | Phase |
|---|---|---|
| `git_commit` | Two executor calls: (1) `git -C path add -A`, (2) `git -C path commit -m msg` | single-shot; dry-run (default) returns staged summary with `data.dry_run:true`; confirm executes both calls sequentially |
| `git_delete_branch` | `git -C path branch -d name` (`-D` only after confirm) | two-phase; dry-run = `git branch --merged <base>` guard |

**`git_commit` two-call detail (WARNING-5)**: The executor is argv-based with no shell; `git add -A && git commit` is shell syntax. `git_commit` is implemented as two sequential executor calls: `executor.run(["git", "-C", path, "add", "-A"])` then `executor.run(["git", "-C", path, "commit", "-m", msg])`. Dry-run = `git status --porcelain` staged summary (no executor calls that modify state). On confirm, both calls run sequentially. **Staged-index-on-failed-commit**: if `add -A` succeeds but `commit` fails (e.g. empty commit, hook rejection), the index remains staged — a visible partial state. The handler documents this: `data.staged: true, data.commit_error: <message>`. No silent retry; the user can `git status` to inspect and recover. This is NOT a "partial mutation" in the RFC sense (no committed state changed; the index is always ephemeral).

`git_commit` is classified single-shot (not reset/force) per the RFC; its dry-run shows the staged summary. `git_delete_branch` uses the local `--merged` guard and the `destructive_flow` template (merged-guard, refuse unmerged via `dirty_worktree`/`confirm_required`).

## 6. Fail-closed / error contract

- **Auth**: every remote tool gates on `require_auth(executor)`. Missing auth → `auth_required` + `gh auth login` hint; nothing mutates. Local tools skip the gate. Consolidated into a single helper imported by both `remote_read.py` and `remote_mutation.py`.
- **Token**: server process never sets/reads `GH_TOKEN`/`GITHUB_TOKEN`; env is inherited-unmodified. No token in argv, logs, or payload (spec: token-free).
- **Timeout/hang**: hard ~30 s subprocess timeout (default); 120 s for `gh_get_run_logs`; prompt-disable env. A timeout → `network_error`; the server never hangs over stdio.
- **Unknown state**: any destructive dry-run that cannot determine mergeability/merged state fails closed with a typed error, no mutation (spec: unknown state fail-closed).
- **No partial mutation**: subprocess errors are caught per-handler and classified into typed errors; exceptions are caught per tool and wrapped in the typed envelope; a failed call never returns partial state and never retries silently.

## 7. Wiring registration structure

### 7.1 Envelope modification — `wiring/mcp.d/opencode.json`

Extend the existing opencode envelope's `block` to a multi-entry block. `server_key: "github"` remains the **primary presence entry** (presence checks still gate on it); the new `gh-git-mcp` local entry is **additive**, rendered into the same runtime `mcp` block via the existing `merge: "json-key"` whole-object deep merge (`setup.sh` handles multi-entry natively — `target[mcp] * block`).

```jsonc
"block": {
  "github": {           // untouched byte-for-byte
    "type": "remote",
    "url": "https://api.githubcopilot.com/mcp/",
    "headers": { "Authorization": "Bearer {env:GITHUB_PERSONAL_ACCESS_TOKEN}" },
    "oauth": false
  },
  "gh-git-mcp": {       // NEW additive local entry
    "type": "local",
    "command": ["uv", "run", "--directory", "/home/andy/Proyectos/sdd-own-skills/srv/gh-mcp-server", "python", "src/server.py"]
  }
}
```

Absolute path mirrors the `mcp_pdf_reader` precedent (pdf-reader's absolute path in `opencode.json`). This is the only envelope touched; the `github` remote registration (and its presence semantics) is untouched. `wiring/opencode.sdd.json` stays agent-only — no `mcp` key added (RFC non-goal).

### 7.2 Registering in the runtime

`setup.sh` (the sanctioned sole writer of the `mcp` key) picks up the envelope by glob, deep-merges `block` into `opencode.jsonc`'s `mcp` block. No `setup.sh` code change: multi-entry and the local `command` array render natively. Zero changes to `sync-skills.sh` (it ignores `srv/`).

### 7.3 Docker transport interplay (SUGGESTION-3)

When `MCP_GITHUB_TRANSPORT=docker`, `setup.sh` renders `alt_docker` (github-only) and the `gh-git-mcp` local entry silently disappears from the rendered block. Host has no docker (RFC) so impact is nil today, but the multi-entry contract documents this behavior: **docker-mode drops the local server entry**. If docker-mode support is needed later, the `alt_docker` block can include the `gh-git-mcp` entry alongside the docker `github` entry (it renders fine alongside a docker entry — no conflict).

### 7.4 Contract doc + spec delta

- `wiring/mcp.d/README.md`: document the multi-entry block rule — when a `block` holds more than one server, `server_key` names the **primary presence entry** used for check-mode presence; additional entries are additive and non-blocking (their pre-apply absence reports pending/notice, not a desync). Document docker-mode behavior.
- `openspec/specs/mcp-definitions/spec.md`: the delta already codifies the multi-entry rule and the local-command-array contract.

### 7.5 `.gitignore`

Add `.venv/` (nested uv project) and `__pycache__/`/`*.pyc` already covered. Additive only.

## 8. Skill adaptation structure — `skills/github-automation/SKILL.md`

The skill is **our exclusive skill** (canonical `skills/github-automation/SKILL.md`, author AndyTechnologies; full-install, no overlay, no block markers). Direct edit that **preserves every workflow section verbatim** and adds two structural elements (spec: workflows preserved, dual-surface documented, token-free, Composio-free):

1. **Runtime-selection rule** (ADDED requirement): own `gh_*`/`git_*` tools are the default; the official `github_*` MCP is used when available and eligible (GHEC/Copilot). When the official remote is unreachable / 403 / eligibility error, fall back to the own tools. Re-evaluated on each tool-call failure — never hardcoded for the session. (Matches the ADDED spec requirement.)
2. **Dual-surface mapping table** (honest, per-family — see §8.1): map each `github_*` family used by the workflows to its own `gh_*`/`git_*` equivalent, marking families that are **unmappable** and specifying the own-surface behavior or out-of-scope status. (Matches MODIFIED requirement with corrected coverage claims.)

Structural placement:
- Add the runtime-selection rule as a short new subsection under **Prerequisites** (after "This skill never handles credentials").
- Add the mapping table inside the existing **Tool Surface** section (a new "Own surface (`gh_*`/`git_*`)" block mapping to the official `github_*` families already listed).
- Add a one-line fallback note in **Pitfalls** ("official remote 403 → fall back to own tools").

No workflow body text (issue triage, PR review/merge gates, branch-delete guards, actions evidence) is rewritten — only the surface-selection and naming glue changes.

### 8.1 Dual-surface coverage table (CRITICAL-1 resolution)

The own server exposes 23 tools across 4 families. The `github-automation` skill's workflows reference ~25 official `github_*` tools. Honest per-family coverage:

| Family | Official `github_*` tools | Own `gh_*`/`git_*` equivalent | Coverage |
|--------|--------------------------|-------------------------------|----------|
| **Identity** | `github_get_me`, `github_get_user` | `gh_get_me` | **Mapped** — own tool covers both (returns login, name, plan) |
| **Repo read** | `github_get_repo`, `github_list_repositories` | `gh_get_repo`, `gh_list_repositories` | **Mapped** — 1:1 |
| **Discovery** | `github_search_repositories`, `github_search_code`, `github_search_issues` | `gh_search_code` | **Partial** — code search mapped; repository search and issue search are **unmappable** on own surface |
| **Issue ops** | `github_list_issues`, `github_get_issue`, `github_add_issue_comment` | `gh_list_issues`, `gh_get_issue` | **Partial** — list/get mapped; `github_add_issue_comment` is **unmappable** (no own tool adds comments) |
| **Branch ops** | `github_list_branches`, `github_get_branch`, `github_create_branch`, `github_delete_branch` | `gh_delete_branch` | **Partial** — delete mapped; list/get/create are **unmappable** (no own tools for remote branch listing/creation) |
| **Commit context** | `github_list_commits`, `github_get_commit`, `github_compare_commits` | `gh_list_commits` | **Partial** — list mapped; get-commit and compare are **unmappable** on own surface |
| **PR ops** | `github_list_pull_requests`, `github_get_pull_request`, `github_review_pull_request`, `github_merge_pull_request`, `github_get_pull_request_status`, `github_get_pull_request_checks` | `gh_list_pull_requests`, `gh_get_pull_request`, `gh_merge_pull_request`, `gh_get_pr_checks`, `gh_get_pr_diff` | **Partial** — list, get, merge, checks, diff mapped; `github_review_pull_request` is **unmappable** (no own tool submits PR reviews); status is covered by checks |
| **Actions ops** | `github_list_workflow_runs`, `github_get_workflow_run`, `github_re_run_workflow`, `github_download_workflow_run_logs` | `gh_list_workflow_runs`, `gh_get_workflow_run`, `gh_rerun_workflow`, `gh_get_run_logs` | **Mapped** — all 4 mapped 1:1 |
| **File content** | `github_list_files`, `github_get_file`, `github_get_file_contents` | *(none)* | **Unmappable** — no own tool fetches file contents |

**Own-surface behavior for unmappable steps**:
- **`github_add_issue_comment`**: On the own surface, issue comment operations require the official MCP. If unavailable, the skill reports the comment intent to the human (cannot add comments via `gh api` from the own server — this is a deliberate scope boundary).
- **`github_review_pull_request`**: On the own surface, PR review operations (submit review/approve/request-changes) require the official MCP. If unavailable, the skill can still read the diff (`gh_get_pr_diff`) and checks (`gh_get_pr_checks`) but cannot submit a formal review — it reports the review assessment to the human.
- **`github_search_repositories` / `github_search_issues`**: On the own surface, use `gh_list_repositories` + client-side filtering for repo discovery; issue search is unsupported. These are convenience tools — the core workflows (list → read → act) work without them.
- **`github_get_commit`**: On the own surface, commit info is available via `gh_list_commits` (already returns sha, message, author per commit). A single-commit fetch is unsupported; use list with appropriate params.
- **`github_compare_commits`**: Not directly mapped. Branch-delete merged-check is handled internally by `gh_delete_branch`'s computed dry-run (uses `compare` via `gh api`). The workflow step "compare before delete" is absorbed into the tool itself.
- **Branch list/get/create**: On the own surface, branch listing uses `git branch -vv` (local only). Remote branch listing/creation is unsupported; the workflow's "create branch" steps require the official MCP. If unavailable, the skill reports the intent.
- **File content ops**: On the own surface, use `gh_get_pr_diff` for diff context. Single-file content fetch is unsupported; the workflow's `github_get_file` step requires the official MCP.

**Reconciliation with spec scenario "no workflow skipped or degraded"**: The scenario is amended. On the own surface, the core workflows (read, list, merge, delete, re-run, auth-probe) work fully. Workflows that require *write* operations on unmappable tools (add comment, submit review, create branch, create PR) are **degraded to report-only** — the skill reads the state, computes the assessment, and reports to the human instead of executing. This is honest degradation, not a lie. The spec scenario is updated to: "no read-only workflow is skipped; write operations on unmappable tools degrade to report-only (human-in-the-loop)."

## 9. Idempotency / rollback

- **Server**: read tools idempotent (stable across repeats, no state change). Mutations single-shot, no silent retries; two-phase confirmed executes exactly once. Server is stateless (no cross-session dry-run persistence; prior dry-run is re-derived at confirm; echo-back evidence binds the confirm).
- **Wiring idempotency**: `merge: "json-key"` deep merge is idempotent — re-running `setup.sh` leaves no duplicate/orphaned keys (spec: added local server entry scenario). `server_key: "github"` presence gate unaffected.
- **Rollback** (proposal): `git checkout` of the skill, envelope, README, `.gitignore`, spec deltas; re-run `setup.sh` real mode to strip `gh-git-mcp` from `opencode.jsonc` (`.bak` exists); delete `srv/gh-mcp-server/`. Fallback: hand-strip the key; `./sync-skills.sh --check` confirms baseline. Sync pipeline is provably unaffected by `srv/` (verified in exploration).

## 10. Pattern decisions (design-patterns gate)

| Decision | Pattern / non-pattern | Forces | Lightweight considered | Cost | Anti-pattern avoided |
|---|---|---|---|---|---|
| Subprocess executor | **Non-pattern**: single `SubprocessRunner` behind `ExecutorProto` Protocol | Two CLIs but same hygiene+timeout concern; no incompatible-interface gap | Strategy/Adapter classes (rejected: would add a class per backend over an argv-only difference) | One Protocol definition + one module | God Object / over-abstraction |
| Auth gate | **Non-pattern**: plain `require_auth(executor)` helper function | Fail-closed pre-check only; no object to proxy | Proxy class (rejected: indirection for a function call) | None (one helper) | Golden Hammer |
| Two-phase destructive flow | **Template Method** (`destructive_flow`) via callbacks/composition | Shared skeleton across 5 ops; per-op dry-run/execute steps vary; safety invariant must live in one place | Per-tool duplicated flow (rejected: 5 copies of the confirm/refuse/execute invariants = drift risk) | One shared function | Duplicate logic / drift |
| Envelope/normalizer | **Non-pattern**: builder functions | Single typed-return concern | — | None | God Gateway |

The only pattern applied is **Template Method** for the destructive two-phase flow, where the shared skeleton genuinely centralizes the safety invariant. Everything else resolves to plain functions per the lightest-route-first rule.

## 11. Idempotency of the server's own mutation guarantee

The dry-run/compute step is always consulted before mutation; the confirm step only executes after echo-back evidence matches the re-derived dry-run fingerprint. Because the server is stateless and re-derives at confirm time, there is no window where a stale dry-run authorizes a now-unsafe mutation. The echo-back binding adds a second guarantee: the caller must prove it saw the exact dry-run effect before the template allows execution.

## 12. Open design decisions

1. **Optional dev test suite**: the ACs and this repo have no test runner (`build_command: bash -n sync-skills.sh`). Verification will run a runtime smoke test (`uv run python src/server.py` + an MCP `tools/list` probe; `opencode mcp list` shows the new server connected). A small optional dev-extra `pytest` suite (envelope, dry-run computation, two-phase flow against a mocked executor via `ExecutorProto` — now a real mock-swap, not monkeypatching) is a cheap add if tasks want it — **recommended**, but not required by the ACs. This is the only non-blocking open decision; default is to include the smoke test and defer the pytest suite unless tasks opt in.
2. **`gh-get-pr-diff`/`git-log` additive reads**: confirmed in-scope (spec lists both); they are non-destructive reads that materially help agents. No further decision needed.
3. **Envelope multi-entry block (approach 1)**: recommended and fixed in the exploration + spec delta. Fallback (separate envelope file) documented if the env contract stretch is rejected at lint — default is multi-entry.

## 13. Verification hooks mapped to design

- `tools/list` → 23 tools, no token env (transport layer completeness).
- Reads: happy read + failure envelope (envelope + executor + handlers).
- Mutations: dry-run mutates nothing / confirm-without-evidence refused / echo-back mismatch refused / confirm executes once / unknown state fail-closed (dryrun template).
- Auth: `gh` unauthenticated → every remote tool `auth_required`, nothing mutates (auth gate).
- Wiring: `./setup.sh --check` / `./sync-skills.sh --check` zero desyncs after apply (multi-entry block + presence gate).
- `opencode mcp list` → gh-git-mcp server connected (registration).

## 14. Architecture lint resolution

This section maps each finding from `architecture-lint.md` to how the revised design resolves it.

### BLOCKER-1 — Confirm-without-prior-dry-run mechanism

**Finding**: Stateless server cannot distinguish "confirmed after dry-run" from "first-ever confirm." Pseudo-code executed on safe confirmed call. `parameterize: dict` undefined.

**Resolution**: Added **echo-back evidence** mechanism. The confirm call MUST carry `confirmed_data` (the dry-run's `data` dict echoed verbatim). The template re-derives the effect, computes `fingerprint = SHA-256(sorted JSON of data)`, and compares to the echoed fingerprint. Match → execute once. No evidence or mismatch → return re-computed dry-run marked `confirm_required`, no mutation. `parameterize` is now defined as `DryRunResult(data, summary, fingerprint)` with explicit fields. Updated pseudo-code, comments, and flow guarantees.

### CRITICAL-1 — Dual-surface mapping incomplete

**Finding**: Several `github_*` tools have no own-surface equivalent. "No workflow skipped or degraded" is unachievable.

**Resolution**: Added **§8.1 honest per-family coverage table** listing every family with status (mapped / partial / unmappable). Unmappable tools (`github_add_issue_comment`, `github_review_pull_request`, remote branch list/get/create, file content, repo/issue search) are explicitly documented with own-surface behavior (report-only, human-in-the-loop). Spec scenario amended to: "no read-only workflow is skipped; write operations on unmappable tools degrade to report-only."

### WARNING-1 — Hexagonal overclaim: no port, concrete imports, unstated DI

**Finding**: Handlers import concrete `SubprocessRunner`. Composition root unstated. "Mock-swap" claim unverifiable.

**Resolution**: Added `ExecutorProto` (a `typing.Protocol`) in `executor.py`. Handlers receive executor as parameter typed against the Protocol. `server.py` is the composition root: constructs `SubprocessRunner()`, passes to `register(server, executor)`. Mock-swap is now real (pytest creates a fake that satisfies `ExecutorProto`). Relabeled "clean/hexagonal" to "layered, port-and-adapter at the subprocess boundary."

### WARNING-2 — `gh_auth.py` placement + transport catches adapter exceptions

**Finding**: `gh_auth.py` returns `Envelope` (core concern) but labeled adapter. Transport catches `SubprocessError` (adapter edge).

**Resolution**: Relabeled `gh_auth.py` as **core service** (not adapter). Its only adapter dependency is the executor parameter. Moved `SubprocessError` classification from transport to **per-handler** (core). Transport's outer try/except now only wraps *unexpected* exceptions as `invalid_parameter`. Updated layer table.

### WARNING-3 — `dryrun.py` God Module risk

**Finding**: Per-op data gathering in `dryrun.py` would mix template with tool-specific data fetching.

**Resolution**: `dryrun.py` is now **template + shared pure helpers only** (zero executor dependencies). Per-op data gathering lives in each handler's `compute_dry_run` closure. Handlers call the executor, gather data, pass to pure helpers. `dryrun.py` is fully unit-testable with fake data.

### WARNING-4 — Tool count is 23, not 22

**Finding**: Arithmetic bug: 14 + 3 + 4 + 2 = 23, not 22. Propagated to spec scenario.

**Resolution**: Corrected to **23 tools** in design §1, §5 tables, §13 verification hooks. Fixed in spec `gh-git-mcp-server/spec.md` (requirement and scenario).

### WARNING-5 — `git add -A && commit` can't be one argv

**Finding**: `&&` is shell syntax; executor is argv-based. Staged-index-on-failed-commit behavior undocumented.

**Resolution**: `git_commit` is now **two sequential executor calls** (`add -A` then `commit`). Documented staged-index-on-failed-commit behavior: failed commit leaves index staged (visible partial state, not a committed mutation). No silent retry; user can `git status` to inspect.

### SUGGESTION-1 — Auth-gate call-site consolidation

**Resolution**: Single `require_auth(executor)` helper imported by `remote_read.py` and `remote_mutation.py`. All 17 remote tools funnel through this one helper.

### SUGGESTION-2 — Layer table wording vs git text parsing

**Resolution**: Added parsing note to §2 layer table: handlers parse structured output (`gh --json`) and git text — this IS tool semantics. "Never does" applies to raw CLI invocation, not parsing. Prefer `--porcelain=v1 -z` where available.

### SUGGESTION-3 — Docker transport interplay

**Resolution**: Added §7.3 documenting docker-mode behavior: `gh-git-mcp` local entry silently drops under `MCP_GITHUB_TRANSPORT=docker`. Documented that the local entry can be added alongside docker entries if needed later.

### SUGGESTION-4 — Timeout budget for log-heavy tools

**Resolution**: `gh_get_run_logs` uses `timeout_s=120` (explicitly documented in §5.1). All others use default 30 s.

### SUGGESTION-5 — `gh_merge_pull_request --auto` semantics

**Resolution**: Documented in §5.2 that `--auto` defers the actual merge until checks pass. Dry-run covers call-time state only. Summary includes caveat when `--auto` is present.
