# CodeGraph Guidance

CodeGraph is the preferred structural/intelligence surface for codebase questions (architecture, call flow, dependencies, symbol references, impact analysis, "how does X work"). A project has an index when `<project-root>/.codegraph/` exists.

## Required order for structural/codebase questions

1. Resolve the project root with `git rev-parse --show-toplevel || pwd`.
2. Confirm the root is a real project/workspace. Do not initialize CodeGraph in `$HOME`, temporary directories, or non-project folders.
3. Check for `<project-root>/.codegraph/` before any broad Read/Glob/Grep filesystem exploration.
4. If `.codegraph/` is missing and CodeGraph is enabled/available, initialize it once with `gentle-ai codegraph init --cwd <project-root>`. A missing `.codegraph/` is the trigger to initialize, not a reason to skip CodeGraph.
5. Query with `codegraph_explore` (MCP) when available; otherwise use the read-only upstream CLI: `codegraph status`, `codegraph query`, `codegraph explore`, `codegraph node`, `codegraph files`, `codegraph callers`, `codegraph callees`, `codegraph impact`, `codegraph affected`.
6. After edits, rely on watcher auto-sync by default. Run `codegraph sync` only when the watcher is disabled or CodeGraph reports stale files that do not refresh normally.
7. Fall back to normal filesystem tools only after CodeGraph initialization or use fails, and briefly explain the fallback.

## Hard boundaries

- Never use `gentle-ai codegraph` as a general proxy: only its `init` command exists to validate the project root before initialization. Intelligence queries belong to the upstream `codegraph` CLI.
- Never run or recommend destructive or administrative lifecycle commands: `codegraph uninit`, `codegraph install`, `codegraph uninstall`, `codegraph upgrade`. Reserve `codegraph index` for explicit index-corruption recovery, never routine use.
- Create Git worktrees that may need CodeGraph under the user's home directory, preferably as a sibling such as `<repo-parent>/<repo-name>-worktrees/<worktree-name>`. Never place a CodeGraph-dependent worktree under `/tmp`, `/var/tmp`, or `/tmp/opencode`.
- Every worktree needs its own `.codegraph/` index. Never copy, symlink, or reuse another checkout's index; its root and checked-out bytes may differ.
- Phases that only consume the index (explore, apply) must never initialize or mutate CodeGraph state. Initialization and freshness are `sdd-init`'s responsibility.