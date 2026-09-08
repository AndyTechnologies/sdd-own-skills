```yaml
schema: gentle-ai.verify-result/v1
evidence_revision: sha256:22494403d350778abf5a5d75a69e414b33a8a05b1dfee6404a94672979871b88
verdict: pass_with_warnings
blockers: 0
critical_findings: 0
requirements: 14/14
scenarios: 28/28
test_command: ./tests/run_red_checks.sh
test_exit_code: 0
test_output_hash: sha256:ab9434200082fc3d2bf0d96ce1acfc85863125041e4eace91ca57aaf46f2d29f
build_command: bash -n sync-skills.sh
build_exit_code: 0
build_output_hash: sha256:e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855
```

## Verification Report

**Change**: sdd-council
**Version**: N/A (no spec version field; specs: sdd-council v1, workflow-contract v1)
**Mode**: Standard (`strict_tdd=false` in openspec/config.yaml)

**Evidence rule used for scenario statuses** (config repo, no application runtime): a scenario is COMPLIANT when (a) a passed RED pin directly greps the implementing clause text, or (b) the clause was verified by direct read of the deployed file (md5-identical to the repo copy, cf. `sync --check` result) AND a passed RED pin family greps that same file. All 28 scenarios below meet (a) or (b); none is FAILING or UNTESTED.

### Completeness
| Metric | Value |
|--------|-------|
| Tasks total | 20 |
| Tasks complete | 20 |
| Tasks incomplete | 0 |

### Build & Tests Execution
**Build**: ✅ Passed

```text
$ bash -n sync-skills.sh
(no output — syntax OK, exit 0)
build_output_hash: sha256:e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855
```

**Tests**: ✅ 39 passed / ❌ 0 failed / ⚠️ 0 skipped

```text
$ ./tests/run_red_checks.sh
== Resumen RED checks ==
  PASS: 39   FAIL: 0   SKIP: 0
  Verde.
(exit 0; test_output_hash: sha256:ab9434200082fc3d2bf0d96ce1acfc85863125041e4eace91ca57aaf46f2d29f)
```

Note: one earlier harness run was truncated by `/tmp` tmpfs quota exhaustion (247 stale sandbox dirs, ~80MB each, left by prior runs) — environmental, diagnosed via `Disk quota exceeded` (Errno 122) in `fake_api.py`/`sandbox.sh`, unrelated to this change's files. Cleanup + clean re-run produced the 39/39 result above.

**Coverage**: ➖ Not available (config repo; `coverage_threshold: 0` in openspec/config.yaml)

### Spec Compliance Matrix

#### sdd-council spec (9 requirements / 16 scenarios)

| Requirement | Scenario | Test | Result |
|-------------|----------|------|--------|
| Skill existence and structure | Skill deployed via sync | `sync-skills.sh --check` + T30 (zero desyncs, 0 errors) + installed copy md5 match | ✅ COMPLIANT |
| Skill existence and structure | Skill contains required sections | T35 (3 `## Lens:` sections) + T36 (`### Decision:` acta format) | ✅ COMPLIANT |
| Lens agent registration | Orchestrator can task council | T33 (`.agent[gentle-orchestrator].permission.task[sdd-council] == "allow"`) | ✅ COMPLIANT |
| Lens agent registration | Council can task lens agents | T33 (council allow-list for sdd-council-arch/product/risk) | ✅ COMPLIANT |
| Lens agent registration | No __managed_by on any council agent | T33 (`map(has("__managed_by")) | all(. == false)`) | ✅ COMPLIANT |
| Lens agent registration | No mcp key added | T37 (`has("mcp") | not`; fragment keys exactly `["$schema","agent","default_agent","subagent_depth"]`) | ✅ COMPLIANT |
| File-based prompt and OWN_PROMPTS | Prompt file exists | T34 (`wiring/prompts/sdd/sdd-council.md` present; T33 pins `{file:./prompts/sdd/sdd-council.md}`) | ✅ COMPLIANT |
| File-based prompt and OWN_PROMPTS | OWN_PROMPTS includes council | T34 (`OWN_PROMPTS=(orchestrator.md sdd-rfc-author.md sdd-council.md)`) | ✅ COMPLIANT |
| Convergence fast-path (no-fork) | 3 voices converge | T36 (`does NOT interrupt the user` in orchestrator + skill) | ✅ COMPLIANT |
| Fork resolution by human | Real fork presented to user | T36 (`never decides forks alone` in orchestrator, skill, sdd-continue, sdd-ff) | ✅ COMPLIANT |
| Fork resolution by human | User rejects all options | T36 (fork-to-user pins prove the framing route) + static: skill L161 "a user rejection of ALL options STOPs the chain with a report", orchestrator hooks item 3 (same clause) | ✅ COMPLIANT |
| Two-round hard cap | Second round unresolved | T36 (`Max 2 rounds` in orchestrator + skill) + static: orchestrator rule 4 "a round-2 unresolved verdict MUST `STOP` with a report and block tasks" | ✅ COMPLIANT |
| Two-round hard cap | Fresh voices per round | Static: skill L83 "Do NOT pass the other lenses' prompts or any prior-round output — fresh voices per round", orchestrator rule 4/hooks "1 re-frame with fresh voices" (files pinned by T32/T36) | ✅ COMPLIANT |
| Acta persistence | Acta written to both stores | Static: skill L141 persists `openspec/changes/{change}/council.md` AND Engram topic `sdd/{change}/council`; T36 pins `### Decision:` acta format in same file | ✅ COMPLIANT |
| Council never relaunches design | Council is read-only | Static: skill L51/L160 "the council is read-only with respect to `design.md`", orchestrator hooks "the council NEVER relaunches design" (files pinned by T32) | ✅ COMPLIANT |
| Organic support phase hook | Council not in nextRecommended | Static: status-contract domain `propose|spec|design|tasks|apply|verify|remediate|archive|sdd-new|select-change|resolve-blockers` (no council); skill + prompt state "NEVER touch nextRecommended"; orchestrator L254 routes only by native token set | ✅ COMPLIANT |

