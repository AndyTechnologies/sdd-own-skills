---
name: red-suite-hygiene
description: "Trigger: RED checks, run_red_checks, sandbox huerfano, tmpfs lleno, Disk quota exceeded, write error, fake_api. Clean test-environment debris before diagnosing RED-suite failures so environmental noise never masquerades as a contract defect."
license: Apache-2.0
metadata:
  author: "sdd-own-skills"
  version: "1.0"
---

# RED Suite Hygiene

## Activation Contract

Load before running or diagnosing `tests/run_red_checks.sh` (the RED suite), after a power/internet outage that may have killed it mid-run, or whenever FAILs show `write error`, `Disk quota exceeded`, or unexpected `exit 2` inside sandboxes.

## Hard Rules

- NEVER diagnose a suite failure as a contract defect while the environment is degraded. Clean first, re-run, then judge.
- NEVER use `pkill -f` with a pattern that can match your own shell cmdline (e.g. `fake_api.py`) — the tool shell can kill itself. Use the explicit PID list from `pgrep -af`.
- The harness `trap cleanup EXIT` only stops fake APIs; it does NOT remove `$SB_ROOT` sandboxes. Stale `/tmp/sdd-red.*` dirs (~80MB each) accumulate and fill the tmpfs — above ~70% the suite starts emitting write errors that fake FAILs.
- Only a FAIL reproduced after a full sweep + clean re-run is a candidate contract defect.

## Decision Gates

| Signal | Diagnosis | Action |
| --- | --- | --- |
| `write error` / `Disk quota exceeded` / `fflush failed` | tmpfs `/tmp` full from stale sandboxes | sweep stale dirs, re-run |
| `exit 2 != 0` from setup.sh in a fresh sandbox | contract/environment mismatch, NOT leftover debris | inspect setup.sh gating + sync seams |
| FAIL persists after full sweep + re-run | real contract drift | diagnose against the contract, scoped correction |
| `fake_api.py` with ppid=1 | orphans from an interrupted run | kill the confirmed PID list |

## Execution Steps

1. Preflight: `df -h /tmp`. If tmpfs > 70%, sweep before anything else.
2. Sweep harness-created dirs only: `rm -rf /tmp/sdd-red.* /tmp/opencode/retro-probe-*`.
3. Orphan API check: `pgrep -af fake_api.py`; kill confirmed PIDs individually.
4. Run the suite: `timeout 300 ./tests/run_red_checks.sh > /tmp/redchecks_clean.log 2>&1`.
5. Classify every FAIL: grep the log for write/quota errors near the failing test. If present, that FAIL is invalid — the suite ran degraded.
6. Only environment-clean, reproduced FAILs are real. Fix those against the contract with one scoped correction; never "fix" environmental noise by editing tests or contract files.

## Output Contract

Report: preflight df/inode state, stale-dir and orphan counts found + cleaned, suite PASS/FAIL/SKIP totals, and for each FAIL an environmental-vs-contract classification backed by the exact log line.

## References

- `tests/helpers/sandbox.sh` — sandbox lifecycle: `init_sandbox` creates `/tmp/sdd-red.*`; `start_fake_api` registers every PID in `SB_API_PIDS` and redirects child stderr to `$SB_TMP/api.stderr` (orphans never hold the runner pipe); `stop_fake_api` kills+waits all registered PIDs.
- `tests/run_red_checks.sh` — runner: `trap cleanup EXIT` (APIs only, not sandboxes), per-test `t/ok/ko/skip` timing traces, `(Ns total)` summary.