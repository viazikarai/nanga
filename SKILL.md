# context-anchor skill

context-anchor is a memory skill that compresses noisy task context into bounded, high-signal carry-forward state.

the skill preserves signal by compiling context into the minimum state needed for the next decision.

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
- `budget`: max memory item count, token budget, or compression level
- `previous_state`: prior compact memory, when available

## process

1. parse task and intent
2. define the next `decision_anchor`
3. extract candidate memory items
4. score each item by decision impact and recency
5. resolve conflicts for competing facts
6. identify `state_delta` versus `previous_state`, when provided
7. bucket into `keep`, `deferred`, `drop`, and `anti_memory`
8. produce compact next-turn prompt from `decision_anchor` + `keep` + required `scope`

## decision anchor

always state the next decision the receiving agent must make.

rules:
- derive `decision_anchor` from `task` + `intent`
- keep it to one sentence
- make it action-oriented
- do not include background facts unless they change the next decision

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
- any item in `keep` must include a reason tag explaining why it affects the next decision
- a true fact that does not affect the next decision must move to `deferred` or `drop`

## compression levels

if `budget` is a named level, apply these limits after scoring and hard overrides:

- `tight`: max 3 `keep` items
- `normal`: max 6 `keep` items
- `expanded`: max 10 `keep` items

if a numeric item limit is provided, use that limit instead of the named levels.
if a token budget is provided, keep the highest-ranked items that fit the budget.
overflow from `keep` moves to `deferred` in ranking order.

## reason tags

prefix each `keep` item with one or more concise reason tags.

use stable tags that explain survival value, such as:
- `[constraint]`: explicit non-negotiable limit
- `[failure]`: current blocker or observed failure
- `[state]`: verified current state
- `[scope]`: allowed or forbidden surface
- `[next-input]`: fact required for the next implementation or validation step

do not create decorative tags. if a tag does not explain decision impact, omit it.

## state delta

when `previous_state` is provided, include only meaningful changes since that state.

rules:
- include changed facts that affect `decision_anchor`
- include newly verified facts that replace older facts
- do not restate unchanged background
- if nothing changed, return `state_delta` with `- none`

## open questions

separate uncertainty from memory.

include a question only when:
- the answer can change the next decision
- the input does not contain enough verified information to resolve it

do not convert uncertainty into a fact.

## anti-memory

use `anti_memory` for items that should not be carried forward.

include:
- repeated transcript chatter
- superseded facts
- resolved investigations that should not be reopened
- style or status noise with no decision value

`anti_memory` prevents future runs from rehydrating discarded noise.

## conflict troubleshooting

use this sequence when two or more items assert different values for the same claim:

1. normalize a claim key as `<entity>.<field>` (example: `migration.status`)
2. for each conflicting candidate, record:
   - verification state: `verified` or `unverified`
   - recency source: explicit timestamp when available, otherwise input order
3. choose the winner:
   - if any `verified` candidates exist, select the newest `verified` candidate
   - if none are `verified`, select the newest candidate and label it `[uncertain]`
4. move non-winning conflicting items to `drop` with reason tags:
   - `[conflict:superseded]` for older conflicting facts
   - `[conflict:unverified]` for conflicting unverified claims discarded in favor of verified facts
5. if recency and verification are equal, prefer earlier appearance in input

## output contract

always return these sections:

- `decision_anchor`: next decision to make
- `keep`: must-carry-forward items
- `state_delta`: meaningful changes from prior compact state, or `none`
- `open_questions`: unresolved questions that can change the next decision
- `deferred`: useful but not required now
- `drop`: explicitly discarded noise
- `anti_memory`: items that must not be carried forward
- `compact_prompt`: next-turn prompt using only `decision_anchor`, `keep`, required `scope`, and decision-changing `open_questions`

## hard rules

- be deterministic for same input
- keep scope explicit and bounded
- prefer concise structured memory over transcript dumps
- do not carry style chatter or duplicate status lines
- if information conflicts, preserve newest verified fact and flag uncertainty
- preserve facts because they change the next action, not because they are merely true
- never include `deferred`, `drop`, or `anti_memory` items in `compact_prompt`

## validation test

the output passes when a fresh agent receiving only `decision_anchor`, `keep`, and `compact_prompt` can make the same next decision.

if the fresh agent cannot make the same next decision, move the missing decision-changing item into `keep`.
if the fresh agent can make the same next decision without an item, move that item to `deferred`, `drop`, or `anti_memory`.

## output template

```text
decision_anchor:
...

keep:
- ...

state_delta:
- ...

open_questions:
- ...

deferred:
- ...

drop:
- ...

anti_memory:
- ...

compact_prompt:
...
```
