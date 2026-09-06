# Architecture Lint: gh-git-mcp

**Status**: needs-changes — findings must go back to design before tasks freeze.
**Reviewer**: sdd-architecture-lint (independent second eye, read-only, no review/delivery/release authority)
**Date**: 2026-09-06
**Inputs**: `design.md` (primary), `proposal.md`, `quest.md`, delta specs (`gh-git-mcp-server`, `mcp-definitions`, `github-automation-skill`), verified against `setup.sh` (merge/presence code), `wiring/mcp.d/opencode.json`, `wiring/mcp.d/README.md`, `skills/github-automation/SKILL.md`, live `opencode.jsonc` `mcp` block, `mcp_pdf_reader` precedent.

## Verdicts by concern

| Concern | Verdict | Rationale |
|---|---|---|
| 1. Layering & one-direction dependency | ⚠️ Risk | Direction is real (`executor.py` is a leaf; handlers never call `subprocess.run`), but the "clean/hexagonal" label overclaims: core imports the **concrete** adapter (no port interface) and DI wiring is unstated. Two internal contradictions: `gh_auth.py` is labeled adapter but returns core `Envelope` while the layer table says adapter "Never does ... envelope"; the transport's outer try/except catches `SubprocessError`, creating a transport→adapter edge that skips the core. |
| 2. Subprocess ownership & fail-closed placement | ⚠️ Risk | Ownership is correctly confined (single `SubprocessRunner`, hygiene/timeout/token-free coherently placed in the adapter; auth policy in flow/handlers, mechanism in `gh_auth`). But §4.4 vs §5.2 leave ambiguous whether per-op dry-run **computation** lives in `dryrun.py` (risking a God Module that must touch the executor) or in the handlers. Also `git_commit`'s compound `git add -A && git commit` cannot run as one argv without `shell=True` — must be two executor calls. |
| 3. Template Method & pattern rejections | ✅ Conforms (with ❌ on flow semantics) | Template Method via callbacks/composition is the right call and the lightest instantiation; Strategy/Adapter/Proxy rejections are sound (verified against design-patterns decision guide). BUT the confirm-without-prior-dry-run mechanism is **self-contradictory** (see BLOCKER-1): stateless server + pseudo-code that executes on any safe confirmed call + text claiming a follow-up confirm is required cannot all be true. |
| 4. Modular families boundary | ✅ Conforms | remote/local × read/mutation split is clean: direction aligns with the auth-gate boundary, intent aligns with the flow template. No accidental coupling. Minor: 17 auth-gate call sites; "never does raw CLI parsing" table row vs handlers parsing gh/git text. |
| 5. Wiring registration & skill adaptation | ⚠️ Risk | Multi-entry block **verified sound and idempotent** against `setup.sh` (jq deep merge `target[mcp] * block`, presence gated on `server_key: github`, other mcp servers preserved, python fallback deep-merge). BUT the dual-surface mapping has real coverage gaps vs the "no workflow skipped or degraded" spec scenario, and the tool count is 23, not 22. |
| 6. DI / port-adapter correctness | ⚠️ Risk | See WARNING-1/2/3 and BLOCKER-1 — all fixable pre-freeze with small, contained changes. |

## Findings

### BLOCKER-1 — Confirm-without-prior-dry-run mechanism is unspecified and the pseudo-code contradicts the RFC and the spec

**Where**: design §4.4 (`destructive_flow` pseudo-code + `parameterize: dict`), vs RFC edge case ("confirmed without dry-run step → server dry-runs internally and returns effect + requires a follow-up confirm, never an accidental mutation") and spec scenario "Confirm without dry-run refused".

**Problem**: The server is declared stateless ("no cross-session state; prior dry-run is re-derived at confirm time"). A stateless server cannot distinguish "confirmed after a prior dry-run" from "confirmed having never seen a dry-run" — both arrive as `confirmed:true`. The pseudo-code is unambiguous about what it does with a safe recomputed effect: `return execute() # exactly once`. So a **first-ever** `confirmed:true` call with a safe effect EXECUTES — violating the RFC's "requires a follow-up confirm, never an accidental mutation" and the spec scenario (re-computes AND no mutation occurs). The inline comment claims the recompute IS the refusal guard, but the recompute runs unconditionally before the branch — it adds nothing. §4.4 text ("still requires a follow-up confirm") disagrees with the pseudo-code. `parameterize: dict` is undefined (a mystery bag), so tasks cannot know what evidence a confirm call must carry.

**Fix (minimal)**: Specify echo-back evidence — the confirm call MUST include the effect returned by the prior dry-run (or a fingerprint of it, e.g. the dry-run `data` echoed via `parameterize`). Template: re-derive effect → if `confirmed` and echoed-effect matches the re-derived effect and it is safe → execute once; if `confirmed` with no/mismatched evidence → return the re-computed dry-run marked `ok:true, dry_run:true` (or `confirm_required`), no mutation. Update the pseudo-code, the comment, and define `parameterize` contents. This satisfies the RFC edge case exactly, stays stateless, and makes the model prove it saw the effect before mutating.

