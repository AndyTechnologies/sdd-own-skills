---
name: ui-ux-principles
description: "Trigger: UI/UX principles, heurísticas, Nielsen, usability, accesibilidad, accessibility, WCAG, POUR, ISO 9241, HCD, user research, SUS. Apply HCD, Nielsen heuristics, metrics, and WCAG 2.2 when designing or evaluating interfaces."
license: MIT
metadata:
  author: andy
  version: "1.0"
---

## Activation Contract

Load when designing OR evaluating an interface — screens, flows, components — or when a design must satisfy usability and accessibility standards. Complements `ui-design` (visual/component decisions): this skill supplies the HCD process, Nielsen heuristics, empirical evaluation methods, quantitative metrics, and WCAG 2.2 conformance rules. Read `references/principles-guide.md` for the condensed tables before evaluating.

## Hard Rules

- **HCD before pixels**: understand context of use and user requirements (ISO 9241-210) BEFORE producing design solutions. Never jump to mockups without users, goals, and tasks.
- **Heuristics are a filter, not proof**: Nielsen's 10 heuristics catch obvious issues early and cheaply; 3–5 evaluators find most problems. They never replace testing with real users.
- **Think-aloud is the ground truth**: 5 participants in a think-aloud protocol reveal 77–85% of usability problems. Design-evaluate-refine in iterations until requirements are met.
- **Measure, don't guess**: pick quantitative metrics (task success, time-on-task, error rate, SUS, SEQ) aligned to ISO 9241-11 (effectiveness, efficiency, satisfaction). A high success rate with high time-on-task means the path is unintuitive.
- **Accessibility is a requirement, not a feature**: target WCAG 2.2 AA by default (POUR: Perceivable, Operable, Understandable, Robust). Automated scans (e.g. axe-core) catch only 1/3–1/2 of issues — manual evaluation is mandatory.
- **Agent/AI evaluations add dimensions**: trust calibration, explainability, agent reliability, and dual evaluation (human + agent) — classic metrics miss them.
- **Know the limits**: AI lacks empathy, contextual intuition, and creative judgment. Act as evaluator/assistant, never as substitute for user research.

## Decision Gates

| Situation | Response |
| --- | --- |
| Design task without user/context data | Start HCD: plan, context of use, user requirements |
| Early design, need quick feedback | Heuristic inspection (Nielsen, 3–5 evaluators) |
| Need proof of real usability | Empirical test with think-aloud (≥5 users) |
| Need a benchmark / compare versions | SUS (≥80 top 10%; average ≈68), SEQ per task |
| Web/app must meet legal standards | WCAG 2.2 AA; VPAT/ACR when customers require |
| Evaluating an AI agent system | Trust calibration, explainability, reliability, dual evaluation |
| Automated a11y scan flagged issues | Manual validation; never auto-close |

## Execution Steps

1. Confirm context: users, tasks, environment, constraints — state them in the artifact.
2. Produce the design/prototype; keep it concrete enough to be evaluated.
3. Run heuristic inspection first (fast, cheap); fix obvious violations.
4. Plan empirical evaluation: think-aloud tasks + the metrics that answer the question (effectiveness/effort/satisfaction).
5. Measure, summarize (success, time, errors, SUS/SEQ), and decide what to iterate.
6. Before shipping: WCAG 2.2 checks — manual + automated scan; note conformance level (A/AA/AAA) in the artifact.

## Output Contract

Record in the artifact: the HCD context (users, tasks, environment), the evaluation method used (inspection vs. empirical), the metrics with actual values, the iteration decision, and the accessibility conformance level (WCAG 2.2, A/AA/AAA) + VPAT ratings (Supports / Partially Supports / Does Not Support / Not Applicable) when applicable. A "don't ship yet / iterate" verdict is a valid outcome.

## References

- `references/principles-guide.md` — condensed tables: HCD phases, 10 Nielsen heuristics, evaluation methods, quantitative metrics, WCAG 2.2 POUR + levels, VPAT ratings, and AI-agent evaluation dimensions.