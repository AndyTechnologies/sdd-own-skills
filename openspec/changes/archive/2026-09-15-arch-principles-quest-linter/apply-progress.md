# Apply Progress — arch-principles-quest-linter

- **Work unit**: U1 — Baseline import (bytes/agent/pins)
- **Date**: 2026-09-15
- **Executor**: sdd-apply
- **Mode**: Strict TDD (test runner: `bash tests/run_red_checks.sh`)
- **Artifact store**: hybrid (openspec repo + engram)
- **Rollback token**: HEAD `f9ec832` (worktree `sdd/arch-principles-quest-linter`)

## Scope executed (this batch)

1. Byte-exact import from `~/.config/sdd-own/` (read-only source) into the repo:
   - `skills/sdd-quest/SKILL.md` (deployed quest v4.0)
   - `skills/sdd-architecture-lint/SKILL.md` (deployed lint v2.0)
   - `wiring/prompts/sdd/orchestrator.md` (deployed orchestrator bytes)
   - `wiring/prompts/sdd/{sdd-architecture-plan,sdd-hard-gate,sdd-hard-verify,sdd-pre-experience}.md` (4 unversioned prompts)
2. Wiring: added `sdd-architecture-plan` agent (verbatim deployed definition, file-based prompt) + orchestrator allow entry in `wiring/opencode.sdd.json`.
3. `sync-skills.sh`: `OWN_PROMPTS` extended from 3 to 7 entries.
4. RED suite pin co-update in `tests/run_red_checks.sh`: T34 literal → 7 prompts; T32 + T36 orchestrator legs re-anchored to the deployed (post-council) contract strings.

## Files changed

| File | Action | What Was Done |
|------|--------|---------------|
| `skills/sdd-quest/SKILL.md` | Replaced (byte-exact) | Deployed quest v4.0 imported, 18467 B |
| `skills/sdd-architecture-lint/SKILL.md` | Replaced (byte-exact) | Deployed lint v2.0 imported, 11494 B |
| `wiring/prompts/sdd/orchestrator.md` | Replaced (byte-exact) | Deployed orchestrator imported, 93659 B |
| `wiring/prompts/sdd/sdd-architecture-plan.md` | Created | Imported, 7252 B |
| `wiring/prompts/sdd/sdd-hard-gate.md` | Created | Imported, 7474 B |
| `wiring/prompts/sdd/sdd-hard-verify.md` | Created | Imported, 7350 B |
| `wiring/prompts/sdd/sdd-pre-experience.md` | Created | Imported, 5873 B |
| `wiring/opencode.sdd.json` | Modified | `sdd-architecture-plan` agent (deployed verbatim) + orchestrator `task` allow |
| `sync-skills.sh` | Modified | `OWN_PROMPTS` → 7 entries |
| `tests/run_red_checks.sh` | Modified | T34 literal (7 prompts); T32/T36 orchestrator legs re-anchored; header T32 title |

Byte-compare: md5(repo) == md5(deployed) for all 7 imported files (verify step below).

## TDD Cycle Evidence (strict TDD — suite pins as the tests)

| Task | RED (test written first) | GREEN (implementation passes) | REFACTOR |
|------|--------------------------|-------------------------------|----------|
| 1.2 quest + lint bytes (B1/B2) | Baseline suite red on these surfaces: repo bytes ≠ deployed (md5: quest `caa8d6a0…` vs `fd83db42…`; lint `dce258e6…` vs `c379c43c…`) → T30/T39 desync legs red. T35 pins already assert the v2.0 strings. | Imported byte-exact. T35 PASS (5/5 v2.0 strings + 3 council lenses); quest/lint desync legs cleared. | None |
| 1.3 orchestrator + 4 prompts (B3/B4) | T32/T36 re-anchored pins written FIRST against the deployed orchestrator's strings (they FAIL against the pre-import repo orchestrator — test-before-implementation honored). T34 file-pins + T31/T48 exist. | Imported orchestrator + 4 prompts. T32 PASS (5/5), T36 PASS (3/3), T31 PASS (8/8), T48 PASS. Prompt FALTA condition cleared. | None |
| 1.4 agent (B5) | Fragment-vs-installed wiring desync leg red (agent absent from fragment while deployed config carries it). | Agent added verbatim (definition byte-identical to deployed via jq field compare); orchestrator allow entry added. Agent defs now fragment == installed (10/10 SAME). | None |
| 1.1 pins (B6) | T34 literal updated to the 7-entry array before OWN_PROMPTS sync (would fail against the old 3-entry array). | `OWN_PROMPTS` → 7 entries; T34 PASS. T37 unchanged and PASS (keys stay `["$schema","agent","default_agent","subagent_depth"]`). T35/T37 required NO change — verified validate. `T35+=axis-3/checklist strings` deferred to U4/U5 per preflight narrowing. | None |

## Work Unit Evidence

| Evidence | Required value |
|----------|----------------|
| Focused test command and exact result | `bash tests/run_red_checks.sh` → **PASS 46 / FAIL 6 / SKIP 0, 58s** (baseline 45/7/0). Every pin this batch owns is green: T31, T32, T33, T34, T35, T36, T37, T38, T48. Zero new failures. The baseline's 7th failure (preflight T15-class flake) passed this run; the remaining 6 FAILs are exactly the pre-existing later-slice desync classes. |
| Runtime harness command/scenario and exact result | `./sync-skills.sh --check --skip-gentleai-sync` → 0 errors; residual 4 DESYNC lines are later-slice surfaces only: `skills/sdd-changelog/SKILL.md`, `skills/sdd-council/SKILL.md`, `wiring/prompts/sdd/sdd-rfc-author.md`, `opencode.jsonc` (user-managed allow-list trio `sdd-hard-gate`/`sdd-hard-verify`/`sdd-pre-experience` — out of scope). Quest/lint/orchestrator/4-prompts/agent surfaces: zero desyncs. |
| Rollback boundary | `git revert f9ec832` (HEAD) drops all 10 worktree changes (6 modified + 4 untracked prompts). Imported deployed state was never written back to `~/.config/sdd-own/` or any installed runtime config — the deployed tree stayed read-only source. |

## Scope mapping — remaining suite FAILs (6)

| Check | Class | Owner |
|-------|-------|-------|
| T05 (no-mutation host) | Pre-existing; greens as the change syncs (preflight-classified) | Later slices |
| T21 (regression + README F7) | Pre-existing; greens as the change syncs (preflight-classified) | Later slices |
| T30 ×2 (sync idempotency + id hygiene) | `--check` desyncs = 4 → all 4 are later-slice surfaces (above) | Later slices |
| T39 ×2 (merge both engines) | same residual desyncs (jq leg 4, python leg 2) | Later slices |
| (T15) | Pre-existing setup.sh 5d-2 mtime-churn defect — passed this run (flake); genuine fix OUT of scope of this change | Follow-up |

## Deviations from design / preflight

