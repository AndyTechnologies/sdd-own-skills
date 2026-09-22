# Feature: odd-rfc-oddy — Refactor ODD-only tras el acta de la quest

- **Objective**: Implementar las 7 decisiones de la quest (acta en topic engram `workflow/odd-refactor-decisions`) sobre la base del rename (`37314bc`): eliminar openspec del flujo ODD, sembrar SIEMPRE `odd/tasks` tras aprobar el product RFC, loop de corrección writer-primero, inline de la mecánica Q&A en ambas quests (sin cargar la skill grilling), mantener allow-list sdd-*, y ajustar triggers/contratos de arch-quest / arch-plan / lint al flujo ODD puro.
- **Problem**: sdd-own ya no describe su alcance (ODD-first, SDD morirá en gentle-ai); los contratos aún referencian openspec/spec-deltas/design.md/SDD phases que ODD no produce; la persistencia ODD no tiene namespace propio; grilling (user-invoked) se carga desde fases que deben ser automáticas.
- **Why**: Pivote full ODD del usuario + decisiones explícitas de la quest.
- **Scope**: Solo extensiones propias (skills `product-quest`, `architecture-quest`, `architecture-lint`, prompts `rfc-author`, `architecture-plan`, overlay `sdd-phase-common`, routing `wiring/sdd-own-routing.md`, fragmento `wiring/opencode.sdd.json`, docs). NO se tocan fases nativas de Alan.
- **Constraints**: reglas de oro AGENTS.md; artículos en inglés; commit por unidad de trabajo; sync solo con `--check`.

## Acta de la quest (binding)

1. **openspec ELIMINADO** del flujo ODD: persistencia ODD pura = `odd/rfcs/<feature>-*.md` (file) + `odd/<feature>/*` (engram). Se quitan ramas/if-branches openspec de quests, rfc-author, arch-plan y lint.
2. **SIEMPRE sembrar `odd/tasks/<feature>.md`** tras aprobar el product RFC (todos los tamaños).
3. **Orden (resuelto)**: seed task doc desde RFC → arch-plan consume RFCs + explore + task doc → acta integrada al task doc (sin archivo separado).
4. **Loop lint**: writer primero con findings; arch-plan solo si el finding invalida arquitectura; máx 2 rounds en auto, 3ra falla → parar y preguntar.
5. **Inline Q&A en AMBAS quests** (product L75 y arch L77): quitar carga de skill grilling; mecánica inline en las skills.
6. **Allow-list sdd-\*** se mantiene (no tocar wiring/opencode.sdd.json salvo lo referido a prompts renombrados).
7. **Base**: commit `37314bc` (rename sin prefijo sdd) ya commiteado.

## Checklist (stable IDs)

- [x] **T1 — routing ODD puro**: `wiring/sdd-own-routing.md` reescrito: eliminar "explicit SDD"; product-quest ALWAYS; arch-quest condicional por trigger afinado (product RFC/explore que superficie decisiones de arquitectura, o intención explícita); arch-plan solo sustancial; lint post-apply parte del verify contra RFCs + odd/tasks + acta (cuando se produjo); declarar delegación como el mecanismo auto (auto = revisión delegada registrada por el orquestador, fase NUNCA se auto-aprueba).
- [x] **T2 — product-quest ODD**: `skills/product-quest/SKILL.md`: quitar referencias openspec/sdd-propose/sdd-spec; persistencia `odd/rfcs/<change>-product-rfc.md` + engram `odd/<change>/product-rfc`; siembra SIEMPRE de odd/tasks (decisión 2); inline Q&A (quitar carga de grilling, L75); gate único post-ensamblado (decisión 5); keep MANDATORY pero re-enfocado a named change ODD.
- [x] **T3 — architecture-quest ODD**: `skills/architecture-quest/SKILL.md`: trigger afinado (decisión 4); namespace ODD; inline Q&A quitar grilling L77; gate único post-ensamblado; out a rfc-author (arch).
- [x] **T4 — rfc-author ODD**: `wiring/prompts/sdd/rfc-author.md`: `next_recommended` product → task-doc ODD (siembra SIEMPRE odd/tasks) en vez de sdd-propose; gate único post-ensamblado presentado al usuario; persistencia ODD (odd/rfcs + engram odd/<feature>/...); sin openspec.
- [x] **T5 — architecture-plan ODD**: `wiring/prompts/sdd/architecture-plan.md`: consumir RFCs + explore + odd/tasks (no spec deltas); acta integrada al task doc; loop: si lint invalida arquitectura → re-lanzar acotado al eje afectado; auto mode = revisión delegada registrada por el orquestador; sin sdd-research → worker ODD.
- [x] **T6 — architecture-lint ODD**: `skills/architecture-lint/SKILL.md`: inputs = RFCs + odd/tasks + acta (cuando arch-plan corrió); N/A por construcción si no se produjeron contratos; si axis falla → findings al writer, arch-plan solo si arquitectura; quitar design.md/sdd-design/sdd-verify.
- [x] **T7 — overlay**: `overlays/shared/sdd-phase-common.md`: des-SDDizar los bloques propios (lenguaje ODD, sin openspec), manteniendo ids de bloque `sdd-own:<id>:start/end` para strip+append idempotente.
- [x] **T8 — docs**: matar `docs/issue-3332-rfc-gate.md`; corregir `README.md:243` y cualquier otra referencia al orden viejo quest→explore→propose/openspec.
- [x] **T9 — verificación**: `./sync-skills.sh --check`; suite RED `tests/run_red_checks.sh`; greps: 0 referencias openspec en superficie live de extensiones propias excepto historia permitida; `bash -n` OK; `jq` valida fragmento.

## Verificación de registro

- Writer: delegado `general` (trigger: 2+ archivos no triviales, 9 archivos interrelacionados), status `success`.
- Gatekeeper: PASS — artefactos leídos (routing, rfc-author, product-quest, lint, arch-plan, overlay), claims verificados, sin drift del acta. Assessment nativo: `medium` (executable_change en lint, 9 paths, 574 líneas) → RDD off → writer self-verification + spot check del parent (greps 0 grilling/0 sdd-propose en surface propia, bash -n OK, suite RED re-corrida 71/7 con los 7 invariantes post-sync esperados).
- Commits: unidad de trabajo en `feat/odd-workflow-refactor` (conventional commit, sin push). Sync real = decisión del usuario posterior.

## Acceptance criteria

1. Persistencia ODD pura documentada en skills/prompts: odd/rfcs + odd/tasks + engram, sin ramas openspec.
2. Ninguna fase propia carga la skill grilling; mecánica Q&A inline.
3. Gate único por artifact: rfc-author ensambla → usuario aprueba; auto = delegación registrada; fase nunca se auto-aprueba.
4. 0 referencias a openspec/spec-deltas/design.md/sdd-propose/sdd-spec/sdd-design/sdd-verify en superficie live propia.
5. Allow-list sdd-* intacta; fases nativas de Alan intactas.