# UI/UX Principles — Reference Guide

Condensed decision tables for the `ui-ux-principles` skill. Source: HCD/ISO 9241-210, Nielsen heuristics, ISO 9241-11 metrics, WCAG 2.2, VPAT.

## HCD Process (ISO 9241-210)

Four iterative phases, applied across the whole system life cycle:

| Phase | What it produces |
| --- | --- |
| 1. Planning | Usability effort scope, risks of low usability, resources/methods/responsibilities/schedule |
| 2. Understand & specify context of use | Who users/stakeholders are, their characteristics, goals, tasks, operational conditions (organizational, technical, social, physical) |
| 3. Specify user requirements | Clear, testable, auditable, consistent requirements supported by stakeholders |
| 4. Produce design solutions + evaluate | Prototypes/simulations/mockups evaluated against requirements; iterate until all problems resolved and usability is sufficient → implementation |

Works with agile and traditional processes. **Never end design at the first artifact.**

## Nielsen's 10 Usability Heuristics

| # | Heuristic | What to check |
| --- | --- | --- |
| 1 | Visibility of system status | Feedback on every action, appropriate and timely |
| 2 | Match system ↔ real world | User's language, familiar concepts, real-world conventions, no jargon |
| 3 | User control and freedom | Visible "emergency exit" from secondary states |
| 4 | Consistency and standards | Same words/situations/actions mean the same; platform conventions |
| 5 | Error prevention | Design prevents problems before they happen |
| 6 | Recognition rather than recall | Options/actions visible; minimize memory load |
| 7 | Flexibility and efficiency of use | Accelerators for experts; never compromise novices |
| 8 | Aesthetic and minimalist design | No irrelevant or rarely-needed information |
| 9 | Help recognize, diagnose, recover from errors | Plain language, describe problem, propose constructive solution |
| 10 | Help and documentation | Searchable, task-based, covers all situations |

## Evaluation Methods

| Method | Cost | Coverage | Limit |
| --- | --- | --- | --- |
| Heuristic inspection | Low, fast | Obvious issues; 3–5 evaluators find most; 5 evaluators → up to 75% of problems | Depends on evaluator skill; no real users |
| Empirical user test (think-aloud) | Higher | Mental model, friction, expectations; 5 participants → 77–85% of usability problems | Needs recruiting; moderated or not, remote or in-person |
| Automated scan (axe-core) | Low | Only a subset of WCAG criteria (~1/3–1/2 of a11y issues) | Context-blind; never final |

Formative tests improve the design; summative tests benchmark/validate. Combine metrics: high success + high time-on-task = working but unintuitive path.

## Quantitative Metrics (ISO 9241-11: effectiveness, efficiency, satisfaction)

| Category | Metric | Calculation |
| --- | --- | --- |
| Effectiveness | Task success rate | (successful completions ÷ total attempts) × 100 |
| Efficiency | Time on task | Start → completion |
| Precision | Error rate | Total errors ÷ total task attempts |
| Satisfaction | SUS (10-item) | Score 0–100; average ≈68; ≥80 = top 10% of industry |
| Satisfaction | SEQ | 1–7 per task ("Very easy" → "Very difficult"); pinpoints problem tasks |

Statistical significance: ≥20–30 participants for quantitative metrics like SUS. Use both qualitative ("why") and quantitative ("what/how much").

## Accessibility — WCAG 2.2 (Oct 2023)

**POUR principles**:

| Principle | Meaning | Examples |
| --- | --- | --- |
| Perceivable | Presentable without relying on one sense | Alt text, transcripts, adequate contrast |
| Operable | Navigable, usable by all input modes | Full keyboard access, sufficient time, no seizure triggers |
| Understandable | Clear and predictable | Plain vocabulary, consistent navigation, error-avoidance aids |
| Robust | Faithful interpretation by assistive tech (today and future) | Valid semantic HTML |

**Conformance levels**: A (basic) → AA (recommended for most public/private sites) → AAA (maximum). Higher level requires all criteria of lower levels.

**New in 2.2**: nine new success criteria, focused on cognitive/learning disabilities and mobile.

## VPAT / ACR

- **VPAT 2.5** aligns with WCAG 2.2. A completed VPAT = **Accessibility Conformance Report (ACR)**.
- Not a quality certificate: a conformance **declaration** between buyers and vendors.
- Ratings: **Supports** / **Partially Supports** / **Does Not Support** / **Not Applicable**.
- Credibility depends on evaluation quality: automated tools detect only ~1/3–1/2 of issues → qualified manual evaluation is indispensable.

## Legal / Regulatory Context

| Region | Instrument | Note |
| --- | --- | --- |
| Global (de facto) | WCAG 2.2 | Baseline standard, adopted by governments/orgs; not law itself |
| US | Section 508 (Rehabilitation Act) | Federal agencies; VPAT commonly demonstrates compliance |
| EU | European Accessibility Act (EAA) + EN 301 549 | Mandatory law; EN 301 549 is the technical reference |
| Horizon | WCAG 3.0 (draft) | Drops A/AA/AAA → Bronze–Gold scale; "success criteria" → outcome-based "requirements" |

## AI-Agent Evaluation Dimensions

Classic metrics miss agentic systems (users delegate instead of navigate):

| Dimension | What it measures |
| --- | --- |
| Trust calibration | User knows when to trust, question, or intervene manually; neither over- nor under-trust |
| Explainability | Quality, clarity, relevance of the agent's explanations for its actions |
| Agent reliability | Dependability and consistency under real-world conditions (beyond accuracy) |
| Dual evaluation | Both human performance AND agent performance; good design optimizes the collaboration |

## AI as Evaluator — Practical Roles and Limits

**Roles**:
1. Automated heuristic audit — rule engine over Nielsen principles on a markup structure or screenshot.
2. Basic accessibility evaluation — integrate axe-core to scan the DOM for a subset of WCAG criteria; always validate manually afterward.
3. Structured evaluation reports — aggregate human-collected usability metrics into actionable findings.
4. Agent-to-agent evaluation — trace workflows (e.g. Patronus AI), measure agent efficiency, tool-selection quality, override frequency → trust profile.
5. Autonomous test agents — navigate the app, generate test cases dynamically, run continuous usability tests.

**Limits (never forget)**:
- AI lacks empathy, contextual intuition, and creative judgment — it augments, never replaces, the human designer.
- AI systems are opaque → prioritize transparency and explainability in recommendations; lost trust is nearly impossible to rebuild.
- Standards evolve (WCAG 3.0) — interpret and apply new frameworks as they mature.