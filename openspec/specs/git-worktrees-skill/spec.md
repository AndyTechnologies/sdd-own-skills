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

Adding the skill SHALL NOT break the rest of the suite: `./sync-skills.sh --check` MUST still report zero desyncs after the change is applied (RFC AC 8).

#### Scenario: Suite integrity

- GIVEN the change applied with all new skills
- WHEN `./sync-skills.sh --check` runs
- THEN it reports zero desyncs