---
name: ui-design
description: "Trigger: UI/UX design, interface, components, design system, dark luxury, dark premium, elegant dark theme, color, typography, layout, accessibility. Produce concise UI decisions and record them in the generated design artifact."
license: MIT
metadata:
  author: andy
  version: "1.0"
---

## Activation Contract

Load when a design task covers UI/UX: new pages, components, design systems, color/typography/layout choices, or interface accessibility. Applies to the SDD `sdd-design` phase and direct design work. Skip when the change is backend, API, or infrastructure only.

## Hard Rules

- Record every UI decision INSIDE the generated design artifact (`design.md`) in a `## UI Decisions` section — never in loose repo files or sidecars.
- Detect the stack from the project (package.json, pubspec.yaml, *.xcodeproj, etc.); never assume one.
- Recommend semantics, not raw values: color/type/spacing tokens; no raw hex, no fixed px containers, no placeholder-only labels.
- Hierarchy: accessibility and touch rule before visual polish. Run the checklist in priority order.
- Never invent an unverifiable decision; if nothing fits, state the fallback explicitly.
- Keep decisions concise: one line per decision with a 1-line rationale (design artifact budget is under 800 words).

## Decision Gates — UI Priority Checklist

| # | Check (must hold) |
| --- | --- |
| 1 | Accessibility: contrast >= 4.5:1; visible focus rings; aria labels for icon-only controls; keyboard nav |
| 2 | Touch & interaction: targets >= 44x44px; 8px+ spacing; loading feedback; no 0ms state changes |
| 3 | Performance: lazy images (WebP/AVIF); space reserved (CLS < 0.1) |
| 4 | Style consistency: match product type; consistent patterns; SVG icons, not emoji |
| 5 | Layout responsive: mobile-first breakpoints; no horizontal scroll; no fixed px containers |
| 6 | Typography & color: base 16px; line-height 1.5; semantic tokens; body >= 12px |
| 7 | Motion: context-aware timing; respect reduced-motion; avoid width/height animation |
| 8 | Forms & feedback: visible labels; errors near field; helper text; progressive disclosure |
| 9 | Navigation: predictable back; bottom nav <= 5; deep linking |
| 10 | Charts & data: legends, tooltips; never color-only meaning |

## Style Direction — Dark Luxury

Activate when the request asks for "dark luxury", "dark premium", "dark gold", "dark mode luxury", "high-end dark theme", "elegant and dark", or "dark but premium" — never design it from memory alone.

- Identity: deep near-black backgrounds; warm metallic accents (Amber/Gold default, Silver/Platinum alt); premium editorial typography; grain texture overlays; ambient glow; purposeful micro-animations.
- Defaults: background warm black #0a0907 (never #000/#111); accent Amber/Gold; font geometric sans (Inter); type landing page.
- Non-negotiables: headlines bold, contrast by COLOR not weight · `[Label]` brackets in mono · cards NO border (inset top highlight) · primary buttons dark bg + amber border + always-visible glow · ONE elliptical hero orb · grain overlay required · SVG only, no emoji.
- Clarify before decisions: accent, background, font, and type options — skip to defaults when the user asks.
- Page structure: Nav, Hero, Logo marquee, Features, Stats, Testimonials, Architecture, Pricing, FAQ, CTA, Footer.
- Stack: React — lucide-react icons, Tailwind for layout only, colors via style or <style>; plain HTML — tokens on :root, JetBrains Mono for metadata.
- Full tokens, all ten rules, required animations, and anti-pattern checklist: read `references/dark-luxury.md`.

## Execution Steps

1. If the change touches UI/UX, run the checklist in priority order; mark each item decided or explicitly out of scope.
2. Record chosen palette, type scale, spacing, tokens, and interaction patterns — one line each, with rationale.
3. Write the `## UI Decisions` section into the generated design artifact before persisting it.
4. Report unresolved UI questions as risks in the phase result.

## Output Contract

Return the `UI Decisions` section content and any unresolved UI risks; keep product choices separate from technical decisions.

## References

- `../_shared/sdd-phase-common.md` — phase retrieval/persistence and return envelope.
- `../sdd-design/SKILL.md` — design phase contract this skill augments.
- `references/dark-luxury.md` — Dark Luxury direction: clarify options, defaults, page structure, stack notes, anti-patterns.