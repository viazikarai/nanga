# output example

```text
keep:
- [constraint] keep backward compatibility
- [fact] attach fails when auth state is unresolved
- [fact] user has completed login previously

deferred:
- [note] secondary diagnostics from non-blocking logs

drop:
- repeated status chatter from debug output
- non-actionable transcript filler

compact_prompt:
fix attach flow for unresolved auth state while preserving backward compatibility.
use prior successful login fact, avoid unrelated refactors, and return concise validation steps.
```
