# archify (vendored)

Agent skill for beautiful, verifiable architecture, workflow, sequence, data-flow, and lifecycle diagrams — self-contained HTML with motion and crisp export. Vendored skill, full install.

- **Upstream**: https://github.com/tt-a1i/archify (MIT)
- **Source**: official release asset `archify.zip` of tag `v2.16.0` (stable channel; see `skill-release.json`)
- **Vendored as-is**: do NOT edit locally. To update, re-fetch the latest stable `archify.zip` release asset, replace `skills/archify/` and sync.
- **Runtime**: pure Node builtins (`node >= 18`), no `npm install` required. Agents run `node bin/archify.mjs validate|deliver|guide|visual-check|preview ...` from the skill directory.
- **Purpose in this repo**: give the agent runtimes (OpenCode, Claude Code, Codex) a polished diagramming skill — architecture/workflow/sequence/dataflow/lifecycle from typed JSON IR or Mermaid input.