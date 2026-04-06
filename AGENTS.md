# AGENTS.md

## Overview

Nanga is a macOS app for agent workflows.

Its purpose is to keep each iteration anchored by extracting live signal from the current task, selecting only the working context that still matters, executing inside the correct scope, then refreshing and saving updated context for the next iteration.

This repository is built with Swift, SwiftUI, and modern Apple frameworks. It is intended for agent-driven development, which means this file is both:

- a product contract for how Nanga should behave
- an engineering contract for how agents should build it

All code written in this repository must be:

- scoped
- technically current
- predictable
- testable
- aligned with Nanga's product loop

## Product Intent

Nanga exists to prevent drift in agent workflows.

It should:

- reduce repeated context dumping
- keep execution constrained to the relevant surface
- preserve momentum across iterations
- carry forward only context that still matters
- make scope visible before execution
- make resulting state legible after execution
- feel frictionless for developers

If a product or implementation decision adds ceremony, stale state, or broad unexplained scope, it is probably wrong.

## Model-Specific Operating Contract

You are not a generic coding assistant in this repository.

You are an implementation agent building a product whose core function is scoped execution across iterations. Your own working style must reflect the product.

You must:

- start from the current task, not from the whole repository
- identify the minimum relevant context before changing code
- keep reasoning bounded to the feature, files, and state relevant to the task
- make changes that strengthen scope clarity, signal quality, refresh correctness, or iteration continuity
- avoid carrying forward irrelevant context from previous work

You must not:

- widen scope without a concrete technical reason
- explore unrelated parts of the codebase by default
- preserve stale assumptions across iterations
- introduce abstractions that make the active task harder to see
- optimize for generic tooling if it weakens Nanga's core loop

The product is about controlled execution. Your behavior in the repo must demonstrate controlled execution.

## Nanga Iteration Contract

Every meaningful task should follow this sequence:

1. identify the current task intent
2. identify the minimum signal required to act
3. define the active scope: feature, files, state, dependencies, and UI surfaces in play
4. execute only within that scope unless a shared dependency requires expansion
5. inspect the resulting state
6. refresh understanding from what changed, not from old assumptions
7. preserve only validated context that should influence the next iteration

For implementation work, this means:

- do not scan the entire codebase if the task is feature-local
- do not modify unrelated files because they are nearby
- do not carry historical context forward unless it still affects the current task
- do not infer broad architectural intent from isolated files without evidence

## Signal vs Noise

Signal is the minimum context required to make the next correct decision.

Signal includes:

- current task intent
- relevant feature files
- active constraints
- recent decisions that still affect the task
- changed artifacts
- unfinished work
- dependencies directly affecting the current change
- scoped repository context

Noise is context that does not improve the next decision.

Noise includes:

- stale context
- unrelated features
- old logs
- irrelevant history
- broad repository exploration without task value
- unused code paths
- changed files that do not affect the active iteration

Only signal should influence decisions.

## Developer Experience Standard

Nanga must feel frictionless for developers.

That means the product should be:

- fast to start
- obvious to operate
- low-ceremony
- predictable before execution
- inspectable during execution
- trustworthy after execution
- easy to resume without reconstructing context manually

When building features, prefer flows that:

- remove repeated setup
- reduce manual context assembly
- avoid unnecessary confirmations
- make scope visible before an agent runs
- make refreshed state easy to understand after an agent runs
- preserve momentum for the next iteration

Avoid workflows that force developers to restate the same task context every iteration.

## Platform and Language Requirements

- Target: macOS 15.0+
- Language: Swift 6.2+
- Concurrency: Strict Swift Concurrency enforced
- UI Framework: SwiftUI unless a lower-level Apple framework is required

Prefer modern Swift across the entire codebase. New code should reflect current language, concurrency, observation, formatting, and API design practices rather than legacy Apple-platform patterns.

You must always:
- use async/await instead of closure-based APIs where a modern async API exists
- prefer structured concurrency over ad hoc task coordination
- prefer Swift-native APIs over legacy Foundation patterns where applicable
- avoid introducing third-party dependencies without approval

You should avoid:

- `DispatchQueue` for new app-level concurrency flows unless interoperating with an API that requires it
- callback-first designs when async alternatives are available
- legacy observation and view lifecycle patterns when modern SwiftUI equivalents exist

