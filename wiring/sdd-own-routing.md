## sdd-own extension (routing only)

Unified quest flow (ODD-first):
1. Explore always runs first; its findings feed the quests.
2. After exploration, ALWAYS run the Product Quest: one question at a time,
   hard budget 50 (inline Q&A mechanics, no external interview skill); then
   rfc-author assembles `product-rfc.md` and the product RFC gate is
   presented; on explicit approval, the change's task doc
   `odd/tasks/<feature>.md` is ALWAYS seeded from the RFC (binding mandate,
   regardless of change size).
3. Run the Architecture Quest only when the approved product RFC or the
   exploration findings surface architectural decisions, or the user
   explicitly requests architecture work: one question at a time, hard
   budget 20 (inline Q&A mechanics); then rfc-author assembles `arch-rfc.md`
   and the architecture RFC gate is presented. Mechanical or
   documentation-only changes skip both quests at the orchestrator's
   discretion.
4. Only when the change is substantial/large and needs deeper planning,
   architecture-plan consumes the approved RFCs (product-rfc.md /
   arch-rfc.md) plus the exploration findings and the seeded task doc
   (`odd/tasks/<feature>.md`) and integrates its binding acta decisions
   INTO that task doc (no separate acta file). Otherwise the RFCs bind the
   task doc and downstream phases directly.
5. After implementation, architecture-lint ALWAYS runs as part of the apply
   verification: it checks the implemented work against the generated RFCs
   and the task doc — including the integrated architecture-plan acta when
   that phase ran — before the change is reported complete.
Automatic pace is delegated review: in auto mode the orchestrator records
the delegated review result of every gate (quest RFCs, plan, lint); no
phase EVER self-approves.
Outside exactly these triggers, behavior is 100% native gentle-ai (ODD/SDD);
no sdd-own phase launches beyond the quest/plan/lint extensions above.