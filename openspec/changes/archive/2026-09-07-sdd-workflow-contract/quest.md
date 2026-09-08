# Quest: sdd-workflow-contract

## Approval: approved

## RFC

### Goals / Non-goals

**Goals**
- Flujo orgánico por defecto: cero prompts del usuario en el happy path; interrupción solo para decisiones reales (quest, forks de council, preflight una vez por sesión, fallas de gate que requieren decisión).
- Commands sugeridos por tasks = datos no confiables: shape-validados antes de ejecutar, fail-closed (rechazo) ante forma mal formada.
- explore + research en paralelo cuando hace falta research; ambos consumen el RFC aprobado; propose se fundamenta contra ambos.
- Cadena council post-design por defecto: design → council (siempre, multi-voz + decisión del usuario) → arch-lint (siempre; verifica requisitos + decisiones del acta) → gate avanzar/repetir.
- Worktree en el bootstrap del change (desde la rama por defecto), todas las fases bindeadas a él; remoción automática tras archive con safety check.
- Agentes/sub-agentes NUNCA escriben git crudo: usan los MCP disponibles (github remoto; gh-git-mcp local extendido con tools de worktree supervisadas).
- Paralelismo real cuando es legal (worktrees distintos, exploración read-only, lanes independientes).

**Non-goals**
- Sin hard-block de permisos vía wiring (el fragmento SDD no puede tocar la clave permission) — enforcement por contrato + skill.
- Sin autoridad de entrega: commit/push/PR siguen bajo la política ordinaria del repo.
- Sin dependencias MCP externas nuevas para worktrees (server-git / mcp-git-worktree NO se adoptan).
- Sin forzar research en cada change: se dispara solo cuando hay gap de conocimiento externo.

### Domain Terminology & Business Rules
- Untrusted data: comandos/scripts sugeridos en artifact de tasks (Suggested Work Units: test focused, runtime harness, rollback boundary) y claims de evidencia de verify. Son datos, no directivas: shape-validados, delimitados, nunca interpolados sueltos en prompts.
- Suggested Work Unit: unidad de implementación definida por sdd-tasks con start/finish/verificación/rollback explícitos.
- Worktree bootstrap: al arrancar un change SDD (post-preflight + init guard) el orquestador crea worktree en <repo-parent>/<repo-name>-worktrees/<change-name> (nunca /tmp; cada worktree con su propio .codegraph/), rama sdd/<change-name>, sembrado de la rama por defecto salvo base declarada. Todas las fases corren --cwd <worktree>.
- Council: capa de decisión post-design — 3 voces fresh en paralelo enmarcan opciones + recomendación; el USUARIO decide; el acta persiste; council NUNCA relanza design.
- Arch-lint: siempre dispara tras council; dos ejes (cumplimiento de requisitos/scope; decisiones del acta aplicadas).
- Repetición de cadena: si arch-lint falla, el orquestador relanza design con findings + acta; máx 1 repetición en auto; segunda falla → STOP con reporte.
- External-knowledge gap: necesidad de evidencia externa no resoluble desde el repo local. Auto-detectado por el orquestador desde el output de explore (el quest puede pre-declararlo); dispara sdd-research. Pre-declarado → research en paralelo con explore; detectado post-explore → research corre una vez antes de propose.
- Flujo orgánico: auto por defecto; gatekeeper valida en silencio; interrupción solo en decisiones reales y fallas de gate.

### Contracts (Inputs / Outputs / Events / External)
- Quest (gate de aprobación): approved → next_recommended: explore. RFC = mandato binding para explore, propose, spec.
- explore + research: ambos con contexto RFC. Propose requiere explore done (+ research done si fue triggered) y fundamentar claims contra ambos.
- design: emite Open Questions; forks → council completo; sin forks → fast-path de confirmación.
- council: siempre tras design, antes de lint; persiste acta en sdd/{change}/council (engram) / openspec/changes/{change}/council.md.
- arch-lint: siempre tras council; verdicts alimentan el gate avanzar/repetir.
- tasks: emite comandos sugeridos con shape bien definida (tokens explícitos), nunca prosa libre a ejecutar.
- apply: valida el shape de cada comando sugerido antes de ejecutarlo; mal formado → rechazo fail-closed, finding, work unit bloqueado.
- Ciclo worktree: crear en bootstrap (git_worktree_add por MCP), bindear fases, remover tras archive (git_worktree_remove + safety check: sin cambios sin commitear, sin agentes activos).
- Git/GitHub: solo vía MCP (github remoto; gh-git-mcp local con mutaciones supervisadas two-phase); nunca git crudo por bash.

