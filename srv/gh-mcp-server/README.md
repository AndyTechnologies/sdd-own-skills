# gh-git-mcp-server

Local FastMCP server exposing typed `gh_*`/`git_*` tools over the `gh` and `git` CLIs, so agents operate GitHub without shelling out via bash.

## Tool Surface

23 tools across 4 families:

| Family | Tools | Count |
|--------|-------|-------|
| Remote read | `gh_get_me`, `gh_get_repo`, `gh_list_repositories`, `gh_list_issues`, `gh_get_issue`, `gh_list_pull_requests`, `gh_get_pull_request`, `gh_get_pr_checks`, `gh_get_pr_diff`, `gh_list_commits`, `gh_list_workflow_runs`, `gh_get_workflow_run`, `gh_get_run_logs`, `gh_search_code` | 14 |
| Remote mutation | `gh_merge_pull_request`, `gh_delete_branch`, `gh_rerun_workflow` | 3 |
| Local read | `git_status`, `git_diff`, `git_log`, `git_branch` | 4 |
| Local mutation | `git_commit`, `git_delete_branch` | 2 |

`git_commit` accepts an optional `paths` list: when provided, only those
paths are staged and committed (dry-run and confirm both scoped); without
`paths` it stages all changes (`git add -A`), preserving the original behavior.

`gh_merge_pull_request` validates `method` against an allow-list
(`squash`/`merge`/`rebase`) and rejects anything else with `invalid_parameter`
before any API call.

## Safety Contract

- **Two-phase destructive ops**: merge PR, delete branch, re-run workflow, and local branch delete require dry-run → confirm with echo-back evidence.
- **Echo-back evidence**: the confirm call carries the dry-run's `data` dict verbatim; the server re-derives the effect, computes a SHA-256 fingerprint, and only executes on match.
- **Auth fail-closed**: every remote tool gates on `gh auth status --exit-code`; not authed → `auth_required`, nothing mutates.
- **Token-free**: the server process never sees, reads, or sets `GH_TOKEN`/`GITHUB_TOKEN`. Auth is delegated entirely to `gh`.
- **Explicit repo**: every tool takes an explicit `owner/repo` or `path` — never infers from cwd.

## Startup

```bash
uv run --directory <repo>/srv/gh-mcp-server python -m src.server
```
