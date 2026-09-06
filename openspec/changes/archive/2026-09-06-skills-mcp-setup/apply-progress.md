# Apply Progress — skills-mcp-setup

## Status

- **State**: implementation complete, RED suite green (21 PASS / 0 FAIL / 0 SKIP).
- **Commits**: 7 total on `main` (5 from earlier phases + 2 final).
- **Next phase**: verify (SDD pipeline); no push, no PR (user-owned step).

## Work units

| Unit | Result | Evidence |
| --- | --- | --- |
| RED test suite for setup.sh MCP invariants (T01-T22) | Done | `tests/run_red_checks.sh`, commit `5c039c9` |
| Scopes delivery fix (validate_token subshell bug + CRLF) | Done | commit `5d7778f` |
| F1 literal-token curl config (empirical finding, supersedes design's `${VAR}` note) | Done | `validate_token` in setup.sh, T11 |
| Host `./setup.sh --check` offline | exit 0, no mutation, zero desyncs | verified |

## Key decisions and findings

1. **F1 mechanism (apply-time supersession)**: curl 8.21 does NOT expand
   `${VAR}` inside `header =` lines of `-K` config files (verified empirically:
   the fake API received the literal `${TESTTOK}`). The design's "config dump
   only ${VAR}" note is superseded; the actual invariant — token only in the
   0600 temp config, deleted on exit, never in argv/env/logs — is implemented
   and asserted by T11.
2. **Scopes subshell bug (real defect found)**: `validate_token` assigned the
   global `SDD_OWN_VALIDATION_SCOPES` inside the caller's command substitution
   subshell, so `prompt_scope_change` always received `''` (spurious
   "fine-grained" notice; T12 scope warning never fired). Fixed by moving the
   scopes into the stdout contract `200|<scopes>`, parsed at the 3 call sites.
3. **CRLF normalization**: GitHub's `x-oauth-scopes` header carries `\r`;
   stripped in the awk extraction. Separators `, ` are also normalized so the
   missing-scopes match (`repo`, `read:org`, `workflow`) works on clean names.
4. **Harness fixes surfaced by the suite**: fake_api.py now matches curl
   processes by `basename(argv[0]) == "curl"` (substring match captured
   pty_run.py); pty_run.py matches retry prompts by occurrence count with
   per-prompt fired tracking (T09/T14 semantics).
5. **T22 sync-check flakiness**: `sync-skills.sh --check` hung twice during
   suite runs (>60s, ~0 CPU — environmental I/O stall, non-deterministic;
   direct runs complete in ~2s). Bounded with `timeout 120` and a clear
   re-run instruction; passed in final runs. No lock/network in check mode
   (pure filesystem diffing).

## Test status (final)

- `bash tests/run_red_checks.sh` → PASS 21, FAIL 0, SKIP 0.
- `./setup.sh --check` (host, offline): exit 0, no file mutation,
  "sincronizado (cero desyncs)", `Token GitHub: ausente` (clean state OK).
- T17 happy path requires `tomli_w` on the host (exposed via PYTHONPATH in
  the sandbox since HOME is redirected); the fail-fast path is always
  exercised via the python3 shim.

## Outstanding / risks

- No push/PR yet (user step). `openspec/` is never versioned in this repo
  (0 commits historically); this file is local persistence only.
- T22 flakiness documented; re-run `timeout 60 ./sync-skills.sh --check`
  manually if the suite ever reports a 124 exit there.