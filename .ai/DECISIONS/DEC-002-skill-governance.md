# DEC-002 Skill governance: managers curate, workers consume

## Context
External Skills are untrusted software until audited. Workers (Codex) must never fetch or install code.

## Decision
Only Claude Opus managers (skill-curator capability) may discover, audit, pin, install, update or remove Skills. Every approved Skill is recorded in `.ai/skills/registry.json` with source, commit, trust tier, audit and findings. Tier 0/1 can be approved by a manager; Tier 2 requires Brain approval; Tier 3 is rejected. The command surface is `agents skills audit|approve|list`.

## Reason
Supply-chain safety and minimum privilege.

## Alternatives
Letting workers install what they need (rejected: uncontrolled supply chain).

## Consequences
Adding a Skill takes an explicit audit step; workers get capabilities only through the registry.
