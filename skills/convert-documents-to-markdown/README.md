# convert-documents-to-markdown (vendored)

Convert Word, PowerPoint, Excel, OpenDocument, RTF, EPUB, CSV, and PDF files to GitHub-Flavored Markdown via the anydoc CLI. Vendored skill, full install.

- **Upstream**: https://github.com/firecrawl/anydoc (MIT)
- **Source**: `skills/convert-documents-to-markdown/SKILL.md` of the upstream repo (main branch)
- **Vendored as-is**: do NOT edit locally. To update, re-fetch the upstream SKILL.md and sync.
- **Runtime**: requires Node 20+; converts via `npx -y @firecrawl/anydoc <file>` (no install needed, CLI never prompts). Inside a Node/Python/Rust codebase the library is preferred over shelling out (`@firecrawl/anydoc` npm, `firecrawl-anydoc` PyPI, `anydoc` crates.io).
- **Purpose in this repo**: give the agent runtimes (OpenCode, Claude Code, Codex) a document-to-Markdown skill so office documents, spreadsheets, presentations, ebooks, and PDFs can be read as Markdown.