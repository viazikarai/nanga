# WORKFLOW

This file defines the collaboration workflow for Nanga.

`AGENTS.md` defines the technical contract.

## Purpose

Work on Nanga should do two things:
- improve skill output quality for small-context runs
- keep reasoning explicit and auditable

## Workflow

Use this order when a task changes behavior, scoring, scope, persistence, or prompt output:

1. state the skill behavior change plainly
2. inspect only relevant code and fixtures
3. define scope and out-of-scope explicitly
4. compare options if there is a real tradeoff
5. implement deterministic logic
6. run tests
7. run `./scripts/agents_stat.sh` and `./scripts/architecture_stat.sh`, then resolve findings
8. review output quality and edge cases
9. extract one practical lesson

## Scope

Before implementation, make these explicit:
- goal
- files in scope
- files out of scope
- tradeoff, if one exists

If the best path requires broader scope than requested, surface that before continuing.

## Learning Process

Learning should come from the change itself.

Explain:
- which decision changed the output
- which tradeoff mattered
- which file is worth inspecting next
- which lesson applies to future skill tuning

## Updates

Progress updates should say:
- what changed or was clarified
- what is blocked, if anything
- what happens next

## Review

Review should help judge:
- correctness
- fit with skill-first product direction
- tradeoffs
- remaining risks

## Boundary

Do not widen scope without reason.
Do not add disconnected process overhead.
