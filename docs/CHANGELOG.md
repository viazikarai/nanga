# changelog

## unreleased

- added `decision_anchor` as the required next-decision summary.
- added reason tags for `keep` items to explain decision impact.
- added `state_delta` for meaningful changes from prior compact memory.
- added `open_questions` to separate uncertainty from facts.
- added `anti_memory` to prevent discarded noise from being carried forward.
- added named compression levels for `tight`, `normal`, and `expanded` budgets.
- tightened `compact_prompt` so it excludes `deferred`, `drop`, and `anti_memory`.
