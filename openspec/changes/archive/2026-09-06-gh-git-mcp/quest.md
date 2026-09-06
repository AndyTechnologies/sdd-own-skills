# Quest: gh-git-mcp

## Approval: approved

## RFC

### Goals / Non-goals

**Goals**
- Build a self-hosted local MCP server that exposes typed, semantic tool names over `gh` (GitHub remote) and `git` (local repo) operations, so agents interact with GitHub without invoking bash commands (which trigger repeated authorization prompts and are prone to logic/parse failures).
- Scope is COMPLETE: repo/issues/PRs/checks/CI log reads PLUS mutations: merge pull requests, delete branches, re-run CI workflows.
- Cover BOTH GitHub remote operations (`gh`) AND local git operations on the repository the agent operates on (status, diff, branch, commit).
- Delegate authentication entirely to `gh` (which reads its own secret store). The MCP server process NEVER sees, reads, or handles the GitHub token.
- Adapt the existing `github-automation` skill to drive this own MCP (its `github_*` tool names map to our new `gh_*`/`git_*` tool names) so the skill stays useful without the official remote MCP.
- Register the server in the runtime via the repo's `wiring/mcp.d/` + `setup.sh` pipeline (the sanctioned writer of the `mcp` key), as a `type: local` server launched with `uv run`, mirroring the `mcp_pdf_reader` deployment pattern.

**Non-goals**
- NOT replacing the official GitHub remote MCP for accounts that have GHEC/Copilot eligibility. That path stays intact for eligible accounts.
- NOT handling tokens inside the MCP (no bearer header, no `GITHUB_PERSONAL_ACCESS_TOKEN` read by the server).
- NOT adding new `mcp` keys into the SDD wiring fragment (`wiring/opencode.sdd.json` stays agent-only).
- NOT rewriting the git worktree / PR-creation / chained-PR / issue-creation skills; those keep their orchestration roles. This MCP supplies the primitive operations.

### Domain Terminology & Business Rules

- **MCP server**: FastMCP (Python) over stdio, launched by the runtime as `type: local` via `uv run --directory <path> python <src>/server.py`.
- **`gh`**: GitHub CLI, already authenticated as `AndyTechnologies` on this host; owns token handling. Server shells out to it.
- **`git`**: local VCS; server runs `git` in the repository working directory of the agent (passed via explicit repo parameter).
- **Repo target**: EXPLICIT per call (`--repo owner/name` argument on every remote call; `--path <repo>` for local git calls). The server does not depend on process cwd for repo resolution.
- **Tool naming**: `gh_*` for remote ops, `git_*` for local ops. Destructive tools carry a `dry_run`/confirm flow.
- **Output contract**: every tool returns structured JSON + a short human-readable summary string, so the model consumes a typed result without parsing raw command text.

**Business rules (safety)**
- Destructive operations (merge PR, delete branch, re-run CI, destructive local git e.g. reset/force operations) follow **dry-run first + explicit confirm**: the first call returns the would-be effect (dry-run); a second call with `confirmed: true` executes. The model cannot break something by accident in a single step.
- The server MUST fail closed on auth failure: if `gh` is not authenticated, every remote tool returns a clear, typed error naming the fix (`gh auth login`), never a partial mutation.
- No token value ever enters tool input, logs, argv, or returned payloads.

### Contracts (Inputs / Outputs / Events / External)

**Inputs**
- Remote tools: `owner`, `repo` (explicit), plus operation-specific args (PR number, branch, workflow, etc.).
- Local tools: `path` (repo working dir), plus operation-specific args.
- Destructive tools: `dry_run` (default true) and `confirmed` (false → error saying a dry-run must be confirmed).

**Outputs/Events**
- Every tool returns `{ "ok": bool, "data": <structured json>, "summary": "<short string>", "error": null | "<typed error>" }`.
- Dry-run calls return the computed effect with `"ok": true` and `"data.dry_run": true`, no mutation.

**External**
- `gh` CLI subprocess (remote).
- `git` CLI subprocess (local).
- Runtime registration via `wiring/mcp.d/` + `setup.sh`.

### Invariants & Validation

- The MCP server process NEVER receives the GitHub token: no env var read, no bearer, no secret in config. `gh` owns all auth.
- Repo target is always explicit; no implicit cwd-based repo guess on the server side.
- Destructive ops are two-phase (dry-run → confirm); a confirmed call without a prior dry-run result MUST refuse or re-run the dry-run.
- Output JSON is stable/schema-typed so the model never parses raw text.
- The server is idempotent for read tools; mutations are explicit, single-shot, with no silent retries.

### Failure Cases & Edge Cases

- `gh` not authenticated → typed `auth_required` error on every remote tool; no partial work.
- Repo parameter invalid / network error → typed `repo_not_found` / `network_error`; nothing persisted.
- Both `dry_run` and `confirmed=true` semantics: confirmed without dry-run step → server dry-runs internally and returns effect + requires a follow-up confirm, never an accidental mutation.
- Non-existent PR/branch/workflow → typed `not_found`; empty result, no crash.
- Local git in a dirty or non-repo path → typed `not_a_repo` / `dirty_worktree` error.

### Security / Privacy / Performance / Operational

- Token secrecy: delegated to `gh`; the server holds no secret.
- Destructive capability gated by two-phase confirm; high enough to be deliberate but safe.
- Performance: every `gh`/`git` call is a subprocess; batch reads are minimized (prefer single answers); document rate-limit friendliness of read tools.
- Operational: `setup.sh` registers the local server; `sync-skills.sh --check`/`./setup.sh --check` must report zero desyncs after structural changes; server fails closed on missing auth.

### Alternatives & Trade-offs

- **Official remote MCP** (rejected for this account): requires GHEC/Copilot eligibility (`plan: None` → 403). Kept as the path for eligible accounts.
- **Local GitHub MCP server via Docker** (rejected): Docker not installed on this host; also heavier than a purpose-built FastMCP server over `gh`.
- **Pure skill invoking bash** (rejected by user): agents running `gh`/`git` by bash causes repeated authorization prompts and logic/parse failures — the exact problem this change solves.
- **Raw JSON passthrough of `gh --json`** (rejected): model still parses; we wrap in typed JSON + summary.

### Acceptance Criteria (measurable)

- `uv run --directory <server> python <src>/server.py` starts and responds to MCP `tools/list` exposing the full `gh_*`/`git_*` surface WITHOUT any token env var present (auth delegated to `gh`).
- Every remote read tool, when `gh` is authenticated, returns the typed envelope with correct `data` and a non-empty `summary`, given an explicit `owner/repo`.
- Every destructive tool: calling with `dry_run=true` (default) returns the effect and mutates nothing (`ok` with `data.dry_run=true`); executing without confirm is refused; confirm+execute performs exactly one mutation.
- `gh` not authenticated → all remote tools return a typed `auth_required` error; nothing mutates.
- The adapted `github-automation` skill drives the own tools (documents the `gh_*`/`git_*` surface) and remains usable with the official MCP for eligible accounts (dual-surface documented).
- `./setup.sh --check` and `./sync-skills.sh --check` report zero desyncs after the change lands.

### Unresolved Questions (blocking)

None — the mandate is complete. Stack (Python + FastMCP + uv, mirroring `mcp_pdf_reader`) is a confirmed implementation requirement chosen to reuse existing conventions; the RFC keeps behavior/contract language primary.