### CRITICAL-1 — Dual-surface mapping cannot be complete; "no workflow skipped or degraded" is unachievable with the stated 22-tool surface

**Where**: design §8 (mapping table claims "map each `github_*` family used by the workflows to its own equivalent"), spec `github-automation-skill` scenario "Official unavailable" ("no workflow is skipped or degraded"), vs §5 tool surface.

**Problem**: The workflows in `skills/github-automation/SKILL.md` reference tools with NO equivalent on the own surface: `github_add_issue_comment` (issue triage), `github_review_pull_request` (PR review), `github_get_file` / `github_search_repositories` / `github_search_issues` (content/discovery), `github_get_commit`, remote branch ops (`github_create_branch` / `github_get_branch` / `github_list_branches`). The mapping table as promised cannot be written truthfully, and on the official-unavailable path the issue-triage comment step and the PR review step have no own-surface mechanism — that IS a degraded workflow, contradicting the spec scenario.

**Fix (minimal)**: Design must (a) document per-family coverage honestly — a mapping table that explicitly marks which `github_*` tools have NO own equivalent — and (b) specify the own-surface behavior of unmappable steps (e.g. "issue-comment steps require the official surface; if unavailable, report to the human"), and (c) reconcile the delta spec scenario ("no workflow degraded") with the actual surface — either amend the scenario or extend the surface. Decide in design, not in tasks.

### WARNING-1 — "Clean/hexagonal" overclaim: no port interface, concrete adapter imports, unstated DI wiring

**Where**: design §2, §4.2.

**Problem**: Handlers import the concrete `SubprocessRunner` and `dryrun.py` imports/calls `assert_authed` — the core depends on the concrete adapter, not on a port. The claim "adapter swappable (e.g. an in-process mock in verify smoke tests)" is therefore weaker than stated, and the design never says who constructs `SubprocessRunner` or how handlers receive it (module-level instantiation would hardcode the adapter at the core). The aspirational pytest suite ("two-phase flow against a mocked executor", §12) would require monkeypatching.

