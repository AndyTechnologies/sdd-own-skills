# Tasks: Architecture Principles — Quest Branch, Lint Axis 3, Plan Checklist

## Review Workload Forecast

1800–2500 changed lines · High risk · single PR, accepted `size:exception` (baseline import)

Decision needed before apply: No
Chained PRs recommended: No
Chain strategy: size-exception
400-line budget risk: High

### Work Units (all PR 1)

- **U1 Baseline import** (bytes/agent/pins): test `bash tests/run_red_checks.sh`; harness `bash sync-skills.sh --check`; rollback revert f9ec832
- **U2 Catalog + shared-loop**: test `rg "## Principles" skills/_shared/architecture-principles.md`; harness `--check` re-run keeps bytes; rollback drop catalog+loop
- **U3 Quest rework**: test RED T53; harness N/A (TTY); rollback revert `skills/sdd-quest/SKILL.md`
- **U4 Lint axis 3**: test RED T55–T59; harness fixtures+`expected.json`; rollback revert `skills/sdd-architecture-lint/SKILL.md`
- **U5 Plan checklist**: test RED T54; harness missing-checklist→fail; rollback revert prompt+T35
- **U6 Fixtures+suite**: test `bash tests/run_red_checks.sh`; harness real suite < 2 min; rollback drop fixtures+T49–T60

## Phase 1: Baseline Import (atomic first)

- [x] 1.1 Pins in `tests/run_red_checks.sh`: T34→7 prompts; T35+=axis-3/checklist strings; T37 shape (B6) — T34→7 ✓, T37 ✓ (validates); `T35+=axis-3/checklist` done in U4 (T35 axis-3 strings) + U5 (T54 plan checklist)
- [x] 1.2 Copy `skills/sdd-quest/SKILL.md` `skills/sdd-architecture-lint/SKILL.md` from `~/.config/sdd-own/skills/` (read-only), byte-exact (B1/B2)
- [x] 1.3 Copy `wiring/prompts/sdd/orchestrator.md` + `sdd-architecture-plan.md` `sdd-hard-gate.md` `sdd-hard-verify.md` `sdd-pre-experience.md` from `~/.config/sdd-own/prompts/sdd/` (read-only), orchestrator file-ref (B3/B4)
- [x] 1.4 Add `sdd-architecture-plan` agent ({file:./prompts/sdd/sdd-architecture-plan.md}) to `wiring/opencode.sdd.json` + 4 prompts to `OWN_PROMPTS` in `sync-skills.sh`

## Phase 2: Catalog + Shared Loop

- [x] 2.1 RED T49/T51: P01..P10 labels, A01..A11 rows, severities, single path, no shebang
- [x] 2.2 RED T52: 4 SHARED loops + copy-only-if-missing + `--check` zero
- [x] 2.3 Create `skills/_shared/architecture-principles.md`: `## Principles` (10× P, fields Definition/Concrete evidence/Default severity) + `## Anti-patterns` table `| ID | Name | Definition | Concrete evidence | Default severity |` (11 rows), English
- [x] 2.4 Add `architecture-principles.md` to 4 SHARED loop sites in `sync-skills.sh` (NOTA: son 5 sitios reales, no 4 — ver apply-progress U2)

## Phase 3: Quest Architecture Branch Rework

- [x] 3.1 RED T53: 8 base Qs + stack; table cols trigger/IDs/questions/early-stop/precedence; budget 20; gaps decision|knowledge|blocking
- [x] 3.2 Rework arch branch in `skills/sdd-quest/SKILL.md`: 8 context Qs first, never principle-by-principle
- [x] 3.3 Branch table: microservice + stack triggers, catalog IDs by path, precedence, early-stop
- [x] 3.4 Stack gate: yes→tech branch; no→skip; confirmed-no-branch→driver + early-stop
- [x] 3.5 Budget 20 + early-stop + consolidation report with classified gaps

## Phase 4: Lint Axis 3

- [x] 4.1 RED T50: S4 cross-check catalog↔lint checks by ID, both directions
- [x] 4.2 Axis 3 in `skills/sdd-architecture-lint/SKILL.md`: checks P01..P10/A01..A11 by catalog path, findings `{id, severity, evidence}`
- [x] 4.3 Verdict `axis_3 pass|fail` (fail iff ≥1 blocker); blocker|warning; ambiguous→warning
- [x] 4.4 Acta interplay (D3): `n-a-justified` suppresses, justification visible; contradiction→dual signal (L6/C7)

## Phase 5: Plan Checklist

- [x] 5.1 RED T54: literal `## Principios no verificables`; translated rejected; missing → axis 2 fail-closed (C1/C2)
- [x] 5.2 Checklist contract in `wiring/prompts/sdd/sdd-architecture-plan.md`: 21 rows, 3 states, evidence/justification mandatory, never omitted

## Phase 6: Fixtures + RED Integration

- [x] 6.1 Create `tests/fixtures/arch-principles/`: clean, 21 dirty, multi, missing-checklist, translated-anchor, `expected.json`
- [x] 6.2 T55–T60 in `tests/run_red_checks.sh`: axis-3 comparisons (pass/fail IDs, full set, warning, N/A, dual) + wiring (agent key + allow-list)
- [x] 6.3 Full `bash tests/run_red_checks.sh`: T01–T48/T42b/T47b + T49–T60 green, < 2 min