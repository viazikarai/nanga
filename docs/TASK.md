# roadmap

## current focus

make context-anchor a reliable markdown skill for bounded memory carry-forward.

## feature set (current)

- [f1] deterministic memory framing from `task` + `intent`
- [f2] explicit scope control using allowed files/surfaces
- [f3] bounded outputs: `keep`, `deferred`, `drop`
- [f4] compact next-turn handoff via `compact_prompt`
- [f5] conflict handling: newest verified fact wins, uncertainty flagged
- [f6] agent-agnostic usage across codex, claude code, and similar tools

## done

- [x] canonical `SKILL.md` with deterministic process and output template
- [x] markdown-first repository structure
- [x] install guidance for skill-folder and submodule usage
- [x] example input and output docs
- [x] deterministic conflict troubleshooting flow documented in `SKILL.md`
- [x] conflict-focused example added under `examples/`

## next

- [ ] add more examples for codex, claude code, and local model runs
- [x] define a compact scoring rubric for keep/deferred decisions
- [x] add troubleshooting notes for conflicting memory facts
- [ ] add versioned changelog entries for skill behavior changes

## why each next item matters

- [ ] add more examples for codex, claude code, and local model runs
  solves: ambiguous interpretation during real runs.
  strengthens: `f2`, `f3`, `f4`, `f6`.
  outcome: clearer boundaries for what to keep/defer/drop and how to write compact prompts across agents.
- [x] define a compact scoring rubric for keep/deferred decisions
  solves: decision drift between runs on the same input.
  strengthens: `f1`, `f3`.
  outcome: more repeatable ranking logic for decision impact and recency.
- [x] add troubleshooting notes for conflicting memory facts
  solves: uncertainty about which fact should survive when notes conflict.
  strengthens: `f5`.
  outcome: deterministic resolution steps for stale, partial, or conflicting evidence.
- [ ] add versioned changelog entries for skill behavior changes
  solves: silent behavior drift and hard-to-review updates.
  strengthens: `f1`, `f6`.
  outcome: auditable history of contract-level changes and migration context.

## stretch path (highest effort)

- [ ] build a cross-agent benchmark suite with scenario corpus + automated scoring
  solves: unproven quality claims at scale.
  strengthens: `f6` primarily, then `f1`-`f4`.
  outcome: measurable portability/quality across codex, claude code, and local models.

## quality bar

- [ ] same input should produce equivalent keep/deferred/drop structure
- [ ] outputs must be concise and easy to audit
- [ ] compact prompt must include only required carry-forward context
