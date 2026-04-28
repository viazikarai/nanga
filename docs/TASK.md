# roadmap

## current focus

make context-anchor a reliable markdown skill for bounded memory carry-forward.

## done

- [x] canonical `SKILL.md` with deterministic process and output template
- [x] markdown-first repository structure
- [x] install guidance for skill-folder and submodule usage
- [x] example input and output docs
- [x] deterministic scoring rubric for keep/deferred decisions
- [x] deterministic conflict troubleshooting flow documented in `SKILL.md`
- [x] conflict-focused example added under `examples/`
- [x] removed redundant example artifact to keep a minimal documentation set

## next

- [ ] add one multi-agent workflow example for codex, claude code, and local runs
- [ ] add versioned changelog entries for skill behavior changes

## quality bar

- [ ] same input should produce equivalent keep/deferred/drop structure
- [ ] outputs must be concise and easy to audit
- [ ] compact prompt must include only required carry-forward context
- [ ] docs/examples must not duplicate each other or contradict `SKILL.md`
