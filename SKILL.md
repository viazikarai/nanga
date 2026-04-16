# context-anchor skill

context-anchor is a memory-optimization skill for smaller context windows.

## Input

Required:
- `task` (title)
- `intent` (desired outcome)
- `root` (approved folder)

Optional:
- `scope-file` (repeatable previous scope file)
- `note` (repeatable recent note/output)
- `signal-budget` (default `8`)
- `scope-budget` (default `4`)
- `token-budget` (default `700`)

## Output

- bounded `signal`
- ranked `candidate files`
- selected `scope`
- `keep/defer/drop` memory buckets
- `compact prompt` for next turn

## Run

```bash
swift run context-anchor \
  --root /path/to/repo \
  --task "improve run-loop memory" \
  --intent "keep constraints and scoped files, defer low-value notes" \
  --note "avoid transcript bloat" \
  --token-budget 280
```

## Install

```bash
swift build -c release --product context-anchor
```

or npm global install:

```bash
npm install -g context-anchor
```

note:
- npm install currently builds from source at install time
- users need a working swift toolchain

## Design Rules

- deterministic ordering
- bounded output
- scope-first behavior
- carry-forward only what changes decisions
- no hidden transcript expansion
