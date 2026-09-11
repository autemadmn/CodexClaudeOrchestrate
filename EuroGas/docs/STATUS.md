# EuroGas — cierre honesto del tramo

## Declaración de alcance

**Beta parcial: este tramo NO completa CORE-7 (§20.2).** Faltan el centro económico completo, persistencia, app y validación en dispositivo/campo.

## Evidencia de comandos

### Gate G0 — Swift — UNVERIFIED-BUILD

Comando ejecutado en Windows 11 (PowerShell):

```powershell
swift --version 2>&1; if (-not $?) { exit 1 }
```

Código de salida: `1`.

Salida literal:

```text
swift: 
Line |
   2 |  swift --version 2>&1; if (-not $?) { exit 1 }
     |  ~~~~~
     | The term 'swift' is not recognized as a name of a cmdlet, function, script file, or executable program.
Check the spelling of the name, or if a path was included, verify that the path is correct and try again.
```

No hay toolchain Swift disponible y no se instalará. No se ejecutaron `swift build` ni `swift test`; el código Swift queda **UNVERIFIED-BUILD**, nunca EXTERNO.

### Suite del repositorio — VERIFIED

Comando: `npm test`
Código de salida: `0`.

Salida final real:

```text
ℹ tests 35
ℹ pass 35
ℹ fail 0
```

Verifica el orquestador, no la compilación de CostCore.

### Gate G2 — esquema — UNVERIFIED-BUILD

La verificación se saltó porque `EuroGas/Packages/CostCore/v1_initial.sql` no existe todavía. No se pudo aplicar el DDL ni ejecutar los rechazos de constraints contra SQLite; no se afirma VERIFIED ni EXTERNO.

## Entregables

Cada fila tiene exactamente una etiqueta.

| Entregable | Etiqueta | Evidencia o limitación |
|---|---|---|
| Tipos monetarios y parsing (§5.1) | **UNVERIFIED-BUILD** | Código y tests escritos; falta toolchain Swift |
| CostCore completo (cálculo, reparto, ledger) | **UNVERIFIED-BUILD** | No implementado en el código congelado |
| Esquema v1 / G2 | **UNVERIFIED-BUILD** | Falta `v1_initial.sql`; causa indicada arriba |
| Suite del orquestador | **VERIFIED** | `npm test`: 35 pass, 0 fail, código 0 |
| Xcode | **EXTERNO** | Remisión a [FIELD_TESTS.md](FIELD_TESTS.md) |
| iPhone | **EXTERNO** | Remisión a [FIELD_TESTS.md](FIELD_TESTS.md) |
| Tracking de campo | **EXTERNO** | Remisión a [FIELD_TESTS.md](FIELD_TESTS.md) |
| StoreKit real | **EXTERNO** | Remisión a [FIELD_TESTS.md](FIELD_TESTS.md) |
| Live Activity | **EXTERNO** | Remisión a [FIELD_TESTS.md](FIELD_TESTS.md) |

Los cinco elementos EXTERNO no se han probado; sus procedimientos están en `FIELD_TESTS.md`.

## RECORTADO

- Motor de coste completo, reparto, ledger y persistencia: recortados; sólo existe el contrato monetario.
- `v1_initial.sql` y G2: recortados/no entregados.
- S3 (GPS y máquina de estados): recortado.

## Requisitos pendientes de CORE-7

- Implementar `CostInputs`, `CostBreakdown`, `SplitRule`, `SplitResult`, cálculo, reparto y ledger.
- Entregar `v1_initial.sql` y ejecutar G2 con constraints contra SQLite real.
- Implementar snapshots, viaje, `ActiveTripState`, app, routing y recuperación.
- Implementar cuentas/grupos, pagos, StoreKit 2/ProGate, Live Activity y pruebas de campo.
- Completar build integrada y matriz de aceptación de §20.2.

## Siguiente ticket

Asignar el siguiente `TASK-NNN` para núcleo económico y pruebas; después, persistencia y G2. T02/T03 son nombres de especificación, no tickets asignados.

## Handoff §19.4

```text
Ticket: TASK-021 / cierre QA de CONTRACTS.md, STATUS.md y FIELD_TESTS.md
Commit/branch: agent/TASK-021 (commit lo realizará el orquestador)
Archivos modificados: EuroGas/docs/CONTRACTS.md; EuroGas/docs/STATUS.md; EuroGas/docs/FIELD_TESTS.md
Contrato consumido o modificado: API real de Money.swift; v1_initial.sql fijado como única fuente canónica, no entregado
Build/test ejecutado y resultado: npm test — PASS, 35 pass, 0 fail, código 0; swift --version — código 1, salida literal arriba
Prueba manual necesaria: procedimientos Xcode, iPhone, tracking de campo, StoreKit real y Live Activity en FIELD_TESTS.md
Bloqueo o limitación: falta toolchain Swift y v1_initial.sql; Beta parcial, NO completa CORE-7
Próximo ticket: asignar TASK-NNN para núcleo económico y pruebas; luego persistencia y G2
```
