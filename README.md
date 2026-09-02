# sdd-own-skills

Proyecto espejo / archivo de las **skills propias** creadas y modificadas para el workflow SDD (Spec-Driven Development), junto con los artifacts de Engram que documentan el diseño e implementación.

## ¿Qué contiene?

Este proyecto es un snapshot versionado (git) de las skills y artifacts relacionados con la **integración del gate de entrevista RFC** (issue #3332) en la fase `sdd-quest` del workflow SDD.

### Skills (carpeta `skills/`)

Skills creadas/modificadas en este trabajo (versiones actuales, después de la corrección #3332):

| Skill | Rol | Original en repo |
|-------|-----|------------------|
| `grilling` | Primitiva de entrevista acotada: UNA pregunta a la vez, presupuesto duro de 50, branch-following, no arrastra stack | `~/.agents/skills/grilling/` |
| `grill-me` | Alias user-invoked que delega a `grilling` | `~/.agents/skills/grill-me/` |
| `sdd-quest` | Fase SDD quest: entrevista RFC una pregunta a la vez, RFC estructurado, gate de aprobación explícita | `~/.agents/skills/sdd-quest/` |
| `sdd-spec` | Fase SDD spec, ahora lee el RFC aprobado como input vinculante | `~/.agents/skills/sdd-spec/` |

> Cada skill vive duplicada en dos rutas del sistema (`~/.agents/skills/` y `~/.config/opencode/skills/`) y deben mantenerse idénticas (mirror). Aquí se guarda la versión canónica.

### Wiring (carpeta `wiring/`)

Los archivos de integración que conectan las skills con el orquestador:

- `prompts/sdd/sdd-quest.md` — prompt de la fase quest (subagente)
- `prompts/sdd/sdd-spec.md` — prompt de la fase spec (subagente)
- `commands/sdd-new.md` — flujo de arranque explore → quest → propose
- `commands/sdd-continue.md` — bloque 'QUEST CONDITIONAL' (gate en `## Approval:`)
- `_shared/sdd-phase-common.md` — protocolo común referenciado por las fases

### Engram snapshot (carpeta `engram-snapshot/`)

Snapshot de los artifacts persistentes (Engram, proyecto `meowrch`) que registran el diseño e implementación:

- `obs-99` (discovery) — Análisis de integrar grill-me en SDD
- `obs-105` (architecture) — integración de sdd-quest como fase auto post-explore
- `obs-107` (architecture) — sdd-continue condicional

### Docs (carpeta `docs/`)

- `issue-3332-rfc-gate.md` — el plan de 5 pasos del issue #3332, decisiones del usuario, y estado de implementación.

## Estructura

```
sdd-own-skills/
├── skills/
│   ├── grilling/SKILL.md
│   ├── grill-me/SKILL.md
│   ├── sdd-quest/SKILL.md
│   └── sdd-spec/SKILL.md
├── wiring/
│   ├── prompts/sdd/{sdd-quest,sdd-spec}.md
│   ├── commands/{sdd-new,sdd-continue}.md
│   └── _shared/sdd-phase-common.md
├── engram-snapshot/
│   ├── README.md
│   ├── obs-99.md
│   ├── obs-105.md
│   └── obs-107.md
└── docs/
    └── issue-3332-rfc-gate.md
```

## Concepto clave

El hilo conductor de este trabajo: **el RFC aprobado es la source of truth** del comportamiento. Antes de `sdd-propose` y `sdd-spec`, la fase `sdd-quest` entrevista al usuario (una pregunta a la vez, tope 50) y produce un RFC lenguaje-agnóstico que el usuario debe **aprobar explícitamente** (`Approval: approved`). Nunca se auto-aprueba una decisión en nombre del usuario (non-goal de #3332).
