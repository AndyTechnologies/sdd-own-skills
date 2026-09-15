<!-- sdd-own:cmd-sdd-ff-quest-support:start -->
**SDD-own personalization — quest + unified flow in fast-forward.** Replace the "Planning phases:" list of the WORKFLOW above with this version:

1. Product Quest — two-branch RFC pre-pass, branch 1: load the `sdd-quest` skill via your Skill tool and interview the user one focused question at a time with your `question` tool (hard budget 50). RFC gate 1: explicit user approval of the product RFC. `needs-changes` reopens ONLY this branch within its remaining budget; STOP on `rejected`. Skip when gate 1 is already `approved`.
2. Architecture Quest — branch 2: same interview primitive (hard budget 20), starting from the approved product RFC. RFC gate 2: explicit user approval of the architecture RFC. `needs-changes` reopens ONLY this branch within its remaining budget; STOP on `rejected`. Skip when gate 2 is already `approved`.
3. sdd-rfc-author — after BOTH gates approve, delegate the collected Q&A to draft the dual artifacts `product-rfc.md` + `arch-rfc.md`.
4. sdd-explore — investigate the codebase consuming the approved RFCs as its mandate (skip only if an exploration already exists); `sdd-research` runs in PARALLEL when external/auditable evidence is needed.
5. sdd-propose — create the proposal from the product RFC + explore/research evidence.
6. sdd-spec — write specifications (consuming arch-rfc + evidence).
7. sdd-architecture-plan — run AFTER spec, BEFORE design: consumes `arch-rfc.md` + explore/research + spec deltas, produces the binding acta `arch-plan.md` with titled decisions, and requires the USER gate before design (interactive: explicit approval; auto: recorded, no interruption). Rejection → return to the Architecture Plan with findings (max 2 rounds); a 3rd rejection stops with a report.
8. sdd-design — create technical design from the RFCs + spec deltas + the arch-plan acta.
9. sdd-tasks — break down into implementation tasks.
10. After apply → sdd-architecture-lint ALWAYS POST-apply (axis 1 requirements/scope; axis 2 verifies the `arch-plan.md` acta title-by-title vs design + implementation, fail-closed when missing; finding → design, max 2 rounds) → verify → sdd-hard-verify OPT-IN (NO default → close; YES → break testing; suite-pass-on-break → Tasks relay, max 2) → changelog (PRE-archive, cumulative append) → sdd-pre-experience (fail-open) → archive → PR ready (merge human-only).

The quest, research, hard-verify, changelog, and pre-experience are SUPPORT hooks: they never join `nextRecommended` and never alter it; detection is by artifact presence/state or the user's explicit answer (hard-verify), exactly as in `/sdd-continue`. Delegate phase and support work only to dedicated sub-agents (never run support phases inline). In `interactive` mode, pause after each phase and ask before the next; in `auto` mode, run the fast-forward back-to-back with the organic hooks applied.
<!-- sdd-own:cmd-sdd-ff-quest-support:end -->