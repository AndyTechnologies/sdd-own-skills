## sdd-own extension (routing only)

Unified quest flow (applies to the default ODD workflow and explicit SDD):
1. Explore always runs first.
2. After exploration, ALWAYS run the Product Quest: one question at a time,
   hard budget 50; then the product RFC gate; on approval rfc-author
   assembles product-rfc.md (binding mandate).
3. Run the Architecture Quest whenever the request involves product/feature
   work or any scope that requires architectural decisions: one question at a
   time, hard budget 20; then the architecture RFC gate; on approval
   rfc-author assembles arch-rfc.md. Mechanical or documentation-only changes
   with no product or architecture surface skip both quests at the
   orchestrator's discretion.
4. If the change is substantial/large and needs deeper planning,
   architecture-plan consumes the approved RFCs (product-rfc.md /
   arch-rfc.md) plus the exploration findings and produces the binding
   arch-plan.md acta.
5. After implementation, architecture-lint ALWAYS runs as part of the apply
   verification: it checks the implemented work against the generated RFCs
   and the arch-plan.md acta (when one was produced) before the change is
   reported complete.
Outside exactly these triggers, behavior is 100% native gentle-ai (ODD/SDD);
no sdd-own phase launches beyond the quest/plan/lint extensions above.