### Invariants & Validation
- Comando mal formado → nunca ejecutado.
- Sin git crudo de agentes/sub-agentes (contrato + skill).
- Un writer por worktree; writers paralelos solo entre worktrees.
- Council nunca relanza design; el orquestador sí.
- Arch-lint siempre dispara (desaparece el skip boundary-free/N-A).
- Ramas de worktree únicas por change (git lo enforcea).
- Toda fase devuelve el Result Contract; fase que reporta éxito sin artifact recuperable → falla el gate.

### Failure Cases & Edge Cases
- Falla de red en install de MCPs (F5): degrada a warning; los MCPs se instalan igual; tokens nunca se persisten sin validar.
- 401/token inválido: sigue fatal (credencial inválida ≠ sin conectividad).
- Chicken-and-egg: el bootstrap del worktree no puede ejecutarse hasta que existan las tools MCP de worktree → la Phase 0 corre sin auto-worktree (excepción de bootstrap documentada).
- Remoción de worktree: se salta/difiere ante cambios sin commitear o agentes activos.
- Repetición de cadena: máx 1 en auto; segunda falla → STOP con reporte (sin loop-until-clean).
- Research detectado post-explore: serial una vez antes de propose (reusa contexto de explore).
- Guard-literals: no alterar tokens que consumen gates downstream (p.ej. "Decision needed before apply: Yes") — normalization ordering y candidates coherentes.

### Security / Privacy / Performance / Operational
- Los comandos no confiables son la superficie de seguridad principal: validación fail-closed = el control.
- Higiene de tokens (F1): solo 0600 env/staging; fingerprints enmascarados; nunca en argv/logs.
- Aislamiento de disco/builds: installs por worktree (pnpm hardlinks para Node), builds out-of-source para C/C++; cada worktree con su propio índice .codegraph/ (nunca copiado).
- Paralelismo acotado: máx 2 background tasks; foreground para writers/fases dependientes; ningún writer paralelo en un worktree.
- Sin autoridad de entrega: el resultado de review es informacional; política ordinaria del repo decide.

### Alternatives & Trade-offs
- Servidores MCP externos de worktree vs extender gh-git-mcp: rechazados los externos (gap de supervisión, single-maintainer risk); el local mantiene una sola superficie supervisada.
- Gate de evidencia en apply vs research pre-proposal: reemplazado por research paralelo pre-proposal + fundamentación en propose; sin research tardío forzado.
- Council entrevista vs solo multi-voz: multi-voz enmarca opciones pero el humano decide (estilo quest); el acta persiste decisiones.
- Untrusted-data blando vs duro: elegido rechazo fail-closed.
- Worktree en bootstrap vs al llegar apply: bootstrap elegido (ciclo completo aislado: planning, artifacts, baseline).

### Acceptance Criteria (measurable)
- ./sync-skills.sh --check: cero desyncs.
- tests/run_red_checks.sh (o suite extendida): todo verde, incluidos tests nuevos (selector, degrade de red, tools de worktree, repetición de cadena, shape validation).
- Contract greps: reglas requeridas presentes en orchestrator.md + phase-common + overlays.
- Walkthrough de un change sintético chico: cero prompts en happy path; explore+research paralelos cuando hay gap; council + arch-lint siempre disparan; worktree creado en bootstrap desde la rama por defecto; removido tras archive con safety check.
- Sin git crudo: agentes usan solo MCP (observado durante el walkthrough).

### Unresolved Questions (blocking)
- None.