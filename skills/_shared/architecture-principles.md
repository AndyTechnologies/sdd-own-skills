# Architecture Principles Catalog

Shared, structured corpus consumed by path — the SDD quest (branch selection), the
architecture plan (acta checklist), and the architecture lint (axis 3). Single source
of truth: consumers resolve this file by exactly one relative path and hold no copies.

## Principles

### P01 — Dependency direction (inward)
- Definition: Dependencies point inward toward the stable core; lower layers never import higher layers, and the shared catalog is a hub all consumers resolve by one path.
- Concrete evidence: grep for import/reference statements crossing layer boundaries against an explicit dependency map; per-skill duplicated catalog copies are a violation.
- Default severity: blocker

### P02 — Explicit interfaces / contracts
- Definition: Boundaries between components are declared, pinned contracts (schema, ID scheme, severity model, verdict form) — never implicit conventions.
- Concrete evidence: the contract surface is grep-able (schema headers, stable identifiers, fixed verdict strings) and enforced by byte-deterministic pins.
- Default severity: blocker

### P03 — Single source of truth / no duplication
- Definition: Each piece of knowledge lives in exactly one canonical artifact; consumers reference it by path and never hold copies.
- Concrete evidence: a cross-check fails on drift when a consumer copy diverges from the canonical file's byte content.
- Default severity: blocker

### P04 — Minimal change / no-dogma
- Definition: Changes stay bounded to the declared affected areas; architecture applies only where a real boundary exists, never manufactured for dogmatic reasons.
- Concrete evidence: the change diff is limited to declared files/surfaces; fixtures assert expected results and never invent findings.
- Default severity: blocker

### P05 — Fail-closed gates
- Definition: Mandatory gates fail closed: a missing required artifact, title, or pre-install check stops the flow with an explicit error rather than proceeding.
- Concrete evidence: an omitted mandatory section fails its gate; a pre-install check failure blocks installation; exhaustion of a hard budget is reported, never silently extended.
- Default severity: blocker

### P06 — Testability / fixture coverage
- Definition: Every behavior surface is exercised by deterministic fixtures with expected outputs, and the acceptance suite is the enforcement mechanism.
- Concrete evidence: clean and dirty fixtures per family with expected findings; the RED suite cross-checks catalog entries against checks and pins byte content.
- Default severity: blocker

### P07 — Separation of concerns (skill boundaries)
- Definition: Each SDD phase owns one concern: the quest owns questioning, the plan owns applicability, the lint owns verification; shared data lives in the catalog.
- Concrete evidence: the branch table lives only in the quest, the checklist only in the acta, axis 3 only in the lint; one catalog serves all three by path.
- Default severity: blocker

### P08 — Cheap, deterministic verification envelope
- Definition: Verification is bounded in cost and deterministic in outcome: restricted to structure/dependencies/imports, fast enough to run on every change.
- Concrete evidence: checks use grep/jq over structure; the acceptance suite completes within its time budget; byte-pins compare exact content.
- Default severity: blocker

### P09 — Stable identity (IDs and schema)
- Definition: Identifiers and the catalog schema are frozen commitments: checks, fixtures, and cross-checks key on stable IDs, never on display text.
- Concrete evidence: P01..P10 / A01..A11 IDs resolve against the catalog in both directions; a renamed display seed does not break the cross-check.
- Default severity: blocker

### P10 — Deterministic execution, no hidden state
- Definition: Operations are idempotent and free of hidden global state: re-running produces the same result, and no action writes outside declared surfaces.
- Concrete evidence: re-deploys preserve existing bytes (copy-only-if-missing); checks are deterministic byte comparisons; no scripted state machine exists.
- Default severity: blocker

## Anti-patterns

| ID | Name | Definition | Concrete evidence | Default severity |
| A01 | Distributed monolith | A system split into services that still must deploy and scale as one: shared state, coordinated releases, or a single point of failure across "independent" components. | Services share a database, synchronous call chains dominate, or deployments cannot proceed independently. | blocker |
| A02 | Premature microservices | Splitting a system into services before the boundaries, scaling needs, and coupling costs are known, trading simplicity for distribution overhead. | Service boundaries added without consumer evidence of independent scalability or ownership. | blocker |
| A03 | Shared DB as integration | Multiple components sharing one database as their only integration mechanism, leaking schema changes and coupling through persistence. | Two or more components read/write the same tables with no API boundary between them. | blocker |
| A04 | Over-engineering | Adding abstraction, generality, or infrastructure beyond what current requirements and consumers justify. | Generic layers with a single concrete use, speculative interfaces, or frameworks for problems that do not exist yet. | blocker |
| A05 | Mutable global state | State reachable and writable from anywhere, making execution order and concurrency the source of truth. | Singleton mutable stores mutated from multiple call sites; tests cannot isolate state. | blocker |
| A06 | Excessive sync | Components synchronously dependent on each other's availability and latency, forming a chain where one slow caller stalls the system. | Deep synchronous call graphs with no buffering, timeouts, or fallbacks. | blocker |
| A07 | God object | A single class/module that knows and does too much, accumulating unrelated responsibilities and becoming the coupling hub of the system. | One module referenced by most of the system while holding state and behavior for many concerns. | blocker |
| A08 | Mud ball | An unstructured tangle of components where every module depends on many others with no clear boundaries or layering. | Dependency graph with no dominant direction; changes ripple across unrelated modules. | blocker |
| A09 | Framework addiction | Building the application around a framework's conventions and services instead of the domain, so the framework rather than the code decides architecture. | Domain code coupled to framework base classes, containers, or lifecycle calls throughout. | blocker |
| A10 | Copy/paste | Duplicating logic across sites instead of extracting shared behavior, so a fix must be repeated in every copy and copies drift. | Near-identical blocks at multiple locations; a single change requires editing the same logic in several files. | blocker |
| A11 | Excessive chain of responsibility | A request flowing through a long chain of handlers where each link adds latency, obscures ownership, and makes the effective path hard to reason about. | Deep handler chains with no visible termination rule; logging and side effects distributed across every link. | blocker |