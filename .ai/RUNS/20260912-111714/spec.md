# Cierre de defectos finales de QA del run 20260911-174246: errores tipados en CostCore, rechazo de total negativo y contratos/estado fieles

# Cierre acotado de defectos QA (run 20260911-174246)

## Objetivo
Cerrar exclusivamente los tres defectos finales de la QA ronda 5 (`.ai/RUNS/20260911-174246/qa-report-round5.json`) conforme a `ARCHITECTURE_BLUEPRINT_rev5.md`:
1. El núcleo aborta el proceso con `precondition` donde el blueprint §5.1 exige validación de rangos con mensajes corregibles → errores tipados capturables.
2. `SplitEngine.split` con total negativo devuelve `shares` vacío, rompiendo la invariante §8.2 «la suma de shares ya es el total» → rechazo explícito.
3. `EuroGas/docs/CONTRACTS.md` describe una API que no coincide con el código y apunta a una ruta de DDL inexistente; `EuroGas/docs/STATUS.md` arrastra evidencia y deuda desfasadas.

## Scope
- `EuroGas/Packages/CostCore/Sources/CostCore/Models/CostCoreError.swift` (nuevo).
- `Cost/CostEngine.swift`, `Split/SplitEngine.swift` (sólo validación → `throws`; fórmulas y valores intactos).
- `Tests/CostCoreTests/{CostEngineTests,SplitEngineTests,SplitPropertyTests}.swift`.
- `EuroGas/docs/CONTRACTS.md` (reescritura completa), `EuroGas/docs/STATUS.md` (evidencia y deuda).
- Evidencia de ejecución (`npm test`, arnés SQLite) en el directorio del run.

## Non-goals
- No cambiar fórmulas de coste, algoritmo de reparto, `LedgerMath`, `MonthlyStatement`, `AccountingPeriod`, `FreeWindow`, `PaymentAllocationProposal` ni el DDL v1.
- No añadir identidad de persona a `SplitResult` ni retirar `netAcrossGroups` (deuda registrada, fuera de alcance).
- No tocar `orchestrator/**`, `bin/**`, `package.json`, `.ai/config.json`, `.ai/skills/registry.json`, `.gitignore`.
- Sin dependencias, toolchains, GRDB, targets Apple, migraciones nuevas, push, deploy ni producción.

## Comportamiento

### 1. `CostCoreError` (nuevo, público)
Enum `Error, Equatable, LocalizedError` con `errorDescription` en español que indique cómo corregir (§5.1, §6.3). Casos exigidos:
`nonPositivePrice`, `nonPositiveConsumption`, `nonPositiveFactor`, `invalidDistance`, `participantCountOutOfRange(Int)`, `passengersOnlyWithoutPassengers`, `negativeTotal`.
Vive en `Models/CostCoreError.swift`; no reemplaza ni duplica `MoneyParsingError`.

### 2. `CostInputs.init` → `throws`
Sustituye los dos `precondition` actuales (CostEngine.swift:17-18) por lanzamientos:
- `distanceMeters` no finita o `< 0` → `invalidDistance`.
- `consumptionPer100 <= 0` → `nonPositiveConsumption`.
- `realWorldFactor <= 0` → `nonPositiveFactor`.
- `unitPriceMilliEUR.milliEUR <= 0` → `nonPositivePrice`.
Orden de comprobación: distancia, consumo, factor, precio (determinista y verificable en test).
`distanceMeters == 0` sigue siendo válido (coste 0).

### 3. `CostEngine` → ambas sobrecargas `throws`
- `calculate(_ input: CostInputs) throws -> CostBreakdown`.
- `calculate(segmentDistancesMeters:consumptionPer100:realWorldFactor:unitPriceMilliEUR:manualExpenses:) throws -> CostBreakdown`: cualquier segmento no finito o negativo → `invalidDistance` **antes** de construir `CostInputs`.
- `energy(for:...)`: el `precondition` y el `preconditionFailure("distancia no convertible a Decimal")` (líneas 70-73) pasan a `throw CostCoreError.invalidDistance`; `energy` y la ruta que la llama se declaran `throws`.
- Invariantes preservadas: un único `roundHalfUp` final, acumulación en `Decimal` sin redondeo por segmento, equivalencia exacta entre N segmentos y distancia total, y los casos §5.3: 899, 3895 (con `energyUnits` 25.986 y `energyCostEUR` 38.953014), 360 y 1149 céntimos.

