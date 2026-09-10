# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased] - 2026-09-08

### Added
- New vendored skill `convert-documents-to-markdown` (firecrawl/anydoc, MIT, main): convert Word/PowerPoint/Excel/OpenDocument/RTF/EPUB/CSV/PDF to GitHub-Flavored Markdown via the anydoc CLI (`npx -y @firecrawl/anydoc`, Node 20+, no install), full-installed to the three agent runtimes by the existing sync mechanics with provenance README.
- New vendored skill `archify` (tt-a1i/archify, MIT, stable v2.16.0): architecture/workflow/sequence/dataflow/lifecycle diagrams as self-contained HTML from typed JSON IR; runtime uses only Node builtins (>=18), full-installed to the three agent runtimes by the existing sync mechanics with provenance README.
- `sdd-verify` now shape-validates evidence claims; malformed evidence is discarded, the unit marked `not-verifiable`, and verify blocks until apply corrects it — no degraded trust from untrusted claims.
- Post-verify Review-Driven Development (RDD) hook in the orchestrator: on RDD ON, a selectorless preflight runs and relays consent as a Lossless Blocking Prompt in both interactive and auto modes, never skipping human authorization; declined consent continues the pipeline to archive.
- Four new test groups (T28–T31) in `tests/run_red_checks.sh` covering contract pins, synthetic SWU probes, sync idempotency, and F4 hook validation.
- New `sdd-council` support phase: 3 lens agents (`sdd-council-arch`, `sdd-council-product`, `sdd-council-risk`) review design+proposal in parallel; convergence proceeds without interrupting the user, real forks are framed for the user to decide (the model never decides forks alone), rounds are capped at 2 then STOP, and the council never relaunches design.
- The council persists an acta (`openspec/changes/{change}/council.md` + Engram mirror `sdd/{change}/council`) with titled decisions, convergence status, and round count.
- The runtime sync merge now propagates root `subagent_depth: 2` (fragment-wins, idempotent, both jq and python merge engines), enabling the orchestrator → council → lens-agent task chain.
- Command overlays (`sdd-continue` SUPPORT-CONDITIONAL, `sdd-ff` item 6) wire the ALWAYS council → arch-lint(acta) chain, and new RED checks T32–T39 pin the council allow-lists, `OWN_PROMPTS` entry, no-`mcp` rule, and `subagent_depth`.
- New `sdd-tool` Go CLI (cobra, pure-Go modernc sqlite, no CGO) closing four SDD gaps plus an incident overlay: `worktree list|verify`, `retro lookup|persist`, on-demand `dashboard` (Bubbletea TUI), and `bug record|resolve|list`, with `--json` on every script surface and ONE shared cached parse of `gentle-ai sdd-status --json` (schema v2) feeding all listing surfaces.
- Hard fail-open execution: tool absence degrades executors to the pre-tool flow; reads warn-and-continue, writes (`retro persist`, `bug record`, `bug resolve`) exit non-zero with a loud FAIL-OPEN marker; `nextRecommended`, `blockedReasons`, and the attempt ledger are never mutated; Engram is reached via the `engram` subprocess only (`~/.engram/engram.db` is never written directly).
- `retro persist` is store-first with cross-store fallback and dedupe by change name: the openspec file is written pre-archive (so the archive folder move carries it) and an Engram observation is saved (topic `sdd/{change}/retrospective`, type `learning`, title carrying the key); the precis is capped at 5 retros of ≤15 lines; `none` mode emits an inline hint only.
- `worktree verify` re-entry check passes only when the three binding signals hold (repo root, `sdd/<change>` branch, scanner parse), names the failing signal, discloses "no worktree" on branch mismatch, reports clean vs. dirty (ignoring server-owned `.codegraph/` and `.sdd-agent-lock`), and never auto-clears — the human decides.
- `dashboard` renders a change table with a detail pane, refreshes only on demand (no polling), emits `--json` consistent with the shared scanner, and is a read-only window (no routing/ledger mutation).
- `bug record|resolve|list` incident recording with privacy-scrubbed summaries (tokens and local paths redacted); `bug resolve --engram-id` binds the fix's direct Engram observation, falls back to `fallback_path` when Engram is off without fabricating an id, and resolved incidents surface in the retro verify-phase incident list.
- Orchestrator archive-close order is now fixed `verify → changelog → retro persist → archive`, with the changelog hook running PRE-archive and consuming the verify-report as its input; four fail-open overlay clauses (prior-context injection, worktree verify rule-5 integration, incident recording hook, archive-close retro persist) are installed in `wiring/prompts/sdd/orchestrator.md`.
- `setup.sh` gains optional step 5d-2 (`go build` of `srv/sdd-tool` honoring check/dry-run/real modes): missing Go or a build failure emits a warning only and never blocks; the binary is gitignored.
- RED checks T40–T48 in `tests/run_red_checks.sh` cover the CLI surface, retro dedupe/fallback/retrievability, worktree verify signals, the incident lifecycle, FAIL-OPEN write markers, and the installed wiring clauses.
- New `git_worktree_acquire` MCP tool: classifies the worktree into one of 7 states, then creates/attaches/re-claims it or confirms it is already yours — returning `{status, path, branch}` with lock v2 and hint-index write-through; active worktrees owned by others are never silently taken over (typed denials `owned_by_other`, `locked_unreadable`, `corrupt_worktree`).
- New `git_worktree_release` MCP tool: removes the caller's claim only — never the worktree, dirty worktrees are fine, and releasing a claim you do not own is a silent no-op.
- 7-state worktree classifier (`absent`, `absent_branch_exists`, `exists_inactive`, `exists_stale`, `exists_active_mine`, `exists_active_other`, `corrupt`) derived from git porcelain + lock file + PID liveness + owner/session match, fail-closed on unreadable evidence.
- Lock v2 schema (version, pid, session, owner, change, repo_root, repo_name, branch, store, created_at, last_seen) with dead-PID stale detection: legacy v1 locks with a dead PID auto re-claim; live-PID v1 locks and same-owner/different-session locks are real conflicts, never silent takeovers.
- Advisory hint index `~/.agent_worktrees/<repo>/.agent-index.json` (version 1, write-through on acquire/release, rebuilt when corrupt or missing; git porcelain stays the source of truth).
- Organic post-power-loss continuation: natural entries such as "continúa con el cambio" discover work via `git_worktree_list` + apply-progress cross-reference with no change name required, presented by volume (1 → direct; 2–5 → selection question; >5 → table with validated input; 0 → informative notice proposing `/sdd-new`).
- Orchestrator acquire gate: every phase needing a worktree calls `git_worktree_acquire` BEFORE `sdd-tool worktree verify`; objective stale evidence auto re-claims without prompting, and a blocking prompt appears only on real conflicts.
- `sdd-tool worktree list|verify` and the server now derive the worktree namespace from the git toplevel basename instead of a hardcoded repo name, fixing the lifecycle in repositories other than the one it was built in.

