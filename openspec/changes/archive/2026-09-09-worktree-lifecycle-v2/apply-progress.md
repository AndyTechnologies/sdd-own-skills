# Apply Progress — worktree-lifecycle-v2

**Change**: worktree-lifecycle-v2
**Mode**: Standard (no test runner pre-existed; pytest 9.1.1 introduced as dev dependency — see testing-capabilities note below)
**Delivery**: single PR, `size:exception` (approved in orchestrator dispatch; batch is the whole 27-task change)
**Status**: 31/31 tasks complete — ready for verify

## Work Unit Evidence

| Work unit | Focused test command + exact result | Runtime harness / scenario | Rollback boundary |
|---|---|---|---|
| WU1 — shared layer + tests (tasks 1.x, 2.x) | `srv/gh-mcp-server/.venv/bin/pytest srv/gh-mcp-server/tests/test_worktree_state.py -q` → **44 passed in 0.2-0.5s** (covers all 9 classifier rows, acquire/release transitions, index, dirty, repo-name, concurrency, enriched list) | Mock-executor harness (FakeExecutor) inside pytest; real-git repos for `derive_repo_name`/`canonical_worktree_path` | `srv/gh-mcp-server/src/worktree_state.py` + `tests/` are new files — deletable; `pyproject.toml` dev group + `uv.lock` revertible; no pre-existing file touched |
| WU2 — MCP handlers (tasks 3.x) | Same pytest run **after** Phase 3 → **44 passed** + `python -c "import src.tool_handlers.worktree_mutation/local_read"` → modules import clean (auto-registration via `register_all` intact) | MCP server runtime not launched (no live sidecar in this environment); tool wiring verified at import level + `register_all` mechanism unchanged | `worktree_mutation.py` rewrite + `local_read.py` list delegation + `envelope.py` docstring — all revertible file-level; no other tool behavior touched |
| WU3 — Go observer (tasks 4.x) | `go vet ./internal/worktree/...` → clean; `go test ./internal/worktree/... -run 'TestParseLockV2|TestIsStale|TestRepoName'` → **all PASS** | Full `go test ./internal/worktree/...` on feature branch: 1 pre-existing branch-sensitive failure (`TestVerifyOnMain`, expects running on `main`), **proven pass on MAIN** (`main` branch → PASS) — not a regression | `lock.go` + `lock_test.go` new files (deletable); `worktree.go` `List()` change (hardcoded name → `RepoNameFromGitRoot`) revertible |
| WU4 — wiring (tasks 5.x) | `./sync-skills.sh --check` from worktree → **exit 1, exactly 2 [DESYNC]** (SKILL.md, orchestrator.md), zero FALTA/ERROR; from MAIN → **exit 0, cero desyncs** | Marker idempotency proven: block strip+append detects cleanly, no duplicate `sdd-own:worktree-lifecycle-v2` block | `orchestrator.md` appended block + amended line inside our own `sdd-tool-integration` block; SKILL.md 6c rewrite — both file-level revertible; Alan's base untouched |

## Completed Tasks (31/31)

Phase 1 — shared pure layer (`worktree_state.py`, 1.1–1.9): lock v2 schema + constants, repo-name derivation, lock helpers, dirty check, 9-row classifier, hint index, acquire transitions, release transitions, enriched list. All done; classifier hardened by RED tests (see deviations).

Phase 2 — RED tests (2.1–2.8): full matrix incl. ghost/phantom row, concurrent-instances threat rows, enriched-list semantics.

Phase 3 — MCP handlers (3.1–3.6): `corrupt_worktree` in catalog; `git_worktree_acquire`/`git_worktree_release` primary tools; `git_worktree_add`/`remove` thin wrappers over `acquire_worktree`/`release_worktree`; enriched `git_worktree_list`.

Phase 4 — Go observer (4.1–4.3): `lock.go` (version==2 guard, `IsStale` kill-0 semantics, `RepoNameFromGitRoot`), hermetic `lock_test.go`, `worktree.go` hardcoded name replaced.

Phase 5 — wiring (5.1–5.2): orchestrator acquire-gate block appended verbatim from design (+ double-apply assertion line, inside markers); sdd-propose line amended within our own block; SKILL.md 6c rewritten (primary tools, 7-state model, typed denials, PID-reuse recovery, no-git-crudo preserved, pre-6c untouched).

Phase 6 — verification (6.1–6.3): sync checks per design (worktree exit 1 with exactly the 2 intended desyncs; MAIN exit 0); spec-delta note confirmed at tasks.md lines 76–80 (do NOT edit spec.md); PID-reuse manual recovery documented (6c bullet + acquire hint).

## Deviations from Design

1. **Classifier row-1 hardened (superset of design table).** RED tests exposed a gap: a porcelain entry whose directory vanished (ghost) fell through to `exists_inactive`, which made acquire try to write a lock into a nonexistent dir. Fixed: disk/porcelain disagreement in EITHER direction → `corrupt` (fail-closed); `exists_inactive` also requires the directory on disk. Added `corrupt_ghost_in_porcelain` classifier row test.
2. **Test infra introduced.** Cached testing-capabilities confirmed "no standard test runner (no pytest, shunit2, BATS)". Added `[dependency-groups] dev = ["pytest>=8"]` + `[tool.pytest.ini_options]` to `pyproject.toml`; `uv sync` created `uv.lock` + `.venv` in the worktree (venv is gitignored). pytest 9.1.1.
3. **`already_mine` short-circuits without the two-phase flow** in acquire/add tools (no mutation occurs — a confirm round-trip would be noise). This follows the design's route-on-`already_mine` rule.
4. **`git_worktree_release` denies `not_found` at tool level** for absent worktrees, while the shared `release_worktree` core remains an ok no-op for missing trees (tool UX vs core semantics — documented in docstrings).
5. **`TestVerifyOnMain` env-sensitivity surfaced.** The pre-existing test fails when the suite runs on a feature branch (it asserts the "no worktree" note that only fires on `main`/`master`) and passes on `main` (verified). Not caused by this change; noted for verify phase.

## Issues Found

- None blocking. See deviation 5 for the one pre-existing branch-sensitive test.
- `uv pip install pytest` without `--python` fails in the worktree (no `.venv` present in a fresh checkout — gitignored); resolved via `uv sync` in `srv/gh-mcp-server`. Future worktrees: run `uv sync` there (dev group now declared).

## Remaining Tasks

- None at apply level. Next: verify phase (`next_recommended: verify`).

## Workload / PR Boundary

- Mode: single PR, `size:exception` (pre-approved in orchestrator dispatch)
- Boundary: whole change — shared layer + handlers + observer + wiring
- Authored line impact: 372 insertions / 283 deletions in tracked files + new files `worktree_state.py` (~675), `tests/test_worktree_state.py` (~540), `lock.go` (~110), `lock_test.go` (~150) — far above the 400-line default budget; honestly reported per budget rules (budget constrains slicing, never the code).