### 4. `SplitEngine.split` → `throws`
Firma: `static func split(total: MoneyCents, people: Int, rule: SplitRule) throws -> SplitResult`.
Orden y semántica:
1. `people < 1 || people > 8` → `participantCountOutOfRange(people)`.
2. `rule == .passengersOnly && people == 1` → `passengersOnlyWithoutPassengers`.
3. `total.cents < 0` → `negativeTotal` (antes: `shares` vacío; defecto).
4. `total.cents == 0` → `SplitResult(shares: [])` (sin asientos, §8.2).
5. Resto: algoritmo actual sin cambios (everyone: conductor `q + remainder`; passengersOnly: conductor 0 y los primeros `remainder` pasajeros +1 céntimo).
El par interno `SplitRejection` / `rejectionReason` deja de existir: su única función era hacer testeable un `precondition`, y el error tipado lo sustituye. Índice 0 = conductor, convención posicional que debe quedar documentada.

### 5. Tests (mismos ficheros, XCTest)
- Todos los llamantes existentes pasan a `try` (los tests son los únicos llamantes del núcleo en el repo; no hay código de producción que adaptar).
- `XCTAssertThrowsError` + comprobación del caso concreto (`as? CostCoreError`) para: precio ≤ 0, consumo ≤ 0, factor ≤ 0, distancia negativa, distancia no finita (`.infinity` y `.nan`), segmento negativo en la sobrecarga de segmentos, `people = 0`, `people = 9`, `passengersOnly` con 1 participante, y total negativo.
- Se conservan sin cambio de valores esperados las cinco pruebas canónicas §8.2, los casos §5.3 y la equivalencia segmentos/total.
- `SplitPropertyTests`: ≥ 500 combinaciones (hoy 1000 × 2 reglas), mismo generador determinista; se mantiene suma(shares) == total, partes ≥ 0, determinismo y conductor 0 en `passengersOnly`; se añade al menos un caso de total negativo que espera `negativeTotal`.

### 6. `CONTRACTS.md` (reescritura literal)
Transcribe sólo símbolos que existen literalmente tras el cambio: `costModelVersion`; `roundHalfUp`; `MoneyCents`; `UnitPriceMilliEUR`; `CostInputs`; `CostBreakdown`; ambas sobrecargas `throws` de `CostEngine.calculate`; `SplitRule`; `SplitResult`; `SplitEngine.split` `throws`; `PersonID`/`GroupID`/`TripID`/`PaymentBatchID`; `LedgerEntry` (+ `Kind`); `LedgerMath` (`balance`, `pending`, `credit`, `netAcrossGroups` marcado como diagnóstico que no debe mostrarse como saldo, §7.2); `AccountingPeriod` (`bounds`, `accountingMonth`); `FreeWindow.visibleRange`; `MonthlyStatement` (ambos init + `build`); `GroupPending`; `PaymentAllocationProposal.propose` (ambas sobrecargas). Errores: `MoneyParsingError`, `CostCoreError`, `PaymentAllocationError`, `AccountingPeriodError`, `FreeWindowError`.
Debe: (a) eliminar la frase que niega la existencia de `CostInputs`/`CostBreakdown`/`SplitRule`/`SplitResult`; (b) documentar la invariante «suma(shares) == total, no existe driverExtra» y la convención posicional del conductor; (c) fijar `EuroGas/Packages/Persistence/Sources/Persistence/Migrations/v1_initial.sql` como única definición canónica del esquema v1, existente y verificado, y borrar toda referencia a `EuroGas/Packages/CostCore/v1_initial.sql`; (d) declarar que cualquier binding futuro debe ejecutar ese mismo texto SQL (DEC-005, DEC-008); (e) actualizar la tabla de propiedad de archivos para cubrir `Cost/`, `Split/`, `Ledger/`, `Models/`, `Persistence/Migrations/`, `Persistence/Tests/`; (f) mantener `LocationProvider`, `RoutingService`, `PurchaseAccess`, `ActiveTripState` como PENDIENTE.
`PaymentAllocation` es matemática local: sin pagos reales, billing ni credenciales. Decirlo explícitamente.

