# DEC-001 Thin orchestrator over Claude Code and Codex CLIs

## Context
We need a Brain -> Managers -> Workers -> Review -> QA -> Brain pipeline that works today on this repository, is cheap, secure, and replaceable per role. Candidate frameworks were evaluated (open-multi-agent, codex-orchestrator, fables, orchestrate, anthropics/skills). The environment authenticates Claude Code via OAuth (no raw ANTHROPIC_API_KEY) and Codex via `codex login`, so API-SDK-based frameworks would need extra credentials.

## Decision
Build a ~1.5k-line dependency-free Node orchestrator (`orchestrator/`, entry `bin/agents.mjs`) that drives `claude -p --json-schema` (managers, fallback roles) and `codex exec --output-schema` (brain and workers when authenticated). Roles are prompts in `.claude/skills/*/SKILL.md`; models/providers in `.ai/config.json`; state in `.ai/`; isolation via git worktrees.

## Reason
The heavy lifting (tool use, sandboxing, file edits, tests) is already solved by the two CLIs. The remaining orchestration (sequencing, waves, retries, structured hand-offs, approvals, logging) is small. A framework would add API-key requirements, 40k+ LOC and its own coordinator model.

## Alternatives
- open-multi-agent (REFERENCE_ONLY): mature, but SDK/API-key-centric; external agents via process/ACP adapters still need an LLM planner with API keys.
- codex-orchestrator (REFERENCE_ONLY): tmux-based Codex workers, single maintainer, last commit 2026-05; `codex exec --json/--output-schema` makes tmux parsing unnecessary.
- fables (USE_PARTIALLY): prompt patterns reused (worker brief, model pinning, retry caps, plan-big/execute-small).
- orchestrate (REJECT): abandoned in favor of a Python rewrite; uses --dangerously-skip-permissions.

## Consequences
Any role can be swapped by editing `.ai/config.json` (provider + model). Codex-specific features (native sub-agents) are not used; if Codex is not authenticated, workers/brain fall back to Claude models automatically.
