# magic test

this example tests whether noisy context compresses into enough signal for a fresh agent to make the same next decision.

## input

- task: prepare release notes for search ranking fix
- intent: preserve only the release-note facts needed for the next writing pass
- constraints:
  - do not mention internal incident names
  - do not claim latency improvements without verified data
- scope:
  - `release-notes/search-ranking.md`
- previous_state:
  - ranking fix was blocked by stale index rebuild failures
  - latency improvement was suspected but unverified
- notes:
  - [14:02][verified] stale index rebuild failure is fixed
  - [14:08][verified] ranking relevance improves for exact-title matches
  - [14:10][unverified] support thread says latency also improved
  - [14:12][verified] no latency benchmark has been run yet
  - [14:15][note] release manager wants wording reviewed before publish
  - transcript repeats the incident codename `falcon-rush`
  - three status lines say the release notes are almost done
- budget: tight

## expected output

```text
decision_anchor:
write release notes for the search ranking fix without exposing internal incident names or unverified latency claims.

keep:
- [constraint] do not mention internal incident names
- [constraint] do not claim latency improvements without verified data
- [state][next-input] ranking relevance improves for exact-title matches (14:08, verified)

state_delta:
- stale index rebuild failure changed from blocking to fixed (14:02, verified)
- latency remains unverified because no benchmark has been run yet (14:12, verified)

open_questions:
- none

deferred:
- release manager wants wording reviewed before publish

drop:
- [conflict:unverified] support thread says latency also improved (14:10, unverified)
- repeated status lines saying release notes are almost done

anti_memory:
- do not carry or mention the internal incident codename `falcon-rush`
- do not carry the unverified latency improvement claim
- do not carry repeated almost-done status lines

compact_prompt:
write `release-notes/search-ranking.md` for the verified ranking relevance improvement on exact-title matches.
do not mention internal incident names. do not claim latency improvements because no latency benchmark
has been run yet.
```

## why this feels like magic

before compression:
- old blocker state
- new verified fix state
- unverified support claim
- verified absence of benchmark data
- internal codename
- repeated status noise
- non-blocking review request

after compression:
- one next decision
- three keep items
- two state changes
- explicit anti-memory for dangerous noise
- compact prompt that cannot accidentally claim unverified latency gains

## fresh-agent test

send only this to a fresh agent:

```text
decision_anchor:
write release notes for the search ranking fix without exposing internal incident names or unverified latency claims.

keep:
- [constraint] do not mention internal incident names
- [constraint] do not claim latency improvements without verified data
- [state][next-input] ranking relevance improves for exact-title matches (14:08, verified)

compact_prompt:
write `release-notes/search-ranking.md` for the verified ranking relevance improvement on exact-title matches.
do not mention internal incident names. do not claim latency improvements because no latency benchmark
has been run yet.
```

pass condition:
- the fresh agent writes release notes around exact-title relevance only.
- the fresh agent does not mention `falcon-rush`.
- the fresh agent does not claim latency improved.

fail condition:
- the fresh agent includes the internal codename.
- the fresh agent treats suspected latency improvement as fact.
- the fresh agent reopens the stale index rebuild failure as the current blocker.
