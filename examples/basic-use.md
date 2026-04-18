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
  - old debug logs include repeated status chatter

expected skill behavior:
- keep: auth state requirement, attach failure fact, compatibility constraint
- deferred: secondary diagnostics
- drop: repeated chatter/debug noise
- compact prompt: focused on auth + attach fix path
