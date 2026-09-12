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

<!-- run 20260911-134615 -->
## Run log
- 2026-09-11 — Smoke test run: added `orchestrator/test/util.test.mjs` (15 tests for `slugify()`/`truncate()`). QA approved round 1, `npm test` green. Confirms M0; branch `feature/smoke-test-add-unit-tests-for-the-slugif-134615` awaits human merge.

<!-- run 20260911-174246 -->
## EuroGas — CORE-7
- Producto elegido: EuroGas; especificación vigente `ARCHITECTURE_BLUEPRINT_rev5.md`.
- Avance parcial: paquete y tipos monetarios integrados; Swift UNVERIFIED-BUILD. QA pendiente de aprobación.
- Prioridad: resolver aprobaciones y fallos repetidos; completar contratos, coste, reparto, ledger y SQLite con pruebas críticas.
- Validaciones Apple y de campo: EXTERNO. Brain y Worker en Codex sin fallback.
