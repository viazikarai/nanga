# AGENTS.md

## technical brief

target:
- markdown-first skill repository
- deterministic, auditable skill behavior
- agent-agnostic usage across codex, claude code, and similar tools

content must be:
- scoped
- current
- predictable
- testable through examples

## product scope

primary scope:
- `SKILL.md` as the canonical behavior contract
- supporting markdown docs and examples
- installation guidance for local skill usage
- versioned, reviewable changes to behavior and outputs

out of scope:
- compiled app surfaces
- platform-specific ui/runtime code
- package manager wrappers as the primary surface

## repository surfaces

- `SKILL.md`
- `README.md`
- `docs/` for roadmap/workflow notes
- `examples/` for realistic input/output references

## agent constraints

- start from the current task
- inspect only required files
- keep diffs small and local
- avoid unrelated rewrites
- explain final results precisely

## learning goals

this repository should teach:
- how to define a deterministic skill contract
- how to compress noisy context into bounded signal
- how to keep scope explicit between iterations
- how to evolve a skill through small, auditable markdown changes

## architecture

prefer a simple, explicit structure:

```text
SKILL.md
README.md
docs/
examples/
```

rules:
- keep behavior rules in `SKILL.md`
- keep install/overview in `README.md`
- keep process and roadmap in `docs/`
- keep realistic use cases in `examples/`

## writing quality

required:
- concise language
- deterministic instructions
- explicit input/output contracts
- no ambiguous optional behavior unless clearly labeled

avoid:
- hidden assumptions
- transcript-style noise
- contradictory rules across files

## validation

before finalizing changes:
- verify `SKILL.md` remains the source of truth
- ensure docs/examples match current skill behavior
- ensure install steps are accurate and minimal
- confirm repository remains markdown-first

## security

- never include secrets
- treat task content examples as intentional user data

## commits

use:
- `feat:`
- `fix:`
- `refactor:`
- `test:`
- `docs:`
- `chore:`

commit subjects must be lowercase after the prefix and describe the actual change.
