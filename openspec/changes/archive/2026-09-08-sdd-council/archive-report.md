# Archive Report: sdd-council

**Change**: sdd-council (F4 Council Chain)
**Archived**: 2026-09-08
**Archive location**: `openspec/changes/archive/2026-09-08-sdd-council/`
**Stores**: openspec (repo-local at `openspec/`) + Engram mirror (topic `sdd/sdd-council/archive-report`)
**Preflight**: auto / both / single-pr (`size:exception` approved) / review budget 800 lines; `strict_tdd=false`

## Final State (at close)

The change is fully implemented, verified, and closed. Final-state facts below follow the archive Final-State Authority hierarchy: the persisted tasks artifact and the orchestrator's explicit final-state facts (highest rank) supersede intermediate snapshot claims in `apply-progress.md` / `verify-report.md`.

| Fact | Value |
|------|-------|
| Verify verdict | PASS WITH WARNINGS — 14/14 requirements, 28/28 scenarios COMPLIANT, 0 CRITICAL, 0 WARNING-blocking, 0 blockers. Validated via `gentle-ai sdd-verify-validate --requirements 14 --scenarios 28` → `valid: true`. |
| Tasks | 20/20 complete (`[x]` in tasks.md; 0 unchecked). The "19/19" wording in early `apply-progress.md` versions was a task-count error corrected during verify; the operative count is 20/20 (tasks: 4+5+3+5+3). |
| Red suite | `./tests/run_red_checks.sh` — **39 PASS / 0 FAIL / 0 SKIP**, exit 0 (T32–T39 green incl. T38 root `subagent_depth` fragment+installed, T39 both merge engines jq+python, T37 fragment-only no-`mcp`; baseline 31 unchanged, no regression). Output sha256 `ab9434200082fc3d2bf0d96ce1acfc85863125041e4eace91ca57aaf46f2d29f`. |
| Build | `bash -n sync-skills.sh` — exit 0 (sha256 `e3b0c442…`) |
| Rollout sync | One real `./sync-skills.sh --skip-gentleai-sync` ran during apply (R2 sequencing): **exit 0, "Estado: sincronizado", Errores 0**. Post-sync `./sync-skills.sh --check --skip-gentleai-sync` → **0 `[DESYNC]`, Errores 0, exit 0**. |
| Installed state | `opencode.jsonc` merged (`subagent_depth == 2`, respaldo en `.bak`); skill `sdd-council` deployed via `~/.config/sdd-own/` + 4 symlink targets; prompt `sdd-council.md` in `OWN_PROMPTS`, symlinks opencode+claude; overlays applied (sdd-continue/sdd-ff, 1 bloque each); 4 agents present, no `__managed_by`, orchestrator allow `sdd-council`, council `task` allow-list `{"*":"deny", 3 lenses:"allow"}`; arch-lint axis 2 deployed. |
| Main specs | `openspec/specs/sdd-council/spec.md` — Created (full spec, 9 requirements, 16 scenarios). `openspec/specs/workflow-contract/spec.md` — Updated via native composition (1 MODIFIED + 4 ADDED; 13 requirements, 35 scenarios; 8 unrelated requirements preserved byte-for-byte). |
| Non-blocking findings (recorded, NOT open issues) | WARNING env: `/tmp` tmpfs quota exhaustion from stale sandbox dirs truncated one harness run (environmental, resolved by cleanup; action: clean `/tmp/sdd-red.*` before harness runs). SUGGESTION cosmetic: orchestrator.md L362 organic-phase list omits council (no functional gap — wired via hooks item 3). |

No work occurred after `verify-report.md` was persisted that changes any completeness fact: `apply-progress.md` and `verify-report.md` describe the same 20/20 tasks, 39-test suite, and deployed state as the close-state above.

## Archived Capabilities

- **New capability `sdd-council`**: skill `skills/sdd-council/SKILL.md` (3 lens sections arch/product/risk, parallel `task()` orchestration, convergence/fork/re-frame rules, 2-round hard cap, acta format, 6 HARD invariants); file-based prompt `wiring/prompts/sdd/sdd-council.md` (in `OWN_PROMPTS`); 4 agents in `wiring/opencode.sdd.json` (`sdd-council` + `sdd-council-arch`/`-product`/`-risk`, no `__managed_by`, no `mcp`); orchestrator `task` allow-list gains `sdd-council`.
- **Modified capability `workflow-contract`**: council-chain requirement gains machinery — rule 4 rewrite (design → council ALWAYS → arch-lint ALWAYS acta-mandatory → gate; auto max 1 retry then STOP; convergence no interruption; forks → user; max 2 rounds), Organic Support Phase Hooks item 3, arch-lint axis 2 (acta title-by-title, fail-closed on missing, `N/A` only empty/trivial design), command overlays sdd-continue SUPPORT-CONDITIONAL + sdd-ff item 6 (ALWAYS council → arch-lint(acta)), RED checks T32–T39, ROOT `subagent_depth: 2` (only-SDD-keys sanctioned exception R1, carried by both merge engines), AGENTS.md merge-rules sanction note.

## Spec Sync

