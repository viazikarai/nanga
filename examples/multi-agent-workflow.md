# multi-agent workflow

this example shows how `context-anchor` preserves signal across codex, claude code, and a local/manual run without carrying transcript noise.

## input

- task: stabilize checkout retry flow
- intent: hand off only the state needed for the next implementation pass
- constraints:
  - do not change payment provider contracts
  - keep retry behavior backward compatible
- scope:
  - `checkout/retry.md`
  - `examples/checkout-retry.md`
- notes:
  - [09:12][verified] retry fails when payment session is expired
  - [09:18][verified] retry succeeds after refreshing session token before provider call
  - [09:21][unverified] chat message says provider timeout is the root cause
  - old transcript repeats debug logs from three retry attempts
  - manual tester asked to verify expired-session retry after docs update
- budget: normal

## codex compression pass

codex loads `SKILL.md`, scores candidate memory, resolves conflicts, and returns:

```text
decision_anchor:
update the checkout retry docs around expired-session recovery without changing payment provider contracts.

keep:
- [constraint][scope] only edit `checkout/retry.md` and `examples/checkout-retry.md`
- [constraint] do not change payment provider contracts
- [constraint] keep retry behavior backward compatible
- [state][next-input] retry succeeds after refreshing session token before provider call (09:18, verified)

state_delta:
- retry status changed from failing on expired payment session to succeeding after session-token refresh

open_questions:
- none

deferred:
- manual tester should verify expired-session retry after docs update

drop:
- [conflict:superseded] retry fails when payment session is expired (09:12, verified)
- [conflict:unverified] chat message says provider timeout is the root cause (09:21, unverified)
- repeated debug logs from three retry attempts

anti_memory:
- do not carry the superseded 09:12 failure as current state
- do not carry the unverified provider-timeout claim
- do not carry repeated retry debug logs

compact_prompt:
update the checkout retry docs using the verified current state: retry succeeds after refreshing
the session token before the provider call. only edit `checkout/retry.md` and
`examples/checkout-retry.md`. preserve provider contracts and backward-compatible retry behavior.
```

## claude code handoff

claude code receives only:

```text
decision_anchor:
update the checkout retry docs around expired-session recovery without changing payment provider contracts.

keep:
- [constraint][scope] only edit `checkout/retry.md` and `examples/checkout-retry.md`
- [constraint] do not change payment provider contracts
- [constraint] keep retry behavior backward compatible
- [state][next-input] retry succeeds after refreshing session token before provider call (09:18, verified)

compact_prompt:
update the checkout retry docs using the verified current state: retry succeeds after refreshing
the session token before the provider call. only edit `checkout/retry.md` and
`examples/checkout-retry.md`. preserve provider contracts and backward-compatible retry behavior.
```

expected behavior:
- use the verified 09:18 state as current truth
- avoid provider-timeout investigation unless new verified evidence appears
- keep edits inside the stated scope
- do not rehydrate dropped transcript logs

## local/manual run

local notes can persist non-blocking follow-up separately:

```text
deferred:
- manual tester should verify expired-session retry after docs update
```

manual execution rules:
- use `deferred` as a follow-up queue, not as next-turn context
- never paste `drop` or `anti_memory` into the next agent prompt
- rerun the skill if new verified facts arrive

## fresh-agent test

pass condition:
- a fresh agent using only `decision_anchor`, `keep`, and `compact_prompt` updates the retry docs with the same current state and constraints.

fail condition:
- the fresh agent reopens provider-timeout investigation, treats the 09:12 failure as current state, or edits outside scope.
