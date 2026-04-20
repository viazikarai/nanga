# context-anchor skill

context-anchor is a memory skill that compresses noisy task context into bounded, high-signal carry-forward state.

## when to use

use this skill when:
- the model has a small context window
- the run has accumulated noisy notes/transcript fragments
- you need deterministic memory carry-forward between iterations

## input contract

required:
- `task`: short current goal
- `intent`: exact expected outcome this iteration

optional:
- `constraints`: non-negotiable limits
- `scope`: files/surfaces explicitly allowed
- `notes`: recent observations/results
- `budget`: max memory item count or token budget

## process

1. parse task and intent
2. extract candidate memory items
3. score each item by decision impact and recency
4. bucket into `keep`, `deferred`, `drop`
5. produce compact next-turn prompt from `keep` + required `scope`

## scoring rubric

score each candidate with:

- `impact` (0-3):
  - `3`: required to satisfy current `intent` or an explicit constraint
  - `2`: directly affects the next implementation or validation decision
  - `1`: useful near-term context, but not required now
  - `0`: no decision value (chatter, filler, repeated status lines)
- `recency` (0-2):
  - `2`: newest verified fact in current run
  - `1`: recent but unverified/indirect fact
  - `0`: stale or superseded fact
- `total`: `total = (impact * 2) + recency` (range `0-8`)

bucket by `total`:

- `keep`: `6-8`
- `deferred`: `3-5`
- `drop`: `0-2`

deterministic tie-break order:

1. higher `total`
2. higher `impact`
3. newer fact
4. earlier appearance in input

hard overrides:

- keep all explicit `constraints` unless a newer verified constraint replaces one
- deduplicate semantically equivalent items; keep the highest-ranked version
- on conflict, keep newest verified fact and move older conflicting facts to `drop`
- if `budget` is set, keep only the top-ranked `keep` items within budget and move overflow to `deferred`

## output contract

always return these sections:

- `keep`: must-carry-forward items
- `deferred`: useful but not required now
- `drop`: explicitly discarded noise
- `compact_prompt`: next-turn prompt using only required memory

## hard rules

- be deterministic for same input
- keep scope explicit and bounded
- prefer concise structured memory over transcript dumps
- do not carry style chatter or duplicate status lines
- if information conflicts, preserve newest verified fact and flag uncertainty

## output template

```text
keep:
- ...

deferred:
- ...

drop:
- ...

compact_prompt:
...
```