### 7. `STATUS.md` (evidencia actual)
- `npm test`: publicar 35/35, exit 0 como **VERIFIED** únicamente con la salida real de una ejecución sobre esta rama, adjuntada íntegra (sin truncar) en el directorio del run. Si el resultado difiere, registrar el real y bloquear; nunca etiquetar VERIFIED sin salida.
- Arnés SQLite: 18/18, exit 0, **VERIFIED**.
- Todo Swift (tipos monetarios, Cost, Split, ledger, y los cambios de esta tarea) permanece **UNVERIFIED-BUILD**; Xcode, iPhone, tracking de campo, StoreKit real y Live Activity permanecen **EXTERNO** con remisión a `FIELD_TESTS.md`.
- Sustituir el párrafo que declara `CONTRACTS.md` incompleto y diferido a otro ticket por la constatación de que los contratos quedan congelados aquí.
- Actualizar el bloque de handoff §19.4 para que coincida con la sección de evidencias, y mantener la declaración «no completa CORE-7».
- No afirmar causas no verificadas (p. ej. del fallo histórico de `npm test`): si la causa no se comprueba, escribirlo como no identificada.

## Bordes y errores
- Total 0 → sin asientos; total negativo → error. Distancia 0 válida; distancia `nan`/`inf`/negativa → error.
- `people` en 1..8 inclusive; `passengersOnly` con 1 → error aun con total 0 (la validación de participantes precede al caso de total cero).
- Ningún `precondition`/`preconditionFailure`/`fatalError` queda en rutas de validación de entrada de `CostEngine.swift` ni `SplitEngine.swift`.
- Swift no se compila en este host: no afirmar compilación ni ejecución de estos cambios.

