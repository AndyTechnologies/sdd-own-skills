# Delta for github-mcp-setup

RFC traceability: AC1 (network degrade), AC2 (401 fatal), AC3 (selector modes).

## ADDED Requirements

### Requirement: Network degrade tolerance

`setup.sh` SHALL treat transient network failures at the two network-fatal insertion points (L308-310 `prompt_new_token` network path and L829-832 `--check` structural path) as warnings instead of fatal exits. On network degradation the script SHALL emit a `[aviso]` warning and continue with `exit ≤1`; it SHALL NOT abort or mutate configs. The 401/invalid-token path (L316-318, `validate_token()`) and the existing-token path (L758-761) are outside this requirement.

#### Scenario: Network failure at prompt_new_token (AC1)

- GIVEN network is unreachable at `prompt_new_token` (L308-310)
- WHEN setup.sh runs in real mode
- THEN it emits a `[aviso]` warning about network failure
- AND continues to the next step without aborting
- AND exits with code ≤1
- AND no token/config side-effects from the failed validation; later steps proceed normally

#### Scenario: Network failure at --check structural (AC1)

- GIVEN API is unreachable at `--check` structural check (L829-832)
- WHEN setup.sh runs with `--check`
- THEN it degrades to a warning about unverifiable network status
- AND continues without setting `mcp_exit=2`
- AND exits with code ≤1

#### Scenario: 401/invalid token stays fatal (AC2)

- GIVEN an invalid token that returns 401 at `validate_token()`
- WHEN setup.sh runs in real mode
- THEN it exits with code 2 (fatal)
- AND no config files are mutated
- AND the user sees an invalid-token error message

#### Scenario: Existing token network degrade unchanged

- GIVEN an existing token file and network unreachable at L758-761
- WHEN setup.sh runs in real mode
- THEN it emits the existing `[aviso]` warning and preserves the env file without rewriting

### Requirement: Interactive MCP runtime selector

`setup.sh` SHALL add step 5g (after 5e, before 5f) reading the `selectors` field (top-level, outside `block` envelope; default: all runtimes). Interactive TTY mode SHALL present a pty-managed toggle (space = toggle, Enter = confirm). Without TTY or in `--check`/`--dry-run`, all runtimes are selected without prompting. Unselected runtimes are skipped in the merge loop without altering `block`/`merge` mechanics, `wiring/opencode.sdd.json`, or `--skip-opencode`/`--skip-mcp` flags.

#### Scenario: Selector with TTY toggle (AC3)

- GIVEN setup.sh is invoked interactively with a TTY
- WHEN step 5g runs
- THEN it presents all runtimes with current selection state
- AND pressing space toggles the focused runtime
- AND pressing Enter confirms and proceeds with selected runtimes

#### Scenario: Selector without TTY (AC3)

- GIVEN setup.sh is invoked without a TTY (e.g. piped, CI)
- WHEN step 5g runs
- THEN all runtimes are selected automatically
- AND no prompt is displayed

#### Scenario: Selector in --check/--dry-run mode (AC3)

- GIVEN setup.sh is invoked with `--check` or `--dry-run`
- WHEN step 5g runs
- THEN all runtimes are selected without prompting
- AND no mutation occurs

#### Scenario: Unselected runtime skipped in merge

- GIVEN the user deselects a runtime in the selector
- WHEN the merge loop runs
- THEN the deselected runtime is skipped entirely
- AND `block`/`merge` mechanics for other runtimes are unaffected
- AND `wiring/opencode.sdd.json` is not modified

## MODIFIED Requirements

### Requirement: Check and dry-run reports

`setup.sh --check` SHALL report skills synced, GitHub MCP configured-or-absent, token valid-or-missing, and network status without mutating (AC 1). `--dry-run` SHALL show the plan including selector output and write nothing (AC 2). Network degradation during check/dry-run SHALL be a warning, not a fatal exit.
(Previously: no network degrade tolerance or selector step.)

#### Scenario: Check state with network degrade

- GIVEN network unreachable during `--check`
- WHEN `--check` runs
- THEN it reports network as degraded with a warning
- AND exits with code ≤1 (not exit 2)
- AND mutates nothing

#### Scenario: Dry-run plan with selector

- GIVEN `--dry-run` invocation
- WHEN the plan is printed
- THEN it shows all runtimes selected (non-interactive) and writes nothing
