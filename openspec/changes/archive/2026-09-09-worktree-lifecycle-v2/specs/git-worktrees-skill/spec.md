# Delta for Git Worktrees Skill

## MODIFIED Requirements

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
