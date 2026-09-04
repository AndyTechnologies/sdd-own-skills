---
name: web-search
description: "Trigger: web search, buscar en la web, external evidence, fuentes externas, docs lookup, url fetch. Prefer donsetch and context7 over built-in web tools; pick search, fetch, crawl, or docs per need."
license: MIT
metadata:
  author: andy
  version: "1.0"
---

## Activation Contract

Load when the task needs external or current information: web search, browsing a site, fetching a URL, crawling multi-page docs, or library/framework documentation lookups. Applies to orchestrator direct work and delegated sub-agents.

## Hard Rules

- Prefer MCP tools: **context7** for library/framework docs; **donsetch** for general web (`web_search`, `web_fetch`, `web_crawl`). Use built-in `websearch`/`webfetch` ONLY as fallback when the preferred tool is unavailable or fails.
- Never fabricate sources: every claim requires a fetched URL, excerpt, or snippet. Report only evidence from retrieved content.
- Finish every web evidence trail with source identification: URL, title, publisher, and accessed date.
- Do not retry endlessly past a wall, paywall, or deadline error: one bounded retry, then report the gap.
- In SDD research, tool selection never bypasses capability admission: grants gate evidence, this skill only selects tools.

## Decision Gates

| Need | Tool |
| --- | --- |
| Library/framework/API docs or version migration | context7 (resolve → query) |
| Find sites or URLs for a topic | donsetch `web_search` |
| Read one known URL | donsetch `web_fetch` |
| Multi-page docs/site or sitemap-aware crawl | donsetch `web_crawl` |
| Verify a page mentions X (cheap) | donsetch `web_fetch` with `must_contain` |
| Navigate structure of a long page | donsetch `web_fetch` `toc`, then `section` |
| Preferred tool unavailable or failed | built-in `websearch` / `webfetch` (fallback only) |

## Execution Steps

1. Classify the need (docs lookup vs general web vs verification) and pick the tool from the gate table.
2. Read `references/tool-notes.md` for the exact call shapes, budgets, and token-saving modes.
3. Capture sources (URL, title, publisher, accessed date) and note contradictions, uncertainty, and freshness.
4. If the preferred tool is unavailable or fails non-recoverably, fall back to the built-in; if that fails too, state the gap — never invent.

## Output Contract

Return sources as URL + title + excerpt; label anything unverified; keep evidence separate from opinion. Report fallback use when applicable.

## References

- `references/tool-notes.md` — operational notes: exact tool call shapes, budgets, and saving modes.
- `../../_shared/research-lifecycle.md` — SDD research admission contract (evidence gating) for SDD phases.