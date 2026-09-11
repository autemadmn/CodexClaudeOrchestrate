# Repositories evaluated (2026-09-11)

Metadata gathered live from shallow clones and GitHub pages during bootstrap. Star/fork counts are as displayed that day.

## anthropics/skills
REPOSITORY: https://github.com/anthropics/skills — OWNER: Anthropic (organization) — PURPOSE: official Agent Skills examples, spec pointer (agentskills.io), SKILL.md template.
STARS: ~175.8k — FORKS: ~20.8k — CONTRIBUTORS: many (org) — LAST COMMIT: 2026-09-10 (34040c9) — LATEST RELEASE: n/a — LICENSE: Apache-2.0 (most), source-available (document skills) — SECURITY POLICY: not checked — ISSUES: 348 open.
MAINTAINER REPUTATION: Tier 0 (technology owner). TRUST TIER: 0.
RISKS: none for format reuse; document skills are source-available, not OSS. BENEFITS: canonical SKILL.md frontmatter/format; `skill-creator` already bundled in Claude Code.
DECISION: **USE_PARTIALLY** — format and conventions adopted for the 7 internal skills; nothing copied or installed (registered as `reference_only` in the registry).

## open-multi-agent/open-multi-agent
REPOSITORY: https://github.com/open-multi-agent/open-multi-agent — OWNER: open-multi-agent org (Shenzhen YuanASI Technology) — PURPOSE: TypeScript orchestration framework (coordinator -> task DAG -> scheduler, approvals, checkpoints, tracing, run store, multi-provider LLM adapters, external agents via process/ACP).
STARS: ~6.9k — FORKS: ~2.4k — CONTRIBUTORS: multiple — LAST COMMIT: 2026-09-09 (a04c7bf) — LATEST RELEASE: @open-multi-agent/core 1.18.0 (2026-09-04) — LICENSE: MIT — SECURITY POLICY: supply-chain audit CI workflow present — ISSUES: 5 open — CI: yes, 168 test files, ~47k LOC core.
MAINTAINER REPUTATION: company-backed, active. TRUST TIER: 1.
RISKS: LLM agents need raw API keys (ANTHROPIC_API_KEY/OPENAI_API_KEY); this environment authenticates via Claude Code OAuth and `codex login`, so the planner/reviewer roles could not run without new credentials. Large surface (47k LOC) for an MVP whose heavy lifting is already done by the CLIs. BENEFITS: mature DAG scheduling, durable approvals, run journal; good reference for approval/checkpoint semantics.
DECISION: **REFERENCE_ONLY** — patterns for approvals, run journal and DAG waves reused conceptually; not installed (DEC-001).

## kingbootoshi/codex-orchestrator
REPOSITORY: https://github.com/kingbootoshi/codex-orchestrator — OWNER: kingbootoshi (individual) — PURPOSE: Claude Code plugin + CLI that launches Codex agents in tmux sessions, tracks jobs, sends follow-ups, captures results.
STARS: ~349 — FORKS: ~39 — CONTRIBUTORS: essentially 1 — LAST COMMIT: 2026-05-27 (035d581), 23 commits — LATEST RELEASE: none — LICENSE: MIT — SECURITY POLICY: none — ISSUES: 2 open.
MAINTAINER REPUTATION: single developer, some community traction. TRUST TIER: 2 (meets star/fork floor, but single maintainer, no releases, 3.5 months idle).
RISKS: requires tmux + bun; install script uses `sudo` package installs and `curl | bash` (bun installer); parses interactive TUI output instead of using `codex exec --json/--output-schema`. BENEFITS: job state machine, follow-up messaging, health check ideas.
DECISION: **REFERENCE_ONLY** — `codex exec --output-schema --output-last-message` gives structured results natively; tmux layer unnecessary.

## czlonkowski/fables
REPOSITORY: https://github.com/czlonkowski/fables — OWNER: Romuald Członkowski (author of n8n-mcp) — PURPOSE: prompt-only Claude Code/Codex plugins: fable-advisor/orchestrator and astra-advisor/orchestrator (consult-up / delegate-down protocols, model pinning, worker briefs).
STARS: ~23 — FORKS: ~2 — CONTRIBUTORS: 1 — LAST COMMIT: 2026-09-07 (914a31c), 12 commits — LATEST RELEASE: none — LICENSE: MIT — SECURITY POLICY: none — ISSUES: 0.
MAINTAINER REPUTATION: known individual developer. TRUST TIER: 2.
RISKS: young, low adoption; no code (Markdown/JSON only) so execution risk is nil; grep for risky patterns: none. BENEFITS: verified (2026-09-07) Codex CLI invocation for `gpt-6-astra` (`codex exec --model gpt-6-astra -c model_reasoning_effort=... --sandbox read-only --ephemeral --output-last-message`), worker-brief format, retry caps, "plan big, execute small".
DECISION: **USE_PARTIALLY** — patterns and CLI invocation shapes reused in `orchestrator/providers.mjs` and the worker/brain skills; not installed as a dependency. Audited by the Skill Curator (see `.ai/skills/audits/`).

## haowjy/orchestrate
REPOSITORY: https://github.com/haowjy/orchestrate — OWNER: haowjy (individual) — PURPOSE: shell-script multi-model primary-agent toolkit for Claude Code/Codex/OpenCode.
STARS: ~19 — FORKS: ~5 — CONTRIBUTORS: 1 — LAST COMMIT: 2026-03-01 (eb7bfb5) — LATEST RELEASE: none — LICENSE: MIT — SECURITY POLICY: none — ISSUES: 0.
MAINTAINER REPUTATION: individual; README states the project is being rewritten in Python elsewhere (meridian-channel). TRUST TIER: 3 (abandoned line).
RISKS: unmaintained; runs agents with `--dangerously-skip-permissions` / `--dangerously-bypass-approvals-and-sandbox` for "unrestricted" profiles. BENEFITS: run-artifact layout ideas only.
DECISION: **REJECT**.

## Summary
| Repo | Decision |
|---|---|
| anthropics/skills | USE_PARTIALLY (format reference) |
| open-multi-agent | REFERENCE_ONLY |
| codex-orchestrator | REFERENCE_ONLY |
| fables | USE_PARTIALLY (patterns) |
| orchestrate | REJECT |