## Architecture

The architecture must serve scoped execution, not abstract purity.

Default structure should be feature-oriented, with each feature owning the code required to implement its behavior. Shared code should exist only when there is a real cross-feature need.

Preferred structure:

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

- prefer organizing by feature over organizing globally by file type
- keep feature logic close to the UI and state it supports
- introduce shared modules only when at least two features need the same behavior
- do not move code into `Core` or `DesignSystem` prematurely
- do not create generic shared folders that become dumping grounds

Each feature should ideally own:

- view code
- state and observation
- feature-specific models
- feature-local services or coordinators when needed

Shared code must remain reusable and must not encode feature-specific assumptions.

## Product Surfaces

The MVP product surfaces are:

- project creation and project opening
- task input
- signal display
- scope display
- run action
- refresh after execution
- saved iteration state per project

Changes should strengthen one of these surfaces or a supporting runtime behind them.

If a proposed abstraction does not improve one of these surfaces or the underlying scoped execution loop, justify it before introducing it.

## Execution Scope Rule

All work must remain scoped to the current task.

You must:

- identify the correct feature or runtime surface before making changes
- operate only within that feature or runtime surface unless shared logic is actually required
- include only relevant files in reasoning
- explain scope expansion when it is not obvious
- leave unrelated files untouched

You must not:

- explore the entire repository by default
- modify files outside the active scope because they look related
- use broad refactors to solve local problems
- pull unrelated context into the current iteration

Each iteration must operate on signal, not noise.

## State Management

Use modern Swift observation patterns.

Preferred:

- `@Observable` for owned mutable state
- `@MainActor` on observable UI-facing types unless a non-main isolation boundary is justified
- `@State` for view-owned state
- `@Bindable` for editable observable state passed into views
- `@Environment` for stable environment dependencies

Avoid introducing for new code:

- `ObservableObject`
- `@Published`
- `@StateObject`
- `@ObservedObject`
- `@EnvironmentObject`

Legacy patterns should not be introduced unless an existing subsystem already depends on them and replacing them would increase risk.

## Persistence and Refresh

Because Nanga is an iteration product, persistence and refresh behavior are core product logic, not implementation detail.

When working on iteration state:

- model saved state so the next iteration can resume without reconstructing context manually
- persist only information that is still useful after refresh
- separate durable state from ephemeral execution state
- ensure refresh derives updated signal from resulting artifacts, not from stale pre-run assumptions
- make it clear what changed, what stayed in scope, and what should carry forward

Avoid:

- saving raw context dumps when a structured representation is possible
- preserving intermediate state that the next iteration cannot trust
- blurring temporary runtime state with resumable project state

## Swift Rules

Modern Swift rules apply.

- avoid force unwraps and `try!`
- prefer value types where appropriate
- keep functions focused and composable
- prefer one primary type per file
- use modern formatting and parsing APIs
- prefer explicit data flow over hidden mutation
- model invalid states out of existence where practical

Formatting example:

Use:

```swift
Text(value, format: .number.precision(.fractionLength(2)))
```

Do not use:

```swift
String(format: "%.2f", value)
```

Use modern Foundation APIs such as `URL.documentsDirectory` and `appending(path:)` where appropriate.

## SwiftUI Rules

Navigation:

- use `NavigationStack`
- use `navigationDestination(for:)`

UI behavior:

- use `Button` instead of gesture recognizers where possible
- avoid `onTapGesture` when semantic controls are more correct
- avoid `GeometryReader` unless layout actually depends on parent geometry
- avoid `AnyView`

Structure:

- keep business logic out of views
- extract subviews when it improves readability or reuse
- keep view bodies legible
- avoid oversized view structs that mix layout, state transitions, and effect orchestration

Styling:

- use `foregroundStyle()`
- use `clipShape(.rect(cornerRadius:))`
- avoid arbitrary hard-coded layout constants without a UI reason

Accessibility:

- respect Dynamic Type where applicable
- avoid fixed font sizes unless the visual treatment truly requires one
- maintain semantic labels and control roles

For macOS specifically:

- respect multi-window and resizable layout behavior where relevant
- design panels and inspector-style surfaces to remain clear in narrow and wide layouts
- prefer native macOS interaction patterns over transplanted iOS assumptions

