# GitHub MCP Secrets Specification

## Purpose

Spec for the PAT lifecycle (RFC goals 3/4, AC 3/4/5; invariants: token never in repo or runtime config, validated before writes, persisted only on HTTP 200).

## Requirements

### Requirement: Secret store

The token `GITHUB_PERSONAL_ACCESS_TOKEN` MUST be persisted only in `~/.config/sdd-own/github-mcp.env` with mode 0600, outside the repo. It MUST NOT appear in the repo, runtime main configs, argv, logs, or setup output. Configs and `wiring/mcp.d/` reference the variable, never a literal.

#### Scenario: No leakage

- GIVEN a full setup run
- WHEN argv, logs, setup output, repo files, and runtime configs are inspected
- THEN the token appears nowhere except the 0600 env file

### Requirement: Validation gate

The token MUST be validated with `GET https://api.github.com/user` returning 200 with user JSON BEFORE anything is persisted; persistence happens only on 200. Invalid or expired tokens SHALL re-prompt up to 3 attempts and write nothing (AC 3/4).

#### Scenario: Clean install

- GIVEN no env file
- WHEN setup prompts and the token validates with 200
- THEN the env file is written 0600 and runtime blocks are configured

#### Scenario: Invalid token

- GIVEN three consecutive non-200 responses
- WHEN validating
- THEN nothing is persisted and setup reports failure

### Requirement: Keep vs replace

If a valid token already exists, setup SHALL ask to keep or replace it; `--force-mcp-token` SHALL force re-prompt and re-validation (AC 5).

#### Scenario: Valid existing token

- GIVEN a valid existing env file
- WHEN setup runs without `--force-mcp-token`
- THEN it asks keep-or-replace
- AND keep -> no rewrite, replace -> re-validates before overwriting

### Requirement: Scope advisory

Missing critical scopes SHALL produce a warning plus an option to change the token before continuing; it MUST NOT block. Classic tokens SHALL be checked via `x-oauth-scopes`; fine-grained tokens (no header) SHALL be reported as unverifiable and continue (RFC non-goal).

#### Scenario: Missing scope

- GIVEN a classic token without `repo` in `x-oauth-scopes`
- WHEN validated with 200
- THEN it warns and offers to change the token before continuing

#### Scenario: Fine-grained token

- GIVEN a `github_pat_...` token with no scope header
- WHEN validated
- THEN it reports scopes unverifiable
- AND continues

### Requirement: Offline behavior

If `api.github.com` is unreachable, setup SHALL fail clearly and persist nothing (RFC failure case).

#### Scenario: No network

- GIVEN no connectivity to `api.github.com`
- WHEN validating
- THEN setup reports a clear network failure
- AND nothing is persisted

### Requirement: Path collision safety

If the env file path already holds a token, setup SHALL NOT clobber it without backup or explicit consent.

#### Scenario: Collision

- GIVEN an existing env file with an invalid token
- WHEN the user chooses replace
- THEN the existing file is backed up
- AND overwritten only with explicit consent