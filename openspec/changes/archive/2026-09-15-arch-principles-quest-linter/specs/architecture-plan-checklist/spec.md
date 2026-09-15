# Delta Spec: Architecture Plan Checklist

## Needs

Non-verifiable principles have no home in the architecture-plan acta: nothing forces the plan to declare per-principle applicability or direction evidence, so applicability drifts silently. The change makes a checklist mandatory in arch-plan.md at a fixed canonical title, with a fail-closed gate when the section is missing.

## Scenarios

#### Scenario: C1 · Section present
- GIVEN an arch-plan.md acta produced after the change
- THEN it contains a section titled `## Principios no verificables` with a table per principle

#### Scenario: C2 · Missing title fail-closed
- GIVEN an acta without that title
- WHEN axis 2 runs
- THEN axis 2 FAILs (incomplete acta)

#### Scenario: C3 · Applicable with evidence
- GIVEN a principle applicable to the change
- THEN the acta records it as applicable with direction evidence

#### Scenario: C4 · N/A justified
- GIVEN a principle not applicable to the change
- THEN the acta declares it N-A justified rather than omitting it

#### Scenario: C5 · N/A unjustified
- GIVEN an N/A row without justification
- THEN axis 2 emits a warning finding requiring the justification

#### Scenario: C6 · No applicable principles
- GIVEN a change with no applicable principles
- THEN the section still exists with N-A justified rows, never omitted

#### Scenario: C7 · Evidence contradicted
- GIVEN direction evidence declared for an applicable principle and contradicted by the implementation
- THEN axis 2 flags the unmet mandate and axis 3 blocks it (dual signal)

## Capabilities

### Added Capability: Architecture Plan Checklist

### Requirement: Mandatory Anchored Section

The arch-plan.md acta MUST include a mandatory section at the fixed canonical title `## Principios no verificables`, formatted as a table per principle. A missing title MUST fail axis 2 closed. The checklist SHALL live inside arch-plan.md (not a separate file), keeping the acta walkable title-by-title.

Scenarios: C1, C2

### Requirement: Per-Principle Applicability Declaration

The checklist MUST declare, per principle, exactly one state: applicable | direction evidence | N-A justified. An applicable principle SHALL carry direction evidence. N/A MUST be accompanied by a justification; N/A without justification SHALL produce a warning finding in axis 2. A change with no applicable principles MUST still include the section with N-A justified declarations rather than omitting it.

Scenarios: C3, C4, C5, C6

### Requirement: Dual Signal on Contradicted Evidence

When an applicable principle's direction evidence is contradicted by the implementation, the lint MUST emit the dual signal: axis 2 flags the unmet mandate and axis 3 blocks the violation.

Scenarios: C7