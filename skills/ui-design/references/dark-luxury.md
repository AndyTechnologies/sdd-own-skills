# Dark Luxury — Style Reference

Operational detail for the `ui-design` skill. Read when the Dark Luxury direction is active. This is a distilled contract derived from the original design system; never design dark luxury from memory alone.

## Design Domain

Deep near-black backgrounds, warm metallic accents (Amber/Gold or Silver/Platinum), premium editorial typography, grain texture overlays, ambient glow lighting, and purposeful micro-animations. Mood: premium, powerful, editorial — expensive without being ornate.

Triggers: "dark luxury", "dark premium", "dark gold", "dark mode luxury", "high-end dark theme", "make it look premium and dark", "give it a luxury dark feel", "elegant and dark", "dark but premium".

## Clarify Before Decisions (skip to defaults on user request)

| Element | Options |
| --- | --- |
| Accent | Amber/Gold (default) · Silver/Platinum · Emerald/Jade · Crimson/Rose · custom hex |
| Background | Warm black #0a0907 (default) · Pure #080808 · Cool #07080a |
| Font | Geometric sans-serif (default, Inter) · High-contrast serif |
| Type | Landing page (default) · Web app · Portfolio · Other |

## Defaults

- Accent: Amber/Gold
- Background: Warm black #0a0907
- Font: Geometric sans-serif (Inter, weights 400–800)
- Type: Landing page
- Sections: Hero, Features, Stats, Testimonials, Pricing, FAQ, CTA, Footer

## Design Tokens

```css
:root {
  --bg-base:       #0a0907;  --bg-surface:    #100f0d;
  --bg-card:       #161412;  --bg-footer:     #141210;
  --border-subtle: rgba(255,248,230,0.07);
  --border-medium: rgba(255,248,230,0.13);
  --border-accent: rgba(212,160,60,0.55);
  --text-primary:  #f0ebe0;  --text-muted:    #5a544a;
  --text-body:     #8a8070;  --text-tertiary: #524c42;
  --font-mono:     'JetBrains Mono', monospace;
  --accent:        #d4a03c;  --accent-bright: #e8b84e;
  --accent-glow:   rgba(212,160,60,0.18);
  --accent-subtle: rgba(212,160,60,0.08);
  --success:       #3d9e5c;
  --grain-opacity: 0.04;
}
/* Alt accents: Silver #b4c0d4 · Emerald #42b872 · Crimson #c8385a */
```

Typography: Inter via Google Fonts; display `clamp(52px,7vw,96px)` weight 700–800, tracking -0.03em; h2 `clamp(28px,3vw,44px)`; h3 `clamp(17px,1.6vw,20px)`; body 16px/1.65; labels 11–13px mono; stats 60–100px weight 800. Section padding 120–160px; grid max-width 1200px; spacing base 4px.

Grain texture (required — body::before): SVG fractalNoise, `opacity:var(--grain-opacity)`, `mix-blend-mode:overlay`, z-index above content, pointer-events none.

## The Ten Rules (follow exactly)

