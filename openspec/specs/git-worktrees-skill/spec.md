# Git Worktrees Skill Specification

## Purpose

Spec for the curated `using-git-worktrees` skill (RFC goal 1, AC 6/8): upstream content adapted to repo conventions, deployed by sync, non-regressive for the existing suite.

## Requirements

### Requirement: Vendored and adapted content

The skill SHALL be vendored from `obra/superpowers/skills/using-git-worktrees/` (MIT, Copyright 2025 Jesse Vincent) into `skills/using-git-worktrees/SKILL.md` as a single file with valid frontmatter (`name`, `description`) matching suite conventions. MIT attribution MUST be preserved. No extra cargo (scripts/dirs) SHALL be added beyond what the content requires.

#### Scenario: Clean deploy

- GIVEN `skills/using-git-worktrees/SKILL.md` with valid frontmatter and MIT attribution
- WHEN `sync-skills.sh` step 1 runs
- THEN the skill is copied to `~/.agents/skills/using-git-worktrees/`
- AND symlinked under `~/.config/opencode/skills/` and `~/.claude/skills/`
- AND listed in the skill registry after refresh

#### Scenario: Minimal adaptation

- GIVEN the upstream file was adapted to repo conventions
- WHEN the vendored file is reviewed
- THEN adaptations are minimal and documented
- AND no base skill of Alan is edited or removed

### Requirement: Trigger and scope

The description SHALL trigger on creating or using isolated git worktrees for parallel work, including worktree safety verification. It SHALL NOT claim PR, issue, or GitHub-automation triggers.

#### Scenario: Worktree task matched

- GIVEN a task "set up an isolated git worktree for this feature"
- WHEN the description is evaluated
- THEN `using-git-worktrees` matches
- AND no PR/issue skill claims it

#### Scenario: Scope exclusion

- GIVEN a PR-creation task
- WHEN the resolver matches
- THEN `github-pr`/`branch-pr` own it; `using-git-worktrees` does not

### Requirement: Non-regression

Adding the skill SHALL NOT break the rest of the suite: `./sync-skills.sh --check` MUST still report zero desyncs after the change is applied (RFC AC 8). Additionally, the 6c extension SHALL be additive only — no existing content may be removed, renamed, or reordered.

#### Scenario: Suite integrity with extension (AC7)

- GIVEN the skill with 6c extension
- WHEN `./sync-skills.sh --check` runs
- THEN zero desyncs are reported
- AND the original content through all existing sections is byte-identical to the pre-change state

### Requirement: MCP worktree lifecycle extension

The vendored `using-git-worktrees` skill SHALL gain an additive section (6c) covering the MCP-native worktree lifecycle. The extension SHALL document: worktree location convention (`~/.agent_worktrees/<basename(repo_path)>/<change-name>`, HOME-relative, resolved via `Path.home()`), branch naming (`sdd/<change>`), per-worktree dependency installation (pnpm hardlinks, out-of-source builds), own `.codegraph/` index (never copied or symlinked), and removal safety checks (no uncommitted changes, no live agents, owner match). The extension SHALL reference the `git_worktree_add`/`list`/`remove` MCP tools and NEVER instruct raw `git worktree` via bash (no-git-crudo invariant). Existing content preceding section 6c SHALL NOT be modified or removed.

#### Scenario: MCP tools documented (AC6)

- GIVEN the skill file is reviewed at section 6c
- WHEN a user reads the worktree lifecycle section
- THEN it documents all three MCP tools: add, list, remove
- AND references the two-phase dry-run pattern for add and remove

#### Scenario: Per-worktree isolation documented (AC6)

- GIVEN a worktree is created via MCP tools
- WHEN the skill's 6c guidance is followed
- THEN `.codegraph/` is initialized separately per worktree
- AND dependencies are installed per-worktree (not shared with main)
- AND location follows the `~/.agent_worktrees/<basename(repo_path)>/<change-name>` convention

#### Scenario: No-git-crudo preserved (AC6)

- GIVEN the skill's full content is reviewed
- WHEN worktree operations are described
- THEN all worktree ops route through `git_worktree_*` MCP tools
- AND no raw `git worktree` commands appear in the instructions

#### Scenario: Non-regression (AC7)

- GIVEN the skill file with the 6c extension applied
- WHEN `./sync-skills.sh --check` runs
- THEN zero desyncs are reported
- AND existing vendored content (all existing content) is byte-identical to the pre-change state