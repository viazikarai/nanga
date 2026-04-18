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
- did scope boundaries remain explicit?
- does compact prompt avoid transcript noise?
- do examples still match the current skill rules?
