# Managers

Claude Opus managers (configured in `.ai/config.json`, role `manager`):

| Manager | Skill | Mode | Tools |
|---|---|---|---|
| PRODUCT_ARCHITECT_MANAGER | `.claude/skills/product-architect-manager` | spec, ADR candidates, escalation flags | read-only |
| IMPLEMENTATION_MANAGER | `.claude/skills/implementation-manager` | task planning + per-task diff review | read-only |
| QA_MANAGER | `.claude/skills/qa-manager` | final QA on the integrated diff | read-only |
| SKILL_CURATOR (capability) | `.claude/skills/skill-curator` | `agents skills audit/approve` | read-only + clone dir |

Managers never edit files directly: the orchestrator applies their JSON decisions (writes specs/ADRs, creates tasks, merges branches). Workers implement.
