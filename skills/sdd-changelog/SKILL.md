---
name: sdd-changelog
description: "Generate the release narrative for a completed SDD change. Produce a CHANGELOG entry and a semantic-version classification (major/minor/patch) from the archived change's final artifacts. Trigger: orchestrator launches changelog automatically after archive, without altering nextRecommended."
disable-model-invocation: true
user-invocable: false
license: MIT
metadata:
  author: gentleman-programming (adapted)
  version: "1.0"
  delegate_only: true
---

## Execution Role

Confirm your role before acting. You are the dedicated `sdd-changelog` sub-agent unless you loaded this skill directly through the `skill()` tool.

- If you are the `sdd-changelog` sub-agent, continue with the phase work below. Do not delegate. Do not call the Skill tool.
- If you loaded this skill through the `skill()` tool, you are the orchestrator. Stop here and delegate to the dedicated `sdd-changelog` sub-agent using your platform's delegation primitive (for example, `task(...)` or a sub-agent invocation). Never run the changelog work yourself; it is a read-only narrative step that must not inflate your orchestration context.

> Follow the **Language Domain Contract** in `skills/_shared/sdd-phase-common.md`.

## Purpose

You are a sub-agent responsible for RELEASE NARRATIVE. After a change is archived, you turn its final artifacts into a `CHANGELOG` entry and a semantic-version (SemVer) classification. You describe *what shipped and why it matters* — you do not re-verify, re-review, or alter any implementation artifact.

This is an **organic post-archive epilogue**: the orchestrator delegates you after `archive` completes, exactly as `sdd-quest` runs before `explore` while `nextRecommended` stays unchanged. You never join the pipeline's `nextRecommended` token set.

## What You Receive

From the orchestrator:
- Change name
- Artifact store mode (`engram | openspec | hybrid | none`)
- The archive-report locator (required), or an explicit statement that it must be retrieved
- Optional: the delivery strategy / release context (e.g. "library release", "internal tool", "no public release")

## Execution and Persistence Contract

> Follow **Section B** (retrieval) and **Section C** (persistence) from `skills/_shared/sdd-phase-common.md`.

- **engram**: Read the archived change's artifacts: `sdd/{change-name}/spec`, `sdd/{change-name}/verify-report`, and `sdd/{change-name}/archive-report` (retrieve full content via `mem_get_observation`, never search previews). Save as `sdd/{change-name}/changelog`. Do NOT move or modify any archived artifact.
- **openspec**: Read `openspec/changes/archive/{YYYY-MM-DD}-{change-name}/specs/` and `verify-report.md` and `archive-report.md`. Follow `skills/_shared/openspec-convention.md`. Write `CHANGELOG.md` at the repository root if one exists; otherwise return the entry inline and do not fabricate a changelog file.
- **hybrid**: Follow BOTH conventions — persist to Engram AND write `CHANGELOG.md` on the filesystem.
- **none**: Return the release narrative inline only. Never create or modify any file.

## Step 1: Load Skills
Follow **Section A** from `skills/_shared/sdd-phase-common.md`.

## Step 2: Retrieve Final-State Artifacts

Retrieve the archived change's final artifacts per the persistence mode above. Read ALL of:

1. **spec** — to classify the change's severity (ADDED vs MODIFIED vs REMOVED vs RENAMED requirements).
2. **verify-report** — to state the evidence-backed outcome (verdict, tests passed, no CRITICAL remaining).
3. **archive-report** — to confirm the change's final state AT CLOSE (per the archive's Final-State Authority, not stale intermediate snapshots).

Never re-run verification and never re-read stale `apply-progress`/`verify-report` claims as current facts. The archive-report is the terminal record; if it is absent, return `blocked` — the changelog cannot be synthesized without the closed state.

## Step 3: Classify Semantic Version (SemVer)

Classify the release severity from the **spec's MODIFIED/REMOVED/ADDED/RENAMED requirements**, not from a subjective guess:

| Spec signal | SemVer bump |
|---|---|
| Any `REMOVED` requirement (breaking behavior/API removed) | **major** |
| Any `MODIFIED` requirement that changes existing behavior/contract | **minor** (or **major** if the archive-report or spec marks it as a breaking behavior change) |
| Only `ADDED` requirements (new behavior, no existing behavior changed) | **minor** |
| Only `RENAMED` requirements (pure rename, same behavior) | **patch** |
| Bug-fix / no external behavior change, per spec + archive | **patch** |
| Nothing that affects consumers | **none — no release** (see Step 4 opt-out) |

State the bump and its basis ("classed minor because MODIFIED requirement REQ-02 changes the existing contract").

## Step 4: Organic Opt-Out (no release)

If the spec and archive-report show **no consumer-facing change** (an internal refactor, a dependency-only bump, a private fix with no visible behavior change), do NOT fabricate a changelog entry:

- Return a status of `success` with `next_recommended: none` and an explicit note: *"no consumer-facing change — changelog entry omitted."*
- Do not invent a release note. Zero entries for a non-release is the correct organic output, mirroring how `sdd-quest` is skipped when its artifact is already `approved`.

## Step 5: Write the CHANGELOG Entry

If a release applies, produce the entry. Keep it honest, evidence-backed, and aligned with the verified outcome:

```markdown
## [Unreleased] - {YYYY-MM-DD}

### {Added | Changed | Fixed | Removed | Security}
- {behavior delivered, derived from an ADDED/MODIFIED requirement and its rationale}
- {second item}
```

Category mapping:
- **Added**: `ADDED` requirements
- **Changed**: `MODIFIED` requirements (behavior/contract change)
- **Fixed**: bug-fix changes (spec marks the change as a fix), patch class
- **Removed**: `REMOVED` requirements
- **Security**: explicitly flagged security fix in the spec/archive

Rules:
- Derive every line from a concrete requirement in the spec. Never invent behavior that the spec does not state.
- Keep it concise — a CHANGELOG entry is a short human summary, not the design.
- If `CHANGELOG.md` already has an `[Unreleased]` section, append under it; otherwise create the `[Unreleased]` section at the top.
- When persisting, write `CHANGELOG.md` only for `openspec`/`hybrid` modes and only when a repository `CHANGELOG.md` already exists or the user has a changelog convention. Otherwise return inline.

## Step 6: Persist Artifact

**This step is MANDATORY when a release applies — do NOT skip it.**

Follow **Section C** from `skills/_shared/sdd-phase-common.md`.
- artifact: `changelog`
- topic_key: `sdd/{change-name}/changelog`
- type: `architecture`

When no release applies (organic opt-out), you MAY skip persistence and return the no-release note inline; persistence is optional because there is no narrative to store.

## Step 7: Return Summary

Return to the orchestrator:

```markdown
## Changelog Generated

**Change**: {change-name}
**SemVer**: {major | minor | patch | none}
**Basis**: {the spec signal that drove the classification}

### Entry
{the CHANGELOG entry, or the no-release note}

### Notes
{any caveats, e.g. "breaking change — flag in the next release communication"}
```

## Rules

- NEVER modify, move, or delete any archived artifact (spec, verify-report, archive-report)
- NEVER re-run verification or claim a test outcome the verify-report does not state
- NEVER invent behavior not present in the spec
- If no consumer-facing change, emit the organic no-release opt-out (Step 4) instead of a fabricated entry
- Classify SemVer from the spec's MODIFIED/REMOVED/ADDED/RENAMED signals, never from commit history or prose
- This is a read-only narrative epilogue; it carries no review, delivery, or release authority — ordinary repository policy decides whether and how to publish
- Return envelope per **Section D** from `skills/_shared/sdd-phase-common.md`.
