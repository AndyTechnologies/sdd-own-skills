# Delta Spec: Architecture Lint Axis 3

## Needs

The architecture lint verifies spec (axis 1) and acta (axis 2) but has no verifiable principles axis. The change adds axis 3: stable checks P01..P10 (principles) and A01..A11 (anti-patterns) resolved from the catalog, with per-check severity and findings, an independent aggregated verdict, acta-driven applicability, and fixture/RED verification.

## Scenarios

#### Scenario: L1 · Clean fixture PASS
- GIVEN a clean SDD change fixture
- WHEN axis 3 runs
- THEN the verdict is `axis_3 pass`

#### Scenario: L2 · Single violation FAIL
- GIVEN a fixture violating one principle or anti-pattern
- WHEN axis 3 runs
- THEN the verdict is `axis_3 fail` with the correct blocker on the expected check ID

#### Scenario: L3 · Full blocker set
- GIVEN a fixture with multiple violations
- THEN findings carry the complete blocker set, not only the first

#### Scenario: L4 · Suspicion warns
- GIVEN ambiguous evidence (possible false positive)
- THEN the finding is a warning, never a blocker

#### Scenario: L5 · N/A suppresses
- GIVEN the acta declares a check N-A justified
- THEN the check is suppressed with the justification visible

#### Scenario: L6 · Dual signal
- GIVEN an applicable principle whose direction evidence is contradicted by the implementation
- THEN the signal is both axis 2 (unmet mandate) and axis 3 (blocker)

#### Scenario: L7 · No regressions
- GIVEN the change is applied
- THEN existing checks T01–T48/T42b/T47b still pass

## Capabilities

### Added Capability: Architecture Lint Axis 3

### Requirement: Axis 3 with Independent Verdict

The lint MUST expose axis 3 as a separate axis with its own aggregated verdict `axis_3 pass|fail`, independent of axis 2. The verdict MUST be `axis_3 fail` only when at least one blocker finding exists.

Scenarios: L1, L2

### Requirement: Stable Check IDs and Findings

Axis 3 MUST implement stable check IDs P01..P10 (principles) and A01..A11 (anti-patterns), resolved against the shared catalog. Each check MUST emit findings carrying its ID and concrete evidence. A fixture with multiple violations MUST produce the full blocker set.

Scenarios: L2, L3

### Requirement: Severity Model

Axis 3 MUST assign per-check severity: blocker for core-principle violations and detected anti-patterns; warning for unconfirmed suspicions. Ambiguous evidence MUST render a warning, never a blocker, absent confirmation.

Scenarios: L2, L4

### Requirement: Acta Interplay

Axis 3 MUST honor the arch-plan acta applicability declarations: a check declared N-A justified SHALL be suppressed with visible justification, and an applicable principle whose direction evidence is contradicted MUST produce the dual signal (axis 2 unmet mandate + axis 3 blocker).

Scenarios: L5, L6

### Requirement: Fixture-Verified, Cheap Checks

The change MUST add `tests/fixtures/arch-principles/` with a clean and a dirty fixture per principle/anti-pattern family and new checks (T49+); the RED suite MUST run axis 3 against the fixtures and compare expected findings. Axis 3 checks SHALL remain cheap (structure, dependencies, imports) and the RED suite SHALL stay under 2 minutes. Existing checks T01–T48/T42b/T47b MUST NOT regress.

Scenarios: L1, L2, L3, L7