1. **Section labels** — `[Label]` bracket notation only, monospace 13px, accent color, no pill/border. Never `— Label —`.
2. **Headlines** — contrast by COLOR not weight: all words bold 700–800, supporting words `--text-muted`, key words `--text-primary`. Never a thin (300) weight line.
3. **Buttons** — dark bg + amber BORDER (never filled amber). Primary: multi-layer always-visible glow (8px/55%, 20px/25%, 40px/10%) pulsing moderate↔strong, hover intensifies. Secondary: no glow, subtle `--border-medium` border.
4. **Cards** — NO border; elevation via bg contrast + `inset 0 1px 0 rgba(255,248,230,0.08)` + outer `0 4px 24px rgba(0,0,0,0.45)`. Featured card adds accent ring + glow.
5. **Feature cards** — large ~240px dark illustration panel (bg #0e0c0a, border-bottom subtle) top, title+desc below with 24px padding, `overflow:hidden`. Not small icon boxes.
6. **Technical metadata** — monospace `//` separator line in architecture/foundation cards: `3F1C9 // CONTEXT DEPTH: 12.4 // INSIGHT HASH: 7B` — invented but realistic, `--text-tertiary`.
7. **Hero** — ONE elliptical orb (900×500px) bottom-center, radial amber gradient (28%→transparent), blur(40px), slow 8s breathe scale 1↔1.08. Plus hero badge pill above headline.
8. **Pricing** — icon in 42×42px square rounded container + tier name inline; featured middle card highlighted by amber border + glow ONLY, never bg change; square checkbox SVG with amber stroke.
9. **Footer** — inside rounded elevated panel (bg-footer, radius 20px, inset top highlight), not flush; `[ALL SYSTEMS OPERATIONAL]` badge with green dot + mono success text.
10. **Navigation** — fixed, transparent at top → on scroll `rgba(10,9,7,0.80)` + `backdrop-filter:blur(16px) saturate(1.5)` + bottom subtle border.

## Required Micro-Animations

- Scroll reveal: every major element translateY(20px)→0, 600ms easeOut, 90ms stagger per sibling, data-delay supported.
- Number countup: 0→target on scroll-enter, 1.8s easeOutCubic.
- Headline word cycling: key word swaps every 2.6s, slides up/out then in from below.
- Hero orb breathe: 8s alternate scale 1↔1.08.
- Card hover: translateY(-2px) + deeper shadow, 220ms.
- Button pulse: primary glow always visible, pulses moderate↔strong (2.8s), stops glowing animation on hover.
- Logo marquee: CSS infinite scroll 45s, edge fade mask, logos grayscale at 30% opacity.

## Page Structure

Nav → Hero (badge + headline + CTAs + orb) → Logo marquee → Features (3-col illustration cards) → Stats (split layout, binary bg texture) → Testimonials (dual counter-scrolling rows) → Architecture (2×2 quadrant, mono metadata) → Pricing (3-col, middle glow) → FAQ → CTA banner → Footer panel.

## Stack Notes

- **React**: lucide-react for icons; Tailwind for layout only; all colors via `style={{}}` or `<style>` block.
- **Plain HTML**: all tokens on `:root`; JetBrains Mono for metadata; no framework needed.
- **Icons**: SVG only, thin 1.5px stroke, 20–24px (Lucide/Phosphor outline). No icon fonts, no emoji.
- **Imagery**: abstract technical (circuits, neural nodes, particle systems) dark-tinted at low opacity; screenshots `brightness(0.85) contrast(1.1)`. No stock people/lifestyle photos.

## Anti-Pattern Checklist

- [ ] Filled amber button backgrounds → dark bg + amber border only
- [ ] Button glow fading to invisible → always-visible multi-layer glow, pulses moderate↔strong
- [ ] Thin-weight (300) headlines → bold 700–800, contrast is COLOR not weight
- [ ] `— Label —` dashes → `[Label]` bracket notation, monospace
- [ ] Small icon-box feature cards → large ~240px illustration panel at top
- [ ] Multiple symmetric orbs → one elliptical orb, bottom-center
- [ ] Footer flush with page → inside rounded elevated panel
- [ ] Solid border on cards → no border, inset top highlight + outer shadow
- [ ] Missing mono metadata in arch cards · missing status badge in footer
- [ ] Missing hero badge pill · emojis (SVG only) · grain texture · scroll reveals

## Replication Notes

- Near-black is not black — #0a0907 has warmth. Never #000000 or flat #111111.
- Grain texture is non-negotiable — the difference between flat dark and tactile dark.
- Headline contrast is COLOR not weight — both dim and bright words are bold.
- Section labels are `[Label]` in monospace, not dashes, not uppercase pills.
- Cards have no border — the inset top highlight IS the edge definition.
- Buttons are never filled amber — dark bg + amber border + multi-layer glow.
- The primary button glow never disappears — it pulses between two visible states.
- One orb in the hero, elliptical, bottom-center — not multiple symmetric blobs.
- Accent is surgical — labels, borders, numbers. Never a large fill.
- SVG icons only. No emoji. No icon fonts.