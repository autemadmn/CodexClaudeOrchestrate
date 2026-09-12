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

<!-- run 20260911-174246 -->
## EuroGas CORE-7 — cierre parcial
- 5/20 tareas integradas; M1 sigue abierto y QA solicita cambios.
- SQLite real: 18/18, exit=0. Swift: UNVERIFIED-BUILD. Suite del orquestador integrada: exit=1, causa pendiente.
- Prioridad: resolver escalación humana, corregir contratos y evidencia, reparar errores del núcleo y repetir QA.
- GRDB y extras diferidos; validaciones Apple y de campo EXTERNO. Brain y Worker en Codex sin fallback.

<!-- run 20260912-111714 -->
## EuroGas CORE-7 — cierre QA bloqueado
- Continuación: 0/5 tareas integradas; tests y QA no ejecutados. M1 sigue abierto.
- Brain aprueba errores tipados con throws, rechazo de total negativo y ruta canónica del DDL; ADR pendientes de registro.
- Prioridad: resolver dependencias y puerta de TASK-025, verificar la base, completar correcciones y obtener evidencia actual y QA aprobada.
- Swift: UNVERIFIED-BUILD. Apple/Xcode/iPhone: EXTERNO. Brain y Worker en Codex sin fallback.

<!-- run 20260912-111714 -->
## EuroGas CORE-7 — cierre QA aprobado
- Este estado sustituye las entradas anteriores de cierre parcial o bloqueado: 5/5 tareas de continuación integradas; QA aprobada con 22 criterios satisfechos.
- Evidencia actual: npm test 35/35 y SQLite 18/18, ambos exit=0. Errores tipados, rechazo de total negativo y contratos completados.
- Cierre del alcance QA: SUCCESS. Swift permanece UNVERIFIED-BUILD; Apple/Xcode/iPhone y campo: EXTERNO. No implica validación completa del MVP.
- Próximo paso: corregir dos detalles menores de STATUS.md. ADR aprobados en contenido, registro pendiente de confirmar.
- Brain y Worker en Codex sin fallback; se mantienen las restricciones operativas del objetivo.
