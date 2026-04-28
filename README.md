# context-anchor

context-anchor is a markdown-first, agent-agnostic memory skill for constrained context windows.

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

## behavior guarantees

- deterministic output shape for the same input
- explicit scope and constraint carry-forward
- fixed scoring and bucketing for `keep`, `deferred`, `drop`
- deterministic conflict resolution for competing facts
- compact next-turn prompt built from required carry-forward state

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

- `SKILL.md`: canonical skill contract (source of truth)
- `README.md`: overview + install guidance
- `docs/TASK.md`: roadmap and quality bar
- `docs/WORKFLOW.md`: change process and review checklist
- `examples/basic-use.md`: baseline scoring and bucket behavior
- `examples/conflicting-facts.md`: deterministic conflict resolution behavior