1. **T32/T36 orchestrator-leg re-anchor** (deviation from the preflight's literal pin list, which named T34/T35/T37): byte-importing the deployed orchestrator necessarily invalidates the council-era pins (`design → council (ALWAYS) …`, `MANDATORY input`, `does NOT interrupt the user`, `Max 2 rounds`, …). Re-anchored them to the exact strings the imported bytes contain (`Council SHALL NOT run anywhere in the flow`, `arch-lint (POST-apply, ALWAYS)`, `acta mandatory and fail-closed when missing`, `never self-audit, never inline`, `relaunches design with the findings`, `WITHOUT interrupting the user`, `a genuine scope/product decision`, `max 2 rounds`). Required by the preflight's own success criterion ("no NEW failure") and task 6.3 (full suite green); no later work unit touches these pins. Governance intent preserved: council delisted from canonical flow (acta D8), lint ALWAYS post-apply with acta fail-closed (D5), 2-round budget STOP.
2. **T35/T37 no change**: the preflight's "exact lint strings from v2.0" already validate against the imported lint (5/5) and the fragment keys stay sanctioned — verified, not edited.
3. **Task 1.1 `T35+=axis-3/checklist strings`** deferred to U4/U5 (preflight narrowing for this run).
4. Council/changelog/rfc-author skill+pipeline desyncs remain unimported — they belong to later work units (U2–U6), consistent with the baseline classification.

## Issues found

1. First copy attempt used wrong deployed path (`wiring/prompts/sdd/…` — deployed prompts live at `~/.config/sdd-own/prompts/sdd/`); corrected and byte-verified.
2. `opencode.jsonc` residual desync: user-managed allow-list trio in the orchestrator (`sdd-hard-gate`, `sdd-hard-verify`, `sdd-pre-experience`) — preflight forbids adding them to the fragment; desync clears only if the user aligns those allow entries (reported, out of scope).
3. T15 flake observed (passed this run): preflight-documented setup.sh 5d-2 real-mode recompile mtime churn — genuine defect, follow-up outside this change.
4. `rtk` display wrapper truncates long lines (even into files); byte-fidelity captures used plain `jq`.

## Status

Phase 1: 3 of 4 tasks complete (1.2, 1.3, 1.4); 1.1 partially complete (T34→7 ✓, T37 ✓; T35+=axis-3/checklist pending U4/U5). **U1 done — no new failures, all owned pins green. Next batch: U2 (catalog + shared loop).**

---

# Apply Progress U2 — arch-principles-quest-linter

- **Work unit**: U2 — Catalog + shared loop (Phase 2: tasks 2.1–2.4)
- **Date**: 2026-09-15 (U2 batch)
- **Executor**: sdd-apply
- **Mode**: Strict TDD (test runner: `bash tests/run_red_checks.sh`)
- **Artifact store**: hybrid (openspec repo + engram)
- **Rollback token**: `git revert f9ec832` + drop catalog file + loop join (see WU evidence)

## Scope executed (this batch)

1. `skills/_shared/architecture-principles.md` created — single source of truth (S3/S4):
   - `## Principles`: 10× `### P01..P10 — <name>` with `- Definition:` / `- Concrete evidence:` / `- Default severity: blocker` (P-names = acta P-seeds, arch-plan checklist)
   - `## Anti-patterns`: table `| ID | Name | Definition | Concrete evidence | Default severity |` with 11 rows A01..A11 (RFC binding 11, D3 order), all `blocker`, English
2. `sync-skills.sh`: catalog joined into **ALL 5** (not 4) shared-loop sites — `for f in "${SHARED_BOOTSTRAP[@]}" codegraph.md architecture-principles.md; do` at lines 541/548/600/606/613 (install dest1 ~/.config/sdd-own, check dest1, DRY_RUN dest2, check dest2, install dest2 ~/.agents) — copy-only-if-missing preserved (2 guards "ya existe (no se toca)", 2 `cp "$SHARED_SRC_DIR/$f"` intact).
3. Comment co-update in `sync-skills.sh`: "9 archivos" → "10 archivos" (lines 26/37/48/597) to match the new 10-file shared set (8 bootstrap + codegraph.md + architecture-principles.md).
4. **Pin defect corrections in `tests/run_red_checks.sh` T52** (documented below as deviations): base-loop pattern dropped the `; do` suffix; runtime leg now uses `env HOME="$REAL_HOME"`.

## Files changed (U2)

| File | Action | What Was Done |
|------|--------|---------------|
| `skills/_shared/architecture-principles.md` | Created | Catalog: 10 P + 11 A, schema per D2, English |
| `sync-skills.sh` | Modified | Catalog joined into 5 shared loops; "10 archivos" comments |
| `tests/run_red_checks.sh` | Modified | T52 pin corrections (2) — see Deviations |
| `openspec/changes/arch-principles-quest-linter/tasks.md` | Modified | 2.1–2.4 marked [x] |

## TDD Cycle Evidence (strict TDD — suite pins as the tests)

| Task | RED (test written first) | GREEN (implementation passes) | REFACTOR |
|------|--------------------------|-------------------------------|----------|
| 2.1 RED T49/T51 (catalog schema/corpus + single path) | Pre-implementation suite RED: T49 10 kos (catalog absent + schema fields 0/10, rows 0/11, severities 0) + T51 2 kos (absent + "corpus duplicado: 0 archivos con ## Principles (esperado 1)"). | Catalog authored → T49 PASS (P-count 10/10, fields 10/10 each, A-rows 11/11, header exact, severities blocker 10+11); T51 PASS (heads==1, no shebang). | None |
| 2.2 RED T52 (shared-loop join, copy-only-if-missing, --check) | Pre-implementation suite RED (after pin corrections): T52 ko "catalog no unido a TODOS los loops shared (0/5; debe igualar codegraph.md)" + "check no reconoce el catalog en el loop shared". | Loop join at all 5 sites → T52 PASS: loops_cat==loops_base==5, guard ≥2, cp SHARED_SRC present, leg `--check` (REAL_HOME) recognizes catalog + `Errores: 0`. | None |
| 2.3/2.4 (catalog content + loop wiring) | Same RED as above (T49/T51/T52 fail while catalog absent / unjoined). | Catalog + join complete. Host re-run: `Actualizados: 6` (4→6), `Errores: 0`, `[FALTA]` for the catalog at BOTH destinations, exit 0. | None |

Run sequence evidence:

```
RED (corrected pins, pre-implementation): PASS: 46   FAIL: 21   SKIP: 0   (57s total)
  → T52 kos present are exactly 2 genuine: counting 0/5 + catalog-unrecognized.
     (The old 3rd ko "check con errores estructurales (regresion S1)" DISAPPEARED →
      proof the REAL_HOME correction removed a harness artifact, not a real signal.)
GREEN (implementation):             PASS: 49   FAIL: 6    SKIP: 0   (57s total)
  → 6 FAIL = exactly the pre-existing later-slice classes (T05, T21, T30×2, T39×2).
     Zero new failures. T49/T51/T52 all PASS.
```

## Work Unit Evidence

| Evidence | Required value |
|----------|----------------|
| Focused test command and exact result | `bash tests/run_red_checks.sh` → RED: **PASS 46 / FAIL 21** (pre-implementation, corrected pins, 57s); GREEN: **PASS 49 / FAIL 6** (57s). T49 PASS, T51 PASS, T52 PASS; no new failures beyond the pre-existing 6 later-slice classes. |
| Runtime harness command/scenario and exact result | `./sync-skills.sh --check --skip-gentleai-sync` → exit 0, `Errores: 0`, `Actualizados: 6` (was 4 → +2: the catalog at both destinations), `[FALTA] ~/.config/sdd-own/skills/_shared/architecture-principles.md` + `[FALTA] .agents/skills/_shared/architecture-principles.md`. Residual 4 DESYNC = later-slice surfaces only (changelog, council, rfc-author, opencode.jsonc). The T52 leg itself runs the same check under `REAL_HOME` and greps `architecture-principles\.md` + `Errores: 0` → PASS. |
| Rollback boundary | Drop the catalog file (`rm skills/_shared/architecture-principles.md`), revert the 5 loop-join lines + "10 archivos" comment edits in `sync-skills.sh` (or git checkout that file), revert the 2 T52 pin corrections in `tests/run_red_checks.sh`, unmark 2.1–2.4. Nothing else touched — quest/lint/orchestrator/prompts/agent bytes from U1 and all pre-existing state stay intact. |

## Deviations from design / tasks — PIN DEFECTS FOUND AND CORRECTED (must be surfaced, not silent)

1. **Tasks/design count "4 SHARED loops" — the real script has 5 loop sites.** Design D7 line 17 and tasks 2.2/2.4 say 4; empirically `sync-skills.sh` has **5** identical `for f in "${SHARED_BOOTSTRAP[@]}" codegraph.md; do` lines (541, 548, 600, 606, 613 — the author missed the dest2 DRY_RUN site at 600). Implemented the join on **all 5** — T52's ko text mandates "unido a TODOS los loops shared" and the T52 count pin requires equality. Documented in tasks.md 2.4.
2. **T52 counting pin was unsatisfiable as written (defective pin, corrected).** The base grep ended in `; do` (`codegraph.md; do`), which matches ONLY unconverted loop lines. A correct full join turns every site into `codegraph.md architecture-principles.md; do` → base=0, so `loops_cat == loops_base` fails (and the `-ge 2` floor fails too) even when the catalog is joined EVERYWHERE — parity alone proves impossibility (k = n−k → k=2.5 on 5 sites; with the author's believed 4 sites k=2 → 2==2×miscount). The ko message itself ("debe igualar codegraph.md") reveals intent: base must count loops carrying `codegraph.md` regardless of catalog. **Correction: dropped the `; do` suffix** — base counts all 5 codegraph.md loops in both states, cat counts catalog-joined loops; RED preserved byte-identical (0/5 ko fires the same), GREEN reachable at 5/5. Verified pre- and post-change counts: 5/0 RED → 5/5 GREEN.
3. **T52 runtime leg was polluted by the harness's own sandbox HOME (defective pin environment, corrected).** The suite header (lines 36–38) mandates legs that run `sync-skills.sh` against the host use `REAL_HOME` ("el HOME real del despliegue target, no un sandbox heredado") — and `REAL_HOME` is even captured at line 41 for exactly this purpose. But the T52 leg at line 1033 omitted `env HOME="$REAL_HOME"`, so it inherited the HOME that T44 exported to a sandbox. Empirically reproduced against a faithful sandbox home: rc=2 with `[ERROR] overlay sin base` ×3 and 107 FALTA — i.e., the "check con errores estructurales (regresion S1)" ko fired for environmental reasons, not code reasons (T30/T39 legs run pre-T44, which is why only T52 shows it). **Correction: added `env HOME="$REAL_HOME"`** to the leg. RED semantics preserved — with REAL_HOME the pre-implementation leg still fails the genuine "check no reconoce el catalog" ko and passes the structural one; post-implementation both pass. The RED→GREEN run sequence above shows the fake ko vanishing while the genuine ko persists until the implementation lands.

No other deviations — catalog corpus, schema, single-path, and copy-only-if-missing all match design D2/D3 and the acta P-seeds/RFC A-list exactly.

## Issues found

1. Design/tasks said "4 SHARED loops"; reality is 5 sites (dest2 DRY_RUN loop missed). Implemented all 5; flagged for spec/design correction (text-only, no behavior change).
2. Two T52 pin defects (unsatisfiable count pattern + missing REAL_HOME on the runtime leg) — corrected minimally and documented above; both preserve the original RED signal. If the change owners prefer a different correction, the tests file is the single revert point (`tests/run_red_checks.sh` T52 block).
3. `Actualizados` moved 4→6 on the real host `--check` after the join — expected and desired (catalog recognized as pending install at both destinations). No host install was executed (out of scope; the change deploys via `sync-skills.sh` at install time).

## Status

Phase 2: 4 of 4 tasks complete (2.1–2.4 [x]). **U2 done — no new failures; T49/T51/T52 green; `--check` recognizes the catalog at both destinations with Errores: 0. Next batch: U3 (quest arch branch rework, RED T53).**
---

# Apply Progress U3 — arch-principles-quest-linter

- **Work unit**: U3 — Quest arch-branch rework (Phase 3: tasks 3.1–3.5)
- **Date**: 2026-09-15 (U3 batch)
- **Executor**: sdd-apply
- **Mode**: Strict TDD (test runner: `bash tests/run_red_checks.sh`)
- **Artifact store**: hybrid (openspec repo + engram)
- **Attempt ledger token**: sha256:c16acf331d672da88fffc2c24201c12801f801af7ede08e26e4dad017769fe85
- **Rollback boundary**: revert the single Step-3 insertion in `skills/sdd-quest/SKILL.md` (hunk: "**Architecture Quest mechanics …**" through "**Product Quest untouched**: budget 50 and current structure unchanged.") + undo the T53 block in `tests/run_red_checks.sh` + uncheck 3.1–3.5. Everything from U1/U2 and all pre-existing state stays intact.

## Scope executed (this batch)

1. `tests/run_red_checks.sh`: wrote **T53** (RED first, before any quest edit) — 8 base Qs + stack, branch-table columns trigger/IDs/questions/early-stop/precedence, budget 20, gaps decision|knowledge|blocking, catalog-by-path/no-inline, Product-Quest-untouched regression greps. Coverage-map line extended (`T53 quest arch rework`).
2. `skills/sdd-quest/SKILL.md`: reworked ONLY the architecture-branch mechanics — single insertion at the end of Step 3 (after the branch-coverage bullets):
   - **8 base context questions** (design D6 / acta Q3/Q4 set): scope/surface · boundary structure · stack driver · distribution · data & persistence · state & concurrency · integration/framework · non-functional envelope; asked first, never principle-by-principle (A1).
   - **Stack trigger** as base question 3: yes → technology branch enabled (A4); no → skipped, language-agnostic default preserved (A5); confirmed-but-no-branch → driver recorded + branch early-stops with zero questions (A10).
   - **Declarative branch table** — the ONLY question-selection source (A2): rows microservices (trigger Base Q4 = yes), technology (trigger Base Q3 = yes), default language-agnostic; each row declares catalog IDs loaded by path (A01/A02/A03/A06/A08/A11, A04, all), branch questions, early-stop, precedence 1|2|3 (A9).
   - **Hard budget: 20**, FIXED, never raised; early-stop when all triggered branches resolve (A6); exhaustion → consolidation report with classified gaps (A7); gaps classify exactly as decision | knowledge | blocking, no gap disappears silently (A8).
   - Catalog consumed **by path** (`skills/_shared/architecture-principles.md`), no inline copy (S3; catalog feeds branching, never the interview).
   - **Product Quest untouched**: budget 50 and structure unchanged (spec regression requirement).
3. `openspec/changes/arch-principles-quest-linter/tasks.md`: 3.1–3.5 marked [x].

## TDD Cycle Evidence (strict TDD — suite pins as the tests)

| Task | RED (test written first) | GREEN (implementation passes) | TRIANGULATE | REFACTOR |
|------|--------------------------|-------------------------------|-------------|----------|
| 3.1 T53 pin | T53 authored BEFORE any quest edit; RED run: **PASS 49 / FAIL 37** — T53 failing with all genuine kos (marker, 8-count, 8 dimensions, stack gate ×3, table header/rows/precedence, budget, early-stop, consolidation, 3 gaps, catalog path, no-gap-silent); baseline 6 (T05/T21/T30×2/T39×2) unchanged. One pin refinement during RED: count pattern `^[1-8]\. \*\*[^*]+\*\* — ` (em-dash) to exclude the 7 pre-existing numbered Hard-constraint lines (`N. **label.** `); the refined pin still fails RED on every other leg. | T53 → **PASS** (GREEN run: **PASS 50 / FAIL 6**, 58s); zero new failures; the 6 FAILs are byte-identical test IDs to the baseline. | All spec scenarios pinned with ≥1 assertion leg: A1 (marker+count+never-principle-by-principle), A2 (ONLY question-selection source + header), A3 (row trigger Base Q4 = yes), A4/A5/A10 (3 stack greps), A6/A7 (early-stop + consolidation), A8 (3 gaps + no-silent), A9 (declared precedence), S3 (path + zero inline schema lines), Product regression (budget-50 + product-branch bullets). | None needed — single declarative insertion, no duplication, style consistent; no GoF pattern introduced (branch table = data module/config-as-data per design D6; alternatives prose/state-machine already rejected in design/acta). |
| 3.2–3.5 quest rework | Same RED as above (all 3.2–3.5 legs fail pre-implementation). | Implementation = the Step-3 insertion; all T53 legs green. | See above (A1–A10 + S3 scenarios). | See above. |

Run sequence evidence:

```
Safety Net (pre-edit baseline): PASS: 49   FAIL: 6    SKIP: 0   (57s total)
  → T05, T21, T30×2, T39×2 — the pre-existing later-slice desync classes; T15 not flaking.
RED (T53 written, quest untouched):     PASS: 49   FAIL: 37   SKIP: 0   (58s total)
  → T53: 31 ko legs, all genuine (no false-green legs); baseline 6 unchanged.
GREEN (quest rework applied):            PASS: 50   FAIL: 6    SKIP: 0   (58s total)
  → T53 PASS; identical 6 failing test IDs as baseline (no new failures).
```

## Work Unit Evidence

| Evidence | Required value |
|----------|----------------|
| Focused test command and exact result | `bash tests/run_red_checks.sh` → Safety Net **49/6**, RED **49/37** (T53 31 kos), GREEN **50/6**. T53 PASS. No new failures: the 6 FAILs after GREEN are exactly the baseline test IDs (T05, T21, T30×2, T39×2). |
| Runtime harness command/scenario and exact result | `./sync-skills.sh --check --skip-gentleai-sync` → **Errores: 0, exit 0**, `Actualizados: 7` (was 6: +1 quest pending rework at destinations). Residual surfaces: 4 pre-existing DESYNC (changelog, council, rfc-author, opencode.jsonc) + quest (this slice's own rework, pending deploy by design) + 2 FALTA (catalog at both destinations, from U2). No [ERROR] lines. |
| Rollback boundary | Revert the single quest Step-3 insertion hunk + strip the T53 block + uncheck 3.1–3.5. U1 bytes (quest/lint/orchestrator/prompts/agent), U2 catalog + loop join, and the deployed tree (`~/.config/sdd-own/`) stay untouched. |

## Scope mapping — remaining suite FAILs (6, pre-existing only)

| Check | Class | Owner | U3 effect |
|-------|-------|-------|-----------|
| T05 (no-mutation host) | Pre-existing; greens as the change syncs (deploy state) | Later slices + final install | Still red: failing leg = `setup.sh --check exit 1 != 0` (host DESYNC set); `git status` leg passes (unchanged). No pre-existing desync cleared in U3. |
| T21 (regression + README F7) | Pre-existing; `sync-skills.sh --check exit 1` from residual desyncs | Later slices + final install | Still red; desync set grew 4→5 with the quest surface (by design). |
| T30 ×2 (sync idempotency + id hygiene) | Pre-existing; counts desyncs post-sync | Later slices + final install | jq leg count 4→5 (quest pending); python leg stays 2. Same test IDs. |
| T39 ×2 (merge both engines) | Pre-existing; same residual desyncs | Later slices + final install | jq leg 4→5; python leg stays 2. Same test IDs. |

## Deviations from design / preflight

1. **None in the design contract**: the rework follows design D6 and the acta quest decision exactly (8 dimensions, table columns trigger/catalog-IDs/questions/early-stop/precedence, stack gate semantics A4/A5/A10, budget 20 fixed, gap taxonomy decision|knowledge|blocking, catalog by path single-source).
2. **T53 count-pattern refinement (test-side, RED phase)**: the first counting regex `^[1-8]\. \*\*[^*]+\*\*` matched 7 pre-existing Hard-constraint lines (file lines 46–52, `N. **label.** ` style) → refined to require the em-dash form `^[1-8]\. \*\*[^*]+\*\* — ` used only by the base-question list. The pin's failure semantics were unchanged (T53 still fell RED on all other legs pre-implementation; the count leg alone can never be a false green).
3. **Preflight's "T05 should stabilize toward GREEN if it belongs to this slice"**: verified T05 does NOT belong to U3 — its gate is the host deploy state (`setup.sh --check` exit code against `~/.config/sdd-own/`), which this slice deliberately leaves read-only. The quest surface now reports as a pending DESYNC (repo reworked vs installed v4.0), which is the intended mid-change state and greens when the change syncs at install time (U6 final). No pre-existing desync cleared; the residual set is exactly the later-slice surfaces + this slice's own pending update.

## Issues found

1. The pre-existing numbered-list collision on the 8-count pattern (documented above; resolved in the pin, not in the skill).
2. T30/T39 jq-leg desync counts move 4→5 while the change is mid-flight — expected and bounded: the rework cannot be deployed until the full change syncs; the verify phase (U6) applies the deploy and re-checks zero desyncs.
3. No other issues. The deployed tree was never written (read-only source per U1 contract).

## Status

Phase 3: 5 of 5 tasks complete (3.1–3.5 [x]). **U3 done — T53 green, zero new failures, `--check` Errores: 0. Next batch: U4 (lint axis 3, RED T55–T59).**
---

# Apply Progress U4 — arch-principles-quest-linter

- **Work unit**: U4 — Lint axis 3 (Phase 4: tasks 4.1–4.4)
- **Date**: 2026-09-15 (U4 batch)
- **Executor**: sdd-apply
- **Mode**: Strict TDD (test runner: `bash tests/run_red_checks.sh`)
- **Artifact store**: hybrid (openspec repo + engram)
- **Attempt ledger token**: sha256:a74749d7817c324608d68d924d4c439bf2a42370e801806727b450b36b755531
- **Rollback boundary**: revert the lint SKILL.md rework (axis-3 block: frontmatter description/version, Purpose paragraph, What-You-Receive bullet, Step 2 catalog read, new **Step 6** `Verify Architecture Principles` + renumber of Opt-Out/Report/Persist/Return to Steps 7–10, Return template Axis-3 table, 3 new Rules lines) + strip the T50 block and the T35 axis-3 legs in `tests/run_red_checks.sh` + uncheck 4.1–4.4. Everything from U1/U2/U3 and all pre-existing state stays intact.

## Scope executed (this batch)

1. `tests/run_red_checks.sh`: wrote **T50** (RED first, before any lint edit) — S4 cross-check catalog↔lint by stable ID, BOTH directions: every catalog ID (P01..P10, A01..A11) must appear in the lint file (`grep -qF` per ID), and every `(P|A)[0-9]{2}` ID found in the lint must exist in the catalog. Coverage-map line extended (`T50` between T49 and T51).
2. `tests/run_red_checks.sh`: **T35 co-update** — kept all 5 v2.0 lint strings + 3 council-lens legs, added 3 axis-3 string greps on the lint: `Axis 3`, `axis_3 pass`, `axis_3 fail`. Red before the rework (pin verified), green after.
3. `skills/sdd-architecture-lint/SKILL.md`: reworked deployed lint v2.0 → **v2.1 with Axis 3** (only additive edits to the U1-imported v2.0 bytes; axes 1 and 2 text untouched except Step renumbering):
   - Frontmatter description + version 2.1 (no pins exist on the version, verified by grep before bumping).
   - Purpose: axis 3 sentence; What You Receive: catalog locator bullet (single source, never duplicated inline); Step 2: read catalog in full.
   - **New Step 6 — Verify Architecture Principles (Axis 3 — ALWAYS, POST-apply)**, placed after Step 5 (No-Dogma), subsequent steps renumbered 6→7 (Opt-Out), 7→8 (Report), 8→9 (Persist), 9→10 (Return); the organic-opt-out cross-reference updated to Step 7.
   - Axis-3 body (design D5 / acta D3): check set P01..P10 + A01..A11 by **stable ID resolved from the catalog BY PATH** (same literal path as quest/plan; no inline copies — a copy inside the lint would itself be a duplication finding); findings `{id, severity, evidence}` in the shared `architecture-conformance` envelope; severity from catalog (`blocker` default), downgrade to `warning` ONLY at lint time by judgment, NEVER baked into the catalog; ambiguous evidence → `warning` (L4); full blocker set (L3); independent verdict `axis_3 pass|fail` — fail iff ≥1 blocker, warnings never fail; ONE dual-signal / N-A-suppress contract shared with the plan checklist (applicable/direction-evidence contradicted → dual signal axis 2 mandate + axis 3 blocker on the SAME check ID, L6/C7; `n-a-justified` suppresses with justification VISIBLE in findings, L5).
   - Report (Step 8) + Return template (Step 10): axis 3 per-check findings table + independent verdict; 3 new Rules lines.
4. `openspec/changes/arch-principles-quest-linter/tasks.md`: 4.1–4.4 marked [x].

## Files changed (U4)

| File | Action | What Was Done |
|------|--------|---------------|
| `skills/sdd-architecture-lint/SKILL.md` | Modified | v2.0 → v2.1: axis 3 step inserted (Step 6), Opt-Out/Report/Persist/Return renumbered to 7–10, frontmatter/Purpose/What-You-Receive/Step 2/Return template/Rules updated; axes 1+2 intact |
| `tests/run_red_checks.sh` | Modified | T50 added (catalog↔lint cross-check, both directions); T35 +3 axis-3 string legs; coverage map line |
| `openspec/changes/arch-principles-quest-linter/tasks.md` | Modified | 4.1–4.4 marked [x] |

## TDD Cycle Evidence (strict TDD — suite pins as the tests)

| Task | RED (test written first) | GREEN (implementation passes) | REFACTOR |
|------|--------------------------|-------------------------------|----------|
| 4.1 T50 cross-check + T35 axis-3 legs | T50 authored BEFORE any lint edit; T35 axis-3 legs added same batch. RED run: **PASS 49 / FAIL 30 (58s)** — T35: 3 new kos (Axis 3, axis_3 pass, axis_3 fail all absent); T50: 21 kos (every catalog ID P01..P10/A01..A11 missing from lint); baseline 6 (T05/T21/T30×2/T39×2) byte-identical and unchanged. No axis-2 string regress: the 5 v2.0 legs of T35 stayed green throughout RED. | Lint rework applied → T35 **PASS** (5 v2.0 legs + 3 council lenses + 3 axis-3 legs all green); T50 **PASS** (21/21 catalog IDs present in lint, 0 lint IDs unknown to catalog — no `(P|A)[0-9]{2}` stray beyond the enumerated check set). GREEN run: **PASS 51 / FAIL 6 / SKIP 0 (57s)** — the 6 FAILs are exactly the baseline later-slice classes, zero new failures. Also verified no version pin on the lint blocks the v2.0→v2.1 bump (grep of tests showed no `2.0`/version pins). | None — additive single-file rework, axes 1+2 byte-untouched (renumbering only), catalog resolved by path, no duplicate entries, no GoF pattern needed (config-as-data check set per D5). |
| 4.2 axis-3 check set (P01..P10/A01..A11, by path, findings shape) | Red legs: T50 21 kos (no IDs in lint). | Check set enumerated by stable ID and resolved from catalog by path; findings `{id, severity, evidence}` documented; no inline catalog copies. T50 direction-2 leg (every lint ID exists in catalog) green — no unknown IDs. | None |
| 4.3 verdict + severity rules | Red legs: T35 `axis_3 pass` / `axis_3 fail` absent pre-rework. | `axis_3 pass|fail` defined with fail-iff-≥1-blocker; severity from catalog default, lint-time-only downgrade, ambiguity→warning, full blocker set. T35 axis-3 legs green. | None |
| 4.4 acta interplay (D3) | Not separately pinnable (acta-read behavior, lint-time): covered by the T35 axis-3 strings pin (contract section present) + design-acta compliance verified by reading the written section against D3. | ONE dual-signal/N-A-suppress contract text written (shared with plan checklist, same catalog IDs): n-a-justified suppresses w/ visible justification; contradiction → dual signal on same ID (L6/C7). | None |

Run sequence evidence:

```
Safety Net (pre-edit baseline): PASS: 50   FAIL: 6    SKIP: 0   (57s total)
RED (T50 + T35 axis-3 legs, lint untouched): PASS: 49   FAIL: 30   SKIP: 0   (58s total)
  → T35: 3 new kos (axis-3 strings absent); T50: 21 kos (no catalog IDs in lint);
    baseline 6 unchanged (T05, T21, T30×2, T39×2). No axis-1/axis-2 string regress.
GREEN (lint rework applied):       PASS: 51   FAIL: 6    SKIP: 0   (57s total)
  → T35 PASS, T50 PASS; identical 6 failing test IDs as baseline (no new failures).
```

## Work Unit Evidence

| Evidence | Required value |
|----------|----------------|
| Focused test command and exact result | `bash tests/run_red_checks.sh` → Safety Net **50/6**, RED **49/30** (T35 3 kos + T50 21 kos), GREEN **51/6**. T35 and T50 PASS; the 6 FAILs after GREEN are exactly the baseline test IDs (T05, T21, T30×2, T39×2). T50 both directions verified: 21/21 catalog IDs present as literals in the lint's check-set enumeration, 0 lint `(P|A)[0-9]{2}` IDs outside the catalog. |
| Runtime harness command/scenario and exact result | `./sync-skills.sh --check --skip-gentleai-sync` → **Errores: 0, exit 0**. The lint surface now additionally reports DESYNC (repo v2.1 reworked vs deployed v2.0) — expected mid-change state: the rework deploys only when the full change syncs (verify/U6 install). T30/T39 jq-leg desync counts move 4/5→6 with the new locus; python leg stays 2. No [ERROR] lines; no new failure classes. |
| Rollback boundary | Revert the lint SKILL.md axis-3 rework hunk + strip T50 + T35's 3 axis-3 legs + uncheck 4.1–4.4. U1 bytes (quest/lint v2.0 base/orchestrator/prompts/agent), U2 catalog+loop, U3 quest rework/T53, and all pre-existing state stay untouched. |

## Scope mapping — remaining suite FAILs (6, pre-existing only)

| Check | Class | Owner | U4 effect |
|-------|-------|-------|-----------|
| T05 (no-mutation host) | Pre-existing; greens as the change syncs (deploy state) | Later slices + final install | Still red (host DESYNC set on setup.sh leg); `git status` leg unchanged. |
| T21 (regression + README F7) | Pre-existing; `sync-skills.sh --check exit 1` from residual desyncs | Later slices + final install | Still red; desync set 5→6 with the lint surface (by design). |
| T30 ×2 (sync idempotency + id hygiene) | Pre-existing; counts desyncs post-sync | Later slices + final install | jq leg count 5→6 (lint pending); python leg stays 2. Same test IDs. |
| T39 ×2 (merge both engines) | Pre-existing; same residual desyncs | Later slices + final install | jq leg 5→6; python leg stays 2. Same test IDs. |

## Deviations from design / preflight

1. **Preflight work-unit split honored**: tasks.md names this unit "4.1 RED T50 …" — the batch implemented exactly 4.1–4.4 (T50 + lint axis 3 + T35 co-update). No U5 plan-checklist code and no U6 fixtures were introduced in this slice (verified: `wiring/prompts/sdd/sdd-architecture-plan.md` untouched, no fixture files created).
2. **T35 co-update includes the P-catalog-string leg now, checklist strings deferred**: the preflight mandated `T35+=axis-3/checklist strings`. Per the per-slice split, this batch added only the **lint-side axis-3 strings** (`Axis 3`, `axis_3 pass`, `axis_3 fail`); the plan-checklist side (`## Principios no verificables`, 21 rows, 3 states) belongs to T54/U5, already declared in tasks.md 5.1. T35 remains the single shared pin for both slices (still green after this batch).
3. **Nothing else deviates**: axes 1 and 2 of the imported v2.0 lint are functionally untouched (renumbering only; every original sentence preserved); the dual-signal/N-A-suppress contract is exactly acta D3 (one contract, both sides consume the same catalog IDs).

## Issues found

1. The lint rework necessarily adds a 6th DESYNC locus mid-change (repo v2.1 vs deployed v2.0) → T30/T39 jq-leg counts move 5→6. Expected and bounded: verify (U6) applies the deploy and re-checks zero desyncs; the deployed tree stays read-only until then (U1 contract).
2. No version pin exists on the lint SKILL.md (grep for `version`/`2.0` in tests returned nothing) — the v2.0→v2.1 bump is safe and was verified before editing.
3. No other issues. The deployed tree was never written.

## Status

Phase 4: 4 of 4 tasks complete (4.1–4.4 [x]). **U4 done — T50 + T35 green, zero new failures (51/6), `--check` Errores: 0; lint axis 3 complete (check set, findings shape, verdict, D3 contract) and cross-checked against the catalog by ID in both directions. Next batch: U5 (plan checklist, RED T54).**
---

# Apply Progress U5 — arch-principles-quest-linter

- **Work unit**: U5 — Plan checklist contract (Phase 5: tasks 5.1–5.2)
- **Date**: 2026-09-15 (U5 batch)
- **Executor**: sdd-apply
- **Mode**: Strict TDD (test runner: `bash tests/run_red_checks.sh`)
- **Artifact store**: hybrid (openspec repo + engram)
- **Attempt ledger token**: sha256:c7fe2ee7fcdc301e68dfae9469b68f7e087bdd871c5807a3eb05fb684ac74418 (work unit: plan-checklist)
- **Rollback boundary**: strip the T54 block + the coverage-map line in `tests/run_red_checks.sh`, revert the Step-4 checklist-contract block in `wiring/prompts/sdd/sdd-architecture-plan.md`, uncheck 5.1–5.2 in `tasks.md`. Everything from U1/U2/U3/U4 and all pre-existing state stays intact; the acta file (`arch-plan.md`) was NOT touched (it is the U5 evidence, not a target).

## Scope executed (this batch)

1. `tests/run_red_checks.sh`: wrote **T54** (RED first, before any prompt edit) pinning the plan-checklist CONTRACT in `wiring/prompts/sdd/sdd-architecture-plan.md`:
   - byte-exact Spanish anchor `## Principios no verificables` (C1/C2 fail-closed on missing) — the literal string (`grep -qF`); English renderings `## Non-verifiable principles` / `## Unverifiable Principles` explicitly REJECTED (translated must not satisfy the gate);
   - 21 rows: ≥10 principle data rows `^\| P[0-9]{2} ` + ≥11 anti-pattern rows `^\| A[0-9]{2} `;
   - the 3 closed states literal: `applicable`, `direction-evidence`, `n-a-justified`;
   - direction evidence MANDATORY per row and justification MANDATORY per N/A row;
   - `never omitted` clause (C6) — the section exists even when no principle applies.
   Coverage-map line added (`T54 plan checklist …`).
2. `wiring/prompts/sdd/sdd-architecture-plan.md`: extended **Step 4 (Author the Acta)** with the **Mandatory checklist section — `## Principios no verificables`** contract (acta D3 / design D4, ONE dual-signal/N-A contract shared with the lint):
   - anchor byte-exact, translated variants NEVER satisfy the gate, missing heading → axis 2 fail-closed (C2);
   - 21-row ID table (P01..P10 + A01..A11) resolved by path from `skills/_shared/architecture-principles.md` — never copied inline;
   - each row declares EXACTLY one state of the closed enum `applicable | direction-evidence | n-a-justified`, evidence/justification MANDATORY and never omitted;
   - normative state semantics (applicable = MUST + evidence REQUIRED + check runs at catalog severity; direction-evidence = recorded direction + evidence REQUIRED + check runs; n-a-justified = suppressed + justification REQUIRED and visible, missing → axis-2 warning C5);
   - dual signal (C7): applicable/direction-evidence contradiction → axis 2 unmet mandate + axis 3 blocker on the SAME check ID; section NEVER omitted even when no principle applies (C6).
3. `openspec/changes/arch-principles-quest-linter/tasks.md`: 5.1–5.2 marked [x].

## Files changed (U5)

| File | Action | What Was Done |
|------|--------|---------------|
| `tests/run_red_checks.sh` | Modified | T54 added (anchor byte-exact + translated rejected + 21 rows + 3 states + mandatory evidence/justification + never omitted); coverage-map line |
| `wiring/prompts/sdd/sdd-architecture-plan.md` | Modified | Step 4 += mandatory checklist contract (anchor fail-closed, 21-row ID table by catalog path, 3-state semantics, mandatory evidence/justification, dual signal, never omitted) |
| `openspec/changes/arch-principles-quest-linter/tasks.md` | Modified | 5.1–5.2 marked [x] |

## TDD Cycle Evidence (strict TDD — suite pins as the tests)

| Task | RED (test written first) | GREEN (implementation passes) | REFACTOR |
|------|--------------------------|-------------------------------|----------|
| 5.1 T54 pin (anchor + translated rejected + fail-closed + 21 rows + 3 states + mandatory) | T54 authored BEFORE any prompt edit. RED run 1 (raw pin): **PASS 51 / FAIL 14** — T54 8 kos, all genuine. Pin corrected 2× within RED (see Deviations): P-row pattern + -F alternation defect + false-green evidence leg. RED run 2 (corrected pins): **PASS 51 / FAIL 15** — T54 **9 genuine kos** (anchor absent, P-rows 0, A-rows 0, 3 states absent ×3, direction-evidence mandatory absent, justification mandatory absent, never-omitted absent); baseline 6 unchanged; no false-green legs. | Checklist contract added to the prompt (Step 4) → T54 **PASS** (GREEN run: **PASS 52 / FAIL 6**, 58s); zero new failures; the 6 FAILs are byte-identical test IDs to the baseline (T05, T21, T30×2, T39×2). Anchor verified byte-exact Spanish: literal `## Principios no verificables` present, 0 occurrences of either English translation. | None — single additive block in Step 4, no duplication (the 21 IDs reference the catalog by path, per S3), no GoF pattern needed (contract text, config-as-data per D4/D3). |
| 5.2 checklist contract content | Same RED (all contract legs fail while the prompt lacks the section). | Contract block lands in `sdd-architecture-plan.md` Step 4: anchor, 21-row table, 3-state legend, mandatory evidence/justification, dual signal, never-omitted. All T54 legs green. | See above. |

Run sequence evidence:

```
Safety Net (pre-edit baseline): PASS: 51   FAIL: 6    SKIP: 0   (57s total)
  → T05, T21, T30×2, T39×2 — the pre-existing later-slice desync classes.
RED (T54 written, prompt untouched):   PASS: 51   FAIL: 15   SKIP: 0   (58s total)
  → T54: 9 ko legs, all genuine (no false-green legs); baseline 6 unchanged.
GREEN (checklist contract applied):    PASS: 52   FAIL: 6    SKIP: 0   (58s total)
  → T54 PASS; identical 6 failing test IDs as baseline (no new failures).
```

## Work Unit Evidence

| Evidence | Required value |
|----------|----------------|
| Focused test command and exact result | `bash tests/run_red_checks.sh` → Safety Net **51/6**, RED **51/15** (T54 9 kos, all genuine), GREEN **52/6**. T54 PASS; the 6 FAILs after GREEN are exactly the baseline test IDs (T05, T21, T30×2, T39×2). |
| Runtime harness command/scenario and exact result | `./sync-skills.sh --check --skip-gentleai-sync` → **Errores: 0, exit 0**, no `[ERROR]` lines. DESYNC set = expected mid-change surfaces: lint (U4 rework), quest (U3 rework), sdd-architecture-plan (THIS slice's own rework — pending deploy by design), changelog/council/rfc-author/opencode.jsonc (pre-existing later-slice/user surfaces); 2 FALTA = catalog (from U2). All clear at verify/U6 install. |
| Rollback boundary | Strip T54 block + coverage-map line (`tests/run_red_checks.sh`), revert the Step-4 checklist block (`wiring/prompts/sdd/sdd-architecture-plan.md`), uncheck 5.1–5.2. U1 bytes, U2 catalog+loop, U3 quest rework/T53, U4 lint axis-3 rework/T50+T35 legs, the acta (`arch-plan.md`, untouched), and the deployed tree (read-only source per U1) all stay intact. |

## Scope mapping — remaining suite FAILs (6, pre-existing only)

| Check | Class | Owner | U5 effect |
|-------|-------|-------|-----------|
| T05 (no-mutation host) | Pre-existing; greens as the change syncs (deploy state) | Later slices + final install | Still red (host DESYNC set on setup.sh leg); `git status` leg unchanged. |
| T21 (regression + README F7) | Pre-existing; `sync-skills.sh --check exit 1` from residual desyncs | Later slices + final install | Still red; desync set 6→7 with the plan-prompt surface (by design). |
| T30 ×2 (sync idempotency + id hygiene) | Pre-existing; counts desyncs post-sync | Later slices + final install | jq leg count 6→7 (plan prompt pending); python leg stays 2. Same test IDs. |
| T39 ×2 (merge both engines) | Pre-existing; same residual desyncs | Later slices + final install | jq leg 6→7; python leg stays 2. Same test IDs. |

## Deviations from design / preflight

1. **Pin defects found and corrected in RED (test-side, before implementation — same protocol as U2/T52 and U3):** three defects in T54 as first authored, all corrected while the suite still fell RED (re-proven each time, no false-green legs):
   - **P-row count unsatisfiable**: `grep -cF '| P0'` matches only P01..P09 (9 lines) because P10 starts `| P1` — the `>=10` threshold could never pass with a natural 21-row table (parity defect class). Corrected to `grep -cE '^\| P[0-9]{2} '` (counts the 10 real P data rows).
   - **Literal alternations**: the mandatory-evidence and never-omitted legs used `grep -F` with `\|` alternations — with fixed strings the alternations are literal, so the legs could never match regex intent. Corrected to `grep -E`, one grep per concept.
   - **False-green evidence leg**: `evidence[^.]*(mandatory|REQUIRED)` matched the prompt's pre-existing line "the explore/research evidence (required)" — "required" there means input paths, NOT checklist evidence — so the leg passed pre-implementation for the wrong reason. Tightened to `direction evidence[^.]*(mandatory|REQUIRED)` — a phrase that does not exist in the prompt until the contract lands. RED semantics preserved: T54 still fell red on 9 genuine kos with the corrected pins.
2. **T35 checklist-half lands in T54 (not a T35 co-update this slice)**: per U1's deferral record and tasks.md 5.1 wording, the plan-checklist side of the original `T35+=axis-3/checklist` instruction is implemented as T54 (the declared venue); T35's lint-side axis-3 strings were already added in U4 and stay green (verified in the GREEN run).
3. **Nothing else deviates**: the contract implements acta D3 / design D4 exactly (anchor byte-exact Spanish, 21 IDs, 3-state closed enum, mandatory evidence/justification, dual signal C7, never omitted C6); the prompt remains English per the Language Domain Contract except the user-approved literal anchor (acta "Artifact language pin" decision).

## Issues found

1. Three T54 pin defects (documented above) — corrected minimally in RED with preserved failure semantics; the tests file is the single revert point.
2. The prompt rework adds a 7th mid-change DESYNC locus (repo `sdd-architecture-plan.md` vs deployed) → T30/T39 jq-leg desync counts move 6→7. Expected and bounded: verify (U6) applies the deploy and re-checks zero desyncs; the deployed tree stays read-only until then (U1 contract).
3. No other issues. The acta (`arch-plan.md`) was never edited — it already carries the exact anchor + 21 rows the contract now mandates (it is the U5 evidence).

## Status

Phase 5: 2 of 2 tasks complete (5.1–5.2 [x]). **U5 done — T54 green (anchor byte-exact Spanish, translated rejected, 21 rows, 3 states, mandatory evidence/justification, never omitted), zero new failures (52/6), `--check` Errores: 0; plan prompt now mandates the checklist contract the acta already exemplifies. Next batch: U6 (fixtures + T55–T60 integration).**

---

# Apply Progress U6 (FINAL) — arch-principles-quest-linter

- **Work unit**: U6 — Fixtures + RED Integration (Phase 6: tasks 6.1–6.3)
- **Date**: 2026-09-15 (U6 batch)
- **Executor**: sdd-apply
- **Mode**: Strict TDD (test runner: `bash tests/run_red_checks.sh`)
- **Artifact store**: hybrid (openspec repo + engram)
- **Attempt ledger token**: sha256:32c076551d53c0b35a684d57bb78cef89c5aee80bfbc3d1b3bf66f9bf047475e (work unit: fixtures-t49-t60)
- **Delivery strategy**: single PR, accepted `size:exception` (tasks.md Review Workload Forecast — no chain decision required)
- **Rollback boundary**: drop `tests/fixtures/arch-principles/` (55 files, all untracked) + strip T55–T60 blocks and coverage-map lines in `tests/run_red_checks.sh` (revert to the U5 state of the file); uncheck 6.1–6.3. Everything from U1–U5 and all pre-existing state stays intact; the deployed tree was never written (U1 contract).

## Scope executed (this batch)

1. `tests/run_red_checks.sh`: wrote **T55–T60** (RED first, before any fixture existed) pinning the axis-3 fixture CONTRACT (acta "Fixture and RED contract for axis 3" / design D9) + wiring (B5):
   - T55: clean fixture → `axis_3 pass`, zero blockers; each `dirty/<ID>` → exactly 1 `VIOLATION(<ID>)` marker, `axis_3 fail`, blockers == [ID], severity read from the catalog (P## `Default severity: blocker`, A## `| blocker |` row);
   - T56: `multi/` → complete blocker set (L3 — all 4 markers detected, not only the first), markers == expected.json blockers, acta rows applicable;
   - T57: `warning/` → `AMBIGUOUS(P05)` renders a warning finding, NEVER a blocker; `axis_3 pass` with warnings only (L4);
   - T58: `na-justified/` → P08 suppressed with visible justification (L5); `dual/` → P02 applicable + `CONTRADICTION(P02)` → axis-2 unmet mandate AND axis-3 blocker on the SAME ID (L6/C7);
   - T59: `missing-checklist/` + `translated-anchor/` → axis 2 fail-closed (C2) and translated title MUST NOT satisfy presence (C1);
   - T60: wiring (B5) — `sdd-architecture-plan` agent key (subagent, hidden, file-based prompt) + orchestrator allow-list + prompt file exists.
   Coverage-map lines added (T55–T60).
2. `tests/fixtures/arch-principles/`: created **55 files**:
   - `expected.json` (schema `sdd/arch-principles-fixtures/v1`) — machine-readable expected outcomes per fixture (D9: the RED suite compares against it);
   - `clean/` (acta.md with literal `## Principios no verificables` + 21 applicable rows; implementation.md with ZERO markers) → `axis_3 pass`;
   - `dirty/{P01..P10,A01..A11}/` — 21 dirty fixtures, each with exactly one `VIOLATION(<ID>): <evidence>` marker mirroring the catalog's Concrete evidence for that family and a 21-applicable-row acta → `axis_3 fail` on the exact ID (L2);
   - `multi/` — 4 violations (P03, P07, A02, A10) → complete blocker set (L3);
   - `warning/` — `AMBIGUOUS(P05)` only → warning finding, `axis_3 pass` (L4);
   - `na-justified/` — P08 `n-a-justified` with visible justification + `VIOLATION(P08)` → suppressed (L5);
   - `dual/` — P02 applicable + `CONTRADICTION(P02)` → dual signal same ID (L6/C7);
   - `missing-checklist/` — acta WITHOUT the Spanish anchor → axis 2 fail-closed (C2);
   - `translated-anchor/` — acta with English-only `## Non-verifiable principles` → MUST NOT satisfy presence (C1).
   Marker grammar (RED-internal, machine-readable shape of findings): `VIOLATION(<ID>):` → blocker at catalog severity; `AMBIGUOUS(<ID>):` → warning, never blocker; `CONTRADICTION(<ID>):` → dual signal (axis 2 unmet + axis 3 blocker on the same ID).
3. `openspec/changes/arch-principles-quest-linter/tasks.md`: 6.1–6.3 marked [x].

## Files changed (U6)

| File | Action | What Was Done |
|------|--------|---------------|
| `tests/run_red_checks.sh` | Modified | T55–T60 added (6 test blocks + Grupo 10 header + coverage-map lines 27–30) |
| `tests/fixtures/arch-principles/` | Created | 55 files: expected.json + clean + 21 dirty + multi + warning + na-justified + dual + missing-checklist + translated-anchor |
| `openspec/changes/arch-principles-quest-linter/tasks.md` | Modified | 6.1–6.3 marked [x] |

## TDD Cycle Evidence (strict TDD — suite pins as the tests)

| Task | RED (test written first) | GREEN (implementation passes) | REFACTOR |
|------|--------------------------|-------------------------------|----------|
| 6.1 fixtures (clean/dirty/multi/missing-checklist/translated-anchor/expected.json) | T55–T59 authored BEFORE any fixture existed. RED run: **PASS 53 / FAIL 120** (5 test blocks red on kos about absent fixtures; T60 PASS). Genuine RED — every ko cites a missing file or absent marker; no false-green legs. | Fixtures created (55 files) → GREEN run: **PASS 58 / FAIL 6**, 65s. T55–T59 all PASS; the 6 FAILs are byte-identical test IDs to the baseline (T05, T21, T30×2, T39×2). | None — fixtures are static reviewed data; marker grammar documented in the Grupo 10 header. |
| 6.2 T55–T60 axis-3 comparisons + wiring | Same RED run (T55–T59 red on missing fixtures; T60 green from the start because the `sdd-architecture-plan` wiring already exists from U1 — T60 is a post-hoc regression pin for B5, not new behavior this slice; fails-closed if the wiring is ever removed). | All 6 tests PASS after fixtures land. | None. |
| 6.3 full suite green < 2 min | Baseline captured pre-edit: **PASS 52 / FAIL 6, 60s**. | Final suite: **PASS 58 / FAIL 6, 65s (< 2 min)**; T49–T60 all green; zero new failures vs baseline. | The 6 residual FAILs are the documented pre-existing mid-change desync classes (T05, T21, T30×2, T39×2) that green at final install (verify applies the deploy; deployed tree read-only until then per U1 contract). |

Run sequence evidence:

```
Safety Net (pre-edit baseline): PASS: 52   FAIL: 6    SKIP: 0   (60s total)
  → T05, T21, T30×2, T39×2 — the pre-existing later-slice desync classes.
RED (T55–T60 written, fixtures absent): PASS: 53   FAIL: 120   SKIP: 0   (65s total)
  → T55–T59: kos on absent fixture files/markers, all genuine; T60 PASS (U1 wiring pin);
    baseline 6 unchanged.
GREEN (fixtures created):                PASS: 58   FAIL: 6    SKIP: 0   (65s total)
  → T55–T60 PASS; identical 6 failing test IDs as baseline (no new failures).
```

## Work Unit Evidence

| Evidence | Required value |
|----------|----------------|
| Focused test command and exact result | `bash tests/run_red_checks.sh` → Safety Net **52/6** (60s), RED **53/120** (T55–T59 genuine kos, T60 PASS), GREEN **58/6** (65s). T49–T60 all green after fixtures; the 6 FAILs after GREEN are exactly the baseline test IDs (T05, T21, T30×2, T39×2) — zero new failures. Suite 65s < 2 min. |
| Runtime harness command/scenario and exact result | `./sync-skills.sh --check --skip-gentleai-sync` (REAL_HOME) → **Errores: 0, exit non-zero con 'hay desyncs'** (expected mid-change). DESYNC set = exactly the documented 7 surfaces (lint, quest, sdd-architecture-plan from U3/U4/U5 reworks; changelog, council, rfc-author, opencode.jsonc pre-existing/user surfaces) + 2 FALTA (catalog, shared bootstrap, pending deploy from U2). No NEW surfaces — fixtures under `tests/` never enter the sync. |
| Rollback boundary | Drop `tests/fixtures/arch-principles/` (55 untracked files) + strip T55–T60 and coverage-map lines from `tests/run_red_checks.sh`; uncheck 6.1–6.3. U1 bytes, U2 catalog+loop, U3 quest, U4 lint, U5 plan checklist, the acta (untouched), and the deployed tree (read-only per U1) all stay intact. |

## Scope mapping — remaining suite FAILs (6, pre-existing only)

| Check | Class | Owner | U6 effect |
|-------|-------|-------|-----------|
| T05 (no-mutation host) | Pre-existing; greens as the change syncs (deploy state) | Final install (verify) | Unchanged — still red, same test ID. |
| T21 (regression + README F7) | Pre-existing; `--check exit 1` from residual desyncs | Final install (verify) | Unchanged — still red, same test ID. |
| T30 ×2 (sync idempotency + id hygiene) | Pre-existing; counts desyncs post-sync | Final install (verify) | jq leg count stays 7 (plan prompt from U5); python leg stays 2. Same test IDs. |
| T39 ×2 (merge both engines) | Pre-existing; same residual desyncs | Final install (verify) | jq leg 7; python leg 2. Same test IDs. |

## Deviations from design / preflight

1. **Design-owned layout extension**: tasks 6.2 lists "warning, N/A, dual" as required axis-3 comparison classes; the acta fixture contract names clean + 21 dirty + multi + missing/renamed-checklist. Added three extra fixtures (`warning/`, `na-justified/`, `dual/`) so T57/T58 pin L4/L5/L6 with deterministic markers. The acta explicitly delegates fixture naming/layout to design ("Fixture file naming and layout are design-owned"), and design D9 mandates machine-readable RED.
2. **T60 greens immediately (no RED phase)**: the `sdd-architecture-plan` wiring was implemented in U1 (task 1.4); T60 adds the specific named pin (T33/T37 only shape-checked the fragment generically). Test-before-implementation is honored for NEW behavior; T60 is a regression pin on U1 state, fails-closed if the wiring regresses.
3. **Fixture marker grammar**: `VIOLATION(<ID>)`/`AMBIGUOUS(<ID>)`/`CONTRADICTION(<ID>)` markers are the machine-readable shape of findings the RED proxy compares against expected.json. The LLM lint evaluates real changes (not fixtures); the fixtures only pin the axis-3 contract rules deterministically, per acta "the RED suite compares against" expected findings. No lint/quest/plan skill text was touched in U6.
4. Nothing else deviates: `expected.json` schema pinned, verdict/severity/suppression rules asserted, suite < 2 min, T01–T48/T42b/T47b unchanged.

## Issues found

1. **Duplicate acta rows in na-justified/dual** (fixture-authoring defect, caught pre-GREEN): the first draft prepended the custom P08/P02 row over the 21-row template, producing two P08/P02 rows with conflicting states. Regenerated both acta files with exactly one row per ID; verified `grep -c` = 1 before the GREEN run. No test change needed (tests assert single-row presence).
2. The 6 residual FAILs remain the documented pre-existing desync classes (see Scope mapping). The deployed tree stays read-only until final install (U1 contract); T05/T21/T30/T39 green at verify-time deploy, out of apply scope.
3. No other issues. Fixtures are untracked new files; nothing outside `tests/` + `tasks.md` was touched in this batch.

## Status

Phase 6: 3 of 3 tasks complete (6.1–6.3 [x]). **U6 done (FINAL) — T55–T60 green (axis-3 fixture comparisons: clean pass, per-family IDs, full blocker set, warning, N/A-suppress, dual signal, fail-closed anchors; wiring B5), zero new failures (58/6), suite 65s < 2 min, `--check` Errores: 0 with no new desync surfaces; all 6 phases complete. All tasks marked [x]. Ready for verify: deploy applies the change and re-checks zero desyncs (final install clears T05/T21/T30/T39).**

---

# Apply Progress U7 — arch-principles-quest-linter

- **Work unit**: U7 — fix-t52-runtime-leg (post-verify remediation)
- **Date**: 2026-09-15 (U7 batch, post-verify)
- **Executor**: sdd-apply
- **Mode**: Strict TDD (test runner: `bash tests/run_red_checks.sh`)
- **Artifact store**: hybrid (openspec repo + engram)
- **Attempt ledger token**: sha256:1172e84c30da9728ecc9a76cb269de40528c395d99861bc7544a15385f5f10fc (work unit: fix-t52-runtime-leg, successor to failed verify-all)
- **Delivery decision**: single-PR remediation, `size:exception` per change policy? — **No**: remediation is a focused test-file pin correction, +11 net lines in `tests/run_red_checks.sh` (well inside the 50-line fix budget and the 400-line review budget). No chain needed.
- **Rollback boundary**: revert ONLY the T52 acceptance block + intent comment in `tests/run_red_checks.sh` (the single changed file; apply-progress.md U7 section is additive, reversible by deleting this section). All other surfaces (U1–U6 bytes, catalog, deployed tree) untouched — `git diff tests/run_red_checks.sh` is the complete rollback unit.

## Context — why this remediation exists

`verify-report.md` (failed verify-all) found **T52 false-negatives after final install**: the runtime leg grepped the literal filename `architecture-principles\.md` in `./sync-skills.sh --check --skip-gentleai-sync` output. That filename only appears in `[FALTA]` (pending) rows; once the sync installs the catalog, `--check` prints directory-level `[up-to-date]` rows for `_shared` and NEVER names the file. So the leg — whose own intent comment says the catalog must be recognized "(pendiente [FALTA] o instalado)" — contradicted its own contract of accepting BOTH states. The implementation itself is correct: catalog md5-identical at both destinations (`9b51fdf5b0ec394ee70b873afd913879`), `--check` exit 0 "sincronizado (cero desyncs)", T30/T39 zero-desync invariants PASS in the same run.

Verify evidence cited: post-install run **PASS 61 / FAIL 1 / SKIP 0 (61s)**, failing check = T52; pre-install run PASS 58 / FAIL 6 with T05/T21/T30×2/T39×2 (all desync classes that final install clears). T52 was passing pre-install (FALTA row present) and breaking post-install — the exact defect.

## Scope executed (this batch)

1. **Root-caused without re-implementing anything** (T52 already correct in U2–U6; only the leg's runtime acceptance was wrong). Verified on the real host: `--check` post-install output contains `[up-to-date] .../skills/_shared (directorio real compartido)` rows and zero occurrences of `architecture-principles.md`; deployed file md5 `9b51fdf5...` identical at `skills/_shared/architecture-principles.md` (repo canonical), `~/.config/sdd-own/skills/_shared/...`, `~/.agents/skills/_shared/...`.
2. **Safety Net (RED)**: full suite unmodified → **PASS 61 / FAIL 1 / SKIP 0 (58s)** — the defective pin red in the installed state, byte-identical to the verify failure. This is the RED leg of the pin correction.
3. **Fix (`tests/run_red_checks.sh`, the ONLY file edited; +11 net lines, all in the T52 block)**:
   - Intent comment (lines 1116–1126) rewritten in English (per gateway instruction) to state the leg MUST accept either valid state: pending (`[FALTA]` row naming the file) or installed (`[up-to-date]` directory row for `_shared` OR deployed catalog byte-identical to canonical), and must still FAIL when the catalog is genuinely missing. Historical PIN DEFECT notes (U2 REAL_HOME) preserved below it verbatim.
   - Runtime acceptance (replaces the single literal grep): three-signal OR — (1) `grep 'architecture-principles\.md'` matches a pending `[FALTA]` row; (2) `grep '\[up-to-date\].*_shared'` AND deployed file exists at `$REAL_HOME/.config/sdd-own/skills/_shared/...` (installed state, output-level); (3) deployed file exists AND `cmp -s` byte-identical to `$REPO/skills/_shared/architecture-principles.md` (installed state, filesystem-level, md5-equivalent). All three false → original `ko "check no reconoce el catalog en el loop shared"` fires (fail-closed preserved). Uses `$REAL_HOME` (suite start capture) consistently with the U2 pin — never the sandboxed `$HOME` T44 exports.
   - No other leg touched; no T05/T21/T30/T39/T15 weakening; strict-TDD invariants unchanged.
4. **Triangulation probe (RED-proof of semantics, live block)**: extracted the exact acceptance block from the file via awk and ran it against 6 synthetic states — pending-FALTA → PASS; installed `[up-to-date]`+deployed → PASS; installed byte-identity-only → PASS; genuinely missing → KO; FALTA-for-different-file → KO (no loose-grep masking); deployed-drift without output signals → KO (cmp guards). All 6 as designed.
5. **GREEN**: full suite → **PASS 62 / FAIL 0 / SKIP 0 (59s)**. T52 `[PASS]`. T15 not flaking; nothing regressed.
6. **Harness re-confirm**: `./sync-skills.sh --check --skip-gentleai-sync` → **exit 0, Errores: 0, "sincronizado (cero desyncs)"** (post-install state unchanged, unmodified harness).

## Files changed (U7)

| File | Action | What Was Done |
|------|--------|---------------|
| `tests/run_red_checks.sh` | Modified | T52 runtime leg: intent comment (English, both valid states + fail-closed), 3-signal acceptance (pending FALTA / `[up-to-date]` _shared + deployed / deployed byte-identical via cmp), rest unchanged |
| `openspec/changes/arch-principles-quest-linter/apply-progress.md` | Modified | U7 section appended (this file); U1–U6 sections byte-untouched |

## TDD Cycle Evidence (strict TDD — suite pins as the tests)

| Task | RED (test written first) | GREEN (implementation passes) | REFACTOR |
|------|--------------------------|-------------------------------|----------|
| T52 runtime-leg acceptance fix | The pin was ALREADY the test; its defect was demonstrated RED **in the installed state** (Safety Net **61/1**, T52 the only failure — identical to verify). Triangulation probe against the live block then proved the CORRECTED acceptance passes pending AND installed AND still fails on genuinely-missing (6/6 synthetic cases). | T52 **PASS** post-fix; full suite **62/0 (59s)** — zero failures, zero regressions vs the 61/1 baseline. | Removed no signal: pending FALTA, installed output, AND installed byte-identity are all still asserted; the loose literal-grep (which could only ever match pending rows) is gone. Fail-closed preserved (probe cases 4–6). |

## Work Unit Evidence

| Evidence | Required value |
|----------|----------------|
| Focused test command and exact result | `bash tests/run_red_checks.sh` → Safety Net (pre-fix) **PASS 61 / FAIL 1 / SKIP 0, 58s** — exactly T52; post-fix GREEN **PASS 62 / FAIL 0 / SKIP 0, 59s** — T52 `[PASS]`, zero new failures, zero regressions. Suite stays < 2 min. |
| Runtime harness command/scenario and exact result | `./sync-skills.sh --check --skip-gentleai-sync` → **exit 0**, `Errores: 0`, `Estado: sincronizado (cero desyncs)` post-install (REAL_HOME). The leg's own `( cd "$REPO" && env HOME="$REAL_HOME" timeout 120 ./sync-skills.sh --check --skip-gentleai-sync )` runs inside the suite and now passes with the `[up-to-date]` output + byte-identity signals. |
| Rollback boundary | `git diff tests/run_red_checks.sh` alone reverts the entire fix (T52 block); apply-progress U7 is additive markdown. Nothing else changed in this batch — U1–U6 bytes, catalog md5s, deployed tree, tasks.md all untouched. |

## Deviations from design / tasks

1. **None in the design contract**: this batch implements no design change — it repairs a test-instrumentation defect discovered by verify. The design's T52 intent ("catalog recognized: pending [FALTA] or installed") is now exactly what the test asserts.
2. **Comment language**: gateway instruction required the updated intent comment in English (technical artifact language rule), while the historical U2 pin notes above it stay verbatim Spanish. No other test comments touched.

## Issues found

1. Root cause confirmed: literal-filename grep only ever matches pending `[FALTA]` rows — an inherent instrumentation flaw, not an implementation flaw. The catalog, loop join, guards, and zero-desync invariants were all correct (T49–T51, T30/T39 PASS in the same runs).
2. The `cmp -s` signal needs `$REPO/skills/_shared/architecture-principles.md` to exist at suite time — it does (repo canonical, md5 `9b51fdf5...`); fail-closed probe case 6 also proved drift is detected (KO) rather than silently accepted.
3. No other issues. The deployed tree was never written (U1 contract held through verify's final install and this remediation).

## Status

**U7 done (post-verify remediation) — 62/62 suite green, `--check` exit 0/Errores: 0, T52 `[PASS]` in the installed state with fail-closed semantics proven by 6-case triangulation. Ready for verify re-run.**