### Changed
- `sdd-tasks` now emits Suggested Work Units (SWUs) with four closed-domain tokens (`start`, `finish`, `verification`, `rollback`), each a command or explicit `N/A` with reason, making commands machine-checkable and never free-form prose.
- `sdd-apply` shape-validates every suggested command before execution; malformed commands are rejected fail-closed with a finding and blocked work unit, never executed or paraphrased.
- `sdd-apply` and `sdd-verify` may only edit files inside authorized edit roots; out-of-root edits produce `blocked(edit_authority_missing)` with two exits (fix into authorized roots or grant authority).
- The post-design chain is now enforceable machinery, not prose: after every `design`, `sdd-council` runs ALWAYS, then `sdd-architecture-lint` runs ALWAYS with the council acta as a mandatory input; auto mode allows at most one retry of the full council → arch-lint chain, then STOP (no loop-until-clean).
- `sdd-architecture-lint` is no longer opt-in or boundary-conditional: it gains axis 2, which verifies each acta decision title-by-title and fails closed when the acta is missing; `N/A` remains valid only for empty/trivial designs.
- `git_worktree_add` and `git_worktree_remove` are now thin retrocompat wrappers over `git_worktree_acquire`/`git_worktree_release`: the `destructive_flow` two-phase envelope, safe-slug rule, and dirty/owner pre-checks are preserved, with no duplicated classifier/lock logic.
- `git_worktree_list` now returns enriched entries (state, owner, session, last_seen, dirty, main worktree included) instead of paths/branches only.
- The worktree error catalog is extended with `locked_unreadable` and `corrupt_worktree` alongside the existing closed error set.
- The vendored `using-git-worktrees` skill gains an additive section 6c documenting the MCP-native lifecycle, the 7-state model, and typed denials (all pre-6c content preserved).

### Fixed
- Worktree hardcode removal: `srv/sdd-tool/internal/worktree/worktree.go` used to hardcode `"sdd-own-skills"` (~L77) for the worktree namespace and lock `repo_name`; both are now derived from `git rev-parse --show-toplevel` basename, so `worktree list|verify` and acquire work correctly in any repository.
