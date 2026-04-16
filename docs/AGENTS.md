# AGENTS.md

## Technical Brief

Target:
- macOS 15.0+
- Swift 6.2+
- strict Swift Concurrency
- terminal-first skill surfaces

Code must be:
- scoped
- current
- predictable
- testable

## Product Scope

Primary scope:
- skill-first agent execution model
- signal extraction and scope resolution
- memory optimization for smaller context windows
- bounded prompt/package construction
- carry-forward state for iterative turns
- terminal and engine tooling surfaces

Secondary scope (optional):
- lightweight local inspector surfaces for debugging

Out of scope for this repository:
- full premium macOS operator app surface
- workspace/project management UX as a product
- broad UI polish tracks

Do not collapse the boundary.
The repository is a skill and core runtime project.

## Product Surfaces

- task + intent input contract
- approved-root scope discovery
- keep/defer/drop memory output
- bounded prompt output
- carry-forward state output per iteration
- terminal execution surface

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
- modeling deterministic transformations
- async/await and structured concurrency in runtime code
- choosing modern Apple APIs over legacy patterns
- writing small, composable types and focused functions

Skill workflows:
- turning noisy input into bounded signal
- defining and enforcing scope before execution
- refreshing context from results instead of stale assumptions
- persisting only the state that should carry into the next iteration
- making small-context models behave more reliably

## Architecture

Prefer feature ownership over file-type grouping.

```text
Core/
  SignalExtraction/
  ScopeResolution/
  PromptCompilation/
  AgentRuntime/
  Persistence/

SkillCLI/

docs/
```

Rules:
- keep skill logic in `Core/SignalExtraction` + `Core/ScopeResolution`
- keep prompt assembly focused and explicit
- introduce shared code only after a second concrete use
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

Use APIs such as `URL.documentsDirectory` and `appending(path:)`.

## State

Preferred:
- explicit value types for skill input/output contracts
- deterministic scoring and ordering logic
- stable formatting for carry-forward output

Avoid:
- implicit global state
- hidden heuristics with non-deterministic ordering

## Persistence

- persist only data that survives refresh
- separate durable project state from transient execution state
- derive refreshed signal from resulting artifacts
- keep carry-forward state explicit

Avoid:
- raw context dumps
- storing transient state as resumable state
- persisting data that should be recomputed during refresh

## Tests And Validation

Required coverage:
- signal extraction
- scope resolution
- prompt budgeting and keep/defer/drop behavior
- persistence and reload
- carry-forward state transitions
- business logic and transformations

Prefer unit tests for logic and state transitions.

Validate with SwiftPM when applicable:
- build
- test
- warnings

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
- prompt
- resulting state

Avoid:
- manager
- handler
- data

## Security

- never include secrets
- use secure storage where required
- treat task content as intentional user data

## Commits

Use:
- `feat:`
- `fix:`
- `refactor:`
- `test:`
- `docs:`
- `chore:`

Commit subjects must be lowercase after the prefix and describe the actual change.
