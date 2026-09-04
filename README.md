# sdd-own-skills

Repositorio público (mirror/archive) de las **skills LLM-first** para agentes de código, junto con el script de sincronización a las carpetas globales (`~/.agents/skills`, `~/.config/opencode/skills`, `~/.claude/skills`) y el wiring que conecta las fases del flujo **SDD** (Spec-Driven Development).

Este repo es **la fuente canónica (única copia)** de las skills: a partir de él se despliegan a los runtimes mediante symlinks, evitando duplicación y manteniendo una única fuente de verdad.

---

## ¿Qué contiene?

### Skills (`skills/`)

Conjunto completo de skills para agentes de código, organizadas por área. Cada carpeta contiene su `SKILL.md` (frontmatter con `name`, `description`, trigger y `license`).

#### Pipeline SDD (Spec-Driven Development)

El flujo SDD: `quest → explore → propose → [spec ∥ design] → tasks → apply → verify → archive`.

| Skill | Rol |
|-------|-----|
| `sdd-quest` | **Fase quest (RFC pre-pass):** entrevista al usuario UNA pregunta a la vez (tope duro de 50), produce un RFC lenguaje-agnóstico que el usuario debe aprobar explícitamente (`Approval: approved`). Corre ANTES del explore. El RFC aprobado es la source of truth. |
| `sdd-explore` | Consume el quest/RFC aprobado como **mandato**, valida "¿se puede buildear esto aquí?" contra el repo real, y mapea el **impacto regresivo** (`## Impact`) en el mismo pase. |
| `sdd-propose` | Consume el quest aprobado + la exploración para crear la proposal. **No entrevista** — recibe el handoff confirmado del quest. |
| `sdd-spec` | Escribe el delta spec, leyendo el **RFC aprobado como input vinculante**. |
| `sdd-design` | Crea el diseño técnico / enfoque de arquitectura. |
| `sdd-tasks` | Descompone specs + design en tareas de implementación. |
| `sdd-apply` | Implementa las tareas (soporta **Strict TDD**: `strict-tdd.md`). |
| `sdd-verify` | Ejecuta las pruebas y demuestra que la implementación cumple specs/design/tasks. |
| `sdd-archive` | Cierra el change y sincroniza delta specs. |
| `sdd-init` | Bootstrap del contexto SDD, detección de capacidades de testing, persistencia. |
| `sdd-onboard` | Guía el ciclo SDD completo sobre un repo real (Quest como Phase 2). |
| `sdd-research` | Evidencia externa con fuentes auditables (antes de `propose`). |
| `sdd-architecture-lint` | Segunda mirada independiente del diseño vs clean/hexagonal architecture (solo cuando el diseño toca boundaries). |
| `sdd-changelog` | Narrativa de release + clasificación SemVer automática (post-archive, con opt-out orgánico si no hay cambio visible al consumidor). |
| `skill-sdd-blueprint` | Reference/patrón para crear skills SDD nuevas sin tocar `nextRecommended` ni sobre-ingeniar. |

#### Review / RDD (Receipt-Driven Development)

| Skill | Rol |
|-------|-----|
| `rdd-defect-workflow` | Flujo de defectos de review: receipt, lineage, corrección/recovery, delivery gate (kill switch). |
| `judgment-day` | Revisión adversarial dual (blind judges) con a lo sumo dos rondas scoped de fix/re-judgment. |

#### Pruebas

| Skill | Rol |
|-------|-----|
| `go-testing` | Patrones de testing en Go (teatest de Bubbletea, golden files, coverage). |
| `gentle-ai-bench` | Autoría y verificación de journey corpi de gentle-ai bench. |

#### Colaboración / GitHub

