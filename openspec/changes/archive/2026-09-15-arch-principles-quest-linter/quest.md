# Quest: arch-principles-quest-linter

## Approval: approved

## Branch: product

## RFC

### Goals / Non-goals

**Goals**
1. Re-mecanizar la rama **architecture** del Quest SDD: selección de preguntas por contexto (8 base de contexto + branching adaptativo + early-stop), manteniendo el presupuesto hard de 20.
2. Agregar al **architecture-lint** un **axis 3** de principios verificables con veredicto propio y severidades (blocker para violaciones del núcleo y anti-patrones; warning para sospechas).
3. Integrar un **checklist obligatorio de principios no-verificables** en el acta del **architecture-plan** (arch-plan.md), con evidencia de dirección; N/A justificado cuando no aplique.
4. Crear una **fuente única de verdad** compartida `skills/_shared/architecture-principles.md` que consumen quest, plan y linter: núcleo de ~10 principios verificables + catálogo de anti-patrones (categoría completa, 11) + criterio de evidencia por principio.
5. Definir la **clasificación explícita de gaps** abiertos por early-stop: decisión puntual (pregunta fuera del cuestionario) / knowledge (research lane) / bloqueante (Unresolved Questions del RFC). Ningún gap desaparece silenciosamente.
6. Permitir preguntas de **stack/tecnología** en el quest architecture cuando el contexto lo pida (excepción explícita, confirmada por el usuario como requerimiento).
7. Verificar con **fixtures + suite RED**: cambios SDD de ejemplo limpios y con violaciones; el linter (axis 3), el quest (presupuesto 20/branching) y el plan (sección obligatoria) con resultados esperados.

**Non-goals**
1. La **Product quest** no se toca: conserva su presupuesto 50 y su estructura actual.
2. **Sin refactor externo**: el catálogo documenta + habilita checks sin forzar tecnología nueva ni refactor de otras skills fuera del scope.

### Domain Terminology & Business Rules

- **Quest**: fase SDD pre-exploración de entrevista acotada; dos ramas — Product (50) y Architecture (20). Cada rama produce un RFC con su propio gate de aprobación explícita.
- **Rama architecture**: entrevista que parte del Product RFC aprobado + intención de arquitectura del usuario; nunca de exploración del repo; language-agnostic salvo excepción de stack confirmada.
- **Principios núcleo (axis 3)**: los ~10 principios mapeables a evidencia concreta en el código — modularidad/límites, cohesión, bajo acoplamiento, separación de responsabilidades, contratos explícitos, testeabilidad, diseño-para-fallo, estado compartido mínimo, seguridad por defecto, simplicidad.
- **Anti-patrones (categoría completa, 11)**: monolito distribuido, microservicios prematuros, DB compartida como integración, sobreingeniería, estado global mutable, sync excesivo, dios-objeto, bolsa de masas, adicción a frameworks, copia/pega, cadena de responsabilidad excesiva.
- **Principios no-verificables**: los que no se prueban estáticamente en un cambio puntual (optimización por evidencia, evolución incremental, reversibilidad, alineación con equipo, etc.) — van al checklist obligatorio del acta.
- **Severidades del linter**: blocker (violación del núcleo o anti-patrón) / warning (sospecha no confirmada). El axis 3 tiene veredicto propio PASS/FAIL.

### Contracts (Inputs / Outputs / Events / External)

- **Input común**: `skills/_shared/architecture-principles.md` — catálogo único (núcleo + anti-patrones + criterio de evidencia).
- **Quest (rama architecture)**: input = Product RFC aprobado + intención de arquitectura + catálogo; output = Architecture RFC (schema fijo) con `## Approval:` y `next_recommended: rfc-author` tras gate 2; failed por presupuesto → report con gaps clasificados.
- **Architecture-plan**: input = arch-rfc + explore/research + spec deltas + catálogo; output = acta arch-plan.md con sección obligatoria "Principios no verificables" (evidencia de dirección por principio aplicable; N/A justificado).
- **Architecture-lint**: input = implementation + design + acta + catálogo; output = veredicto axis 1 (spec), axis 2 (acta title-by-title + sección de principios), axis 3 (principios núcleo + anti-patrones) con severidades.
- **Suite RED**: `tests/run_red_checks.sh` extiende T-checks con fixtures positivos/negativos del axis 3, quest y plan.

### Invariants & Validation

- Presupuesto de la rama architecture = **20**, nunca excedido; agotamiento → report, nunca extensión silenciosa.
- No-goal product quest / sin refactor externo: el cambio no altera la product quest ni otras skills fuera de quest/plan/lint.
- Validación del linter: un principio del núcleo violado = blocker; anti-patrón detectado = blocker; sospecha = warning; veredicto axis 3 PASS solo cuando no hay blockers.
- Validación del plan: sección "Principios no verificables" obligatoria; falta → axis 2 fail-closed (acta incompleta).
- Quest language-agnostic salvo que la pregunta de stack sea confirmada por el usuario en esa entrevista.

