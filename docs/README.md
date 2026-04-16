# Nanga

Internal working note. Not for external publication without explicit approval.

## What This Project Is

Nanga is a skill-first memory optimizer for agent runs.

The goal is simple:
- take a task and intent
- scan only an approved root
- extract high-value signal
- keep scope bounded
- output a compact prompt for smaller context windows

Nanga helps local and low-context models keep decision-critical memory instead of carrying noisy transcripts.

## Primary Workflow

1. Provide task title and execution intent.
2. Provide an approved project root.
3. Optionally provide previous scope files and recent notes.
4. Run the optimizer.
5. Receive:
   - bounded signal
   - ranked candidates
   - selected scope files
   - keep/defer/drop memory buckets
   - compact next-turn prompt

## Skill Surface

The terminal surface is now first-class:

```bash
swift run context-anchor \
  --root /path/to/repo \
  --task "improve memory budget" \
  --intent "keep constraints and scoped files, defer weaker notes" \
  --note "avoid transcript bloat" \
  --token-budget 300
```

Output is deterministic and human-auditable.

## Repository Boundaries

This repository now prioritizes:
- core skill logic
- scope and signal derivation
- prompt budgeting
- carry-forward state
- terminal/engine usage

The old macOS app code may remain as a local harness, but it is not the primary product direction.

## Privacy And Data Minimization

Nanga should store only the minimum structured context needed.

It should not:
- collect unrelated user data
- add analytics or telemetry
- add remote logging
- scan beyond user-approved files or folders

Preferred persistence model:
- structured summaries over raw dumps
- selected paths over broad file snapshots
- explicit carry-forward state over full transcripts

## Main Files

- [nanga/Core/SignalExtraction/SkillMemoryOptimizer.swift](../nanga/Core/SignalExtraction/SkillMemoryOptimizer.swift)
  deterministic keep/defer/drop pipeline.
- [nanga/Core/SignalExtraction/SkillMemoryInput.swift](../nanga/Core/SignalExtraction/SkillMemoryInput.swift)
  skill input contract.
- [nanga/Core/SignalExtraction/SkillMemoryOutput.swift](../nanga/Core/SignalExtraction/SkillMemoryOutput.swift)
  skill output contract.
- [nanga/Core/ScopeResolution/FileDiscoveryService.swift](../nanga/Core/ScopeResolution/FileDiscoveryService.swift)
  deterministic file discovery and scoring.
- [SkillCLI/main.swift](../SkillCLI/main.swift)
  terminal entrypoint.

## Current Status

Implemented:
- deterministic signal extraction from task + scope
- deterministic scope candidate ranking
- bounded keep/defer/drop memory partitioning
- compact next-turn prompt generation
- CLI invocation surface
- unit coverage for scope, run-loop behavior, and skill budgeting

Still to do:
- stronger artifact-derived signal refresh
- better token estimation calibration by model family
- richer export formats for toolchains and plugin integration
