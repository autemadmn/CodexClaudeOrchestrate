# CLAUDE.md

This repository contains a multi-agent development system (`agents` CLI) and the application it builds.

- Read `AGENTS_QUICKSTART.md` for how the system is used, `AGENTS.md` for rules when you act as an orchestrated agent.
- Role prompts: `.claude/skills/{brain,product-architect-manager,implementation-manager,qa-manager,worker,skill-curator}/SKILL.md` (shared rules in `agent-common`).
- Config: `.ai/config.json` (models/providers/limits/guardrails). State: `.ai/PROJECT_STATE.md`, `.ai/ROADMAP.md`, `.ai/TASKS.json`, `.ai/DECISIONS/`, `.ai/RUNS/`, `.ai/skills/registry.json`.
- Orchestrator code: `orchestrator/*.mjs` (no runtime dependencies; Node >= 22). Tests: `npm test`.
- Never print or store secrets. Never force-push. Workers never manage skills.
