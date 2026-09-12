# EuroGas CORE-7 — Tramo 1: contratos, CostCore (dinero/reparto/ledger) y esquema v1 verificable

# EuroGas CORE-7 — Tramo 1

Fuente de verdad: `ARCHITECTURE_BLUEPRINT_rev5.md` (rev. 5, 11-09-2026). Cada regla cita su sección. Si esta spec y el blueprint difieren, manda el blueprint y se escala.

## Continuidad (trabajo previo que se conserva)
Este run ya produjo un pase de arquitectura: **DEC-004** (no crear `EuroGas.xcodeproj` ni target App aquí), **DEC-005** (esquema v1 como DDL SQL canónico, sin capa GRDB todavía), **DEC-006** (taxonomía VERIFIED / UNVERIFIED-BUILD / EXTERNO), **DEC-007** (tipos monetarios nominales distintos). Siguen vigentes y **no se vuelven a decidir**. Esta spec las implementa.

## Estado de partida (verificado por inspección)
El repositorio **no contiene código de EuroGas**: no existen `EuroGas/`, `Packages/` ni `docs/`; 0 ficheros Swift. Lo único presente es el orquestador (`orchestrator/*.mjs`, `bin/`, `.ai/`), que **no se toca**. Host: Windows 11, sin Xcode, sin Mac, sin iPhone. Node ≥ 22 disponible (`package.json` engines).

## Objetivo
Entregar el tramo de CORE-7 **verificable en este host**: contratos congelados (§19.3), estructura real de paquetes (§4.3) y el núcleo económico —dinero, cálculo, reparto, ledger y esquema de datos— con pruebas ejecutadas de verdad.

## No-objetivos
`EuroGas.xcodeproj` y target App, SwiftUI/ViewModels, CoreLocation, MapKit/RoutingService, ActivityKit/Live Activity, StoreKit/paywall, Widgets, VehicleDB, `tools/vehicle-db`, inglés, CSV, EXTRA-7 y NEXT. Prohibidos: deploy, TestFlight, compras reales, push, cambios de producción.

## Taxonomía de verificación (obligatoria, DEC-006)
Cada entregable lleva en `EuroGas/docs/STATUS.md` exactamente una etiqueta:
- **VERIFIED** — comando ejecutado en este host, con salida real.
- **UNVERIFIED-BUILD** — código escrito, no compilado aquí por falta de toolchain. **No es EXTERNO.**
- **EXTERNO** — depende de Apple/hardware/credenciales (Xcode, iPhone, campo, StoreKit real, Live Activity).

Prohibido VERIFIED sin salida de comando; prohibido llamar EXTERNO a lo que sólo falta por no haber toolchain local.

## Gate G0 (primera acción, bloqueante para el etiquetado)
Ejecutar `swift --version` y registrar la salida literal en STATUS.md.
- **Con toolchain:** `swift build` y `swift test` de CostCore son obligatorios y deben pasar → VERIFIED.
- **Sin toolchain:** NO instalar nada (requiere aprobación humana). El código se escribe igual, se etiqueta UNVERIFIED-BUILD, y la verificación del esquema (G2) queda como única prueba VERIFIED del tramo.

## Gate G2 (esquema)
Aplicar el DDL v1 contra un SQLite real disponible en el host (propuesta: módulo integrado `node:sqlite`, cero dependencias nuevas) y ejecutar los tests de rechazo de constraints. Si el módulo no está disponible en el Node instalado, el esquema queda UNVERIFIED y **se dice**; no se añade ninguna dependencia sin aprobación.

## Niveles de alcance (recortar por la cola, nunca por el centro)
**S1 — obligatorio**
1. `EuroGas/Packages/CostCore/{Sources,Tests}` con `Package.swift` (swift-tools 6.0, **cero dependencias**, sólo Foundation) y `EuroGas/docs/{CONTRACTS.md,STATUS.md}`.
2. Tipos monetarios y parsing (§5.1).
3. Motor de coste (§5.2, §5.3).
4. Motor de reparto (§8).

**S2 — debería**
5. Ledger puro: saldos derivados, meses Europe/Madrid, ventana Free 30 días, propuesta de reparto de pago por grupos (§7.2, §9.3, §9.4, §10.1).
6. Esquema v1 como DDL SQL canónico + verificación contra SQLite real (§7.3, DEC-005).

**S3 — se recorta primero**
7. Filtro de fixes GPS puro (§11.3) y máquina de estados (§11.4), sin CoreLocation.

## Contrato monetario (§5.1, DEC-007)
Tipos nominales **distintos**, nunca intercambiables ni `Int64` desnudo:
- `MoneyCents` — importes finales (viaje, gasto, cargo, pago).
- `UnitPriceMilliEUR` — precio por L o kWh en milésimas de euro.
- Consumo e intermedios en `Decimal`; distancia `Double` en metros.
- `1,499 €/L → UnitPriceMilliEUR(1499)`; `14,99 € → MoneyCents(1499)`.

