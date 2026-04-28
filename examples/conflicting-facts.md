# conflicting facts

input:

- task: decide release readiness for migration rollout
- intent: carry only the latest migration status and release constraints
- constraints:
  - do not ship if migration status is failing
- notes:
  - [10:05][verified] migration dry-run failed on null constraint
  - [10:19][verified] migration dry-run passed after patch
  - [10:22][unverified] chat message says migration still failing
  - [10:24][note] monitor first production write path after deploy
  - standup transcript chatter repeated status updates

expected skill behavior:
- decision_anchor: decide release readiness using the latest verified migration status
- keep: release constraint and newest verified migration status (`passed`)
- state_delta: none because no `previous_state` was provided
- open_questions: none
- deferred: monitor-first-write-path note
- drop: older conflicting failure fact, unverified conflicting claim, repeated chatter
- anti_memory: older failure, unverified failure claim, repeated status chatter
- compact prompt: proceed with release checks using `passed` as current status

conflict resolution walkthrough:
- `migration.status` candidates:
  - 10:05 verified fail -> older verified conflicting fact -> `drop` (`[conflict:superseded]`)
  - 10:19 verified pass -> newest verified winner -> `keep`
  - 10:22 unverified fail -> conflicting unverified claim -> `drop` (`[conflict:unverified]`)
- monitor note is non-conflicting context -> `deferred`

sample output:

```text
decision_anchor:
decide release readiness using the latest verified migration status.

keep:
- [constraint] do not ship if migration status is failing
- [state][next-input] migration dry-run passed after patch (10:19, verified)

state_delta:
- none

open_questions:
- none

deferred:
- [note] monitor first production write path after deploy

drop:
- [conflict:superseded] migration dry-run failed on null constraint (10:05, verified)
- [conflict:unverified] chat message says migration still failing (10:22, unverified)
- repeated standup transcript chatter

anti_memory:
- do not carry the superseded 10:05 migration failure
- do not carry the unverified 10:22 failure claim
- do not carry repeated standup status chatter

compact_prompt:
continue release readiness checks with migration status set to passed (10:19 verified).
preserve the no-ship-on-failure constraint.
```
