# CodexClaudeOrchestrate

A small, dependency-free multi-agent development system for this repository:

```
USER -> GPT Astra (BRAIN) -> Claude Opus (MANAGERS) -> Codex (WORKERS) -> Claude Opus (REVIEW/QA) -> BRAIN -> summary
```

- **One command**: `npx agents run "your objective"`.
- **Shared state in Git**: `.ai/PROJECT_STATE.md`, `.ai/ROADMAP.md`, `.ai/TASKS.json`, `.ai/DECISIONS/`, `.ai/RUNS/`, `.ai/skills/registry.json`.
- **Isolation**: one git worktree per worker task, up to 3 in parallel, merged by the orchestrator after review.
- **Guardrails**: allowed_files enforcement, forbidden paths, approval categories (auto / brain / human), retry caps, budget caps.
- **Replaceable models**: `.ai/config.json` (`gpt-6-astra` brain, `claude-opus-5` managers, `gpt-5.6-luna` workers; automatic fallback to Claude when Codex is not authenticated).

Start with [AGENTS_QUICKSTART.md](AGENTS_QUICKSTART.md). Architecture decisions: [.ai/DECISIONS](.ai/DECISIONS). Repository evaluations: [.ai/REPOS_EVALUATED.md](.ai/REPOS_EVALUATED.md).

```bash
npm install && npx agents doctor && npm test
```
