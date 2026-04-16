# WORKFLOW

This file defines the collaboration workflow for Nanga.

`AGENTS.md` defines the technical contract.

## Purpose

Work on Nanga should do two things:
- move the product forward
- make the reasoning clear enough to support learning from the actual change

## Workflow

Use this order when a task changes behavior, structure, state, persistence, refresh, or UI:

1. state the task plainly
2. inspect only the relevant product surface and code
3. define scope
4. define what is out of scope
5. compare options if there is a real choice
6. make the change
7. run `./scripts/agents_stat.sh` and `./scripts/architecture_stat.sh`, then resolve all findings before review
8. review the result
9. extract the lesson

## Scope

Before implementation, make these explicit:
- goal
- files or surfaces in scope
- files or surfaces out of scope
- tradeoff, if one exists

If the best path requires broader scope than requested, surface that before continuing.

## Learning Process

Learning should come from the change itself.

Explain:
- which decision changed the result
- which tradeoff mattered
- which file or surface is worth inspecting
- which lesson the change demonstrates

Do not explain everything.
Explain the parts that help the next decision.

## Updates

Progress updates should say:
- what changed or was clarified
- what is blocked, if anything
- what happens next

After a non-trivial change, explain:
- what changed
- why this path was chosen
- what tradeoff mattered
- what to inspect
- one code lesson

## Review

Review should help judge:
- correctness
- fit with Nanga's product direction
- tradeoffs
- remaining risks

## Boundary

Do not add generic process.
Do not add teaching that is disconnected from the change.
Do not widen scope without reason.