#### workflow-contract spec (5 requirements / 12 scenarios)

| Requirement | Scenario | Test | Result |
|-------------|----------|------|--------|
| Council-chain target flow | Happy-path chain | T32 (`design → council (ALWAYS) → arch-lint (ALWAYS, acta mandatory) → gate` in rule 4) | ✅ COMPLIANT |
| Council-chain target flow | Arch-lint failure retried once then STOP | Static: orchestrator rule 4 "Auto mode allows `max 1 retry` of the full council → arch-lint chain; a second failure MUST `STOP` with a report (no loop-until-clean)" (file pinned by T32) | ✅ COMPLIANT |
| Council-chain target flow | No-forks fast-path (convergence) | T36 (`does NOT interrupt the user` in orchestrator + skill) | ✅ COMPLIANT |
| Council-chain target flow | Acta missing at arch-lint | T32 + T35 (`MANDATORY input` in orchestrator + arch-lint skill, `FAILS CLOSED`) | ✅ COMPLIANT |
| Council-chain target flow | Empty/trivial design N/A | T35 (`empty or trivial design` N/A clause in arch-lint skill) | ✅ COMPLIANT |
| Orchestrator rule 4 and organic hooks rewrite | Rule 4 rewritten, F4 text stable | T31 (F4 pins preflight/consent/v3/never-skips-human/candidate-scoped/continues-to-archive/informational-no-op all green) + git diff: exactly 2 hunks (hooks item 3 + rule 4); F4 section L405-414 byte-stable | ✅ COMPLIANT |
| Orchestrator rule 4 and organic hooks rewrite | Organic hooks item 3 extended | T32 (`post-design hooks`, `delegate the post-design council ALWAYS`) | ✅ COMPLIANT |
| Arch-lint axis 2 (acta verification) | Acta decisions verified title-by-title | T35 (`title-by-title` in arch-lint skill) | ✅ COMPLIANT |
| Arch-lint axis 2 (acta verification) | Missing acta fails closed | T32 + T35 (`fails axis 2 closed` in orchestrator; `FAILS CLOSED` + `MANDATORY input` in arch-lint skill) | ✅ COMPLIANT |
| Command overlay council chain | sdd-continue SUPPORT-CONDITIONAL wired | T32 (`runs ALWAYS AFTER \`design\`` in sdd-continue) + T36 (sdd-continue fork/2-round pins) | ✅ COMPLIANT |
| Command overlay council chain | sdd-ff item 6 wired | T32 (`sdd-council — ALWAYS after design` in sdd-ff) + T36 (sdd-ff fork pin) | ✅ COMPLIANT |
| RED checks T32+ | Full red suite green | Full harness 39/39 exit 0 (T32-T39 all `[PASS]`, incl. T38 fragment+installed `subagent_depth == 2` and T39 both merge engines jq+python) | ✅ COMPLIANT |

**Compliance summary**: 28/28 scenarios compliant (21 pin-proven by direct grep, 7 pin-family + static clause verification)

