## sdd-own extension (routing only)

Unified quest flow (applies to ODD default and explicit SDD):
1. Explore always runs first.
2. After exploration, a gap detection decides quest usage:
   - SDD (explicit): the product quest is MANDATORY before sdd-propose.
   - ODD (default): the product quest is OFFERED only when the orchestrator
     detects >=2 unresolved product/domain decisions; the user accepts or
     declines. If declined, continue ODD pure (one focused question at a time).
3. sdd-product-quest: one question at a time, hard budget 50; then the product
   RFC gate; on approval sdd-rfc-author assembles product-rfc.md (binding mandate).
4. If a design phase is ahead (SDD do-design) or the change is substantial with
   architecture uncertainty (ODD): sdd-architecture-quest, hard budget 20; then
   the architecture RFC gate; on approval sdd-rfc-author assembles arch-rfc.md.
5. An approved arch-rfc.md precedes sdd-architecture-plan, which produces the
   binding arch-plan.md acta.
6. After apply (SDD), sdd-architecture-lint always runs as the independent
   second eye, before verify/archive.
Outside exactly these triggers, behavior is 100% native gentle-ai (ODD/SDD);
no sdd-own phase launches beyond the quest/plan/lint extensions above.