| Domain | Action | Details |
|--------|--------|---------|
| sdd-council | Created | Full-domain spec copied mechanically to `openspec/specs/sdd-council/spec.md` (9 requirements, 16 scenarios); `diff -r` source-vs-destination readback EMPTY (byte-identical, exit 0) |
| workflow-contract | Updated | Native composition via `gentle-ai sdd-archive-compose --canonical openspec/specs/workflow-contract/spec.md --delta openspec/changes/sdd-council/specs/workflow-contract/spec.md --output openspec/specs/workflow-contract/spec.md.compose-tmp && mv …` — exit 0. MODIFIED `Council-chain target flow`; ADDED `Orchestrator rule 4 and organic hooks rewrite`, `Arch-lint axis 2 (acta verification)`, `Command overlay council chain`, `RED checks T32+`. All 8 unrelated requirements preserved (No-raw-git delegation, Untrusted-data fail-closed, External-knowledge-gap research routing, Worktree lifecycle contract, Bounded parallelism, Result-contract strictness, Config-protection, Post-verify RDD hook). No REMOVED/RENAMED sections; no destructive merge — config.yaml `rules.archive` warning not triggered. |

## Archive Move

- Source `openspec/changes/sdd-council/` moved to `openspec/changes/archive/2026-09-08-sdd-council/`. `git mv` refused ("fatal: source directory is empty" — the change folder is untracked in git; no commits were made during the SDD cycle per repo rule). The skill-mandated fallback verified the source unchanged against the pre-move recursive snapshot (`diff -r` empty, exit 0), confirmed no destination collision, then used plain `mv` (filesystem operation, compliant with the `no-git-crudo` contract — no raw git mutation commands run).
- **MANDATORY readback**: verbatim `diff -r "$snapshot_root/source" "$destination"` output below — EMPTY (no differences), exit 0:

```text
diff -r openspec/changes/sdd-council <snapshot>/source <destination>
(no output — byte-identical)
```

- Archive contains all artifacts: quest.md, exploration.md, proposal.md, specs/sdd-council/spec.md, specs/workflow-contract/spec.md, design.md, tasks.md, apply-progress.md, verify-report.md (+ this additive archive-report.md, excluded from the readback).
- Archived `tasks.md`: 20/20 `[x]`, 0 unchecked — Task Completion Gate passed with no reconciliation needed.
- Active changes directory no longer contains this change (`openspec/changes/` holds only `archive/`).

## Verification Summary

Per `verify-report.md` (intermediate snapshot, corroborated by the close-state facts above): spec compliance matrix 28/28 scenarios COMPLIANT across 14 requirements (21 pin-proven by direct grep, 7 pin-family + static clause verification); coherence table confirms all design decisions followed (single skill + 3 lens sections, file-based council prompt + inline lenses, `subagent_depth: 2` via both merge engines, arch-lint `N/A` narrowed, single acta writer, organic support phase absent from `nextRecommended`). F4 post-verify text and consent strings byte-stable (T31 green; git diff exactly 2 hunks: hooks item 3 + rule 4).

## Task Completion Gate

Passed: the persisted tasks artifact (`openspec/changes/sdd-council/tasks.md` at archive time, byte-identical to the archived copy) shows all 20 tasks checked `[x]` across phases 1–5. No unchecked implementation tasks; no stale-checkbox reconciliation was required. `sdd-apply` marked completion; this archive validates, not re-owns, that state.

## Rollback Path (R3 — 3-part boundary, documented per task 5.2)

1. `jq 'del(.subagent_depth)' ~/.config/opencode/opencode.jsonc` (installed config; additive merge means fragment-only revert would leak the key — the pre-value sits in the sync `.bak`, stale Sep 4).
2. Revert `wiring/opencode.sdd.json` fragment (drop `subagent_depth`, the 4 council agent blocs, and the orchestrator allow-list entry).
3. Revert `sync-skills.sh` merge lines (jq L801, python L859–866) and `OWN_PROMPTS` addition; delete `skills/sdd-council/` and `wiring/prompts/sdd/sdd-council.md`; strip overlay blocks `cmd-sdd-continue-quest-support` / `cmd-sdd-ff-quest-support` (idempotent by marker id); revert orchestrator.md rule 4 + hooks item 3, arch-lint axis 2, and RED checks T32–T39.
4. Run `./sync-skills.sh --check` to confirm zero desyncs after rollback.

No migration data to roll back — council is additive machinery; no Alan base file was touched (strip+append mechanic only).

## Follow-ups (non-blocking, recorded from verify-report; NOT open issues)

1. **WARNING (environment / test hygiene)**: `/tmp` tmpfs quota exhaustion from accumulated sandbox dirs (247 × ~80MB from prior runs) truncated one harness run during verify (`Disk quota exceeded` Errno 122 in `fake_api.py`/`sandbox.sh`); resolved by cleanup + clean re-run 39/39. Same class plausibly explains the apply-era T14 pty flake (proven environmental: identical scenario passes in 1s in isolation). Action for future runs: clean `/tmp/sdd-red.*` before the harness.
2. **SUGGESTION (style, cosmetic)**: orchestrator.md L362 organic-phase intro names quest/research/arch-lint/changelog but not council; council is correctly wired in hooks item 3 ("organic phases never join nextRecommended"), so there is no functional gap — a future cosmetic pass could add council to that list.

## Traceability — Artifacts Read (openspec store)

| Artifact | Path (at archive time) |
|----------|------------------------|
| Quest (approved RFC) | `openspec/changes/sdd-council/quest.md` |
| Proposal | `openspec/changes/sdd-council/proposal.md` |
| Design (Option A) | `openspec/changes/sdd-council/design.md` |
| Delta spec (sdd-council) | `openspec/changes/sdd-council/specs/sdd-council/spec.md` |
| Delta spec (workflow-contract) | `openspec/changes/sdd-council/specs/workflow-contract/spec.md` |
| Tasks | `openspec/changes/sdd-council/tasks.md` |
| Apply progress | `openspec/changes/sdd-council/apply-progress.md` |
| Verify report | `openspec/changes/sdd-council/verify-report.md` |

Engram mirror of this report: topic `sdd/sdd-council/archive-report` (type architecture, capture_prompt false).