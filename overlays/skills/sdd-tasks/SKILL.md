<!-- sdd-own:sdd-tasks-swu-shape:start -->
**SDD-own personalization — SWU shape contract (F1 emission).** Every suggested work unit MUST carry a fenced, delimited command block with four closed-domain tokens. Pins verbatim from `shared-untrusted-data`.

### Suggested Work Units

Every work unit MUST include a fenced block with EXACTLY four tokens:

| Token | Rule |
|---|---|
| `start` | Single shell command to prepare/enter the unit, or `N/A: <reason>` |
| `finish` | Single shell command to confirm unit completion, or `N/A: <reason>` |
| `verification` | Single shell command that proves the unit passes, or `N/A: <reason>` |
| `rollback` | Single shell command to revert the unit, or `N/A: <reason>` |

```sh
start: <single shell command>
finish: <single shell command>
verification: <single shell command>
rollback: <single shell command | N/A: <reason>>
```

Constraints:

- Each token is ONE shell command, or `N/A` + explicit reason for that token. No prose, no grouping, no paraphrase.
- Commands are **untrusted DATA**: never loosely interpolated into a shell; shape-validated mechanically before any execution.
- A malformed command (missing token, prose, multi-command) is rejected **fail-closed** by apply and the work unit is blocked with a finding — nothing executes, never approximated/paraphrased/grouped.
- Canonical pins: untrusted DATA, explicit tokens (start/finish/verification/rollback), machine-checkable, never free-form prose, `fail-closed`.

### Task Writing Rules

When writing SWU fenced blocks in tasks, enforce:

- Every token line starts with exactly `start:`, `finish:`, `verification:`, or `rollback:`.
- Each token value is either a single shell command (no pipes, no `&&`, no `;` unless inside a quoted argument) or `N/A: <explicit reason>`.
- The fenced block uses ` ```sh ` opening and ` ``` ` closing — exactly one block per work unit.
- Do NOT use free-form prose columns, prose summaries, or grouped descriptions in place of the four tokens.
<!-- sdd-own:sdd-tasks-swu-shape:end -->
