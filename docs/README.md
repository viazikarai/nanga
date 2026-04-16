# Nanga

Internal working note. Not for external publication without explicit approval.

## What This Project Is

Nanga is a skill-first memory optimizer for agent runs.

The skill is agent-agnostic: it can be used with Codex, Claude Code, Cursor, local models, or any other runtime that accepts structured prompt/context input.

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

## What Works Today

- deterministic task + intent parsing into structured signal
- deterministic file discovery and ranking from an approved root
- bounded scope selection
- keep/deferred/drop memory partitioning under a token budget
- compact prompt compilation for next-turn handoff
- installable CLI surface as `context-anchor`
- agent-agnostic usage across supported agent runtimes
- passing SwiftPM test coverage for discovery and budget behavior

## What Is Next

- stronger artifact-derived refresh from real execution outputs
- better token estimate calibration per model family
- structured export formats for easier toolchain integration
- richer confidence/scoring metadata for keep/deferred items

## Install In Your Project

Use one of these paths.

### Option A: swift install (submodule in your project)

```bash
cd /path/to/your-project
git submodule add https://github.com/viazikarai/nanga.git tools/context-anchor
cd tools/context-anchor
swift build -c release --product context-anchor
```

Run it from your project root:

```bash
tools/context-anchor/.build/release/context-anchor \
  --root "$PWD" \
  --task "improve context handoff" \
  --intent "keep constraints and scoped files, defer weak notes"
```

### Option B: install globally on your machine

```bash
git clone https://github.com/viazikarai/nanga.git
cd nanga
swift build -c release --product context-anchor
install -m 0755 .build/release/context-anchor /usr/local/bin/context-anchor
```

Then run from any project:

```bash
context-anchor \
  --root /path/to/your-project \
  --task "improve context handoff" \
  --intent "keep constraints and scoped files, defer weak notes"
```

### Option C: npm global install

```bash
npm install -g context-anchor
```

Then run from any project:

```bash
context-anchor \
  --root /path/to/your-project \
  --task "improve context handoff" \
  --intent "keep constraints and scoped files, defer weak notes"
```

Important right now:
- npm install currently builds from source during `postinstall`
- users still need a working Swift toolchain installed

## Repository Boundaries

This repository now prioritizes:
- core skill logic
- scope and signal derivation
- prompt budgeting
- carry-forward state
- terminal/engine usage

The macOS app surface was intentionally removed in this branch to keep this repository skill-first.

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
