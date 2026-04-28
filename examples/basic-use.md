# basic use

input:

- task: stabilize runtime attach flow
- intent: keep only errors and constraints needed for next fix
- constraints:
  - do not widen scope
  - keep backward compatibility
- notes:
  - attach failed on missing auth state
  - user already completed login once
  - secondary diagnostics from non-blocking logs
  - old debug logs include repeated status chatter
  - transcript includes non-actionable filler lines

expected skill behavior:
- decision_anchor: fix the attach failure without widening scope or breaking compatibility
- keep: auth state requirement, attach failure fact, compatibility constraint
- state_delta: none because no `previous_state` was provided
- open_questions: none
- deferred: secondary diagnostics
- drop: repeated chatter/debug noise
- anti_memory: repeated status chatter and non-actionable filler
- compact prompt: focused on auth + attach fix path

rubric walkthrough:
- keep backward compatibility (constraint): impact 3, recency 2, total 8 -> keep
- attach failed on missing auth state: impact 3, recency 2, total 8 -> keep
- user already completed login once: impact 2, recency 2, total 6 -> keep
- secondary diagnostics from non-blocking logs: impact 1, recency 1, total 3 -> deferred
- repeated status chatter: impact 0, recency 1, total 1 -> drop
- non-actionable transcript filler: impact 0, recency 1, total 1 -> drop

sample output:

```text
decision_anchor:
fix the attach failure caused by missing auth state without widening scope or breaking compatibility.

keep:
- [constraint][scope] do not widen scope
- [constraint] keep backward compatibility
- [failure][next-input] attach failed on missing auth state
- [state][next-input] user already completed login once

state_delta:
- none

open_questions:
- none

deferred:
- secondary diagnostics from non-blocking logs

drop:
- old debug logs include repeated status chatter
- transcript includes non-actionable filler lines

anti_memory:
- do not carry repeated debug/status chatter
- do not carry non-actionable transcript filler

compact_prompt:
fix the attach failure caused by missing auth state. preserve the constraints: do not widen
scope and keep backward compatibility. user already completed login once, so do not treat
login completion as the primary unknown.
```
