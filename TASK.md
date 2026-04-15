# Task

The app is not usable in its current state.

## Current Problem

Nothing meaningful works in the UI:

- Codex does not feel actually connected from the user’s perspective.
- The UI does not clearly prove install state, login state, attach state, or active thread state.
- Entering a task does not reliably lead to useful scope resolution.
- Pressing `Run` does not produce a trustworthy visible execution flow.
- The app still behaves more like a prototype shell than a real operator surface.

## What Needs To Change

### 1. Make Codex connection undeniable

The UI must show:

- whether `codex` is installed
- whether the user is logged in
- whether Nanga is merely ready to attach or actually attached
- the active `thread_id` when attached
- the last attach/run error when something fails

The app should never show `Connected` unless a real Codex session exists.

### 2. Fix task-to-scope behavior

Nanga should:

- read only the approved folder
- derive a bounded scope from the task
- auto-select the highest-signal files
- explain why those files were selected

The user should not have to guess whether the task did anything.

### 3. Make run observable

When the user presses `Run`, the app must visibly show:

- package preparation
- Codex attach or resume
- active execution state
- returned result or failure

This needs a compact runtime panel, not hidden state.

### 4. Keep the UI stable

Do not keep redesigning the whole app while runtime behavior is broken.

For now:

- preserve the stable layout
- make only small UI changes tied to real functionality
- avoid fake status labels

## Proposed Implementation Order

1. Correct the connection model so `available` and `attached` are separate states.
2. Add a compact runtime status block showing login, attach state, thread id, and latest event/error.
3. Verify the real Codex attach path from the app.
4. Verify the real `Run` path from the app.
5. Tighten task-to-scope resolution only after connection and run are trustworthy.

## Definition Of Done

This task is done when:

- selecting `Codex` visibly attaches or clearly fails
- the UI shows a real thread id after attach
- entering a task produces scope
- pressing `Run` visibly invokes Codex
- the result or error is shown clearly in the app
