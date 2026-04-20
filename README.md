# context-anchor

context-anchor is an agent-agnostic memory skill for smaller context windows.

it helps models keep only decision-critical context by producing bounded memory blocks:
- keep
- deferred
- drop
- compact next-turn prompt

## what works now

- deterministic memory framing from task + intent
- deterministic scoring rubric using impact + recency with fixed thresholds
- deterministic conflict resolution for stale, conflicting, or unverified facts
- explicit scope framing from approved files/surfaces
- bounded keep/deferred/drop outputs
- compact prompt handoff format for next turn
- markdown-first skill contract in `SKILL.md`

## what is next

- confidence labels and calibration on top of the scoring rubric
- artifact-driven refresh guidance after each run
- more examples for codex, claude code, and local model workflows

## run the skill in your loop

1. load `SKILL.md` as the behavior contract in your memory-compression step.
2. send structured input with at least:
   - `task`
   - `intent`
   - optional `constraints`, `scope`, `notes`, `budget`
3. parse returned sections:
   - `keep`
   - `deferred`
   - `drop`
   - `compact_prompt`
4. pass only `keep` + `compact_prompt` into the next execution turn.
5. persist `deferred` for later, and do not carry `drop` forward.

## install this skill in your actual project

### option a: install as a codex skill folder

```bash
mkdir -p ~/.codex/skills/context-anchor
cp SKILL.md ~/.codex/skills/context-anchor/SKILL.md
```

optional supporting docs:

```bash
cp -R docs ~/.codex/skills/context-anchor/docs
cp -R examples ~/.codex/skills/context-anchor/examples
```

### option b: install from this repo into your project

```bash
cd /path/to/your-project
git submodule add https://github.com/viazikarai/nanga.git tools/context-anchor
```

then reference `tools/context-anchor/SKILL.md` in your workflow/tooling.

## repository structure

- `SKILL.md`: canonical skill definition
- `README.md`: overview and install guidance
- `docs/`: roadmap + workflow notes
- `examples/`: concrete usage examples

## documentation map

- contract: `SKILL.md` (source of truth)
- roadmap: `docs/TASK.md`
- change process: `docs/WORKFLOW.md`
- examples:
  - `examples/basic-use.md`
  - `examples/conflicting-facts.md`
  - `examples/output-example.md`
