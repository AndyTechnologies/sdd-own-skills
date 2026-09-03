# sdd-own-skills

Proyecto espejo / archivo de las **skills propias** creadas y modificadas para el workflow SDD (Spec-Driven Development), junto con los artifacts de Engram que documentan el diseño e implementación.

## ¿Qué contiene?

Este proyecto es un snapshot versionado (git) de las skills y artifacts relacionados con la **integración del gate de entrevista RFC** (issue #3332) en la fase `sdd-quest` del workflow SDD.

### Skills (carpeta `skills/`)

Skills creadas/modificadas en este trabajo:

| Skill | Rol | Original en repo |
|-------|-----|------------------|
| `grilling` | Primitiva de entrevista acotada: UNA pregunta a la vez, presupuesto duro de 50, branch-following, no arrastra stack | `~/.agents/skills/grilling/` |
| `grill-me` | Alias user-invoked que delega a `grilling` | `~/.agents/skills/grill-me/` |
| `sdd-quest` | Fase SDD quest (RFC pre-pass): entrevista RFC una pregunta a la vez, RFC estructurado, gate de aprobación explícita; corre ANTES del explore | `~/.agents/skills/sdd-quest/` |
| `sdd-spec` | Fase SDD spec, ahora lee el RFC aprobado como input vinculante | `~/.agents/skills/sdd-spec/` |
| `sdd-explore` | Fase SDD explore: consume el quest/RFC aprobado como mandato y valida contra el repo; incluye sección `## Impact` (análisis regresivo) | `~/.agents/skills/sdd-explore/` |
| `sdd-propose` | Fase SDD propose: consume quest aprobado + exploración para crear proposal | `~/.agents/skills/sdd-propose/` |
| `sdd-onboard` | Guía el ciclo SDD completo sobre el repo real (incluye Quest como Phase 2) | `~/.agents/skills/sdd-onboard/` |
| `sdd-changelog` | Fase de soporte post-archive: genera narrativa de release y clasificación SemVer orgánica (opt-out automático si no hay cambio visible al consumidor) | `~/.agents/skills/sdd-changelog/` |
| `sdd-architecture-lint` | Fase de soporte post-design: segunda mirada independiente sobre el diseño vs clean/hexagonal architecture. Solo corre cuando el diseño toca boundaries (opt-in del orquestador) | `~/.agents/skills/sdd-architecture-lint/` |
| `skill-sdd-blueprint` | Blueprint/reference: patrón para crear skills SDD nuevas sin tocar nextRecommended ni sobre-ingeniar. Invocable por el usuario. | `~/.agents/skills/skill-sdd-blueprint/` |

> Cada skill vive duplicada en dos rutas del sistema (`~/.agents/skills/` y `~/.config/opencode/skills/`) y deben mantenerse idénticas (mirror). Aquí se guarda la versión canónica.

### Sincronización (`sync-skills.sh`)

Las skills canónicas de `skills/` se copian a las dos rutas globales con [`sync-skills.sh`](sync-skills.sh) (reemplaza si difiere, no toca lo que ya está idéntico). Ambas rutas son escaneadas por opencode y por pi (via el skill-registry de gentle-pi), así que una corrida cubre los dos runtimes.

El script también sincroniza la carpeta `wiring/` hacia los globales reales de opencode — esto es lo que enruta las fases del flujo SDD (p.ej. que la quest RFC corre antes que explore):

- `wiring/commands/*.md` → `~/.config/opencode/commands/*.md`
- `wiring/prompts/sdd/*.md` → `~/.config/opencode/prompts/sdd/*.md`
- `wiring/_shared/*.md` → `~/.config/opencode/skills/_shared/` y `~/.agents/skills/_shared/`

```bash
./sync-skills.sh            # sincroniza (copia solo lo que difiere)
./sync-skills.sh --check    # verifica sin modificar (reporta desyncs)
./sync-skills.sh --dry-run  # ensayo: muestra qué se haría, sin copiar
```

Es idempotente y sin redundancia: solo escribe los archivos que realmente cambian.

### Wiring (carpeta `wiring/`)

Los archivos de integración que conectan las skills con el orquestador:

- `prompts/sdd/sdd-rfc-author.md` — prompt del subagente `sdd-rfc-author` (rol: autor del RFC — recibe las Q&A y redacta; NO entrevista)
- `prompts/sdd/sdd-spec.md` — prompt de la fase spec (subagente)
- `commands/sdd-new.md` — flujo de arranque quest → explore → propose
- `commands/sdd-continue.md` — bloque `QUEST-CONDITIONAL` (gate en `## Approval:`) + bloque `SUPPORT-CONDITIONAL` (enrutamiento orgánico de research, architecture-lint, changelog)
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
│   ├── sdd-explore/SKILL.md          # v2.2 — incluye ## Impact
│   ├── sdd-spec/SKILL.md
│   ├── sdd-onboard/SKILL.md
│   ├── sdd-propose/SKILL.md
│   ├── sdd-changelog/SKILL.md        # soporte post-archive (narrativa release + SemVer)
│   ├── sdd-architecture-lint/SKILL.md # soporte post-design (clean/hex audit independiente)
│   └── skill-sdd-blueprint/SKILL.md  # reference: patrón para crear skills SDD nuevas
├── wiring/
│   ├── prompts/sdd/{sdd-rfc-author,sdd-spec}.md
│   ├── commands/{sdd-new,sdd-continue}.md
│   └── _shared/sdd-phase-common.md
├── engram-snapshot/
│   ├── README.md
│   ├── obs-99.md
│   ├── obs-105.md
│   └── obs-107.md
├── docs/
│   └── issue-3332-rfc-gate.md
└── sync-skills.sh            # sincroniza skills/ y wiring/ -> globales de opencode/pi
```

## Concepto clave

El hilo conductor de este trabajo: **el RFC aprobado es la source of truth** del comportamiento. La fase `sdd-quest` (el RFC pre-pass) se ejecuta **ANTES de la exploración**: entrevista al usuario (una pregunta a la vez, tope 50), produce un RFC lenguaje-agnóstico que el usuario debe **aprobar explícitamente** (`Approval: approved`), y ese RFC aprobado es el **mandato** que consume la fase `explore`. Luego `sdd-propose` y `sdd-spec` usan ese RFC como input vinculante. Nunca se auto-aprueba una decisión en nombre del usuario (non-goal de #3332).

**Modelo de ejecución (OpenCode):** el ORQUESTADOR (único rol con el canal interactivo `question`) es quien realiza la entrevista de quest una pregunta a la vez, siguiendo la skill `sdd-quest`; NO delega la entrevista al subagente. El subagente `sdd-rfc-author` cumple el rol de **autor del RFC**: tras la aprobación explícita del usuario, el orquestador le delega las Q&A recolectadas para que redacte el RFC canónico final que se persiste como mandato. La entrevista fluye de forma continua — tras cada respuesta se hace la siguiente pregunta de inmediato, sin pausar pidiendo "continúa"/"go on" entre preguntas; el único punto de espera para el visto bueno del usuario es el gate de aprobación del RFC.

Pipeline: `quest → explore → propose → [spec ∥ design] → tasks → apply → verify → archive`.

**Fases de soporte orgánicas** (detectadas por estado de artefactos en `sdd-continue`, sin tocar `nextRecommended`):
- `sdd-research` — evidencia externa con fuentes auditables (invocable antes de `propose`)
- `sdd-architecture-lint` — segunda mirada independiente sobre boundaries cuando el diseño los toca (post-design)
- `sdd-changelog` — narrativa de release + clasificación SemVer automática (post-archive, solo si hay cambio visible al consumidor)

> `skill-sdd-blueprint` documenta el patrón de creación de skills SDD nuevas. Invocable por el usuario.
