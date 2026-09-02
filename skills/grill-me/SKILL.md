---
name: grill-me
description: "A deliberate, bounded interview to sharpen a plan or design before committing. User-invoked only — the human starts it. Never model-invoked."
disable-model-invocation: true
---

# grill-me — user-invoked grilling entry point

This is the user-facing entry point for a **bounded** grilling session. It is user-invoked only: it must never be reached automatically by a model, which is why `disable-model-invocation: true`.

## Usage

The human types `/grill-me` (or the equivalent) to start a grilling session about a plan, design, or decision. It sharpens alignment before any code is written.

## Execution

Load and follow the `grilling` skill, which owns the interview primitive:

- Call the `skill()` tool with the `grilling` skill.
- Follow its design-tree + 50-question budget discipline exactly: ask ONE focused question at a time, follow each branch to resolution, and do not drag in a stack/language/framework unless the human confirms it as a requirement.
- Produce the shared-understanding summary and pending branches, then stop for the user's explicit confirmation.

## Boundary (why this avoids the infinite loop)

`grill-me` is a **one-shot bounded session**. It never re-invokes itself, never loops, and never runs more than 50 questions in a single session. If the user wants to continue past the budget, that is a fresh session — not an extension.
