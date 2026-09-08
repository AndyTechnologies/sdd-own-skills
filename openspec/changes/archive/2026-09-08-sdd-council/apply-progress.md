# Apply Progress: sdd-council (F4 Council Chain)

**Change**: sdd-council
**Mode**: Standard (strict_tdd=false)
**Delivery**: `size:exception` — single PR (~600-750 lines, review budget 800). Explicit per sdd-apply skill (task 5.1 of the orchestration contract: single-apply batch, one real sync, no commits).
**Store**: openspec (this file) + Engram mirror `sdd/sdd-council/apply-progress`.

## Status

**20/20 tasks complete — Ready for verify.**

## Work Unit Evidence (Hard Gate)

| Evidence | Required value |
|---|---|
| Focused test command and exact result | `./tests/run_red_checks.sh` — post-sync **39 PASS / 0 FAIL / 0 SKIP, exit 0** (baseline 31 + 8 new T32-T39; no regression), independently re-run in the verify phase (output sha256 `ab9434200082fc3d2bf0d96ce1acfc85863125041e4eace91ca57aaf46f2d29f`). Pre-sync numbers recorded during apply (32 PASS / 12 FAIL, T14 pty flake) are unreconstructible after the real sync and were superseded by the verify-phase re-run; verify also observed one truncated harness run caused by `/tmp` tmpfs quota exhaustion from stale sandbox dirs (247 × ~80MB), resolved by cleanup (see verify-report issues). |
| Runtime harness command/scenario and exact result | One real `./sync-skills.sh --skip-gentleai-sync` (R2 sequencing): **exit 0, "Estado: sincronizado", Errores 0** — installed skill `skills/sdd-council` (copy in `~/.config/sdd-own/` + 4 symlink targets), prompt `sdd-council.md` (OWN_PROMPTS, file symlinks opencode+claude), overlays applied (sdd-continue / sdd-ff: 1 bloque each), `opencode.jsonc` merged `[actualizado] (respaldo en .bak)`. Post-sync `./sync-skills.sh --check --skip-gentleai-sync` → 0 `[DESYNC]`, Errores 0, exit 0. Installed config verified: `.subagent_depth == 2`, 4 agents present, no `__managed_by`, orchestrator allow `sdd-council`, council `task` = `{"*":"deny",3 lenses:"allow"}`, arch-lint axis 2 deployed. |
| Rollback boundary (R3) | Additive merge; pre-value of `subagent_depth` preserved in `~/.config/opencode/opencode.jsonc.bak` (sync `.bak`, idempotent). To revert the key: `jq 'del(.subagent_depth)' ~/.config/opencode/opencode.jsonc` + revert `wiring/opencode.sdd.json` fragment + revert sync-skills.sh merge lines (jq L801, python L859-866) — see tasks.md rollback column. Skill revert: delete `skills/sdd-council/`, `wiring/prompts/sdd/sdd-council.md`, revert 4 agent blocs. Overlays: strip `cmd-sdd-continue-quest-support` / `cmd-sdd-ff-quest-support` blocks. No Alan base file was touched; nothing non-additive shipped. |

## Completed Tasks

- [x] 1.1 Create `skills/sdd-council/SKILL.md` (3 lens sections, parallel task() orchestration, convergence/fork/re-frame, 2-round cap, acta format, 6 invariants, steps 1-6, verdict envelope).
- [x] 1.2 Create `wiring/prompts/sdd/sdd-council.md` (file-based council prompt, sdd-rfc-author.md pattern).
- [x] 1.3 Register 4 agents in `wiring/opencode.sdd.json` (council file-prompt + 3 inline lenses; `{"*":"deny", lenses:"allow"}`; NO `__managed_by`; orchestrator allow-list + `sdd-council`).
- [x] 1.4 Add `sdd-council.md` to `OWN_PROMPTS` (`sync-skills.sh:105`).
- [x] 2.1 Add top-level `"subagent_depth": 2` to the fragment (only-SDD-keys exception, R1).
- [x] 2.2 Extend jq merge: `| .subagent_depth = ($f.subagent_depth // $u.subagent_depth)` — fragment-wins, idempotent.
- [x] 2.3 Extend python fallback: copy `frag["subagent_depth"]` when present — idempotent; agent logic/`.bak` (L891) untouched.
- [x] 2.4 Rewrite `orchestrator.md` rule 4: design → council (ALWAYS) → arch-lint (ALWAYS, acta mandatory) → gate; auto max 1 retry; convergence no interruption; forks → user alone; max 2 rounds STOP. F4 post-verify text + consent strings byte-stable (T31 passes).
- [x] 2.5 Extend hooks item 3 to council → arch-lint(acta) → gate (T32).
- [x] 3.1 Axis 2 in `skills/sdd-architecture-lint/SKILL.md`: acta decisions title-by-title (✅/⚠️/❌); acta MANDATORY fail-closed; `N/A` only empty/trivial; axis 1 unchanged (T35).
- [x] 3.2 `overlays/commands/sdd-continue.md` SUPPORT-CONDITIONAL: council ALWAYS → arch-lint(acta) ALWAYS; boundary skip dropped.
- [x] 3.3 `overlays/commands/sdd-ff.md` item 6: ALWAYS council → arch-lint(acta).
- [x] 4.1 T32-T36 appended (council always-fire pins, wiring asserts, OWN_PROMPTS, acta fail-closed, convergence/fork/2-round).
- [x] 4.2 T37 no-`mcp` on FRAGMENT only + sanctioned-keys assert.
- [x] 4.3 T38 `.subagent_depth == 2` fragment AND installed (jsonc-first detection).
- [x] 4.4 T39 extended merge BOTH engines: `--check` with jq; python leg forced via PATH shim (jq holders `/usr/sbin /bin /sbin /usr/bin` dropped; full-dir shim re-provides tooling); zero DESYNC both.
- [x] 4.5 `AGENTS.md` merge-rules sanctioned-exception note (R1) + prompts-dir listing gains `sdd-council.md`.
- [x] 5.1 R2: pre-sync RED run (expected DESYNC-class failures documented above) → one real `./sync-skills.sh --skip-gentleai-sync` → T30 comment "full sync applied by orchestration" convention preserved.
- [x] 5.2 R3: rollback-leak documented (see Work Unit Evidence rollback row + Risks).
- [x] 5.3 Final: `./sync-skills.sh --check --skip-gentleai-sync` → 0 desyncs, Errores 0, exit 0 AND `./tests/run_red_checks.sh` green (39 PASS).

