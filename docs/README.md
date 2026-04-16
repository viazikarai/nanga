# Nanga

Internal working note. Not for GitHub publication or external sharing unless explicitly approved.

## What This Project Is

Nanga is a macOS prototype for scoped agent workflows.

The working idea is:

- select an agent surface such as `Codex`, `Claude Code`, or `Cursor`
- define the current task
- derive a bounded file scope from a user-approved folder
- build a compact execution package
- preserve only the minimum structured state needed for the next iteration

`Nanga` means anchor. The internal design goal is to keep an agent workflow anchored to the current task instead of accumulating stale context.

## Current User Flow

The app currently works like this:

1. Launch the app.
2. Select an agent on the landing screen.
3. Lock into that agent surface.
4. Open a project folder that the user explicitly chooses.
5. Enter a task title.
6. Enter execution intent/detail.
7. Run `Discover` to scan the approved folder and propose candidate files.
8. Adjust the selected scope.
9. Run the iteration.
10. Build an `ExecutionPackage` from the task, signal, and selected files.
11. Pass that package through the selected runtime adapter.
12. Persist the resulting structured iteration state locally.

Important current limitation:

- runtime selection is real
- runtime execution is still mocked
- the app does not yet perform a real Codex/Claude/Cursor execution handoff

## Intended Flow

The intended end-state is:

1. User opens an approved working folder.
2. Nanga detects which supported agent surfaces are available.
3. User selects an agent.
4. User states the task.
5. Nanga reads only the approved workspace surface.
6. Nanga derives signal and scope.
7. Nanga builds a bounded execution package.
8. The selected agent executes inside that package.
9. Nanga refreshes from the result.
10. Nanga carries forward only the state that still matters.

## Privacy And Data Minimization

This prototype should store only the minimum structured context needed for the feature.

It should not:

- collect unrelated user data
- add analytics
- add telemetry
- add remote logging
- add training capture
- add background collection
- scan beyond user-approved files or folders

Preferred persistence model:

- structured summaries over raw content
- selected file paths over broad content dumps
- compact carry-forward state over full transcripts

If raw content is ever stored, it should be tightly scoped, explicitly justified, and easy to inspect.

## What Is Currently Persisted

Current local persistence includes:

- selected project metadata
- project root bookmark/reference
- current task draft
- signal items
- selected scope files and folders
- execution summary
- saved iteration state
- iteration history snapshots
- selected agent runtime and model

This is still broader than the target minimization standard. In particular, iteration history snapshots should likely be reduced over time so the app retains less raw structured state by default.

## Tech Stack

Current implementation uses:

- `Swift`
- `SwiftUI`
- `Observation` with `@Observable`
- `async/await`
- JSON persistence on disk
- security-scoped bookmarks for user-selected folders
- local runtime adapters for supported agent surfaces

Current agent surfaces modeled in the app:

- `Codex`
- `Claude Code`
- `Cursor`

## Main Files

- [nanga/Features/RunLoop/ContentView.swift](../nanga/Features/RunLoop/ContentView.swift)
  Main macOS UI, landing flow, and locked agent workspace.
- [nanga/Features/RunLoop/NangaAppModel.swift](../nanga/Features/RunLoop/NangaAppModel.swift)
  Main app state, iteration flow, persistence wiring, and discovery orchestration.
- [nanga/Core/AgentRuntime/AgentRuntime.swift](../nanga/Core/AgentRuntime/AgentRuntime.swift)
  Runtime protocol, registry, runtime detection, and current mock execution adapters.
- [nanga/Core/Persistence/ProjectStore.swift](../nanga/Core/Persistence/ProjectStore.swift)
  Local JSON persistence for project state.
- [nanga/Core/AgentRuntime/ExecutionPackage.swift](../nanga/Core/AgentRuntime/ExecutionPackage.swift)
  Bounded execution package model.
- [nanga/Core/AgentRuntime/ExecutionPackageBuilder.swift](../nanga/Core/AgentRuntime/ExecutionPackageBuilder.swift)
  Package construction from current task, signal, and scope.

## Current Status

Implemented:

- agent selection and lock-in flow
- project folder import
- task input
- candidate file discovery
- selected scope management
- local persistence
- compact package construction
- runtime adapter selection

Not implemented yet:

- real runtime execution through Codex, Claude Code, or Cursor
- stronger scope derivation
- result-driven signal refresh from real agent artifacts
- tighter minimal-memory persistence model
- final UI direction

## Distribution Note

Do not publish this README to GitHub or treat it as public-facing product copy unless explicitly approved.