### Failure Cases & Edge Cases

- Quest agota presupuesto 20 con ramas abiertas → report de consolidación con gaps clasificados (decisión puntual / research / bloqueante); sin extensión frente al usuario.
- Early-stop corta con gap de decisión humana sin resolver → clasificación explícita, nunca desaparición.
- Acta sin sección de principios no verificables → axis 2 fail-closed.
- Linter con evidencia ambigua (¿violación o falso positivo?) → warning, no blocker; sospecha no degrada a blocker sin confirmación.
- Catálogo desincronizado entre consumidores → fuente única en `_shared`, los tres leen por ruta.
- Cambio sin principios aplicables → N/A justificado en la sección del acta, no omisión.

### Security / Privacy / Performance / Operational

- **Security**: el principio "seguridad por defecto" entra al núcleo verificable del axis 3 (validación de entrada, secretos no hardcodeados).
- **Performance**: los checks del axis 3 y del quest son baratos (estructura, dependencias, imports); sin análisis estático pesado; la suite RED sigue < 2 min.
- **Operational**: catálogo mantenible en un solo lugar; fixtures proporcionan evidencia ejecutable de los tres consumidores.

### Alternatives & Trade-offs

1. **Subir el presupuesto del quest >20** → descartado (trade-off: cobertura vs fatiga de entrevista); se resuelve con selección por contexto + early-stop + clasificación.
2. **Integrar principios al axis 2** → descartado (eje separado da veredicto y severidades propios sin contaminar la verificación del acta).
3. **Checklist de no-verificables en design en vez de plan** → descartado (el design es posterior al plan; el acta es el ancla binding título-a-título).
4. **Copiar el catálogo por skill** → descartado (desincronización); fuente única `_shared`.
5. **Solo 3 anti-patrones detectables** → usuario eligió categoría completa (11) para el primer ciclo.

### Acceptance Criteria (measurable)

- La suite RED corre con nuevos T-checks: fixtures positivos (cambio limpio → axis 3 PASS) y negativos (una violación por principio del núcleo y por cada anti-patrón → axis 3 FAIL con blocker correcto); 0 regresiones en T32-T55 existentes.
- Quest architecture: T-check que verifica 8 base + branching (un escenario sin contexto microservicios no pregunta por microservicios) y early-stop dentro del presupuesto 20.
- Arch-plan: T-check fail-closed — acta sin sección de principios no verificables → lint axis 2 FAIL.
- Todos los tres consumidores (quest, plan, lint) referencian la misma ruta `_shared/architecture-principles.md` (verificado por grep en suite).
- `sync-skills.sh --check` reporta 0 desyncs tras el cambio.

### Unresolved Questions (blocking)

- Ninguna bloqueante para el Product RFC.

---

# Quest: arch-principles-quest-linter

## Approval: approved

## Branch: architecture

## RFC

### Goals / Non-goals

**Goals**
1. **Catálogo compartido como documento estructurado**: `skills/_shared/architecture-principles.md` — único archivo Markdown con campos fijos por principio (nombre, definición, evidencia concreta, severidad default) y tabla de anti-patrones; sin JSON paralelo.
2. **El catálogo alimenta el branching del quest**: ninguna entrevista pregunta principio por principio; cada rama de contexto carga los principios/anti-patrones relevantes; la validación de aplicabilidad ocurre en el plan con N/A justificado.
3. **Tabla de ramas declarativa** en la skill `sdd-quest`: cada rama declara disparador (contexto que la activa), principios/anti-patrones que carga, preguntas de la rama y condición de early-stop; el orquestador la recorre.
4. **Pregunta base gatillo de stack**: una de las 8 base pregunta si el stack/tecnología es un driver del cambio; `sí` habilita la rama tecnología, `no` la saltea (default language-agnostic preservado).
5. **Axis 3 con checks de ID individual**: P01..P10 (principios) + A01..A11 (anti-patrones), severidad por check, findings por check, veredicto axis_3: pass|fail agregado.
6. **El acta decide la aplicabilidad**: la sección obligatoria del arch-plan declara por principio aplicable | evidencia de dirección | N/A justificado; N/A suprime el check con justificación visible; aplicable contra evidencia violada → doble señal axis 2 + axis 3.
7. **Ancla canónica del checklist**: título fijo `## Principios no verificables` en arch-plan.md con tabla por principio; ausencia del título → axis 2 fail-closed.

**Non-goals**
1. La **Product quest** no se toca: conserva su presupuesto 50 y su estructura actual.
2. **Sin refactor externo**: el catálogo documenta + habilita checks sin forzar tecnología nueva ni refactor de otras skills fuera del scope.
3. **JSON paralelo** del catálogo: el MD estructurado es la única fuente en el primer ciclo.
4. **Máquina de estados en script** para el branching: la tabla declarativa en la skill es la representación.

