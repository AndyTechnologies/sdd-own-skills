# gh-git-mcp-server

Local FastMCP server exposing typed `gh_*`/`git_*` tools over the `gh` and `git` CLIs, so agents operate GitHub without shelling out via bash.

## Tool Surface

The tool surface is NOT enumerated here. The single machine-readable source of
truth is [`tools.json`](tools.json): 29 tools in 5 families, grouped by family.
The per-family lists are the source of the counts — nothing writes a total by
hand, so the list cannot drift away from its own arithmetic.

This README previously carried its own table and its own count, which had gone
stale (it claimed 23 tools in 4 families while the server registered 29 in 5).
Duplicating the inventory in prose is how that happened, so the prose now points
at the file instead of restating it. Check T67 of `tests/run_red_checks.sh`
requires set equality between the `@server.tool()` registrations in
`src/tool_handlers/` and `tools.json`, in both directions, and requires every
tool to be named in the spec requirement.

Note that `git_delete_branch` (local) and `gh_delete_branch` (remote) are
different tools in different families.

`git_commit` accepts an optional `paths` list: when provided, only those
paths are staged and committed (dry-run and confirm both scoped); without
`paths` it stages all changes (`git add -A`), preserving the original behavior.

`gh_merge_pull_request` validates `method` against an allow-list
(`squash`/`merge`/`rebase`) and rejects anything else with `invalid_parameter`
before any API call.

## Safety Contract

- **Two-phase destructive ops**: merge PR, delete branch, re-run workflow, and local branch delete require dry-run → confirm with echo-back evidence.
- **Echo-back evidence**: the confirm call carries the dry-run's `data` dict verbatim; the server re-derives the effect, computes a SHA-256 fingerprint, and only executes on match.
- **Auth fail-closed**: every remote tool gates on `gh auth status --json hosts` (the `--exit-code` flag was removed in gh >= 2.98; the `active` field is the authoritative signal); not authed → `auth_required`, nothing mutates.
- **Token-free**: the server process never sees, reads, or sets `GH_TOKEN`/`GITHUB_TOKEN`. Auth is delegated entirely to `gh`.
- **Explicit repo**: every tool takes an explicit `owner/repo` or `path` — never infers from cwd.

## Startup

```bash
uv run --directory <repo>/srv/gh-mcp-server python -m src.server
```

## Tests

```bash
uv run --directory <repo>/srv/gh-mcp-server pytest
```

The pytest suite is also run automatically by the repo's RED suite (check **T69**), so
a broken test here cannot reach a green run unnoticed. If `uv` is absent from the
environment, that check reports `SKIP` rather than failing — a missing optional tool
must not paint the suite red on a machine that never intended to run it.