| Skill | Rol |
|-------|-----|
| `branch-pr` | Pull requests de Gentle AI con checks issue-first. |
| `chained-pr` | División de cambios grandes en PRs encadenados (>400 líneas). |
| `comment-writer` | Comentarios cálidos y directos (feedback de PR, reviews, issues). |
| `issue-creation` | Creación y triage de issues de GitHub desde evidencia del repo. |
| `work-unit-commits` | Planificación de commits como unidades reviewables. |
| `systemic-issue-triage` | Ataque de issues por causa raíz, nunca uno a uno. |
| `skill-registry` | Indexado de skills por trigger y path. |

#### Documentación / UI / utilidades

| Skill | Rol |
|-------|-----|
| `cognitive-doc-design` | Documentación que reduce carga cognitiva (guides, RFCs, onboarding). |
| `ui-design` | Decisiones de UI (dark luxury / premium), diseño de sistemas, accesibilidad. |
| `web-search` | Búsqueda web con preferencia por MCP dedicados (donsetch, context7). |
| `hf-cli` | CLI de Hugging Face Hub (`hf`). |
| `grilling` | Primitiva de entrevista acotada: UNA pregunta a la vez, tope duro de 50, branch-following. **User-invoked only.** |
| `grill-me` | Alias user-invoked que delega a `grilling`. |
| `skill-creator` / `skill-improver` | Creación y auditoría de skills LLM-first. |

### Sincronización (`sync-skills.sh`)

`sync-skills.sh` despliega las skills canónicas de `skills/` a los runtimes globales:

- **`~/.agents/skills/<skill>/`** — única **copia física** (compartida por opencode y pi).
- **`~/.config/opencode/skills/<skill>/`** — **symlink** a `../../.agents/skills/<skill>`.
- **`~/.claude/skills/<skill>/`** — **symlink** a `../../.agents/skills/<skill>`.
- **`~/.claude/commands/*.md`** y **`~/.claude/prompts/sdd/*.md`** — **symlinks** al wiring de opencode.
- `wiring/_shared/*.md` → copia física en `~/.agents/skills/_shared/` + symlink en `~/.config/opencode/skills/_shared`.

Es idempotente y sin redundancia: solo escribe/recrea lo que difiere o falta, recrea symlinks donde haya directorios/archivos que debieran serlo, y reporta `up-to-date / creado / desincronizado`.

```bash
./sync-skills.sh            # sincroniza (copia + symlinks)
./sync-skills.sh --check    # verifica sin modificar (reporta desyncs)
./sync-skills.sh --dry-run  # ensayo: muestra qué se haría, sin copiar
```

### Wiring (`wiring/`)

Archivos de integración que enrutan las fases SDD con el orquestador:

- `commands/sdd-new.md` — arranque: `explore → quest → propose` (+ fase RESEARCH).
- `commands/sdd-continue.md` — bloques `QUEST-CONDITIONAL` y `SUPPORT-CONDITIONAL` (enrutamiento orgánico de research / architecture-lint / changelog por estado de artefactos, sin tocar `nextRecommended`).
- `prompts/sdd/sdd-rfc-author.md` — prompt del subagente autor del RFC (recibe las Q&A, **no entrevista**).
- `prompts/sdd/sdd-spec.md` — prompt de la fase spec.
- `_shared/sdd-phase-common.md` — protocolo común (loading de skills, retrieval, persistencia, envelope de retorno) referenciado por las fases.

### Engram snapshot (`engram-snapshot/`) y Docs (`docs/`)

- **`engram-snapshot/`** — snapshot de los artifacts persistentes (proyecto `meowrch`) que documentan el diseño e implementación del quest RFC gate y sus decisiones.
- **`docs/issue-3332-rfc-gate.md`** — el plan de 5 pasos del issue #3332, decisiones del usuario y estado de implementación.

---

## Cambios clave en las skills SDD

Este repo documenta y versiona el trabajo de evolución del pipeline SDD. Los cambios principales sobre las skills originales:

### 1. El RFC aprobado es la source of truth (`sdd-quest` v3.1)