Parsing localizado explícito: se usa **sólo el separador decimal del `Locale` dado** (es-ES: coma). Se **rechaza** (no se «arregla»): separador de millares, más de un separador, >3 decimales en precio, >2 en importe, signo negativo, vacío, caracteres no numéricos. Errores tipados con mensaje corregible.

## Cálculo (§5.2)
```
effectiveConsumption = consumptionPer100 × realWorldFactor
energyUnits          = acceptedDistanceMeters / 100000 × effectiveConsumption
energyCostEUR        = energyUnits × unitPriceMilliEUR / 1000
energyCostCents      = roundHalfUp(energyCostEUR × 100)
tripTotalCents       = energyCostCents + Σ manualExpenseCents
```
Todo en `Decimal`, **un único redondeo final** half-up. Prohibido redondear por fix o por segmento: el coste se recalcula sobre el acumulado aceptado. Parámetros del viaje como snapshot: cambiar precio/consumo en Ajustes no altera viajes existentes. La cifra en vivo usa el mismo redondeo final (§5.2).

## Reparto (§8)
`SplitResult` contiene **sólo las partes finales, incluido el conductor; su suma ya es el total**. Prohibido un `driverExtra` que haya que sumar aparte.
- `everyone`: `q = total / n`, `r = total % n`; pasajeros `q`; conductor `q + r`.
- `passengersOnly`: exige ≥1 pasajero; `q = total / passengerCount`; los primeros `r` pasajeros reciben +1 céntimo por `sortOrder`; conductor 0.
- 1–8 personas. Total 0 → todas las partes 0 y **ningún asiento**.
- Determinista, partes no negativas; no se exige monotonía (399→400 es contraejemplo legítimo).

## Ledger puro (§7.2, §9.3, §9.4, §10.1)
Saldos **siempre derivados**, nunca almacenados: `balance = Σcargos − Σpagos`; `pending = max(balance,0)`; `credit = max(−balance,0)`. Un crédito en un grupo **no** compensa otro. Mes contable en `Europe/Madrid`, `[inicio(M), inicio(M+1))`; el viaje pertenece al mes de su inicio; `closing = opening + charges − payments`. Ventana Free: desde las 00:00 de hace 29 días hasta ahora; las estadísticas del mes consultan el periodo completo, no la ventana. Propuesta de pago: distribución determinista entre grupos con pendiente, ordenados por `createdAt` y luego `id`; la suma de partidas iguala el importe recibido; ninguna partida sin grupo.

## Esquema v1 (§7.3, DEC-005) — sólo tablas usadas
DDL canónico en `EuroGas/Packages/Persistence/Sources/Persistence/Migrations/v1_initial.sql`: FKs activas; `amountCents > 0`; `debtorID <> creditorID`; `charge ⇒ tripID NOT NULL AND paymentBatchID NULL`; `payment ⇒ paymentBatchID NOT NULL AND tripID NULL`; `groupID` obligatorio («Sin grupo» sustituye a NULL); índice único parcial de un solo owner; índice único parcial de un solo viaje activo/interrumpido; un solo cargo por persona y viaje; precio y consumo positivos; `endedAt >= startedAt`; índices de viaje por `startedAt`/`status` y de ledger por persona/grupo/`occurredAt` y por `tripID`. Sin `PeriodClose` ni `RefuelEvent`. Sin borrado automático de base ante cambio de esquema. **No** se escribe código GRDB en este tramo.

## Casos de referencia que deben pasar
| Entrada | Resultado exigido |
|---|---|
| 100 km; 6 L/100; f=1; 1,499 €/L | 6 L; 899 céntimos |
| 355 km; 6,1 L/100; f=1,20; 1,499 €/L | 25,986 L; 38,953014 €; **3895 céntimos** |
| 100 km; 18 kWh/100; f=1; 0,200 €/kWh | 18 kWh; 360 céntimos |
| 899 + peaje 250 | 1149 céntimos |
| 3420, 7, everyone | conductor 492; seis de 488 |
| 3420, 4, passengersOnly | conductor 0; tres de 1140 |
| 1000, 4, passengersOnly | conductor 0; 334, 333, 333 |
| 399, 4, everyone | conductor 102; tres de 99 |
| 400, 4, everyone | 100 cada uno |

## Bordes y errores
Precio o consumo ≤ 0 → error tipado. `passengersOnly` con 0 pasajeros → error, no reparto silencioso. >8 o <1 participantes → error. Conductor duplicado o ausente en named → error. Distancia negativa o no finita → error. Mes sin cargos → `closing = opening`. Fronteras DST de Europe/Madrid (marzo y octubre) verificadas explícitamente. Ningún camino borra datos por límite Free ni por revocación (§10.2).

## Cierre obligatorio
`EuroGas/docs/STATUS.md` lista, sin adornos: comandos ejecutados con salida resumida, qué quedó VERIFIED / UNVERIFIED-BUILD / EXTERNO / recortado, requisitos de CORE-7 pendientes y siguiente ticket (§19.2). **No se declara CORE-7 completado**: este tramo es una fracción de §2.1 y así debe decirse («Beta parcial», §20.2).

