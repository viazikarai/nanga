# STUDY

Updated: 2026-04-16

Legend:
- [x] Studied in this project
- [ ] Next to study deeply

## Swift

- [x] Modeling app state with explicit data flow using focused value types.
- [x] Observation with `@Observable` and UI isolation with `@MainActor`.
- [x] Async/await orchestration for connect, run, and refresh flows.
- [x] Structured concurrency (`async let`) for concurrent process output collection.
- [x] Protocol-oriented runtime abstraction (`AgentRuntime`, registry, runtime adapters).
- [x] Error propagation via typed `LocalizedError` and runtime failure surfaces.
- [x] Modern URL and File APIs (`URL.applicationSupportDirectory`, `appending(path:)`).
- [x] Deterministic transformation logic for scoring and selecting scoped files.
- [x] Persistence minimization patterns (`minimizedForPersistence()` snapshots).
- [ ] Move long-running discovery/persistence work to dedicated actor boundaries.

## SwiftUI

- [x] Feature-oriented UI ownership under `Features/RunLoop`.
- [x] Environment-driven app model integration with `@Environment(NangaAppModel.self)`.
- [x] State and input coordination with `@State`, `@FocusState`, `@AppStorage`.
- [x] Semantic interaction patterns with `Button`-first controls.
- [x] Conditional rendering from explicit runtime/task/scope state.
- [x] Panelized macOS layout with readable sections for signal, scope, and output.
- [x] State-driven motion for selection/runtime transitions.
- [ ] Further decomposition of large run-loop view bodies into smaller subviews.

## Agentic Workflows

- [x] Signal-first execution framing.
- [x] Defining scope before execution using approved folder boundaries.
- [x] Building bounded execution packages from task, signal, files, and constraints.
- [x] Runtime capability detection (`installed`, `login required`, `available`, `connected`).
- [x] Session continuity through attach/relink and `thread_id` handling.
- [x] Human-in-loop gating with explicit login verify and attach/run steps.
- [x] Refreshing carry-forward state after execution.
- [x] Maintaining open execution model boundaries across runtime adapters.
- [ ] Stronger artifact-derived signal refresh beyond text result summaries.

## macOS Development

- [x] Security-scoped project folder access and bookmark refresh.
- [x] Folder import with `fileImporter` for user-approved scope.
- [x] CLI process integration with `Process` and `Pipe`.
- [x] AppleScript bridge to Terminal for assisted login flow.
- [x] Handling app-vs-shell environment differences (`PATH`, `HOME`) for CLI execution.
- [x] Local persistence in Application Support using JSON.
- [x] Resizable macOS panel UX with persistent project/workspace state.
- [ ] Release hardening for signing/distribution workflow.

## Testing And Quality

- [x] Unit tests for persistence round-trip and state transitions.
- [x] Unit tests for scope resolution relevance and deterministic fallback behavior.
- [x] Unit tests for run success/failure and carry-forward behavior.
- [x] Runtime gating tests for login-required execution blocking.
- [x] Project compliance checks with `agents_stat` and `architecture_stat` scripts.
- [ ] Dedicated tests for Codex login parser edge cases.
- [ ] UI tests for login verify -> attach -> run end-to-end flow.

## Immediate Study Queue

1. Write focused tests for login status parsing and environment setup.
2. Split run-loop UI into smaller feature-owned views without behavior regressions.
3. Add UI tests for the human-loop execution journey.
