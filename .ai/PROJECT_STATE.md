# PROJECT STATE

## Current status
EuroGas CORE-7 parcialmente integrado en `feature/implementa-eurogas-usando-architecture-b-174246`: 5/20 tareas según el manager. QA solicita cambios. Especificación vigente: `ARCHITECTURE_BLUEPRINT_rev5.md`.

## Features done
- CostCore sin dependencias, tipos monetarios, parsing, redondeo, coste, reparto, ledger y ventana Free revisados estáticamente; Swift UNVERIFIED-BUILD.
- DDL v1 en `EuroGas/Packages/Persistence/Sources/Persistence/Migrations/v1_initial.sql`, verificado sobre SQLite real: 18/18, exit=0 según QA.

## In progress
Congelación de contratos, corrección de errores del núcleo y validación de la rama integrada.

## Blockers
- `npm test`: exit=1 en la rama integrada; causa desconocida por salida truncada.
- QA rechazada; aprobaciones humanas pendientes e intentos agotados. No repetir automáticamente.
- Swift sin compilación ni pruebas verificadas; autenticación actual de Codex desconocida.
- Xcode, iPhone, tracking de campo, StoreKit real y Live Activity: EXTERNO.

## Important debt
- Corregir afirmaciones VERIFIED obsoletas en STATUS.md y completar CONTRACTS.md con firmas, errores y ruta real del DDL.
- Sustituir abortos por errores tipados y rechazar repartos con total negativo.
- Revisar compensación entre grupos e identidad explícita de participantes en el reparto.
- Resolver referencias ADR no acreditadas. Deuda previa de `slugify`/`truncate` documentada en DEC-003.

## Pending decisions
Resolución humana consolidada de puertas de aprobación y reanudación tras fallos repetidos. GRDB y extras diferidos.

## Next priority
Resolver la escalación y reparar evidencia, contratos y núcleo; obtener suite integrada verde y nueva aprobación QA. Brain y Worker en Codex sin fallback. Sin deploy, TestFlight, compras reales, push ni producción.