## Acceptance criteria
- G0 ejecutado primero: la salida literal de `swift --version` (éxito o error) queda registrada en EuroGas/docs/STATUS.md antes de etiquetar cualquier entregable.
- Existe EuroGas/Packages/CostCore/Package.swift con swift-tools 6.0 y CERO dependencias externas; CostCore no importa UI, CoreLocation, MapKit, GRDB ni StoreKit (verificable por grep: ningún import fuera de Foundation/Testing/XCTest).
- MoneyCents y UnitPriceMilliEUR son tipos nominales distintos (no typealias de Int64) y ninguna API pública de CostCore acepta o devuelve Int64 desnudo para dinero o precio (verificable por grep sobre firmas públicas).
- El motor de coste produce exactamente 899, 3895 y 360 céntimos para los tres casos de §5.3, y 1149 al sumar un gasto manual de 250; el caso de 355 km expone energyUnits = 25,986 y energyCostEUR = 38,953014 sin redondeo intermedio.
- No existe redondeo a céntimos por fix ni por segmento: test que acumula N segmentos y compara con el cálculo sobre la distancia total debe dar resultados idénticos; un único roundHalfUp final.
- SplitEngine cumple las cinco pruebas canónicas de §8.2 (3420/7 everyone; 3420/4 y 1000/4 passengersOnly; 399/4 y 400/4 everyone) con las partes exactas indicadas.
- Invariante de reparto probada con propiedad sobre al menos 500 combinaciones generadas (total 0..100000, n 1..8, ambas reglas): suma(shares) == total, todas las partes >= 0, resultado determinista y, en passengersOnly, parte del conductor 0.
- SplitResult no expone ningún campo que deba sumarse aparte de las partes (sin driverExtra); total 0 produce todas las partes 0 y ningún asiento.
- Parsing localizado: '1,499' en es-ES da UnitPriceMilliEUR(1499); '1.499', '1,4,9', '1,4999', '' y '-1,5' son RECHAZADOS con error tipado y mensaje corregible, no reinterpretados.
- Ledger: balance/pending/credit se derivan en cada consulta y no existe ningún campo de saldo almacenado; test explícito con dos grupos demuestra que un crédito en uno no reduce el pendiente del otro.
- Meses en Europe/Madrid: límites [inicio(M), inicio(M+1)), closing = opening + charges - payments, mes sin cargos devuelve closing == opening, y hay test explícito en las fronteras DST de marzo y octubre.
- Ventana Free: devuelve desde las 00:00 de hace 29 días en la zona contable hasta ahora; test que demuestra que el total del mes NO disminuye cuando un viaje sale de la ventana visible.
- Propuesta de distribución de pago: determinista por createdAt y luego id, suma de partidas == importe recibido, ninguna partida sin grupo; el ejemplo de §9.3 (12 € Trabajo + 8 € Universidad, pago de 15 € = 12+3) deja Trabajo 0 y Universidad 5.
- El DDL v1 se aplica sin errores sobre SQLite real y los tests demuestran que se RECHAZA: amountCents = 0, debtorID == creditorID, charge con paymentBatchID, payment con tripID, groupID NULL, segundo owner, segundo viaje activo/interrumpido, cargo duplicado por persona+viaje, precio o consumo <= 0, y endedAt < startedAt.
- El DDL v1 no contiene tablas no utilizadas en este tramo (sin PeriodClose ni RefuelEvent) ni ninguna sentencia de borrado automático de base ante cambio de esquema.
- La verificación del DDL usa un SQLite real sin añadir dependencias al proyecto; si el SQLite del host no está disponible, el esquema se etiqueta UNVERIFIED con la causa registrada y NO se instala nada.
- Si hay toolchain Swift: `swift build` y `swift test` de CostCore se ejecutan y pasan, con su salida registrada. Si no lo hay: TODO el código Swift queda UNVERIFIED-BUILD, nunca EXTERNO ni VERIFIED, y no se instala ningún toolchain.
- EuroGas/docs/CONTRACTS.md congela las firmas de MoneyCents, UnitPriceMilliEUR, CostInputs/CostBreakdown, SplitRule/SplitResult, los errores tipados y el DDL v1 como única definición de esquema, con propietario de archivo por cada uno.
- EuroGas/docs/STATUS.md declara explícitamente que este tramo NO completa CORE-7, enumera lo VERIFIED / UNVERIFIED-BUILD / EXTERNO / recortado y lista los requisitos de CORE-7 pendientes.
- Xcode, instalación en iPhone, tracking de campo, StoreKit real y Live Activity aparecen como EXTERNO con procedimiento pendiente y NO se afirman probados en ningún documento, commit ni resumen.
- Las decisiones DEC-004, DEC-005, DEC-006 y DEC-007 se respetan y no se duplican con ADRs nuevos equivalentes.
- El orquestador no se modifica: orchestrator/**, bin/**, package.json, .ai/config.json y .ai/skills/registry.json quedan intactos y `npm test` sigue en verde.
