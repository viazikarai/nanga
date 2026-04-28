# workflow

this file defines how to evolve the skill.

## purpose

each change should:
- improve memory quality for constrained-context runs
- keep behavior explicit and reviewable

## change order

1. state the behavior change clearly
2. define in-scope and out-of-scope
3. update `SKILL.md` first
4. update examples to match new behavior
5. review wording for ambiguity or hidden assumptions
6. update roadmap if priorities changed

## review checklist

- is the output contract still deterministic?
- does the `decision_anchor` state the next decision in one sentence?
- did scope boundaries remain explicit?
- do conflict-resolution rules still produce a single deterministic winner?
- does `compact_prompt` avoid transcript noise and exclude `deferred`, `drop`, and `anti_memory`?
- do `keep` items include reason tags that explain decision impact?
- does `anti_memory` block resolved or noisy context from being carried forward?
- do examples still match the current skill rules?
- does `README.md` describe behavior without contradicting `SKILL.md`?
- are there stale files or references that can be removed to keep the repo minimal?
