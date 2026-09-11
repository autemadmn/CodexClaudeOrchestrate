# ROADMAP

## MVP
- [x] Multi-agent orchestration system operational (smoke test passed)
- [ ] First real product feature (to be chosen by the human)

## Milestones
1. **M0 — Agent system ready** (done): doctor, run, status, tasks, skills, logs, resume, stop.
2. **M1 — First feature**: chosen by the human; run through the full pipeline.
3. **M2 — Product MVP**: iterate feature by feature with `agents run`.

## Priorities
1. Keep the system simple; the application matters more than the agent infrastructure.
2. Only approved, pinned, audited skills enter the registry.

## Dependencies
- Claude Code CLI (managers, fallback brain/workers).
- Codex CLI login (preferred brain `gpt-6-astra` and workers `gpt-5.6-luna`).

## Next steps
- Human: decide the first feature. Run `agents run "<objective>"`.