**Fix (minimal)**: Composition root — `server.py` constructs `SubprocessRunner()` once and passes it through `register(server, executor)`; handlers receive the executor as a parameter (matching the design's own `assert_authed(executor)` signature). Type the executor against a tiny `Protocol` (`run(argv, *, cwd, text, timeout_s) -> ProcResult`) defined once. No new files, one extra parameter — makes the mock-swap and core unit-testability claims true.

### WARNING-2 — `gh_auth.py` placement contradicts the design's own layer table; transport catches adapter exceptions

**Where**: design §2 diagram (gh_auth = adapter), §2 layer table (adapter "Never does ... envelope"), §4.3 (`assert_authed(...) -> Envelope | None`), §4.1 (transport catches `Exception` → `network_error` for subprocess errors).

**Problem**: (a) `gh_auth.py` returns core `Envelope` objects — adapter→core edge by the design's own labels, while the table forbids the adapter from touching the envelope. The cleanest reading: `assert_authed(executor)` is a core application service (policy: translate an auth probe into a typed error) whose only adapter dependency is its parameter — relabel it as core (file may stay), fix the table row. (b) The transport's outer try/except classifying `SubprocessError` as `network_error` requires `server.py` to import the adapter's exception type — a transport→adapter edge that skips the core, and the spec says exceptions are "caught per tool". Per-tool catch in handlers should classify subprocess errors; the transport net should only wrap unexpected exceptions as `invalid_parameter`.

### WARNING-3 — `dryrun.py` ownership ambiguity risks a God Module

**Where**: design §4.4 (template with per-op `compute_dry_run` / `execute` callables) vs §5.2 ("Dry-run computation detail (`dryrun.py`)", per-op computations).

**Problem**: If tasks implement the per-op dry-run computations inside `dryrun.py`, that module mixes the flow skeleton (safety invariant) with tool-specific gh data gathering (mergeability rollup, compare check, run status) — it would need executor access and grow with every new destructive op. The template's whole point is that computation is the **variation axis** passed in.

**Fix (minimal)**: State the split explicitly: `dryrun.py` = pure skeleton + shared pure helpers (mergeability/merged-check/unknown-state classification, taking data as inputs, not fetching it); the handlers gather gh data via the executor and wire `compute_dry_run` / `execute` callables into the template. Keeps the template adapter-free and unit-testable with fake data.

### WARNING-4 — Tool count is 23, not 22 (arithmetic bug propagated into a spec scenario)

**Where**: design §1/§5 ("22-tool"), proposal ("22-tool surface"), spec `gh-git-mcp-server` scenario "Full surface advertised" ("lists 22 `gh_*`/`git_*` tools"), vs the requirement's own enumeration: 14 remote reads + 3 remote mutations + 4 local reads + 2 local mutations = **23**.

**Problem**: `verify` will run `tools/list` against a 23-tool server and its own scenario demands 22 — a guaranteed mismatch, and the wrong number is in a delta spec (survives archive into the main spec).

**Fix (minimal)**: Renumber to 23 in design, proposal, and the spec delta (or drop a tool — not recommended). Trivial but must happen before freeze.

### WARNING-5 — `git_commit` compound command is not expressible in one argv

**Where**: design §5.4 (`git -C path add -A && git commit -m msg`, single subprocess row).

**Problem**: The executor is argv-based with no shell (`run(argv: list[str])`); `&&` is shell syntax. Running this faithfully either needs `shell=True` (quoting/injection hazard the argv design rightly forbids) or two executor calls. Also: if `commit` fails after `add` succeeds, the index remains staged — a visible partial state that the "never returns partial mutation" claim should address.

**Fix (minimal)**: Specify `git_commit` as two executor calls (`add -A`, then `commit`), dry-run = `git status --porcelain` staged summary, and document that a failed commit leaves the index staged (recoverable via `git status`, no silent retry).

### SUGGESTION-1 — Auth-gate call-site consolidation

17 remote tools gate on `assert_authed()` (14 reads directly + 3 mutations inside the template). A single shared `require_auth(executor, ...)` helper (or a small decorator) imported by `remote_read.py`/`remote_mutation.py` prevents drift if the gate signature changes. Per-tool calls are acceptable; the design should just pick one.

### SUGGESTION-2 — Layer table wording vs git text parsing

Core "Never does ... raw CLI parsing" conflicts with handlers necessarily parsing `gh --json` (structured) and git text (`status --porcelain`, `log`, `diff`). Parsing IS tool semantics and correctly lives in handlers — fix the table wording rather than adding a normalizer. Robustness note: prefer `git status --porcelain=v1 -z` (or v2) for script-safe filenames.

### SUGGESTION-3 — Docker transport interplay

With `MCP_GITHUB_TRANSPORT=docker`, `setup.sh` renders `alt_docker` (github-only) and the `gh-git-mcp` local entry silently disappears. Host has no docker (RFC) so impact is nil today, but the multi-entry contract should state the behavior: either include the local entry under `alt_docker` too (it renders fine alongside a docker entry) or document docker-mode as dropping the local server.

### SUGGESTION-4 — Timeout budget for log/read-heavy tools

`gh_get_run_logs` streaming a large run can exceed 30 s. The executor already allows `timeout_s` per call — specify a larger default for log tools rather than the blanket 30 s. Also note the `timeout → network_error` typing is semantically muddy (a timeout need not be a network failure) but acceptable inside the closed catalog.

### SUGGESTION-5 — `gh_merge_pull_request --auto` semantics

`--auto` defers the actual merge until checks pass — the "exactly one mutation" guarantee covers the call, not the effect. Dry-run covers call-time state only. Document this (or drop `--auto` if nothing drives it).

## Verified-sound claims (spot-checked against code)

- Multi-entry opencode block: `setup.sh` `merge_json_key` deep-merges the whole `block` into `target[mcp]` (jq `*`, python fallback deep-merge); idempotent on re-run; presence stays gated on `server_key: "github"` (`has($s)` check); other runtime mcp servers (codegraph/context7/engram in the live config) are preserved; absence of the new entry in check mode reports pending/notice, not a desync — matches the `mcp-definitions` delta scenarios. Zero `setup.sh` code change confirmed.
- Envelope error catalog matches the spec's closed set (8 types).
- 4-family module split matches the tool taxonomy and the auth boundary; no family-level accidental coupling.
- Template Method via callbacks is the lightest correct instantiation (design-patterns: "composition with callbacks" is the documented lightweight alternative to Template Method); Strategy/Adapter/Proxy rejections are sound.
- Fail-closed placement: mechanism (prompt-disable env, timeout, inheritance, `gh auth status`) in the adapter; policy (refuse on auth failure, refuse unknown state, exactly-once) in core flow/handlers — coherent once WARNING-2/3 are resolved.
- Skill direct-edit path is legal (exclusive skill, canonical source, full-install).

## Risks if findings are not addressed

1. First-confirmed-call mutation (BLOCKER-1) — the exact accident the RFC exists to prevent.
2. Skill claims a dual surface the server cannot serve (CRITICAL-1) — agents get a false fallback and unmappable steps.
3. Verify failure on its own 22-tool scenario (WARNING-4), and a God Module forming in `dryrun.py` (WARNING-3).

## Recommendation

Fix BLOCKER-1 and CRITICAL-1 in `design.md` (orchestrator re-runs `sdd-design`); apply WARNING-1..5 as cheap pre-freeze clarifications. The architecture skeleton, pattern choices, and wiring plan are otherwise sound and verified. Fit to freeze **after** BLOCKER-1 and CRITICAL-1 are resolved.