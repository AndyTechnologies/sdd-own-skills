# Delta Spec: Architecture Principles Catalog

## Needs

The quest, the architecture plan, and the architecture lint must share one verifiable principles corpus. Today none exists in the repo, and per-skill copies would drift. The change adds a single structured catalog consumed by path and deployed through the sync-skills.sh shared loop.

## Scenarios

#### Scenario: S1 · Catalog deploy to zero desyncs
- GIVEN `skills/_shared/architecture-principles.md` copied to the installed shared directory
- WHEN `sync-skills.sh --check` runs
- THEN it reports zero desyncs

#### Scenario: S2 · Re-deploy never overwrites
- GIVEN the shared catalog already exists at the target
- WHEN sync-skills.sh runs the shared copy-only-if-missing loop
- THEN the existing file is preserved byte-for-byte

#### Scenario: S3 · Consumers resolve one path
- GIVEN the RED suite greps quest, plan, and lint for the catalog reference
- THEN all three reference exactly `skills/_shared/architecture-principles.md`

#### Scenario: S4 · Catalog and checks in sync
- GIVEN the catalog content is modified
- WHEN the RED suite cross-checks catalog entries against lint checks
- THEN every P01..P10/A01..A11 check resolves to a catalog entry and vice versa

#### Scenario: S5 · Full corpus present
- GIVEN the change is applied
- THEN the catalog carries P01..P10 with fixed fields and an 11-entry anti-pattern table

## Capabilities

### Added Capability: Shared Architecture Principles Catalog

### Requirement: Single Source of Truth

The change MUST provide the principles catalog as one structured Markdown file at `skills/_shared/architecture-principles.md`. The quest, the architecture plan, and the architecture lint SHALL consume it by path; per-skill duplication SHALL NOT exist. The change MUST NOT introduce a parallel JSON catalog in this cycle.

Scenarios: S1, S3, S5

### Requirement: Fixed Catalog Schema

Each principle entry MUST declare name, definition, concrete evidence, and default severity. The catalog MUST include a table of the full first-cycle set of 11 anti-patterns. The catalog SHALL remain the single source; consumers SHALL NOT hold copies.

Scenarios: S4, S5

### Requirement: Safe Shared-Loop Deployment

The catalog MUST join the sync-skills.sh shared loop with copy-only-if-missing semantics: an existing installed copy MUST NOT be overwritten, and `sync-skills.sh --check` MUST report zero desyncs after deployment.

Scenarios: S1, S2