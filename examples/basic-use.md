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
- keep: auth state requirement, attach failure fact, compatibility constraint
- deferred: secondary diagnostics
- drop: repeated chatter/debug noise
- compact prompt: focused on auth + attach fix path

rubric walkthrough:
- keep backward compatibility (constraint): impact 3, recency 2, total 8 -> keep
- attach failed on missing auth state: impact 3, recency 2, total 8 -> keep
- user already completed login once: impact 2, recency 2, total 6 -> keep
- secondary diagnostics from non-blocking logs: impact 1, recency 1, total 3 -> deferred
- repeated status chatter: impact 0, recency 1, total 1 -> drop
- non-actionable transcript filler: impact 0, recency 1, total 1 -> drop
