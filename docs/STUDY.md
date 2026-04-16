# STUDY

Updated: 2026-04-16

Legend:
- [x] studied in this project
- [ ] next to study deeply

## Swift

- [x] modeling deterministic input/output contracts for skill execution.
- [x] explicit scoring and sorting pipelines for stable behavior.
- [x] modern URL + file APIs for bounded local discovery.
- [x] value-driven persistence minimization patterns.
- [ ] tighter token estimation models per runtime.

## Skill Workflows

- [x] converting task text into bounded signal.
- [x] deriving scope before execution.
- [x] deterministic keep/defer/drop partitioning by budget.
- [x] compiling compact prompts for small-context turns.
- [x] preserving only carry-forward state that affects decisions.
- [ ] artifact-first refresh to reduce stale assumptions.

## Runtime Integration

- [x] runtime abstraction and capability detection patterns.
- [x] bounded prompt package handoff shape.
- [x] terminal-first invocation pattern via `nanga-skill`.
- [ ] runtime-specific schema adapters for deeper integration.

## Testing And Quality

- [x] unit tests for scope resolution relevance and fallback behavior.
- [x] unit tests for run success/failure and carry-forward behavior.
- [x] unit tests for memory-budget partition behavior.
- [ ] reproducibility fixtures for larger corpora and noisy logs.

## Immediate Study Queue

1. calibrate token estimates against real tokenizer outputs.
2. add fixture-heavy tests for noisy terminal transcript cleanup.
3. measure success delta on 4k/8k context limits.
