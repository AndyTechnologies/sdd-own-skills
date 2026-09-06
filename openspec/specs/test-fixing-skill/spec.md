# Test Fixing Skill Specification

## Purpose

Spec for the curated `test-fixing` skill (RFC goal 1, AC 6/8), adapted from the Apache-2.0 marketplace plugin to repo conventions and stack-neutral guidance.

## Requirements

### Requirement: Adapted and attributed content

The skill SHALL be adapted from `mhattingpete/claude-skills-marketplace` `engineering-workflow-plugin/skills/test-fixing/` (Apache-2.0) into `skills/test-fixing/SKILL.md`, keeping Apache-2.0 attribution and the repo's conventional frontmatter. The adaptation SHALL rewrite pytest/`uv run pytest`-specific guidance into stack-neutral terms: command examples are allowed, but no mandatory pytest/uv dependency.

#### Scenario: Curated deploy

- GIVEN `skills/test-fixing/SKILL.md` adapted and attributed
- WHEN `sync-skills.sh` step 1 runs
- THEN the skill is installed, symlinked, and registered

#### Scenario: Stack neutrality

- GIVEN upstream content hard-codes `pytest` and `uv run pytest`
- WHEN curated
- THEN the workflow describes commands generically
- AND pytest is presented as one example, not a requirement

### Requirement: Trigger

The description SHALL trigger on failing tests with the loop: red test -> diagnosis -> patch -> re-run. It SHALL NOT cover test authoring or coverage policy.

#### Scenario: Red test matched

- GIVEN a task "fix the failing controller test"
- WHEN matched
- THEN `test-fixing` triggers the diagnosis-to-patch loop

#### Scenario: Authoring excluded

- GIVEN a task "write tests for the new module"
- WHEN matched
- THEN `test-fixing` does not claim it; test authoring stays with the requesting work