### Contracts (Inputs / Outputs / Events / External)

- **Catálogo `_shared/architecture-principles.md`**: campos fijos por principio (nombre, definición, evidencia concreta, severidad), tabla de anti-patrones con detección; consumido por ruta por quest, plan y lint.
- **Quest (rama architecture)**: input = Product RFC aprobado + intención de arquitectura + catálogo; output = Architecture RFC con `## Approval:`; errores de presupuesto → report con gaps clasificados.
- **Architecture-plan**: input = arch-rfc + explore/research + spec deltas + catálogo; output = acta arch-plan.md con sección obligatoria `## Principios no verificables`.
- **Architecture-lint**: input = implementation + design + acta + catálogo; output = veredicto axis 1 + axis 2 (incluye la sección de principios) + axis 3 con checks PXX/AXX.
- **Suite RED**: `tests/run_red_checks.sh` y fixtures `tests/fixtures/arch-principles/` — un cambio SDD limpio + uno sucio por familia, comparando findings esperados.

### Invariants & Validation

- Presupuesto de la rama architecture = **20**, nunca excedido; agotamiento → report, nunca extensión silenciosa.
- La validación de aplicabilidad de un principio ocurre en el arch-plan (N/A justificado), nunca preguntando principio por principio en la entrevista.
- La tabla de ramas es la única fuente de selección de preguntas del quest architecture; no hay ramas implícitas en prosa.
- Un check con severidad blocker debe emitir finding con ID y evidencia; el veredicto axis_3 FAIL ocurre solo con ≥1 blocker.
- El título `## Principios no verificables` es la ancla canónica; ausencia → axis 2 fail-closed.

### Failure Cases & Edge Cases

- Rama con disparador ambiguo (contexto que activa dos ramas): el orquestador elige por precedencia declarada en la tabla; conflicto real → gap clasificado como decisión puntual.
- Usuario confirma stack en la pregunta base pero ninguna rama de tecnología aplica al contexto: se registra el driver pero la rama no genera preguntas (early-stop de rama).
- Acta dice "aplicable con evidencia de dirección" y el código la contradice: axis 2 la atrapa como mandato no cumplido + axis 3 bloquea la violación (doble señal).
- N/A sin justificación: fila con estado inválido → finding warning en axis 2 (no fail-closed, exige justificación).
- Fixture sucio con violaciones múltiples: se espera el set completo de blockers, no solo el primero.
- Catálogo modificado sin tocar fixtures: la suite verifica que el catálogo y los checks PXX/AXX estén sincronizados.

### Security / Privacy / Performance / Operational

- **Security**: el principio "seguridad por defecto" entra al núcleo verificable (P0x) con evidencia concreta de validación de entrada y secretos no hardcodeados.
- **Performance**: los checks del axis 3 son baratos (estructura, dependencias, imports); sin análisis estático pesado; la suite RED sigue < 2 min.
- **Operational**: catálogo mantenible en un solo lugar; fixtures proporcionan evidencia ejecutable; `sync-skills.sh --check` reporta 0 desyncs.

### Alternatives & Trade-offs

1. **JSON paralelo del catálogo** → descartado (duplica contenido, desincroniza); documentación estructurada MD basta para el primer ciclo.
2. **Checklist por principio en la entrevista** → descartado (quema el presupuesto 20 sin contextualizar); el catálogo alimenta ramas y el plan valida N/A.
3. **Máquina de estados en script** → descartado (duplica el contrato skill↔runtime); la tabla declarativa es mantenible y testeable.
4. **Formato libre del checklist del acta** → descartado (sin veredicto accionable); título canónico + tabla fija.
5. **Archivo separado para el checklist** → descartado (rompe la unidad del acta que recorren los axis).

### Acceptance Criteria (measurable)

- La suite RED corre con nuevos T-checks: fixtures positivos (cambio limpio → axis 3 PASS) y negativos (una violación por principio del núcleo y por cada anti-patrón → axis 3 FAIL con blocker correcto); 0 regresiones en T32-T55 existentes.
- El catálogo `_shared/architecture-principles.md` existe con campos fijos por principio y tabla de 11 anti-patrones; `grep` de la suite verifica que quest/plan/lint referencian la misma ruta.
- Quest architecture: T-check verifica 8 base + branching (escenario sin contexto microservicios no pregunta por microservicios) y early-stop dentro del presupuesto 20; pregunta base de stack presente en las 8.
- Arch-plan: T-check fail-closed — acta sin `## Principios no verificables` → lint axis 2 FAIL; N/A sin justificación → warning.
- Fixtures por familia en `tests/fixtures/arch-principles/`: limpio + sucio, comparando findings esperados (IDs PXX/AXX).
- `sync-skills.sh --check` reporta 0 desyncs tras el cambio.

### Unresolved Questions (blocking)

- Ninguna bloqueante para el Architecture RFC.