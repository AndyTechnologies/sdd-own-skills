# Council Acta: sdd-mcp-worktree

Date: 2026-09-07
Mode: fast-path con ajustes (usuario pidió adjust dos veces)
Status: **approved** (usuario: "vale, continuemos entonces")

## Decisions

| ID | Decision | Detail |
|----|----------|--------|
| C1 | Worktree root | `~/.agent_worktrees/<repo-name>/<change-name>` — HOME-relative, portable entre PCs, fuera de cualquier árbol git (sin .gitignore, sin contaminación). Resuelto con `Path.home()` en runtime; nunca rutas de máquina hardcodeadas. Reemplaza la convención Phase 0 `<repo-parent>/<repo-name>-worktrees/` (lockstep en contrato). Un worktree por change/agente; 2+ agentes sobre el mismo repo con `--cwd` propios. |
| C2 | Permission deployment | El sync despliega acceso a `~/agent_worktrees/**` sin config manual. opencode: `permission.external_directory` glob; claude: `permissions.additionalDirectories` + tool-spec allow globs; codex: `sandbox_workspace_write.writable_roots`; pi: `pi-permission-modes`. Solo opencode/pi soportan glob; claude/codex literales → C3 es la frontera real de seguridad. Mecánica por runtime en setup.sh; `permission_roots` en envelopes. |
| C3 | Cross-repo AND cross-worktree boundary | MCP = única superficie de mutación. Remove toma `(repo_path, change)` — nunca un path crudo; el server deriva `~/.agent_worktrees/<basename(repo_path)>/<change>` validando slug seguro. `.sdd-agent-lock` gana `owner`; remove exige lock.owner == caller.owner (si no → `owned_by_other`); pid vivo → `active_agents`. Agente A(change C) estructuralmente no puede remover D; force/recovery cross-session explícito y two-phase. |
| E1 | Echo-contract discoverability | Hallazgo del incidente `git_commit` re-confirm loop (llm-proxy): 7 tool descriptions two-phase documentan el protocolo de eco; `confirm_required` mensaje accionable; check grep en run_red_checks.sh. El fingerprint fail-closed NO se debilita. |
| D1-D6 | Preexistentes | degrade guard, exit mapping, selector 5g, skip mechanics, tool placement, shared helper, active_agents lock, catalog closed-set, skill 6c (todo trazado a proposal/spec). |

## Scope confirmed (frontera del change)

- F5: degrade network + selector 5g en setup.sh; `selectors` en envelopes.
- F6: `git_worktree_add`/`remove` (worktree_mutation.py) + `git_worktree_list` (local_read.py); `.sdd-agent-lock`; C3 boundary; `owned_by_other` en catálogo.
- C2: `permission_roots` en envelopes + deploy por runtime en setup.sh.
- E1: descriptions de 7 tools two-phase + mensaje confirm_required.
- 6c: append aditivo en skill using-git-worktrees (MCP-native, no-git-crudo).

## Non-goals re-confirmed

- No persistencia del selector (decisión quest).
- No weaken del fingerprint gate.
- No refactor de `_validate_worktree` a módulo compartido (patrón duplicado existente).
- No permiso en `wiring/opencode.sdd.json` (setup.sh es el único escritor `mcp`/config runtime; `permission_roots` vive en envelopes de mcp.d).

## Next

Arch-lint (siempre post-council) → gate → tasks → apply → verify → archive.