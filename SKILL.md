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
