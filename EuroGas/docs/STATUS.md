# EuroGas — cierre honesto del tramo

## Declaración de alcance

**Beta parcial: este tramo NO completa CORE-7 (§20.2).** El ledger derivado y `v1_initial.sql` están escritos y el arnés G2 se verifica contra SQLite real; también faltan app y validación en dispositivo/campo.

## Taxonomía de etiquetas (DEC-006)

- **VERIFIED** — comando ejecutado en este host y salida real registrada en este documento.
- **UNVERIFIED-BUILD** — código escrito, pero no compilado aquí por falta de toolchain Swift; no es EXTERNO.
- **UNVERIFIED** — entregable no entregado o verificación omitida; no es VERIFIED ni EXTERNO. En G2 se conserva la causa explícita.
- **EXTERNO** — depende de Apple, hardware, credenciales o pruebas de campo; su procedimiento está en `FIELD_TESTS.md`.
- **NO ENTREGADO** — entregable que todavía no existe en el código congelado; puede formar parte de lo RECORTADO.

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

La salida íntegra, sin truncar, está archivada en [`evidence-npm-test.txt`](../../.ai/RUNS/20260912-111714/evidence-npm-test.txt). Resumen final real:

```text
ℹ tests 35
ℹ pass 35
ℹ fail 0
```

Verifica el orquestador, no la compilación de CostCore.

### Gate G2 — esquema — VERIFIED

Comando ejecutado: `node --test EuroGas/Packages/Persistence/Tests/PersistenceTests/schema_v1.test.mjs` (código de salida `0`). La salida íntegra, sin truncar, está archivada en [`evidence-sqlite-harness.txt`](../../.ai/RUNS/20260912-111714/evidence-sqlite-harness.txt). No hubo aviso de módulo experimental en este Node.
Resumen final de la salida real:
```text
✔ PRAGMA foreign_keys está activo
✔ control positivo: inserción válida
✔ control positivo: segundo Trip completed
✔ control positivo: cargo de otra persona en el mismo viaje
✔ Group.createdAt existe y es NOT NULL
✔ schema rechaza amountCents = 0
✔ schema rechaza debtorID == creditorID
✔ schema rechaza charge con paymentBatchID
✔ schema rechaza payment con tripID
✔ schema rechaza groupID NULL
✔ schema rechaza segundo owner
✔ schema rechaza segundo viaje active/interrupted
✔ schema rechaza cargo duplicado por persona+viaje
✔ schema rechaza precio <= 0
✔ schema rechaza consumo <= 0
✔ schema rechaza endedAt < startedAt
✔ schema rechaza FK inexistente
✔ borrar Trip con cargos está restringido
ℹ tests 18
ℹ pass 18
ℹ fail 0
ℹ skipped 0
```
El arnés aplicó el texto íntegro de `v1_initial.sql` a una base `:memory:`, comprobó `PRAGMA foreign_keys = 1` y rechazó los trece casos de integridad; los tres controles positivos también pasaron.

## Entregables

Cada fila tiene exactamente una etiqueta.

| Entregable | Etiqueta | Evidencia o limitación |
|---|---|---|
| Tipos monetarios y parsing (§5.1) | **UNVERIFIED-BUILD** | Código y tests escritos; falta toolchain Swift |
| CostEngine y SplitEngine (§5, §8) | **UNVERIFIED-BUILD** | Este run añade CostCoreError, validación mediante errores tipados en CostEngine y rechazo de total negativo en SplitEngine; código y tests no compilados ni ejecutados en este host por falta de toolchain Swift |
| Ledger y persistencia | **UNVERIFIED-BUILD** | Código Swift y sus tests escritos; no compilados por falta de toolchain Swift |
| Esquema v1 / G2 | **VERIFIED** | Arnés SQLite real: 18 pass, 0 fail, código 0; salida íntegra en [`evidence-sqlite-harness.txt`](../../.ai/RUNS/20260912-111714/evidence-sqlite-harness.txt) |
| Suite del orquestador | **VERIFIED** | `npm test`: 35 pass, 0 fail, código 0; salida íntegra en [`evidence-npm-test.txt`](../../.ai/RUNS/20260912-111714/evidence-npm-test.txt) |
| Xcode | **EXTERNO** | Remisión a [FIELD_TESTS.md](FIELD_TESTS.md) |
| iPhone | **EXTERNO** | Remisión a [FIELD_TESTS.md](FIELD_TESTS.md) |
| Tracking de campo | **EXTERNO** | Remisión a [FIELD_TESTS.md](FIELD_TESTS.md) |
| StoreKit real | **EXTERNO** | Remisión a [FIELD_TESTS.md](FIELD_TESTS.md) |
| Live Activity | **EXTERNO** | Remisión a [FIELD_TESTS.md](FIELD_TESTS.md) |

