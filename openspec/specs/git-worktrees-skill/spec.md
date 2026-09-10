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

The vendored `using-git-worktrees` skill SHALL gain an additive section (6c) covering the MCP-native worktree lifecycle with acquire/release semantics. The extension SHALL document: worktree location convention (`~/.agent_worktrees/<basename(repo_path)>/<change-name>`), branch naming (`sdd/<change>`), per-worktree dependency installation, own `.codegraph/` index (never copied/symlinked), and the 7-state model (absent/absent_branch_exists/exists_inactive/exists_stale/exists_active_mine/exists_active_other/corrupt). The extension SHALL reference `git_worktree_acquire`, `git_worktree_release`, `git_worktree_list` as primary tools and `git_worktree_add`/`git_worktree_remove` as retrocompat wrappers. It SHALL document acquire states (created/attached/claimed/reclaimed/already_mine), typed denials (owned_by_other/locked_unreadable), and the release-only-claims contract. The no-git-crudo invariant MUST be preserved.
(Previously: referenced add/remove/remove as primary tools with no state model)

#### Scenario: Acquire/release documented

- GIVEN the skill file is reviewed at section 6c
- WHEN a user reads the lifecycle section
- THEN it documents acquire, release, and list as primary tools
- AND add/remove are documented as thin retrocompat wrappers

#### Scenario: State model documented

- GIVEN the skill's 6c section
- WHEN the lifecycle section is reviewed
- THEN the 7-state model is described
- AND acquire paths for each state are summarized

#### Scenario: Denial semantics documented

- GIVEN the skill's 6c section
- WHEN acquire denial is described
- THEN `owned_by_other` and `locked_unreadable` are documented as typed errors
- AND the user is guided on how to resolve them

#### Scenario: No-git-crudo preserved

- GIVEN the skill's full content is reviewed
- WHEN worktree operations are described
- THEN all worktree ops route through MCP tools
- AND no raw `git worktree` commands appear

#### Scenario: Non-regression

- GIVEN the skill file with modified 6c section
- WHEN `./sync-skills.sh --check` runs
- THEN zero desyncs are reported
- AND existing vendored content (all pre-6c) is preserved
