# Task Backlog

## Milestone Focus

Make the runtime flow undeniable and calm:

`Install -> Login -> Verify -> Attach -> Task -> Scope -> Run -> Refresh`

## Completed Foundation

- [x] Separate runtime states (`unavailable`, `available`, `connected`) and block execution when login is required.
- [x] Show runtime install state, auth state, attach state, and active thread id in the app.
- [x] Surface latest runtime events and last runtime error in the run loop UI.
- [x] Add assisted Codex login launcher with fallback path (`device-auth` -> standard `codex login`).
- [x] Add explicit `Verify Login` interaction and in-app verification signal.
- [x] Harden login-state parsing for mixed CLI output and explicit logged-in markers.
- [x] Normalize Codex process environment (`PATH`, `HOME`) for app-launched runtime checks and execution.
- [x] Implement scoped file discovery from approved folder with deterministic ranking and reasons.
- [x] Auto-select highest-signal files and show scoped selection in iteration state.
- [x] Build bounded execution package from task, signal, constraints, and selected files.
- [x] Support real runtime attach/relink/run flow through runtime adapters.
- [x] Persist project state, selected runtime/model, iteration state, and history snapshots.
- [x] Add architecture and AGENTS compliance checks via scripts.
- [x] Add unit coverage for scope resolution, persistence round-trip, and run-loop state transitions.

## P0 Next Tasks

- [ ] Declutter the task/runtime section so each state has one clear primary action.
- [ ] Add a calm, explicit transition animation from login verify to attach to run.
- [ ] Show `Last verified at` and an expandable raw status detail after login verification.
- [ ] Refresh runtime auth/install state automatically when app becomes active.
- [ ] Add retry-safe verification behavior for transient CLI errors and slow status responses.

## P1 Follow-Up Tasks

- [ ] Split oversized run-loop UI into smaller feature-owned views under `Features/RunLoop/`.
- [ ] Add targeted unit tests for Codex login parsing edge cases and process environment setup.
- [ ] Add UI tests for verify-login, attach/relink, and run visibility flow.
- [ ] Tighten run timeline messaging into a compact, ordered phase strip.
- [ ] Reduce persisted history payload toward stricter minimal carry-forward storage.

## P2 Expansion Tasks

- [ ] Bring Claude/Cursor runtime surfaces up to the same observability level as Codex.
- [ ] Refresh signal from resulting artifacts more strongly than text-only result summaries.
- [ ] Add lightweight export of iteration summary and scoped decision state.

## Definition Of Done (Current Milestone)

- [ ] Browser/terminal login reliably becomes `Login verified` in-app after pressing `Verify Login`.
- [ ] Attach always returns a real `thread_id` or a clear actionable failure.
- [ ] Run always shows observable phase progression and final result/failure.
- [ ] Task and scope surfaces feel focused, readable, and low-stress at narrow and wide window sizes.
