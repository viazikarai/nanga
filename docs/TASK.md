# Task Backlog

## Milestone Focus

make nanga the default memory optimizer skill for smaller context windows:

`task -> signal -> scope -> keep/defer/drop -> compact prompt`

## Completed Foundation

- [x] deterministic task-to-signal shaping
- [x] deterministic scope discovery with explicit reasons
- [x] auto-selection of top-signal files
- [x] bounded execution package construction
- [x] keep/defer/drop memory partitioning with token budget
- [x] terminal skill surface (`nanga-skill`)
- [x] unit coverage for scope and run-loop state transitions
- [x] unit coverage for skill budgeting behavior

## P0 Next Tasks

- [ ] calibrate token estimator against real model tokenizers
- [ ] add json output mode for tool-chain integration
- [ ] add explicit confidence scoring for each keep/defer item
- [ ] add stronger note normalization for long noisy logs
- [ ] add regression fixtures for small-context failure cases

## P1 Follow-Up Tasks

- [ ] add plugin-ready schema docs for codex/claude/cursor workflows
- [ ] add reproducibility snapshot tests for compact prompt output
- [ ] add artifact-first refresh mode to reduce stale carry-forward state
- [ ] add benchmark script for success rate at 4k/8k context budgets

## P2 Expansion Tasks

- [ ] model-family profiles (aggressive, balanced, conservative memory)
- [ ] optional minimal local inspector surface for debugging only
- [ ] lightweight export bundle for handoff and audit trails

## Definition Of Done (Current Milestone)

- [ ] same input always yields the same keep/defer/drop ordering
- [ ] compact prompt stays within configured budget envelope
- [ ] skill output is understandable without opening source code
- [ ] 4k-context runs show lower failure from forgotten constraints