## Acceptance criteria
- Existe EuroGas/Packages/CostCore/Sources/CostCore/Models/CostCoreError.swift con un enum público `CostCoreError: Error, Equatable, LocalizedError` que incluye exactamente los casos nonPositivePrice, nonPositiveConsumption, nonPositiveFactor, invalidDistance, participantCountOutOfRange(Int), passengersOnlyWithoutPassengers y negativeTotal, cada uno con errorDescription no nulo y corregible en español.
- Un grep de `precondition`, `preconditionFailure` y `fatalError` sobre Cost/CostEngine.swift y Split/SplitEngine.swift devuelve cero coincidencias en rutas de validación de entrada.
- CostInputs.init es `throws` y lanza invalidDistance (distancia no finita o negativa), nonPositiveConsumption, nonPositiveFactor y nonPositivePrice; distanceMeters == 0 sigue siendo entrada válida.
- Ambas sobrecargas de CostEngine.calculate son `throws`; la sobrecarga de segmentos lanza invalidDistance si algún segmento es no finito o negativo, y la conversión interna de distancia a Decimal lanza invalidDistance en lugar de abortar.
- SplitEngine.split es `throws` y lanza, en este orden, participantCountOutOfRange(people) para people < 1 o > 8, passengersOnlyWithoutPassengers para passengersOnly con people == 1, y negativeTotal para total.cents < 0; con total.cents == 0 sigue devolviendo SplitResult(shares: []).
- SplitRejection y SplitEngine.rejectionReason ya no existen y ninguna prueba los referencia.
- Los valores canónicos siguen siendo exactamente los mismos tras la conversión a throws: §8.2 (3420/7 everyone → [492,488×6]; 3420/4 passengersOnly → [0,1140×3]; 1000/4 passengersOnly → [0,334,333,333]; 399/4 everyone → [102,99,99,99]; 400/4 everyone → [100×4]) y §5.3 (899; 25.986 / 38.953014 / 3895; 360; total 1149 con extra de 250).
- La equivalencia entre la suma de N segmentos y la distancia total se mantiene en energyUnits, energyCostEUR y energyCostCents, con un único roundHalfUp final.
- CostEngineTests, SplitEngineTests y SplitPropertyTests cubren con XCTAssertThrowsError y comprobación del caso concreto: precio <= 0, consumo <= 0, factor <= 0, distancia negativa, distancia no finita (infinity y nan), segmento negativo, people = 0, people = 9, passengersOnly con un participante y total negativo.
- SplitPropertyTests conserva al menos 500 combinaciones deterministas manteniendo suma(shares) == total para total > 0, shares vacío para total == 0, partes >= 0, determinismo y conductor 0 en passengersOnly, e incluye al menos un caso de total negativo que espera negativeTotal.
- CONTRACTS.md transcribe literalmente, sin divergencias respecto al código fuente, las firmas públicas de costModelVersion, roundHalfUp, MoneyCents, UnitPriceMilliEUR, CostInputs, CostBreakdown, CostEngine (ambas sobrecargas throws), SplitRule, SplitResult, SplitEngine.split (throws), los cuatro identificadores, LedgerEntry, LedgerMath, AccountingPeriod, FreeWindow, MonthlyStatement, GroupPending y PaymentAllocationProposal (ambas sobrecargas).
- CONTRACTS.md documenta los cinco tipos de error existentes (MoneyParsingError, CostCoreError, PaymentAllocationError, AccountingPeriodError, FreeWindowError) con sus casos reales.
- CONTRACTS.md ya no contiene la afirmación de que CostInputs, CostBreakdown, SplitRule o SplitResult no existen, y documenta la invariante suma(shares) == total sin driverExtra más la convención posicional índice 0 = conductor.
- CONTRACTS.md declara EuroGas/Packages/Persistence/Sources/Persistence/Migrations/v1_initial.sql como única ruta canónica del esquema v1, existente y verificado, y no menciona EuroGas/Packages/CostCore/v1_initial.sql ni ninguna otra ruta de DDL.
- CONTRACTS.md advierte que LedgerMath.netAcrossGroups es sólo diagnóstico y no puede mostrarse como saldo por grupo (§7.2), y que PaymentAllocationProposal es matemática local sin pagos reales ni billing.
- La tabla de propiedad de archivos de CONTRACTS.md cubre Models/, Cost/, Split/, Ledger/, Tests/, Persistence/Sources/Persistence/Migrations/ y Persistence/Tests/.
- STATUS.md publica `npm test` 35 pass / 0 fail / exit 0 como VERIFIED con la salida real de una ejecución sobre la rama de trabajo, cuya salida íntegra y sin truncar queda archivada en el directorio del run; si el resultado difiere, la etiqueta no es VERIFIED y se registra el resultado real más el bloqueo.
- STATUS.md publica el arnés SQLite (node --test EuroGas/Packages/Persistence/Tests/PersistenceTests/schema_v1.test.mjs) como VERIFIED con 18 pass / 0 fail / exit 0.
- STATUS.md mantiene todo el código Swift, incluidos los cambios de esta tarea, como UNVERIFIED-BUILD sin afirmar compilación ni ejecución, y Xcode, iPhone, tracking de campo, StoreKit real y Live Activity como EXTERNO con remisión a FIELD_TESTS.md.
- STATUS.md ya no declara CONTRACTS.md incompleto ni difiere su congelación a un ticket futuro, y su bloque de handoff §19.4 coincide con la sección de evidencias.
- STATUS.md no atribuye causas no verificadas a ejecuciones de tests: toda causa afirmada está respaldada por salida real, y en su defecto se declara explícitamente no identificada.
- No se modifica ningún fichero de orchestrator/**, bin/**, package.json, .ai/config.json, .ai/skills/registry.json ni .gitignore, y no se añade ninguna dependencia ni toolchain.
- El DDL v1, LedgerMath, MonthlyStatement, AccountingPeriod, FreeWindow, PaymentAllocationProposal y Money.swift permanecen sin cambios funcionales.
