# sdd-tool-worktree Specification

## Purpose

Worktree re-entry checks: `worktree list` enumerates worktrees under the `~/.agent_worktrees/<repo-name>/<change>` convention; `worktree verify` passes ONLY when three binding signals hold, classifies clean vs. dirty with disclosure, and NEVER auto-clears — the human decides. A failing branch signal discloses "no worktree".

## Requirements

### Requirement: Worktree list

`worktree list` SHALL enumerate worktrees under the repo convention `~/.agent_worktrees/<repo-name>/<change>` and SHALL show each worktree's branch (`sdd/<change>`).

#### Scenario: List shows convention worktrees

- GIVEN one worktree at `~/.agent_worktrees/sdd-own-skills/sdd-tool` on branch `sdd/sdd-tool`
- WHEN `worktree list` runs
- THEN it shows the worktree path and branch

### Requirement: Verify binding signals

`worktree verify` SHALL pass ONLY when all three binding signals hold: (1) `git rev-parse --show-toplevel` equals the expected repo root; (2) `git branch --show-current` equals `sdd/<change>`; (3) `gentle-ai sdd-status --json` parses successfully. A failing signal SHALL be reported explicitly, naming which signal broke, with a clean non-zero exit.

#### Scenario: All signals hold

- GIVEN the worktree root matches, branch is `sdd/<change>`, and the scanner JSON parses
- WHEN `worktree verify` runs
- THEN verify passes

#### Scenario: Failing signal reported by name

- GIVEN branch is `main` (no worktree) while root and scanner hold
- WHEN `worktree verify` runs
- THEN it fails cleanly, reports signal 2 broke, and discloses "no worktree"

#### Scenario: Scanner JSON unparseable

- GIVEN `gentle-ai sdd-status --json` returns invalid output
- WHEN `worktree verify` runs
- THEN it fails cleanly and reports signal 3 broke

### Requirement: Dirty-state disclosure, never auto-clear

When signals hold, `worktree verify` SHALL classify the tree clean vs. dirty and disclose the dirty state (ignoring server-owned artifacts `.codegraph/` and `.sdd-agent-lock`). The tool SHALL NOT auto-clear or mutate the worktree; the human decides. Dirty state SHALL be disclosed even when a signal fails.

#### Scenario: Dirty tree disclosed, not cleared

- GIVEN signal-holding worktree with uncommitted changes (excluding server-owned artifacts)
- WHEN `worktree verify` runs
- THEN it reports dirty without clearing anything

#### Scenario: Hidden server artifacts ignored

- GIVEN dirty output limited to `.codegraph/` and `.sdd-agent-lock`
- WHEN `worktree verify` runs
- THEN the tree is classified clean; no mutation happens