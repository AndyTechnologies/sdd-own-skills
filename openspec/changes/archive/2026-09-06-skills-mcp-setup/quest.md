# Quest: skills-mcp-setup

## Approval: approved

## RFC

### Goals / Non-goals

**Goals**
- Add three Composio-originated skills to the suite: `using-git-worktrees`, `test-fixing` (curated/adapted to repo conventions) and `github-automation` (rewritten to drive the official `github-mcp-server`, not the Composio Gateway).
- Turn the repo into a "definitive setup": a `setup.sh` wrapper that orchestrates `sync-skills.sh` (gentle-ai + skills) and configures MCPs.
- Install the official GitHub MCP server with a GitHub PAT, prompting for the token during installation and validating it via `GET /user` (must respond 200; no owner-match requirement).
- Store the secret in a separate env file, never in the runtime config or the repo.
- Extensible per-runtime MCP mechanism (OpenCode, Claude Code, Pi, Codex, more) driven by declarative definitions in the repo.

**Non-goals (for now)**
- No other MCPs beyond GitHub. No Composio Gateway/API key.
- No owner-match validation. No blocking on missing scopes (warn + offer change).
- The SDD wiring fragment (`wiring/opencode.sdd.json`) never gains `mcp` keys.

### Domain Terminology & Business Rules

- **PAT**: GitHub Personal Access Token — classic (`ghp_...`) or fine-grained (`github_pat_...`).
- **github-mcp-server**: official ecosystem MCP server exposing GitHub tools; receives the token via `GITHUB_PERSONAL_ACCESS_TOKEN` env.
- **setup.sh**: new entry point orchestrating `sync-skills.sh` + an MCP installation step.
- **Runtime config targets**: OpenCode (`~/.config/opencode/opencode.jsonc` `mcp` block), Claude Code (user-level mcp config), Pi (Pi config), Codex (`~/.codex/config.toml`).
- **Valid token**: `GET https://api.github.com/user` → 200 with user JSON.
- **Scopes**: `x-oauth-scopes` header only present for classic tokens; fine-grained tokens expose none.

**Business rules**
- If a valid token already exists → ask the user to keep it or replace it.
- Missing critical scopes → warn and offer to change the token before continuing; never block.
- Setup is idempotent; `--check`/`--dry-run` never mutate; `--force-mcp-token` forces re-prompt.

### Contracts (Inputs / Outputs / Events / External)

**Inputs**: `setup.sh` flags (`--check`, `--dry-run`, `--skip-gentleai-sync`, `--skip-opencode`, `--skip-mcp`, `--force-mcp-token`, `--registries`); PAT from interactive prompt; repo git remote (shown as context, never enforced).
**Outputs/Events**: per-runtime secrets env file (0600); declared MCP blocks in runtime configs; scope warning when applicable; install/update/skip summary like the sync report.
**External**: `GET https://api.github.com/user`; `x-oauth-scopes` diagnostic; `github-mcp-server` binary install (npx `@modelcontextprotocol/server-github` or chosen transport).

### Invariants & Validation

- The token is NEVER persisted in the repo or the runtime's main config — only in the referenced env file.
- The token is validated against `GET /user` BEFORE anything is written; persisted only on 200.
- MCP blocks reference the env file, never literal values.
- `setup.sh` never overwrites the SDD fragment or personal config keys; additive merges with backup (`.bak`) like the sync.
- Re-running never duplicates blocks; `--check` reports drift without mutating.

### Failure Cases & Edge Cases

- Invalid/expired token → not persisted, re-prompt (max 3 attempts).
- Fine-grained token (no scope header) → warn scopes are unverifiable; continue.
- No network to `api.github.com` → clear failure, nothing persisted.
- Missing runtime config → create with backup; unsupported runtime → skip with notice.
- Existing valid token → ask keep vs replace; secrets path collision → don't clobber without backup/consent.
- Machine without some runtimes → skip absent runtimes with notice.

### Security / Privacy / Performance / Operational

- Secret file with 0600; token never in argv, logs, or setup output.
- Validation precedes all writes; failed validation writes nothing.
- `--check` reports token configured/valid without mutating.
- The `github-automation` skill embeds no tokens — it instructs using the MCP.

### Alternatives & Trade-offs

- Composio Gateway vs official MCP → official (user choice; no third-party API key).
- Strong owner-match vs responds-only validation → responds-only (multi-repo friendly).
- Separate env file vs inline env → env file (regeneration, leakage).
- Vendor as-is vs curate → curated (suite homogeneity).
- Extend sync vs wrapper → wrapper (`setup.sh`), per user choice.
- Silent reuse vs always-ask → ask keep-or-replace when valid exists.

### Acceptance Criteria (measurable)

1. `setup.sh --check` on clean state reports: skills synced, GitHub MCP configured-or-absent, token valid-or-missing.
2. `setup.sh --dry-run` with no token shows the plan and writes nothing.
3. Real `setup.sh` prompts for token when absent, validates via `GET /user`, persists only on 200, configures MCP in supported runtimes.
4. Invalid token → writes nothing, re-prompts (≤3).
5. Valid existing token → asks keep vs replace. Missing scopes → warning + change option before continuing.
6. All 3 skills land in `skills/` (curated), are deployed by sync, appear in the registry.
7. `github-automation` references the official MCP server, not Composio.
8. Repo gains: 3 skills + extensible MCP wiring (definitions dir) + `setup.sh` + README updated. `./sync-skills.sh --check` still reports zero desyncs.

### Unresolved Questions (blocking)

- None (all 10 branches resolved).