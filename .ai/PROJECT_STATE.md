# PROJECT STATE

## Current status
EuroGas CORE-7 parcialmente integrado en `feature/implementa-eurogas-usando-architecture-b-174246`: 3/20 tareas. QA solicita cambios. Especificación vigente: `ARCHITECTURE_BLUEPRINT_rev5.md`.

## Features done
- Orquestador operativo; `npm test` pasa 35/35.
- Paquete CostCore y tipos monetarios, parsing y redondeo revisados estáticamente. Swift: UNVERIFIED-BUILD.

## In progress
- Contratos completos, CostEngine, SplitEngine, ledger, ventana Free, distribución de pagos y persistencia SQLite con pruebas críticas.

## Blockers
- Aprobaciones humanas pendientes e intentos agotados; no repetir automáticamente.
- Test SQLite falla por arnés inexistente; G2 no ejecutado.
- Swift no verificado en este host; autenticación actual de Codex desconocida. Brain y Worker requieren Codex sin fallback.
- Validación Xcode, iPhone, tracking de campo, StoreKit real y Live Activity: EXTERNO.

## Important debt
- Completar contratos y unificar la ruta del DDL en `EuroGas/Packages/Persistence/Sources/Persistence/Migrations/v1_initial.sql`.
- Corregir alcances de archivos y derivar constantes esperadas antes de fijar pruebas.
- Deuda previa de `slugify`/`truncate` documentada en DEC-003.

## Pending decisions
- Resolución humana de puertas de aprobación y fallos repetidos.
- Condiciones de integración adicional de Swift sin compilación verificada.

## Next priority
Resolver la escalación consolidada y reanudar el núcleo económico y la persistencia, conservando lo correcto y aportando evidencia ejecutada. Sin deploy, TestFlight, compras reales, push ni producción.
