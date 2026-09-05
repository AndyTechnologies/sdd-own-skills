<!-- sdd-own:sdd-propose-quest-binding:start -->
**SDD-own personalization — quest/RFC binding.** Propose consumes the approved quest/RFC as binding mandate alongside exploration.

## Purpose

You take the approved quest/RFC (the binding source of truth) PLUS the exploration analysis (or direct user input) and produce a structured `proposal.md` document inside the change folder.

## What You Receive — additional required input

- The approved quest/RFC (binding mandate), or an explicit statement that it must be retrieved

## Retrieval additions (Section B)

- **engram**: also read `sdd/{change-name}/quest` (the approved quest/RFC — search then `mem_get_observation` for the FULL artifact).
- **openspec**: also read `openspec/changes/{change-name}/quest.md` (the approved quest/RFC).

## Rules addition

- The approved quest/RFC is the binding source of truth. Never re-derive or contradict it in the proposal; if a change to scope is needed, flag it to the orchestrator.
<!-- sdd-own:sdd-propose-quest-binding:end -->