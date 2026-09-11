# AGENTS.md — instructions for coding agents working in this repository

You may be a Codex worker or a Claude agent launched by the `agents` orchestrator. Read this first.

## What this repository is
A multi-agent development system (Brain -> Claude Opus managers -> Codex workers -> review -> QA -> Brain) plus the application it builds. Orchestrator code lives in `orchestrator/` and `bin/agents.mjs`; shared state lives in `.ai/`; role prompts live in `.claude/skills/*/SKILL.md`.

## If you are a WORKER (most likely)
- You received a task brief (TASK_ID, FILES YOU MAY EDIT, ACCEPTANCE CRITERIA, TEST COMMANDS). Follow it literally.
- Edit only files matching FILES YOU MAY EDIT. If you truly need another file, stop and report `needs_escalation=true`.
- Do not commit, push, reset, rebase or rewrite history. The orchestrator commits for you.
- Do not add dependencies, install software, download anything, or touch `.env`, secrets, billing, auth, CI, production or `.ai/skills/registry.json`.
- Run the TEST COMMANDS you were given; report honestly in the required JSON.

## Source of truth
- Code: Git. Tasks: `.ai/TASKS.json`. State: `.ai/PROJECT_STATE.md`. Decisions: `.ai/DECISIONS/`. Skills: `.ai/skills/registry.json`. Runs: `.ai/RUNS/`.

## Commands
- `npm test` runs the orchestrator unit tests. `npx agents doctor` checks the environment.
