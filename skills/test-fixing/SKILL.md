---
name: test-fixing
description: "Trigger: failing tests, test suite failures, make tests pass. Run the project's test command and systematically fix ALL failing tests using smart error grouping - red test, diagnosis, patch, re-run - until the whole suite is green."
license: Apache-2.0
metadata:
  author: mhattingpete (claude-skills-marketplace, adapted)
  version: "1.0"
  source: "https://github.com/mhattingpete/claude-skills-marketplace (engineering-workflow-plugin/skills/test-fixing)"
---

# Fixing Failing Tests

## When to Use

Use this skill when tests are failing and need to be systematically fixed. It is for FIXING existing failures — not for writing new tests and not for setting coverage policy. If the suite is green and you need new coverage, use the project's testing conventions instead.

## Workflow

### 1. Run the Tests

Run the project's test command — `make test`, `npm test`, `go test ./...`, `uv run pytest`, or whatever the project declares — and capture the failures:

```bash
# Example with a common entry point
make test 2>&1 | tee /tmp/test-output.log
```

**Loop invariant:** a red test → diagnosis → patch → re-run loop. Keep the loop tight: small batches, verify after each patch, never "fix everything then hope."

### 2. Smart Error Grouping

Don't fix tests one by one. Group errors by root cause first:

- **Same error message, different tests** → one shared cause (fixture, helper, shared state).
- **Same module/file implicated** → likely one broken unit.
- **One failing test in a tightly coupled area** → often a symptom, not the root cause.

Fixing by root-cause group fixes N tests with one patch. Fixing one-by-one fixes N tests with N patches and usually misses the shared cause.

### 3. Systematic Fixing Process

For each error group:

1. **Read the failure.** The assertion message and stack trace say what is expected vs. what the code produced.
2. **Diagnose before patching.** Read the test AND the code under test. Decide: is the TEST wrong (stale expectation, bad fixture) or the CODE wrong (regression, missing branch)? Fixing the code to satisfy a wrong test bakes the wrong behavior in.
3. **Patch the smallest thing that fixes the group.** Prefer the root cause over a test-local workaround.
4. **Re-run the group.** In tight loops, re-running just the affected subset is fine; the full suite must run before you declare done.
5. **Fix order strategy:** fix cheap, certain, root-cause groups first (fast green feedback, confidence), leave slow or ambiguous ones for last — unless one group blocks everything else (then it goes first).

### 4. Final Verification

Run the FULL suite — not just the previously failing subset — so the final state proves the whole suite green:

```bash
make test  # or the project's command
```

The fix is only done when the full suite passes.

## Best Practices

- **One failure at a time is a trap** — always read the full failure list before touching anything.
- **Never silence tests.** Deleting a test, skipping it with `@pytest.mark.skip`, or wrapping it in `//nolint` is only acceptable when you and your human partner explicitly agree it's obsolete — with a reason — never as a shortcut to green.
- **Keep fixes minimal** and aligned with the codebase's existing style. No drive-by refactors inside a fix.
- **Fixture/state pollution is the most common hidden cause** — mutated shared state, leftover files, seeded DB rows. Check test isolation before blaming the assertion.
- **Flaky tests** (pass locally, fail in CI, fail intermittently) get their own investigation: timing, ordering, and shared state are the usual suspects.

## Example Workflow

1. Run `make test` → 5 failures.
2. Group: 3 share `fixtures/user_builder.py` errors, 2 share a `# timeout` in the same module.
3. Fix `fixtures/user_builder.py` + the timeout root cause → 5 patches collapse into 2.
4. Run the full suite → green. Report the grouped summary.

---

## Provenance

Adapted from [`mhattingpete/claude-skills-marketplace`](https://github.com/mhattingpete/claude-skills-marketplace) — `engineering-workflow-plugin/skills/test-fixing/SKILL.md` (Apache-2.0). Adaptation makes it stack-neutral: concrete `make test`/`uv run pytest` invocations became "the project's test command," and scope is explicitly limited to fixing existing failures (not authoring tests, not coverage policy).