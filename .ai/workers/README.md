# Workers

Workers run one task each inside an isolated git worktree (`.worktrees/TASK-xxx`, branch `agent/TASK-xxx`).

- Provider/model: `.ai/config.json` role `worker` (default `gpt-5.6-luna` via Codex with reasoning `medium`; falls back to `claude-sonnet-5` when Codex is not authenticated).
- Codex sandbox: `workspace-write` (writes confined to the worktree). Claude fallback: `acceptEdits` + Bash allowlist limited to the task's test commands and read-only commands.
- Guardrails enforced by the orchestrator after the worker finishes: files outside `allowed_files` or in forbidden paths -> task FAILED + escalation.
- Workers never install dependencies, manage skills, push, or touch secrets/billing/production.