- **`sdd-quest` corre ANTES del explore.** Entrevista al usuario una pregunta a la vez (tope duro de 50 para evitar loops), produce un RFC lenguaje-agnóstico y exige **aprobación explícita del usuario** (`Approval: approved`).
- **Nunca se auto-aprueba una decisión** en nombre del usuario: el quest es el *confirmed pre-proposal handoff* (non-goal de #3332).
- **El orquestador** (único rol con canal interactivo `question`) realiza la entrevista; el subagente `sdd-rfc-author` solo **redacta** el RFC canónico a partir de las Q&A recolectadas — no entrevista.

### 2. Exploración regresiva (`sdd-explore` v2.1 → v2.2)

- Nueva sección **`## Impact`**: en el mismo pase de exploración se inventarían features, tests, contratos e interfaces existentes que el change tocaría, con su riesgo de regresión.
- **Opt-out orgánico:** si el cambio es greenfield/aditivo, `## Impact` = `None` y no se fabrica riesgo regresivo.

### 3. Fases de soporte orgánicas (`sdd-continue`)

Sin tocar `nextRecommended`, se añadieron fases de soporte enrutadas por **estado de artefactos** (bloque `SUPPORT-CONDITIONAL`):

- **`sdd-changelog`** — narrativa de release + clasificación SemVer tras `archive` (con opt-out automático si no hay cambio visible al consumidor).
- **`sdd-architecture-lint`** — segunda mirada independiente del diseño vs clean/hexagonal (solo cuando el diseño toca boundaries).
- **`sdd-research`** — evidencia externa auditada antes de `propose`.
- **`skill-sdd-blueprint`** — patrón de referencia para añadir nuevas skills SDD sin romper el flujo.

### 4. Gestión del quest en `sdd-continue`

- Bloque **`QUEST-CONDITIONAL`**: en `/sdd-new` el quest **siempre** corre (primera alineación); en `/sdd-continue` es **condicional** — se salta si ya existe un quest `confirmed` de una corrida previa (evita re-entrevistas redundantes).

### 5. Topología de sincronización

- Reemplazo del mirror duplicado (2 copias físicas) por **una sola copia física** en `~/.agents/skills` + **symlinks** hacia los demás runtimes (opencode, claude), incluido el wiring de commands/prompts para Claude Code.

---

## Estructura

```
sdd-own-skills/
├── LICENSE
├── README.md
├── sync-skills.sh                # despliega skills/ + wiring/ a los globales (copias + symlinks)
├── skills/
│   ├── <skill>/SKILL.md          # frontmatter: name, description, trigger, license, version
│   └── ...                       # (34 skills)
├── wiring/
│   ├── prompts/sdd/*.md
│   ├── commands/*.md
│   └── _shared/sdd-phase-common.md
├── engram-snapshot/              # artifacts de Engram (diseño/implementación del quest gate)
├── docs/                         # issue-3332-rfc-gate.md
└── .gitignore                    # ignora .atl/ (registry con rutas absolutas locales)
```

---

## Licencia

**Este repositorio** está bajo **MIT** (ver [`LICENSE`](LICENSE)) — cubre la colección, la sincronización (`sync-skills.sh`), el wiring y las skills **propias/adaptadas**.

**Las skills individuales conservan su propia licencia** declarada en el frontmatter de cada `SKILL.md`:

- **MIT**: skills SDD (incluidas las *adaptadas*: `sdd-quest`, `sdd-changelog`, `sdd-architecture-lint`, `skill-sdd-blueprint`), `ui-design` y `web-search` (autor `andy`).
- **Apache-2.0**: skills originales de gentleman-programming / Alan-TheGentleman (ej. `branch-pr`, `chained-pr`, `go-testing`, `judgment-day`, `issue-creation`, `skill-creator`, `systemic-issue-triage`, `work-unit-commits`, entre otras).
- **Sin frontmatter de licencia**: `grilling`, `grill-me` (adaptadas de mattpocock) y `hf-cli` (generada por `hf`, CLI de Hugging Face Hub).

Respeta la licencia declarada en cada skill individual según su autor upstream.
