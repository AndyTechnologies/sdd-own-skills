# Web Search — Tool Notes

Operational detail for the `web-search` skill. Read before calling web tools. Preference order: context7 and donsetch first, built-ins only as fallback.

## context7 (library/framework docs)

- Resolve the library ID first: `resolve-library-id` with the official library name and the question you need answered.
- Then `query-docs` with one scoped concept per call; max 3 calls per question.
- Use for API syntax, configuration, version migrations, setup, and CLI usage — even for well-known libraries.

## donsetch (general web)

- `web_search`: discovery only — returns ranked URLs + titles + snippets. Use it to decide WHAT to fetch; pass up to 2 `query_variants` for ambiguous multilingual needs.
- `web_fetch`: read one URL as clean markdown. Cheapest modes:
  - `must_contain="X"` to verify a page mentions X (~60 tokens).
  - `toc=true` to get an outline, then `section="s3"` or a heading for just that part.
  - `focus="query"` to keep only relevant blocks (50-80% cheaper).
  - Set `focus`/`must_contain`/`toc` whenever you know what you are looking for.
- `web_crawl`: multi-page extraction from a seed (docs sites, wikis). Use `focus` to rank the frontier, `max_pages`/`max_total_chars` for budget, `since_last=true` for delta re-checks.
- Handles PDFs, bot walls, and JS pages automatically; on walls/paywalls it reports an escalated error — do not pretend to have read the page.

## Built-ins (fallback only)

- `websearch` / `webfetch`: use ONLY when donsetch or context7 is unavailable or fails. Never prefer them while the MCP tools are present.

## Evidence discipline

- Record per source: URL, title, publisher, accessed date.
- Map each claim to its source; mark contradictions and stale or uncertain facts.
- A refusal, wall, or deadline error is a gap, not content — report it.