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

The skill SHALL support a dual surface: the official `github-mcp-server` tools (`github_*`, remote `https://api.githubcopilot.com/mcp/`, Docker `ghcr.io/github/github-mcp-server`, or stdio) for eligible accounts, and the own local server's `gh_*`/`git_*` tools as the default and fallback. It MUST NOT reference Composio, the rube Gateway, or RUBE_* environment tools. It SHALL NOT embed tokens; it instructs using the configured MCP or the own server's explicit-repo interface (RFC AC 7). Workflow behaviors in the skill SHALL be preserved regardless of the active surface. (Previously: the skill referenced official `github-mcp-server` tools only; no own-tool surface existed.)

#### Scenario: Composio-free content

- GIVEN the final SKILL.md
- WHEN searched for `Composio`, `rube`, or `RUBE_`
- THEN zero matches
- AND all tool references point to `github_*` or own `gh_*`/`git_*` tools

#### Scenario: Token-free content

- GIVEN the final SKILL.md
- WHEN searched for PAT patterns (`ghp_`, `github_pat_`)
- THEN zero matches
- AND the skill instructs "use the configured GitHub MCP" or the own server (which delegates auth to `gh`)

#### Scenario: Workflows preserved

- GIVEN an automation workflow (issue triage, PR merge gates, branch deletion guards, actions log evidence)
- WHEN the skill is applied on either surface
- THEN the behavioral rules (list→read→act, checks-before-merge, merged-check-before-delete) are unchanged

#### Scenario: Own-tool mapping documented

- GIVEN the skill's tool surface documentation
- THEN it maps own `gh_*`/`git_*` tools to `github_*` equivalents, explicitly marking unmappable tools and their report-only own-surface behavior
- AND notes the own server's surface is stable but still verifiable via `tools/list`

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

### Requirement: Runtime selection rule

The skill SHALL drive automation through one of two surfaces selected at runtime. The own local server (`gh_*`/`git_*` tools) SHALL be the default; the official `github_*` MCP SHALL be used when it is available and works for the account (e.g. GHEC/Copilot eligibility). When the official remote is unreachable or returns a `403`/eligibility error, the skill SHALL fall back to the own tools. The selection SHALL be re-evaluated when a tool call fails, never hardcoded for the session.

#### Scenario: Official unavailable

- GIVEN the official remote MCP returns 403 (no eligibility)
- WHEN an automation task runs
- THEN the skill uses the own `gh_*`/`git_*` tools
- AND no read-only workflow is skipped; write operations on unmappable tools (e.g. `github_add_issue_comment`, `github_review_pull_request`, remote branch create) degrade to report-only (the skill reads state, computes the assessment, and reports to the human instead of executing)

#### Scenario: Eligible account

- GIVEN the account has GHEC/Copilot eligibility and the official server works
- WHEN an automation task runs
- THEN the skill uses the official `github_*` tools
- AND falls back to own tools on any runtime failure

#### Scenario: Runtime failure fallback

- GIVEN an official-`github_*` call fails mid-task
- WHEN the model retries the operation
- THEN it selects the own `gh_*`/`git_*` equivalent and completes the task