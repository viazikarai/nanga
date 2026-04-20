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
- keep: release constraint and newest verified migration status (`passed`)
- deferred: monitor-first-write-path note
- drop: older conflicting failure fact, unverified conflicting claim, repeated chatter
- compact prompt: proceed with release checks using `passed` as current status and include monitor step

conflict resolution walkthrough:
- `migration.status` candidates:
  - 10:05 verified fail -> older verified conflicting fact -> `drop` (`[conflict:superseded]`)
  - 10:19 verified pass -> newest verified winner -> `keep`
  - 10:22 unverified fail -> conflicting unverified claim -> `drop` (`[conflict:unverified]`)
- monitor note is non-conflicting context -> `deferred`

sample output:

```text
keep:
- [constraint] do not ship if migration status is failing
- [fact] migration dry-run passed after patch (10:19, verified)

deferred:
- [note] monitor first production write path after deploy

drop:
- [conflict:superseded] migration dry-run failed on null constraint (10:05, verified)
- [conflict:unverified] chat message says migration still failing (10:22, unverified)
- repeated standup transcript chatter

compact_prompt:
continue release readiness checks with migration status set to passed (10:19 verified),
preserve the no-ship-on-failure constraint, and include post-deploy write-path monitoring.
```
