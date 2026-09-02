# RFC Interview Gate — Issue #3332 (plan de corrección + estado)

Referencia: https://github.com/Gentleman-Programming/gentle-ai/issues/3332 — "feat(skills): add an RFC interview gate before SDD" (viniciosrab, abierta 2026-08-16).

**Problema original del issue**: no existe un workflow pre-SDD que desafíe al usuario / descubra requerimientos; los agentes inventan comportamiento; los specs se acoplan a la implementación. Cita clave: *"The problem is not the absence of another documentation template. The missing capability is a disciplined interview that forces shared understanding before implementation begins."*

## Plan de 5 pasos (corregido, según decisión del usuario)

1. **Trigger point (la fase quest ES el RFC pre-pass)**: la fase `sdd-quest` ES el pre-pass de RFC y corre ANTES de la exploración. Produce el RFC aprobado como mandato que consume el `explore`. No hay un "pre-pass opcional" separado de la fase quest — son la misma fase implementada por nosotros. Pipeline: `quest → explore → propose`.
2. **Esquema RFC estructurado (lenguaje-agnóstico)**: Goals/Non-goals, Domain Terminology, Contracts (Inputs/Outputs/Events/External), Invariants & Validation, Failure/Edge Cases, Security/Privacy/Performance/Operational, Alternatives & Trade-offs, Acceptance Criteria (measurable), Unresolved Questions (blocking).
3. **Gate de cierre explícito**: de auto-derivado (`confirmed`/`partial`) a APROBACIÓN EXPLÍCITA del usuario (`approved`/`needs-changes`/`rejected`). Solo en `approved` el quest emite `next_recommended: explore`. NUNCA inferir aprobación de un frontier vacío (matches el non-goal #3332 "Automatically approving decisions on behalf of the user").
4. **Lenguaje-agnóstico**: NO arrastrar el stack del repo al RFC salvo que el usuario lo confirme explícitamente como requisito.
5. **Handoff "source of truth"**: el RFC aprobado es input VINCULANTE para proposal — no solo "recommended scope". Aplica tanto a `sdd-propose` como a `sdd-spec`.

## Decisiones del usuario (vía `question` tool)

- Entrevista UNA pregunta a la vez (branch-following), NO rondas/frontier-batch (alineado con #3332).
- El RFC es source of truth para BOTH `sdd-propose` AND `sdd-spec`.
- Se mantiene el tope de 50 preguntas como guard-rail.

## Estado de implementación (2026-09-02)

Completado en las 5 correcciones:

- `grilling/SKILL.md` — primitiva de entrevista acotada: UNA pregunta a la vez, sigue cada rama a resolución, presupuesto duro 50, no arrastra stack salvo confirmación del usuario. Los hechos se buscan, no se preguntan.
- `grill-me/SKILL.md` — alias user-invoked que delega a `grilling` (refleja el nuevo comportamiento).
- `sdd-quest/SKILL.md` + `prompts/sdd/sdd-quest.md` — ahora producen un RFC estructurado lenguaje-agnóstico con esquema fijo y gate `## Approval: approved | needs-changes | rejected`. Solo `approved` → `explore`. El RFC aprobado es el mandato del explore y binding source of truth de propose Y spec. (Reordenado post-implementación: el quest es el pre-pass y corre ANTES del explore.)
- `sdd-spec/SKILL.md` + `prompts/sdd/sdd-spec.md` — leen `sdd/{change}/quest` (RFC aprobado) como input obligatorio; la spec debe ser trazable a los acceptance criteria del RFC; se niega a escribir spec de un RFC no aprobado.
- `commands/sdd-continue.md` — 'QUEST CONDITIONAL' gatillea en `## Approval:` (approved → SKIP quest y pasar a explore; needs-changes → re-run; rejected → NO continuar, reportar). Flujo: quest → explore → proposal → [specs ∥ design] → tasks → apply → verify → archive.
- `opencode.json` — sección orquestador 'SDD Quest Phase' + tabla SDD Phases (quest ES el pre-pass; el explore consume el quest aprobado; propose/spec leen el quest/RFC aprobado).

**Nota**: `obs-105` y `obs-107` documentan el gate ANTERIOR (`## Confirmation: confirmed | partial`) y el orden post-explore. Fueron superados por esta corrección #3332: gate de aprobación explícita (`## Approval:`) y quest como pre-pass ANTES del explore. `obs-99` y `obs-105` siguen siendo referencias válidas de diseño de la entrevista.
