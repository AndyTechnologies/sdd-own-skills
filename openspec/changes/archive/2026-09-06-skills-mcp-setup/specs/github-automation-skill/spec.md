# GitHub Automation Skill Specification

## Purpose

Spec for the reauthored `github-automation` skill (RFC goal 1, AC 6/7): zero upstream vendoring, automation/ops scope, official `github-mcp-server` tooling only, no Composio, no embedded tokens.

## Requirements

### Requirement: Fresh authorship with repo licensing

The skill SHALL be reauthored: no upstream file exists to vendor, so the Composio family skeleton and README description serve only as structure inspiration. It SHALL carry the repo's own attribution conventions, never a Composio or upstream license, and SHALL note the inspiration in the README.

#### Scenario: No vendored license

- GIVEN the skill directory
- WHEN inspected for license files
- THEN no Composio or upstream license is present
- AND attribution is the repo's own

### Requirement: Official GitHub MCP only

The skill SHALL reference official `github-mcp-server` tools (remote `https://api.githubcopilot.com/mcp/`, Docker `ghcr.io/github/github-mcp-server`, or stdio) via the configured GitHub MCP. It MUST NOT reference Composio, the rube Gateway, or RUBE_* environment tools. It SHALL NOT embed tokens; it instructs using the MCP (RFC AC 7).

#### Scenario: Composio-free content

- GIVEN the final SKILL.md
- WHEN searched for `Composio`, `rube`, or `RUBE_`
- THEN zero matches
- AND all tool references point to github-mcp-server tools

#### Scenario: Token-free content

- GIVEN the final SKILL.md
- WHEN searched for PAT patterns (`ghp_`, `github_pat_`)
- THEN zero matches
- AND the skill instructs "use the configured GitHub MCP"

### Requirement: Trigger scope with disambiguation

The description SHALL scope to automation/ops: issues, PRs, repos, branches, actions, and code search. It MUST explicitly disambiguate from `github-pr`, `branch-pr`, `chained-pr`, and `issue-creation`, which own PR-creation and issue-creation workflows.

#### Scenario: Ops task matched

- GIVEN a task "list open issues across repos via MCP"
- WHEN matched
- THEN `github-automation` matches

#### Scenario: PR workflow excluded

- GIVEN a task "create a PR from this branch"
- WHEN matched
- THEN `github-pr`/`branch-pr` win; `github-automation` does not claim it

### Requirement: Registry presence

The skill SHALL appear in the skill registry after refresh with its scoped trigger description (AC 6).

#### Scenario: Registered

- GIVEN the skill lands in `skills/`
- WHEN the registry refreshes
- THEN it is listed with its automation/ops trigger description