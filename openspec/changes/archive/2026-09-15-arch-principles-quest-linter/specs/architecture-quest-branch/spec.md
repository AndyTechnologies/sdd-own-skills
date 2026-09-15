# Delta Spec: Architecture Quest Branch

## Needs

The architecture branch of the SDD Quest interviews without context selection and burns its budget on principle-by-principle questions. The change reworks it into context-driven selection — 8 base context questions, a declarative branch table, early-stop, and a stack trigger — inside the FIXED budget of 20, with explicit gap classification. The catalog feeds branching; it never drives interviews.

## Scenarios

#### Scenario: A1 · Base questions first
- GIVEN the architecture branch starts
- THEN it asks the 8 base context questions and never interviews principle-by-principle

#### Scenario: A2 · Branch follows the table
- GIVEN a context matching a branch's declared trigger
- WHEN the orchestrator walks the branch table
- THEN only that branch's questions are asked

#### Scenario: A3 · Non-matching branch skipped
- GIVEN a change with no microservices context
- THEN no microservices-branch question is asked

#### Scenario: A4 · Stack trigger yes
- GIVEN the stack base question is answered "yes"
- THEN the technology branch is enabled

#### Scenario: A5 · Stack trigger no
- GIVEN the stack base question is answered "no"
- THEN the technology branch is skipped and the language-agnostic default is preserved

#### Scenario: A6 · Early-stop within budget
- GIVEN all triggered branches resolve before question 20
- THEN the interview stops early within budget

#### Scenario: A7 · Budget exhaustion
- GIVEN 20 questions asked with branches still unresolved
- THEN a consolidation report with classified gaps is produced, never a silent extension

#### Scenario: A8 · Gap classified
- GIVEN an early-stop gap
- THEN it classifies as exactly one of decision (targeted question outside the questionnaire), knowledge (research lane), or blocking (RFC Unresolved Questions)

#### Scenario: A9 · Ambiguous trigger
- GIVEN a context matching two branches
- THEN the orchestrator applies the precedence declared in the table; a real conflict becomes a decision gap

#### Scenario: A10 · Stack-only driver
- GIVEN stack confirmed but no technology branch applies
- THEN the driver is recorded and the branch early-stops with no questions

## Capabilities

### Added Capability: Architecture Quest Branch Rework

### Requirement: Eight Base Context Questions

The architecture branch MUST begin with 8 base context questions, including the stack/technology base question. The interview MUST NOT ask principle-by-principle.

Scenarios: A1

### Requirement: Declarative Branch Table

The sdd-quest skill MUST codify branching as a declarative table; each branch MUST declare its trigger, the principles/anti-patterns it loads, its branch questions, and its early-stop condition. The orchestrator SHALL walk the table as the ONLY source of question selection; implicit prose branches SHALL NOT exist, and no scripted state machine SHALL replace the table. Triggers SHALL have declared precedence for ambiguous contexts.

Scenarios: A2, A3, A9

### Requirement: Catalog Feeds Branching

Each branch SHALL load the applicable principles/anti-patterns from the shared catalog by path. Applicability validation MUST occur in the plan with justified N/A, never during the interview.

Scenarios: A2

### Requirement: Stack Trigger

One of the 8 base questions MUST ask whether stack/technology drives the change. "Yes" MUST enable the technology branch; "No" MUST skip it, preserving the default language-agnostic stance. A stack-confirmed context with no applicable technology branch MUST record the driver and early-stop the branch without questions.

Scenarios: A4, A5, A10

### Requirement: Fixed Budget and Early-Stop

The architecture branch MUST enforce a hard budget of 20 questions; the budget MUST NOT be raised. Early-stop MUST trigger when all triggered branches resolve within budget. Budget exhaustion MUST produce a consolidation report with classified gaps, never a silent extension.

Scenarios: A6, A7, A8

### Requirement: Explicit Gap Classification

Every early-stop gap MUST classify into exactly one of: decision gap (targeted question outside the questionnaire), knowledge gap (research lane), or blocking gap (Unresolved Questions in the RFC). No gap MAY disappear silently.

Scenarios: A7, A8, A9

### Requirement: Product Quest Untouched

The change MUST NOT alter the Product Quest: its budget of 50 and its current structure remain unchanged, and existing Product Quest checks keep passing.

Scenarios: A1, A2 (Product Quest behavior unchanged; regression covered by the existing suite)