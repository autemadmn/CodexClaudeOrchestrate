# PROJECT STATE

## Current status
EuroGas CORE-7: cierre de QA BLOCKED. Continuación en `feature/continua-el-trabajo-integrado-del-run-20-111714`, pendiente de verificar su base. Especificación: `ARCHITECTURE_BLUEPRINT_rev5.md`. Este intento integró 0/5 tareas; tests y QA no ejecutados.

## Features done
Trabajo previo de CostCore, CostEngine, SplitEngine, ledger y Persistence conservable según los informes recibidos. SQLite previo: 18/18 según QA anterior; no revalidado en este intento. Todo Swift: UNVERIFIED-BUILD.

## In progress
Errores tipados capturables, rechazo de total negativo, actualización de pruebas, contratos literales y evidencia de STATUS.md.

## Blockers
Dependencias insatisfacibles en TASK-023..025; TASK-026 depende de TASK-025. Puerta humana de TASK-025 sin fundamento especificado. Sin QA actual.

## Important debt
Verificar integración previa y commit `02fc09c`; ejecutar npm test y arnés SQLite. Acreditar ADR y usar exclusivamente `EuroGas/Packages/Persistence/Sources/Persistence/Migrations/v1_initial.sql`. No presentar resultados históricos como evidencia actual.

## Pending decisions
Brain aprueba las firmas throws, rechazo de total negativo, eliminación asociada de SplitRejection y ruta canónica. Registrar ADR sin presumir identificadores. Identificar cualquier acción humana real detrás de TASK-025.

## Next priority
Resolver bloqueos del manager, completar únicamente los defectos finales y obtener QA aprobada. Apple/Xcode/iPhone: EXTERNO. Brain y Worker: Codex sin fallback. Sin instalaciones, dependencias nuevas, push, deploy, TestFlight, compras reales ni producción.
