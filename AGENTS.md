# AGENTS.md

## Technical Brief

Target:
- macOS 15.0+
- Swift 6.2+
- strict Swift Concurrency
- SwiftUI unless a lower-level Apple framework is required

Code must be:
- scoped
- current
- predictable
- testable

## Product Scope

Open-source scope:
- scoped agent execution model
- signal and scope model
- architecture and runtime design
- core implementation
- basic execution surfaces such as CLI or engine tooling

Paid macOS app scope:
- project and workspace management
- task input
- signal and scope panels
- run and refresh UI
- saved iteration state
- exports
- integrated agent workflows
- macOS-native UX, performance, and polish

Do not collapse the boundary.
The repository exposes the model and core parts.
The macOS app is the full operator surface.

## Product Surfaces

- project creation and opening
- task input
- signal display
- scope display
- run
- refresh after execution
- saved iteration state per project

## Agent Constraints

- start from the current task
- inspect only the required code
- stay inside the active feature or runtime surface
- avoid unrelated edits
- keep diffs small when the problem is local
- explain the final result precisely

## Learning Goals

The agent should use this project to teach:

Swift:
- modeling app state with explicit data flow
- using async/await and structured concurrency in product code
- choosing modern Apple APIs over legacy patterns
- writing small, composable types and focused functions

SwiftUI:
- structuring feature-oriented views, state, and models
- keeping logic out of views without over-abstracting
- building macOS-native interfaces that stay clear across window sizes
- deciding when to split, simplify, or keep a view intact

Agentic workflows:
- turning signal into bounded execution
- defining scope before execution
- refreshing context from results instead of stale assumptions
- persisting only the state that should carry into the next iteration
- separating an open execution model from a paid product surface

## Architecture

Prefer feature ownership over file-type grouping.

```text
Features/
  ProjectSelection/
  TaskInput/
  SignalPanel/
  ScopePanel/
  RunLoop/
  IterationHistory/

Core/
  Persistence/
  AgentRuntime/
  SignalExtraction/
  ScopeResolution/

DesignSystem/
  Components/
  Styles/
```

Rules:
- keep feature logic with the UI and state it serves
- introduce shared code only after a second concrete use
- do not move code into `Core` or `DesignSystem` early
- do not create generic shared folders

## Swift

Required:
- async/await where modern APIs exist
- structured concurrency
- Swift-native APIs over legacy Foundation patterns
- explicit data flow
- focused functions
- one primary type per file when practical

Forbidden:
- force unwraps
- `try!`

Prefer:

```swift
Text(value, format: .number.precision(.fractionLength(2)))
```

Avoid:

```swift
String(format: "%.2f", value)
```

Use APIs such as `URL.documentsDirectory` and `appending(path:)`.

## SwiftUI

Required:
- `NavigationStack`
- `navigationDestination(for:)`
- semantic controls such as `Button`
- readable view bodies

Avoid:
- `onTapGesture` when a semantic control is available
- `GeometryReader` unless layout depends on geometry
- `AnyView`
- business logic in views
- oversized views mixing layout, state transitions, and orchestration

For macOS:
- support resizable layouts
- keep panel surfaces readable at narrow and wide widths
- prefer native macOS interaction patterns

## State

Preferred:
- `@Observable`
- `@MainActor` on UI-facing observable types unless a different isolation boundary is required
- `@State`
- `@Bindable`
- `@Environment`

Do not introduce:
- `ObservableObject`
- `@Published`
- `@StateObject`
- `@ObservedObject`
- `@EnvironmentObject`

## Persistence

- persist only data that survives refresh
- separate durable project state from transient execution state
- derive refreshed signal from resulting artifacts
- keep carry-forward state explicit

Avoid:
- raw context dumps
- storing transient state as resumable state
- persisting data that should be recomputed during refresh

SwiftData with CloudKit:
- no `@Attribute(.unique)`
- all properties must have default values or be optional
- all relationships must be optional

## Tests And Validation

Required coverage:
- signal extraction
- scope resolution
- persistence and reload
- carry-forward state transitions
- business logic and transformations

Prefer unit tests for logic and state transitions.
Add UI tests when run, refresh, and resume behavior depends on UI coordination.

Validate with Xcode when applicable:
- build
- warnings
- previews for UI work
- macOS interaction checks for panel, navigation, and persistence changes

## Naming And Quality

- keep files focused
- avoid duplication
- keep state transitions easy to trace
- comment only when recovering non-obvious logic

Prefer:
- signal
- scope
- iteration
- refresh
- project state
- resulting state

Avoid:
- manager
- handler
- data

## Security

- never include secrets
- use secure storage where required
- treat project state and task content as intentional user data

## Commits

Use:
- `feat:`
- `fix:`
- `refactor:`
- `test:`
- `docs:`
- `chore:`

Commit subjects must be lowercase after the prefix and describe the actual change.