## Feature Implementation Rules

When implementing a task:

1. identify the feature or runtime surface first
2. inspect only the files needed to understand the task
3. follow the local structure already present
4. update the smallest complete set of components needed
5. verify that the resulting change still matches product intent

Typical components may include:

- UI
- state
- logic
- models
- persistence
- tests

Do not introduce new architectural patterns without clear justification tied to the product loop.

## Testing

Testing is required for durable logic.

You must test:

- signal extraction logic
- scope resolution logic
- persistence and reload behavior
- state transitions that determine what carries forward
- business logic and transformations

You should prefer unit tests for:

- pure logic
- reducers, coordinators, or state transitions
- model transformations
- persistence boundaries

UI tests should be added when:

- a workflow depends on multiple UI surfaces coordinating correctly
- the risk is interaction-level rather than logic-level
- the run/refresh/resume loop cannot be trusted from unit coverage alone

Avoid writing tests that merely restate implementation details.

## SwiftData Rules

If SwiftData is used with CloudKit:

- do not use `@Attribute(.unique)`
- all properties must have default values or be optional
- all relationships must be optional

If SwiftData is used for iteration persistence:

- keep model boundaries explicit
- distinguish resumable project state from transient execution state
- avoid storing data that should be recomputed during refresh

## Xcode and Tooling

Use Xcode tooling to validate work whenever available.

Preferred validation steps:

- build the project after meaningful changes
- inspect warnings and navigator issues
- review previews when UI changes are involved
- verify macOS-specific interactions when changing panels, navigation, or persistence flows

Do not treat a local code edit as complete until the relevant validation path has been checked.

## Agent Communication Requirements

Agents must always explain what they did after completing meaningful work.

Every implementation response should include, at minimum:

- what changed
- why the change was made
- which files or product surfaces were affected
- how the change fits Nanga's signal, scope, refresh, or iteration model
- what validation was performed
- any remaining risks, assumptions, or unverified areas

When work is partial or blocked, say so explicitly.

Do not:

- present code changes without explanation
- claim validation that was not actually performed
- hide uncertainty behind vague summaries
- omit scope changes or side effects

The explanation should be technically specific. It should help the user understand both the code change and the product implication of the change.

## Commit Message Rules

Use concise conventional commit prefixes.

Preferred prefixes:

- `feat:` for new product behavior or user-visible capability
- `fix:` for bug fixes
- `refactor:` for structural code changes without intended behavior change
- `test:` for adding or updating tests
- `docs:` for documentation changes
- `chore:` for tooling, maintenance, or project configuration

Commit messages should:

- be lowercase after the prefix
- describe the actual change, not vague activity
- reflect Nanga's product language when relevant
- stay short enough to scan quickly

Prefer:

- `feat: build initial nanga iteration shell`
- `feat: add task signal and scope surfaces`
- `fix: correct saved iteration state rendering`
- `test: cover carry-forward iteration summary`

Avoid:

- vague messages such as `feat: stuff`
- overly broad summaries that hide the actual change
- commit subjects written like status updates instead of code history

## Code Quality

- keep code readable and maintainable
- maintain consistent naming with product concepts
- avoid duplication
- add comments only where they improve recoverability of non-obvious logic
- keep files focused
- make state transitions easy to trace
- make scope boundaries obvious in code, not just in UI copy

Prefer names aligned with the product:

- signal
- scope
- iteration
- refresh
- project state
- resulting state

Avoid vague names like `manager`, `handler`, or `data` when a more specific model exists.

## Security

- never include secrets in code
- use secure storage where required
- avoid exposing sensitive data
- treat project state and task content as user data that should be persisted intentionally

## Decision Filter

Before shipping a change, ask:

1. Does this help the agent stay anchored to the current iteration?
2. Does this improve signal quality or scope clarity?
3. Does this reduce noise or repeated context dumping?
4. Does this preserve momentum into the next iteration?
5. Does this reduce developer friction rather than add ceremony?
6. Is the added complexity justified by the product loop?
7. Does the implementation follow modern Swift and SwiftUI practice?

If the answer to most of these is no, the change is likely off-track.

## Final Rule

Only carry forward what still matters.

Do not accumulate stale context.
Do not expand scope without reason.
Stay precise.
Stay scoped.
Stay technically current.
