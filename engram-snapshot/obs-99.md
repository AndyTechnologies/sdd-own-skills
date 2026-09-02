# obs-99 [discovery] Análisis: integrar skill grill-me (mattpocock) en workflow SDD

**What**: Analicé cómo integrar la skill `grill-me` de mattpocock/skills al workflow SDD de andy, enfocado en NO romper el setup ni generar loops infinitos de preguntas.
**Why**: El usuario quiere la entrevista relenless de grill-me (align antes de codear) sin chocar con el framework Lossless Blocking Prompts / question del orquestador gentle-ai ni con el contrato SDD que PROHIBE al proposer entrevistar.
**Where**: Repo clonado en /tmp/opencode/mattpocock-skills; config en /home/andy/.config/opencode/opencode.json; skill-registry en /home/andy/.atl/skill-registry.md; skill-resolver en skills/_shared/skill-resolver.md.
**Learned**:
1. `grill-me/SKILL.md` es un stub (`disable-model-invocation: true`) que solo dice "Call the Skill tool with grilling". El primitivo real es `grilling` (productivity/grilling), no user-invoked. `grill-me` es el nombre de slash command en Claude Code; en OpenCode maps a un skill.
2. El conflict de diseño central: `grilling` dice "Interview relentlessly until shared understanding" + "Do not act until user confirms" — eso es un bucle de preguntas por diseño. Si se auto-triggerea en cada delegación SDD, crea el loop infinito que el usuario teme.
3. El orquestador gentle-ai tiene contrato duro: "MUST NOT interview or infer consent" para el proposer lo haría chocar con grilling si se inyecta en sdd-propose.
4. La skill se debe integrar como USER-INVOKED SOLO (manual, /grill-me en una sesión, produce spec/design previo), NUNCA modelo-invoked en la cadena SDD automática. Por eso hay que forzar `disable-model-invocation: true` + NO indexarla en la skill-registry (que es lo que la haría auto-disponible a subagentes).
5. El `question` tool de OpenCode es la vía nativa para las rondas de grilling, evitando que el orquestador pregunte por texto plano (que SÍ rompe el contrato Lossless Blocking Prompts).
6. Buena costumbre de mattpocock: identificó que mis skills registradas NO mencionan grill-me; ninguna skill SDD lo referencia. La integración es greenfield, no hay colisión existente.

Session: manual-save-meowrch
Project: meowrch
Scope: project
Created: 2026-09-02 15:46:40