Los cinco elementos EXTERNO no se han probado; sus procedimientos están en `FIELD_TESTS.md`.

## Run 20260912-111714 — cierre de correcciones QA

Los segmentos suman 355000 m y comparan `energyUnits`, `energyCostEUR` y `energyCostCents`; los valores Decimal de consumo y factor se construyen desde cadenas; `roundHalfUp` mantiene una única llamada desde Cost; y la distancia valida `isFinite` antes de convertir. La validación de `passengersOnly`, del rango de participantes y del total negativo se realiza mediante errores tipados capturables (`CostCoreError`) lanzados antes del caso de total cero, sin `precondition`. CostCoreError, los cambios de CostEngine y SplitEngine y sus tests tampoco se han compilado ni ejecutado en este host: quedan **UNVERIFIED-BUILD**, no EXTERNO.

Los contratos quedan congelados aquí: [`CONTRACTS.md`](CONTRACTS.md) ya transcribe las declaraciones contra el código real, incluidos CostCoreError, CostEngine, SplitEngine, ledger, errores tipados y el DDL v1 canónico. Este estado documental no afirma que el código Swift compile ni que se haya ejecutado.

## RECORTADO

- S3 (GPS y máquina de estados): recortado.

## Requisitos pendientes de CORE-7

- Integrar la capa de persistencia Swift/GRDB sobre el DDL v1.
- Implementar snapshots, viaje, `ActiveTripState`, app, routing y recuperación.
- Implementar cuentas/grupos, pagos, StoreKit 2/ProGate, Live Activity y pruebas de campo.
- Completar build integrada y matriz de aceptación de §20.2.

## Siguiente ticket

Asignar el siguiente `TASK-NNN` para la capa Swift/GRDB de Persistence. T02/T03 son nombres de especificación, no tickets asignados.

## Handoff §19.4

```text
Ticket: TASK-026 / evidencia real y handoff de STATUS.md
Commit/branch: feature/continua-el-trabajo-integrado-del-run-20-111714 (commit integrado 02fc09c)
Archivos modificados: EuroGas/docs/STATUS.md; .ai/RUNS/20260912-111714/evidence-npm-test.txt; .ai/RUNS/20260912-111714/evidence-sqlite-harness.txt
Contrato consumido o modificado: CONTRACTS.md congelado contra el código real; v1_initial.sql fijado como única fuente canónica
Build/test ejecutado y resultado: `npm test` — VERIFIED, 35 pass, 0 fail, código 0, salida íntegra en evidence-npm-test.txt; arnés SQLite — VERIFIED, 18 pass, 0 fail, código 0, salida íntegra en evidence-sqlite-harness.txt; `swift --version` — código 1, salida literal arriba
Prueba manual necesaria: procedimientos Xcode, iPhone, tracking de campo, StoreKit real y Live Activity en FIELD_TESTS.md
Bloqueo o limitación: falta toolchain Swift; el código Swift, incluidos CostCoreError, CostEngine, SplitEngine y sus tests, permanece UNVERIFIED-BUILD; Xcode, iPhone, tracking de campo, StoreKit real y Live Activity permanecen EXTERNO; Beta parcial, NO completa CORE-7
Próximo ticket: capa Swift/GRDB de Persistence sobre el DDL canónico
```