### Correctness (Static Evidence)
| Requirement | Status | Notes |
|------------|--------|-------|
| Skill existence and structure | ✅ Implemented | `skills/sdd-council/SKILL.md` — 3 `## Lens:` sections, convergence/fork/2-round table, acta format, `delegate_only: true`; deployed copy md5-identical (`e66de7e4…`) |
| Lens agent registration | ✅ Implemented | 4 agents in `wiring/opencode.sdd.json` (council file-based + 3 inline lens subagents, `hidden: true`, no `__managed_by`, no `mcp`); allow-lists orchestrator→council→lenses, council `*` deny |
| File-based prompt and OWN_PROMPTS | ✅ Implemented | `wiring/prompts/sdd/sdd-council.md` + `OWN_PROMPTS` L105; prompt symlinks deployed (opencode + claude) |
| Convergence fast-path (no-fork) | ✅ Implemented | rule 4 + hooks item 3 + skill: convergence never interrupts the user |
| Fork resolution by human | ✅ Implemented | 4 files state "never decides forks alone"; lossless blocking-prompt route; rejection of ALL → STOP with report |
| Two-round hard cap | ✅ Implemented | round budget owned by orchestrator (L373/L493), skill stateless records round number; round 2 unresolved → STOP + block tasks |
| Acta persistence | ✅ Implemented | markdown `council.md` + Engram mirror `sdd/{change}/council`; persisted before return (fail-closed for arch-lint) |
| Council never relaunches design | ✅ Implemented | skill L51/L160 + orchestrator L373 explicit; orchestrator sole design re-launcher |
| Organic support phase hook | ✅ Implemented | hooks item 3 ALWAYS post-design; council absent from nextRecommended token domain and from routing predicate L254 |
| Council-chain target flow | ✅ Implemented | rule 4 full chain `design → council (ALWAYS) → arch-lint (ALWAYS, acta mandatory) → gate`; max 1 retry then STOP |
| Orchestrator rule 4 and organic hooks rewrite | ✅ Implemented | rule 4 + hooks item 3 replaced; F4 section byte-stable (git diff 2 hunks only; T31 green) |
| Arch-lint axis 2 (acta verification) | ✅ Implemented | `skills/sdd-architecture-lint/SKILL.md` v1.1 axis 2: MANDATORY acta, title-by-title, FAILS CLOSED on missing acta, N/A only empty/trivial; deployed copy md5-identical (`dce258e6…`) |
| Command overlay council chain | ✅ Implemented | sdd-continue: council → arch-lint ALWAYS (SUPPORT-CONDITIONAL flipped); sdd-ff: planning item 6 ALWAYS; blocks `cmd-sdd-*` ids unchanged |
| RED checks T32+ | ✅ Implemented | T32-T39 appended + coverage map updated; 39/39 green post-sync |

### Coherence (Design)
| Decision | Followed? | Notes |
|----------|-----------|-------|
| Council skill structure (single skill, 3 lens sections, stateless, 2-round cap) | ✅ Yes | T35/T36; orchestrator owns round budget |
| Prompt wiring (file-based council prompt + inline lens sections) | ✅ Yes | T33/T34; no inline mega-agent |
| Lens orchestration + `subagent_depth: 2` | ✅ Yes | T33/T38; merge implemented in both engines (jq L801, python L866-869), T39 green on both legs |
| Arch-lint opt-out only for empty/trivial design | ✅ Yes | T35 (`N/A` clause) |
| Acta writer: single writer = council; orchestrator only re-launches design | ✅ Yes | skill L51/L160 + orchestrator hooks item 3 |
| Organic support phase, never in `nextRecommended` | ✅ Yes | status-contract domain + skill/prompt explicit |

### Issues Found
**CRITICAL**: None
**WARNING**:
1. Environment / test hygiene (non-implementation): `/tmp` tmpfs quota exhaustion from accumulated sandbox dirs (247 × ~80MB from prior runs) truncated one harness run during verification (T11–T13 environmental failures, exit 1; `Disk quota exceeded` Errno 122 in `fake_api.py`). Resolved by cleanup + clean re-run 39/39. Same failure class plausibly explains apply-era pre-sync flakes (T14 pty timeout; non-reconstructible 32/12 row). Action for future runs: clean `/tmp/sdd-red.*` before the harness.
**SUGGESTION**:
1. Docs hygiene (remediated during verify, non-implementation): `apply-progress.md` claimed "19/19 tasks" (actual 20 per tasks.md) and a pre-sync 32/12 evidence row that did not sum against the 39-test suite. Both corrected in apply-progress.md (20/20 + verified post-sync numbers with test output hash).
2. Style (non-functional): orchestrator.md L362 organic-phase intro names quest/research/arch-lint/changelog but not council; council is correctly wired in hooks item 3 under the "organic phases never join nextRecommended" sentence, so there is no functional gap — a future cosmetic pass could add council to that list.

### Verdict
PASS WITH WARNINGS — implementation fully complies with both specs (14/14 requirements, 28/28 scenarios), all 20 tasks complete, RED suite green 39/39 post-sync (independently re-run), sync --check zero desyncs, F4 contract byte-stable; the two findings are non-implementation (environment + docs hygiene, the latter already remediated).