## Files Changed

| File | Action | What Was Done |
|------|--------|---------------|
| `skills/sdd-council/SKILL.md` | Created | Council skill: 6 HARD invariants, 3 `## Lens:` sections, Steps 1-6, acta format, verdict envelope |
| `wiring/prompts/sdd/sdd-council.md` | Created | File-based council prompt (lens dispatch, convergence vs fork framing) |
| `wiring/opencode.sdd.json` | Modified | 4 new agents + `subagent_depth: 2`; orchestrator allow-list gains `sdd-council` |
| `sync-skills.sh` | Modified | `OWN_PROMPTS` (L105); jq merge (L801); python fallback (~L859-866) carry `subagent_depth` |
| `wiring/prompts/sdd/orchestrator.md` | Modified | Rule 4 rewritten (council chain ALWAYS); hooks item 3 extended; F4 post-verify + consent byte-stable |
| `skills/sdd-architecture-lint/SKILL.md` | Modified | Axis 2 (acta title-by-title, mandatory fail-closed); opt-out narrowed to empty/trivial; lens headers normalized to `## Lens:` |
| `overlays/commands/sdd-continue.md` | Modified | SUPPORT-CONDITIONAL: council ALWAYS → arch-lint(acta) ALWAYS (block id unchanged) |
| `overlays/commands/sdd-ff.md` | Modified | Item 6 flipped to ALWAYS council → arch-lint(acta) (block id unchanged) |
| `tests/run_red_checks.sh` | Modified | T32-T39 appended; coverage map updated; T32 pattern fix (backtick escaping) |
| `AGENTS.md` | Modified | R1 sanctioned-exception note in merge rules; prompts-dir brace listing + `sdd-council.md` |
| `openspec/changes/sdd-council/tasks.md` | Modified | All 20 tasks marked `[x]` |

## Deviations from Design

- **Real sync run as `./sync-skills.sh --skip-gentleai-sync`** (not bare): per AGENTS.md rule 5 and the apply-time decision, avoiding destructive step-0 `gentle-ai sync`. Idempotent wiring verified by the T39 python-leg check and the post-sync `--check`. No deviation in delivered behavior.
- **Lens headers normalized** to `## Lens: Architecture / Product/UX / Risk/Resilience` (were `###` under `## Lens Sections`) so the inline lens-agent prompts' `## Lens:` references resolve verbatim. Cosmetic; no contract change.
- **None otherwise — implementation matches design.**

## Issues Found

- **T14 pty timeout in the full-suite pre-sync run (4 fails, exit 201)**: proven ENVIRONMENTAL flake — the identical scenario (fresh sandbox, 401-first fake API, same pty answers) passes in **1s** in isolation (2026-09-08 repro). setup.sh MCP is untouched by this change; not a regression. Re-ran clean inside the final suite.
- **T32 harness pattern**: my first T32 grep used `\`` (backslash-backtick) inside single quotes → literal backslash, no match. Fixed to plain backticks; verified matching before the post-sync run.
- **Pre-sync RED expectations (R2)**: T05/T21/T30/T38/T39 fail pre-sync by design (green-pins on `sync --check` state that only a real sync can satisfy; T38 needs the installed config deployed). All green post-sync.

## Remaining Tasks

- None — apply complete. Hand back to orchestrator for `sdd-verify`.

## Workload / PR Boundary

- Mode: `size:exception` (single PR)
- Current work unit: N/A (single-apply batch covering tasks 1.1-5.3)
- Boundary: from canonical repo sources (`skills/`, `wiring/`, `overlays/`, `tests/`, `AGENTS.md`) to the deployed state (real sync applied, idempotent)
- Estimated review budget impact: ~600-750 changed lines; budget 800 reserved (400-line default overridden by `size:exception`)
- **R3 rollback leak (documented per task 5.2)**: the additive merge and sync `.bak` (stale Sep 4 pre-value) mean a rollback of ONLY the fragment would leak `subagent_depth` in the installed config — rollback MUST be the 3-part boundary: `jq 'del(.subagent_depth)'` installed + revert fragment + revert sync merge lines.

## Status

20/20 tasks complete. **Ready for verify.**