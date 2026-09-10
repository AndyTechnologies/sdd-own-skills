# Council Acta: sdd-tool

## Round
1

## Lens Verdicts

### sdd-council-arch
- Viable option: D1 — direct edit of `skills/sdd-changelog/SKILL.md`
- Verdict: converge on D1 (direct edit)
- Concerns:
  - D1 maintainer-acknowledgment gate must close before tasks freeze.
  - `PersistentPreRunE` parses sdd-status for ALL commands incl. mutating ones (e.g. `bug record`) — a lazy per-command snapshot avoids paying the parse when no listing surface needs it.
  - Proposal affected-areas table still lists "sdd-changelog thin overlay" — reconcile in the same change so tasks/executors do not re-introduce the overlay file.
  - T42 (title retrievability) should explicitly exercise the adapter's title-key filter (engram search matches title/content only).

### sdd-council-product
- Viable option: Option (b) — direct edit of `skills/sdd-changelog/SKILL.md`
- Verdict: converge on Option (b)
- Concerns:
  - D1 open question unresolved (design.md L89) — tasks freeze should not proceed until maintainer acknowledges the mechanism change; proposal rollback plan still references stripping an overlay that will not exist.
  - Proposal table (L47) still lists `overlays/skills/sdd-changelog/SKILL.md — New` while the design mandates a direct edit — reconcile before task freeze.

### sdd-council-risk
- Viable option: D1(b) — direct edit of `skills/sdd-changelog/SKILL.md`
- Verdict: converge on D1(b)
- Concerns:
  - Fail-open on DATA-PRODUCING commands (`retro persist`, `bug record/resolve`) converts a tool failure into silent data loss — reads fail-open, writes need asymmetric behavior: fail-closed or a loud, non-ignorable FAIL-OPEN marker.
  - Scrub scope: `retro persist --body-file` carries arbitrary text into openspec AND engram (long-lived memory) — bodies must be scrubbed uniformly; the regex also misses `ghe_` (enterprise) token prefix.
  - Rollback asymmetry: reverting the direct edit leaves `~/.config/sdd-own/skills/sdd-changelog/` stale — rollback needs a REAL sync, not `--check` (which reports DESYNC, does not fix it).
  - Scanner failure behavior unspecified: concurrent external process can yield half-written sdd-status output; parse failure must exit non-zero loudly, never fabricate empty worktree/dashboard surfaces; dashboard `r` re-parse must be explicit that the snapshot is process-lifetime.

## Convergence
convergence

## Decision
### Decision: D1 changelog direct edit
Edit `skills/sdd-changelog/SKILL.md` directly (repo canonical; exclusive skill, agents symlink to `~/.config/sdd-own/` canonical). A strip/append overlay would write through the symlink and be clobbered by `sync_dir` full-install → permanent DESYNC (fails AC1). verify-report becomes the PRE-archive input (consumes verdict/tests/no-CRITICAL); "absent archive-report → blocked" applies post-archive only. Reconcile the proposal's affected-areas table and rollback references to the direct edit so executors never re-introduce `overlays/skills/sdd-changelog/`.

### Decision: D2 asymmetric fail-open
Reads (`retro lookup`, `worktree list|verify`, `dashboard`, `bug list`) stay fail-open (warn + continue exactly pre-tool). Data-producing commands (`retro persist`, `bug record`, `bug resolve`) MUST NOT silently lose data on tool failure: exit non-zero with a loud, non-ignorable FAIL-OPEN marker naming the lost write; never convert a write failure into silent success.

### Decision: D3 scrub scope extension
Apply the privacy scrub uniformly to incident summaries AND retro bodies (`--body`/`--body-file`), because retros persist into engram long-lived memory. Extend the token regex to cover `ghp_`/`gho_`/`ghu_`/`ghs_`/`ghe_`/`github_pat_` prefixes. Scrub is a pure function shared by incidents and retro persist.

### Decision: D4 rollback via real sync
Rollback of the sdd-changelog direct edit requires running `./sync-skills.sh` in REAL mode to propagate the reverted canonical to `~/.config/sdd-own/skills/sdd-changelog/`; `--check` alone reports DESYNC but does not fix. Document this in the rollback plan.

### Decision: D5 scanner failure loud, snapshot explicit
Scanner parse failure (`gentle-ai sdd-status --json` unreadable/half-written) exits non-zero loudly; never fabricates empty worktree/dashboard surfaces. The shared snapshot is process-lifetime; dashboard `r` re-parses once per keypress and the snapshot semantics are documented in the UI.