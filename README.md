# context-anchor

context-anchor is a markdown-first, agent-agnostic memory skill for constrained context windows.

## run the skill in your loop

1. load `SKILL.md` as the behavior contract in your memory-compression step.
2. send structured input with at least:
   - `task`
   - `intent`
   - optional `constraints`, `scope`, `notes`, `budget`, `previous_state`
3. parse returned sections:
   - `decision_anchor`
   - `keep`
   - `state_delta`
   - `open_questions`
   - `deferred`
   - `drop`
   - `anti_memory`
   - `compact_prompt`
4. pass only `decision_anchor` + `keep` + `compact_prompt` into the next execution turn.
5. persist `deferred` separately, and do not carry `drop` or `anti_memory` forward.

## behavior guarantees

- deterministic output shape for the same input
- next-decision anchor for each compression pass
- explicit scope and constraint carry-forward
- fixed scoring and bucketing for `keep`, `deferred`, `drop`
- deterministic conflict resolution for competing facts
- explicit anti-memory for noise that must not be rehydrated
- named compression levels for tight, normal, and expanded memory budgets
- compact next-turn prompt built from required carry-forward state

## before and after

before:
- carry forward transcript dumps, repeated status lines, stale facts, and unverified claims.
- ask the next agent to infer what still matters.
- risk reviving discarded context in later runs.

after:
- carry forward one `decision_anchor`, reason-tagged `keep` items, and a compact prompt.
- separate `deferred`, `drop`, and `anti_memory` from next-turn context.
- test whether a fresh agent can make the same next decision from bounded signal.

## add this skill to a project

important:
- project-local submodule installs are path-based; reference `tools/context-anchor/SKILL.md` explicitly.
- name-based invocation, such as `use context-anchor`, requires global installation in `~/.codex/skills/context-anchor`.

### project-local install

```bash
cd /path/to/your-project
git submodule add https://github.com/viazikarai/nanga.git tools/context-anchor
```

then reference the skill contract in your agent workflow:

```text
tools/context-anchor/SKILL.md
```

use this path when you want the skill versioned with a specific project.

## use after adding the submodule

after installing with:

```bash
git submodule add https://github.com/viazikarai/nanga.git tools/context-anchor
```

start a new agent session from your project and paste:

```text
Use `tools/context-anchor/SKILL.md` as the behavior contract.

Compress this task state and return the exact output sections required by the skill:

task: <current goal>
intent: <expected outcome for this iteration>
constraints:
- <non-negotiable rule>
scope:
- <allowed file or surface>
notes:
- <verified fact, observation, conflict, or noisy context>
budget: tight
```

for the next agent turn, carry forward only:

```text
decision_anchor
keep
compact_prompt
```

store separately if useful:

```text
deferred
```

do not carry forward:

```text
drop
anti_memory
```

verify with a prompt like:

```text
use `tools/context-anchor/SKILL.md` as the behavior contract and compress this task state:

task: continue checkout retry fix
intent: preserve only the facts needed for the next implementation pass
notes:
- retry failed on expired session
- latest verified fix refreshes token before retry
- old logs repeated timeout messages
budget: tight
```

expected behavior:
- the agent reads `tools/context-anchor/SKILL.md`
- it returns `decision_anchor`, `keep`, `state_delta`, `open_questions`, `deferred`, `drop`, `anti_memory`, and `compact_prompt`
- the next turn uses only `decision_anchor`, `keep`, and `compact_prompt`

## will the agent see the instructions?

yes, if the agent is told to read the project-local skill file.

after the submodule is added, Codex can read:

```text
tools/context-anchor/SKILL.md
```

but a project submodule does not automatically register as a named Codex skill. use one of these patterns:

direct prompt:

```text
Use `tools/context-anchor/SKILL.md` as the behavior contract for this memory compression pass.
```

project instruction:

```markdown
When asked to compress or carry forward task context, read `tools/context-anchor/SKILL.md` and follow its output contract exactly.
```

if you want name-based invocation like `use context-anchor`, install it globally in the Codex skills directory.

update the project-local skill later with:

```bash
git submodule update --remote tools/context-anchor
git add tools/context-anchor
git commit -m "chore: update context-anchor skill"
```

### optional codex-global install

install globally when you want Codex to show or invoke the skill by name instead of referencing a project path.

```bash
git clone https://github.com/viazikarai/nanga.git ~/.codex/skills/context-anchor
```

start a new codex session after installing. then invoke it with:

```text
use context-anchor to compress this task state:

task: <current goal>
intent: <expected outcome for this iteration>
notes:
- <verified fact, observation, conflict, or noisy context>
budget: tight
```

global install is required for name-based availability. a project submodule alone will not make `context-anchor` appear as an installed skill.

### optional local copy

from this repository:

```bash
mkdir -p ~/.codex/skills/context-anchor
cp -R SKILL.md docs examples ~/.codex/skills/context-anchor/
```

start a new codex session after copying the files.

### troubleshooting

if codex says the skill is unavailable:

- use the project-local path explicitly: `tools/context-anchor/SKILL.md`
- install globally if you want name-based invocation: `git clone https://github.com/viazikarai/nanga.git ~/.codex/skills/context-anchor`
- confirm the file exists at `~/.codex/skills/context-anchor/SKILL.md`
- confirm `SKILL.md` starts with YAML frontmatter containing `name` and `description`
- start a new codex session after installing or updating the skill
- do not expect a project submodule to auto-register as a global Codex skill; submodules are project-local and must be referenced by path

## repository structure

- `SKILL.md`: canonical skill contract (source of truth)
- `README.md`: overview + install guidance
- `docs/TASK.md`: roadmap and quality bar
- `docs/WORKFLOW.md`: change process and review checklist
- `docs/CHANGELOG.md`: versioned behavior changes
- `examples/basic-use.md`: baseline scoring and bucket behavior
- `examples/conflicting-facts.md`: deterministic conflict resolution behavior
- `examples/multi-agent-workflow.md`: codex, claude code, and local/manual handoff behavior
- `examples/magic-test.md`: fresh-agent preservation test for noisy context
