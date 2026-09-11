# ARCHITECTURE BLUEPRINT — EuroGas — rev. 5

> **Calcula el combustible de cada viaje y cuánto toca a cada uno.**
> App iOS nativa. Mercado inicial: España. Cuentas entre personas que ya comparten coche.
> Fecha: 11-09-2026. Sustituye íntegramente al blueprint rev. 4.
> **Objetivo operativo: MVP instalable y probado en un iPhone al terminar un sprint de siete días, usando Claude Code y Codex.**
> Este documento especifica trabajo pendiente. No afirma que exista una app compilada, un catálogo validado ni pruebas de campo ya realizadas.

## 0. Cómo usar este documento

Esta revisión conserva la base de rev. 4: Swift/SwiftUI, dominio independiente, GRDB, cálculo por distancia y consumo, navegación externa, Live Activity, privacidad local y Pro para llevar las cuentas. Consolida las decisiones en una sola especificación, corrige los errores identificados y sustituye la previsión de nueve semanas por un sprint de beta de siete días.

**Orden de prioridad:** integridad de los importes y datos → continuidad del viaje → recorrido completo del usuario → claridad de la interfaz → extras.

El objetivo del día 7 es probar el producto real, incluida su propuesta Pro. La aprobación de Apple y la disponibilidad para todos los testers externos son dependencias externas; no se prometen dentro de ese plazo. La beta puede estar instalada y probándose en el iPhone del desarrollador mientras se procesa la distribución externa.

Los días son relativos al inicio efectivo. Si D1 es el 11 de septiembre, D7 es el 17 de septiembre de 2026. No cambiar el alcance a escondidas para declarar el sprint terminado: registrar las funciones terminadas, diferidas y bloqueadas.

### 0.1 Etiquetas

| Etiqueta | Significado |
|---|---|
| CORE-7 | Requisito para dar por terminada la beta del día 7 |
| EXTRA-7 | Se intenta dentro del sprint después de que funcione CORE-7 |
| NEXT | Conservado en roadmap, fuera del compromiso de siete días |
| VALIDAR | Hipótesis o comportamiento pendiente de prueba/documentación |
| EXTERNO | Depende de credenciales, hardware, proveedor o revisión de Apple |

Las decisiones de producto son normativas. Una cifra de rendimiento objetivo no es una capacidad comprobada. No convertir una hipótesis en un indicador de “soportado” sin evidencia.

### 0.2 Cambios principales respecto a rev. 4

| Tema | Decisión rev. 5 |
|---|---|
| Monetización | Un único Pro de compra única a 3,99 € de lanzamiento. Se eliminan las alternativas de suscripción |
| Fecha objetivo | Siete días hasta beta usable, con integración y pruebas reales desde el inicio |
| Mensaje | Coste estimado de combustible/energía; nunca “exactamente lo que cuesta conducir” |
| Precio por litro/kWh | Entero en milésimas de euro; importes de viajes y asientos en céntimos |
| Historial Free | Ventana visible de 30 días; sin límite adicional de 20 viajes y sin borrado automático |
| Pérdida de Pro | Conservación completa, consulta/exportación de datos existentes; nuevas operaciones Pro bloqueadas |
| Ledger | Cargos derivados y reemplazables; pagos explícitos del usuario. No se describe como append-only |
| Pagos por grupo | Toda partida pertenece a un grupo concreto o al grupo técnico “Sin grupo” |
| Recuperación GPS | Estado guardado recuperable; relanzamiento automático y continuidad durante una terminación no garantizados |
| Ralentí | Desactivado por defecto para evitar sumar dos veces un efecto ya incluido en el consumo medio |
| Catálogo de coches | Contrato y fallback manual desde D1; catálogo pequeño verificado como EXTRA-7; fusión multinacional completa NEXT |
| Gastos manuales | Añadir un importe compartido por peajes/parking entra en CORE-7 |
| CarPlay/widgets | Live Activity con vista pequeña se intenta en EXTRA-7; widgets estadísticos NEXT |
| Métricas | Beta mide uso y fiabilidad. TestFlight no demuestra conversión a compras reales |
| Proyecciones | Escenarios aritméticos explícitos; no pronósticos de descargas ni valoración basada en datos que no se recogen |

## 1. Producto y usuarios

### 1.1 Propuesta

Cuatro momentos conectados:

1. Antes: introducir destino y ver kilómetros, coste estimado y parte por persona.
2. Durante: iniciar el viaje y ver cómo sube el coste estimado mientras se utiliza el navegador habitual.
3. Después: ajustar quién viajó, añadir peajes/parking y compartir el importe.
4. Con Pro: consultar cuánto debe cada persona, registrar pagos y ver el detalle del mes.

**Free:** “¿Cuánto nos cuesta este viaje y cuánto toca a cada uno?”
**Pro:** “Lleva las cuentas con quienes compartes coche habitualmente.”

El conductor propietario del iPhone paga la energía y los gastos registrados en esta beta. Los pasajeros no necesitan instalar nada, registrarse ni confirmar movimientos. La app registra lo que introduce el conductor; no acredita que una deuda haya sido aceptada ni que un pago haya ocurrido.

### 1.2 Target inicial

Priorizar conductores que llevan repetidamente a compañeros de universidad, trabajo, deporte o actividades. El viaje ocasional sirve para descubrir y compartir la app; la repetición es la hipótesis de valor de Pro.

Riesgo principal a observar: que abrir la app e iniciar cada trayecto resulte demasiado tedioso. La propuesta del último grupo usado y “Repetir viaje” deben reducir esa fricción. Auto-start no se promete en esta beta.

### 1.3 Exclusiones

Sin marketplace, búsqueda de pasajeros, cuentas de usuario, cobros, Bizum integrado, navegación propia, OBD, anuncios, suscripción ni modelo físico del motor. Los nombres de personas son etiquetas locales, no identidades verificadas.

Nombre de trabajo: EuroGas. Mantener los identificadores técnicos de rev. 4, sujetos a comprobar su registro antes de firmar/distribuir:

- App: com.autem.eurogas
- App Group: group.com.autem.eurogas
- Producto StoreKit: com.autem.eurogas.pro
- URL scheme: eurogas

No se afirma disponibilidad de nombre comercial, marca o identificadores. El nombre no bloquea las pruebas de cálculo.

## 2. Alcance de siete días

### 2.1 CORE-7

| Área | Resultado exigido |
|---|---|
| Proyecto | App nativa que compila en el Mac de integración, esquema de tests y ejecución en iPhone |
| Onboarding | Vehículo manual, energía, consumo y precio sugerido editable; sin introducir un repostaje por viaje |
| Energías | Gasolina, diésel, GLP y BEV con unidades correctas; HEV mediante consumo medio introducido |
| Planificación | Origen actual o introducido, destino, una ruta MapKit, coste y reparto; viaje libre sin ruta |
| Navegadores | Apple Maps y apertura de Google Maps/Waze instalados, con fallback |
| Tracking | Inicio, pausa, reanudación, fin; funcionamiento con pantalla bloqueada y Maps delante validado en campo |
| Live Activity | Pantalla bloqueada y Dynamic Island en hardware compatible; fallo de la actividad no detiene el viaje |
| Resultado | Distancia, energía estimada, coste, participantes y gasto adicional manual |
| Free | Reparto entre todos o sólo pasajeros, mensaje compartible y últimos 30 días visibles |
| Pro | Personas, grupos, presencia por viaje, cargos, saldo por persona/grupo y mes |
| Pagos | Total/parcial, fecha, nota, distribución explícita por grupos y deshacer |
| Compra | StoreKit 2, restaurar, cancelación, pendiente y revocación; pruebas sin cobro en entorno de test |
| Historial | Detalle, editar participantes/gastos y borrar con actualización contable transaccional |
| Estadísticas | Hoy/mes: coste y km; información de qué incluyen las cifras |
| Conservación | Sin borrados por límite Free o por pérdida de Pro; exportación e importación de backup completo |
| Calidad | Mensajes de estimación, errores recuperables, importes coherentes y pruebas críticas aprobadas |
| Idioma | Español completo; String Catalog preparado desde D1 |

BEV no implica modelar batería, regeneración, pérdidas de carga ni tarifas horarias. Se usa kWh/100 km y €/kWh introducidos. PHEV queda fuera: admitir un perfil manual elegido por el usuario, sin presentar la cifra combinada homologada como consumo real.

### 2.2 EXTRA-7, por este orden

1. Vista pequeña de Live Activity, con comprobación en CarPlay real si la versión de iOS y el coche lo permiten.
2. Catálogo inicial local con registros verificables y selección de coche.
3. Polilínea simplificada y mapa del detalle.
4. Alternativas de ruta y evitar peajes cuando la API del SDK mínimo lo permita.
5. Inglés completo.
6. Mejoras visuales, accesibilidad adicional y compartir con más opciones.

Si un extra deja de caber, pasa explícitamente a NEXT. CORE-7 no depende del catálogo ni de CarPlay para calcular, repartir o llevar cuentas.

### 2.3 NEXT conservado del blueprint anterior

Widgets Home/Lock/CarPlay de estadísticas; cierre de mes como marcador; reparto por pesos; catálogo EEA/RDW/VCA/ADEME completo; IDAE si permite acceso; calibración por repostajes; varios coches en UI; contactos; App Intents/Siri; Core Motion; auto-start; MITECO; sincronización iCloud; refinamiento del consumo; PHEV de doble perfil; Android.

El catálogo completo mantiene su arquitectura de SQLite empaquetada. Se aplaza la integración de múltiples fuentes, no se sustituye por un listado inventado.

## 3. Condiciones del sprint

### 3.1 Requisitos D1

- Mac con Xcode compatible y acceso a un iPhone para compilar, firmar e instalar la app nativa. Claude Code/Codex pueden preparar código en otros entornos, pero eso no prueba el comportamiento de iOS.
- Repositorio Git y una rama de integración.
- Apple ID/equipo de firma configurado por Alejandro. Apple Developer y App Store Connect preparados si se quiere distribuir por TestFlight y configurar IAP.
- Al menos una prueba de conducción supervisada durante D2 y otra en D6. Quien conduce no manipula el móvil.
- Consumo y precio de un vehículo real para configurar el primer ensayo.
- Dos sesiones de integración al día; las esperas a compilación, revisión o Apple no desaparecen por usar dos asistentes.

El plazo se considera ambicioso y condicionado a estos requisitos. Una limitación de firma o de hardware se registra como EXTERNO, nunca como prueba aprobada.

### 3.2 Distribución

Meta controlable: build instalada y probada localmente al día 7. Intentar subir una primera build útil a TestFlight en D3 para descubrir bloqueos pronto.

Los testers externos requieren el proceso de revisión beta de Apple; no fijar una hora garantizada de disponibilidad. Los testers internos deben ser usuarios legítimos de App Store Connect con los permisos adecuados; no dar acceso administrativo a amigos para acelerar una beta. [Apple: testers externos](https://developer.apple.com/help/app-store-connect/test-a-beta-version/invite-external-testers/).

No incluir los tiempos de aprobación de Apple como trabajo que “la IA hará más rápido”.

## 4. Arquitectura técnica

### 4.1 Decisiones

| Capa | Elección y responsabilidad |
|---|---|
| UI | SwiftUI, MVVM ligero, modelos observables y estado visual en MainActor |
| Dominio | CostCore, Swift puro + Foundation, sin CoreLocation/MapKit/GRDB/StoreKit |
| Datos | Persistence con GRDB/SQLite; transacciones y migraciones explícitas |
| Sistema | Services: ubicación, navegación, ActivityKit, compra, exportación |
| Catálogo | VehicleDB con SQLite de sólo lectura, activado cuando hay dataset validado |
| Compartido | EuroGasShared: atributos de Live Activity, identificadores y DTO mínimos |
| Composición | AppContainer construye dependencias; sin framework de inyección |
| Concurrencia | Swift 6, TripEngine actor, proveedor de ubicación dueño de su delegate/ejecutor |
| Plataforma | Mínimo iOS 18; disponibilidad de cada API adicional verificada al compilar |
| Red | MapKit y servicios Apple de compras/distribución; sin servidor propio en beta |

La elección de GRDB se mantiene por consultas, control de migraciones y agregaciones. No se justifica con afirmaciones genéricas de que otra tecnología “siempre funciona peor”.

### 4.2 Flujo de dependencias

~~~mermaid
flowchart TD
    UI["SwiftUI y ViewModels"] --> APP["Servicios y AppContainer"]
    APP --> CORE["CostCore"]
    APP --> DATA["Persistence y VehicleDB"]
    APP --> IOS["APIs de iOS"]
    DATA --> CORE
    EXT["Extensión Live Activity"] --> SHARED["EuroGasShared"]
    APP --> SHARED
~~~

Persistence nunca decide si una compra existe. Los comandos de aplicación comprueban permisos de producto; las restricciones de integridad funcionan siempre, también en Free o durante una revocación.

### 4.3 Estructura

~~~text
EuroGas/
  EuroGas.xcodeproj
  Packages/
    CostCore/Sources/CostCore/
      Models/ Cost/ Split/ Ledger/ GPS/ State/ Support/
    CostCore/Tests/CostCoreTests/
    Persistence/Sources/Persistence/
      AppDatabase.swift Migrations/ Records/ Stores/ Queries/
    Persistence/Tests/PersistenceTests/
    EuroGasShared/Sources/EuroGasShared/
    VehicleDB/                         # EXTRA-7/NEXT; sin dataset ficticio en Release
  App/
    EuroGasApp.swift AppContainer.swift RootView.swift
    Features/
      Onboarding/ Drive/ Plan/ Trips/ Accounts/ People/ Paywall/ Settings/
    Services/
      Trip/ Location/ Routing/ LiveActivity/ Ledger/ Store/ Backup/
    Resources/
      Localizable.xcstrings PrivacyInfo.xcprivacy EuroGas.storekit
  Widgets/
    TripLiveActivity.swift
  Tests/
    Fixtures/ ServicesTests/ UITests/
  tools/vehicle-db/                     # NEXT, aislado del build del núcleo
  docs/
    BLUEPRINT.md CONTRACTS.md STATUS.md FIELD_TESTS.md
~~~

Crear módulos cuando tengan código y uso real. No generar decenas de archivos vacíos, tablas futuras ni servicios sin implementación sólo para aparentar avance.

App target: ubicación en background, App Group, IAP y configuración de Live Activities. Extensión: App Group cuando lo necesite. No solicitar entitlements CarPlay nativos para la beta.

## 5. Dinero, unidades y redondeo

### 5.1 Contrato único

| Magnitud | Representación |
|---|---|
| Importe final de viaje, gasto, cargo o pago | Int64 en céntimos EUR |
| Precio por L o kWh | Int64 en milésimas de euro por unidad |
| Consumo efectivo | Decimal en L/100 km o kWh/100 km |
| Distancia GPS | Double en metros; conversión decimal controlada para valoración |
| Energía y coste antes del redondeo | Decimal, sin redondeo a céntimos por segmento |
| Duraciones | Reloj monotónico durante ejecución; timestamps UTC para persistencia |
| Moneda beta | EUR; no sumar monedas ni convertir divisas |

Ejemplos obligatorios:

- 1,499 €/L se guarda como unitPriceMilliEUR = 1499.
- 0,200 €/kWh se guarda como unitPriceMilliEUR = 200.
- 14,99 € de gasto se guarda como amountCents = 1499.
- Los campos de precio e importe tienen tipos/nombres diferentes para evitar confundir las escalas.

Parsear entradas localizadas con una estrategia explícita; aceptar coma decimal en español. Rechazar entradas ambiguas en lugar de reemplazar caracteres sin control. Validar rangos como protección de errores, con mensajes que permitan corregir.

### 5.2 Fórmula

~~~text
effectiveConsumption = consumptionPer100 × realWorldFactor
energyUnits = acceptedDistanceMeters / 100000 × effectiveConsumption
energyCostEUR = energyUnits × unitPriceMilliEUR / 1000
energyCostCents = roundHalfUp(energyCostEUR × 100)
tripTotalCents = energyCostCents + sum(manualExpenseCents)
~~~

Mantener energía/coste sin redondear hasta producir una cifra visible o persistir el importe final. Recalcular el coste del acumulado aceptado, sin redondear cada fix. Guardar los parámetros del viaje como snapshot: editar precio o consumo en Ajustes afecta a viajes futuros.

La cifra en vivo se obtiene del acumulado no decreciente con el mismo redondeo final. No usar un redondeo de presentación distinto del utilizado para los cargos. Los cambios manuales después del viaje pueden aumentar o disminuir el total y deben mostrarse como edición.

### 5.3 Casos de referencia

| Entrada | Resultado |
|---|---|
| 100 km; 6 L/100; factor 1; 1,499 €/L | 6 L; 8,994 € sin redondeo; 899 céntimos finales |
| 355 km; 6,1 L/100; factor 1,20; 1,499 €/L | 25,986 L; 38,953014 €; **3895 céntimos**, corrige el ejemplo de rev. 4 |
| 100 km; 18 kWh/100; factor 1; 0,200 €/kWh | 18 kWh; 360 céntimos |
| Energía 899 céntimos + peaje 250 céntimos | Total compartible 1149 céntimos |

No redondear primero a 25,99 L para calcular el dinero del segundo caso.

## 6. Consumo y precisión

### 6.1 Perfiles

- **userEntered:** consumo medio que el usuario conoce; factor 1,0.
- **official:** consumo de una fuente identificada y ciclo indicado; corrección visible y editable.
- **calibrated:** reservado a calibración futura; factor 1,0 y muestra de referencia conservada.
- **bodyDefault:** sugerencia aproximada por tipo de coche, claramente etiquetada; no aparenta identificar el modelo exacto.

En beta, la entrada manual fiable es el camino principal. No pedir consumo instantáneo ni exigir saber la motorización técnica. Explicar dónde encontrar el consumo medio del coche.

Los factores de rev. 4 (gasolina 1,20; diésel 1,15; HEV 1,25; GLP 1,20; BEV 1,15) quedan como hipótesis de investigación NEXT. No aplicar por defecto esos números a un perfil manual ni afirmar que estén calibrados para cada coche.

Si entra un catálogo oficial en EXTRA-7, debe incluir un factor por defecto documentado por fuente/ciclo o mostrar el consumo oficial sin corrección validada y permitir editarlo. Un valor NEDC conserva su etiqueta: no convertir automáticamente a WLTP con ×1,20 y volver a aplicar otro factor sin justificar ambas etapas.

### 6.2 Ralentí

Desactivado por defecto. El consumo combinado o medio ya refleja parte del tiempo parado; añadir un consumo por hora encima puede duplicar ese efecto. Tampoco el GPS sabe si el motor está encendido o si actúa Start-Stop.

EXTRA-7 puede ofrecer una opción explícita de estimación adicional con límite de tres minutos por parada, rate visible y aviso de que puede sobreestimar. No desarrollarla a costa de CORE-7. En BEV no se infiere climatización ni consumo auxiliar a partir de estar parado.

### 6.3 Mensajes

Durante y después: “Combustible estimado” o “Energía estimada”. En desglose: “Según los kilómetros registrados, tu consumo y el precio configurado”. Un gasto manual se identifica como importe introducido por el usuario.

No prometer una banda de error fija sin validación. La precisión del GPS no equivale a precisión del consumo. No se incluyen mantenimiento, seguro, amortización o desgaste. En recorridos de montaña no asumir que subida y bajada se compensan energéticamente.

La calibración posterior puede mejorar la estimación media, pero no reconstruye el consumo instantáneo del motor.

## 7. Modelo de datos

Todos los IDs de dominio son UUID. Fechas de eventos en UTC. La beta utiliza **Europe/Madrid** como zona contable de la app, también para pagos y estadísticas; no cambia silenciosamente con la zona del teléfono. El viaje pertenece al mes de su inicio.

### 7.1 Entidades

~~~text
Vehicle
  id, displayName, energyKind, activeProfileID, specificationSnapshot
  createdAt, updatedAt

ConsumptionProfile
  id, vehicleID, source, consumptionPer100, realWorldFactor
  unit, sourceReference?, testCycle?, createdAt

FuelPrice
  id, energyKind, unitPriceMilliEUR, currency="EUR"
  source(manual|suggested|stationFuture), effectiveFrom

PlannedTrip
  id, vehicleID, createdAt, origin, destination
  distanceMeters, expectedSeconds, hasTolls?, routePolyline?
  estimateSnapshot, totalPeople, splitRule, groupID, participantIDs

Trip
  id, vehicleID, plannedTripID?, status(active|interrupted|completed)
  startedAt, endedAt?, accountingMonth, accountingTimeZone
  acceptedDistanceMeters, gapDistanceMeters, movingSeconds, pausedSeconds
  estimatedEnergy, energyCostCents
  profileSnapshot, fuelPriceSnapshot, costModelVersion
  totalPeople, splitRule, groupID, accountingMode(anonymous|named)
  origin?, destination?, polyline?, qualityFlags
  createdAt, updatedAt, revision

ActiveTripState
  tripID, schemaVersion, sequence, savedAt
  state, lastAcceptedFix?, accumulatorSnapshot
  lastMovementAt?, unmeasuredIntervalFlag, liveActivityID?

Person
  id, name, emoji?, isOwner, createdAt, archivedAt?

Group
  id, name, emoji?, isUngrouped, defaultSplitRule, createdAt, archivedAt?

GroupMember
  groupID, personID, sortOrder

TripParticipant
  tripID, personID, role(driver|passenger), sortOrder

ManualExpense
  id, tripID, label, kind(toll|parking|other), amountCents
  createdAt, updatedAt

LedgerEntry
  id, kind(charge|payment), debtorID, creditorID
  amountCents, groupID, tripID?, paymentBatchID?
  occurredAt, accountingMonth, createdAt, note?

PaymentBatch
  id, personID, occurredAt, note?, createdAt
~~~

Se crea exactamente un owner y un grupo técnico “Sin grupo” durante la inicialización de la base, incluso en Free. No son un registro de usuario. El índice único parcial garantiza como máximo un owner; la inicialización y las validaciones garantizan que exista.

Los participantes de un viaje named incluyen siempre al owner, una vez, con role driver. totalPeople coincide con el número de participantes. Un viaje anonymous guarda el número y la regla, pero no produce asientos aunque la persona tenga Pro.

### 7.2 Campos derivados

No almacenar saldos mutables ni duplicar totales que se puedan derivar de un único origen:

~~~text
extrasCents(trip) = SUM(manual_expense.amount_cents)
totalCents(trip) = trip.energyCostCents + extrasCents(trip)
balance(person, group) = SUM(charges) - SUM(payments)
balance(person) = SUM(balance(person, everyGroup))
pending(person, group) = MAX(balance(person, group), 0)
credit(person, group) = MAX(-balance(person, group), 0)
~~~

Un crédito en un grupo no salda automáticamente otro. Mostrar por separado pendientes y créditos cuando existan. “Saldo neto” y “total pendiente” tienen nombres distintos para que la UI no sugiera una compensación inexistente.

### 7.3 Persistencia y restricciones

GRDB DatabasePool en App Group con WAL y foreign keys activadas. La app escribe; extensiones leen únicamente lo necesario. Proteger archivos con una clase compatible con las pruebas de acceso tras desbloqueo; verificar en iPhone bloqueado antes de cambiar la protección por defecto.

Restricciones mínimas:

- Un solo viaje activo/interrumpido pendiente de resolver mediante índice parcial o transacción de inicio.
- Precio positivo, consumo positivo y fin del viaje no anterior a inicio.
- amountCents > 0 en asientos; no insertar cargos de 0.
- debtorID distinto de creditorID.
- kind charge implica tripID no nulo y paymentBatchID nulo.
- kind payment implica paymentBatchID no nulo y tripID nulo.
- groupID obligatorio y con FK; “Sin grupo” sustituye a NULL.
- Un solo cargo de energía+gastos por persona y viaje.
- Personas/grupos referenciados se archivan, no se borran.
- Eliminar un viaje elimina participantes, gastos y cargos; no sus pagos.
- Borrar un lote de pagos elimina sus partidas en una sola transacción.
- Índices de viaje por startedAt y status; ledger por persona/grupo/occurredAt y por tripID.

Migración v1 sólo con tablas utilizadas. Añadir PeriodClose, RefuelEvent y otras tablas cuando se implemente su funcionalidad. No usar borrado automático de base ante cambios de esquema en una build distribuida.

## 8. Reparto

### 8.1 Reglas beta

Sólo everyone y passengersOnly. La UI beta permite entre 1 y 8 personas en total, incluido el conductor. El reparto por pesos pasa a NEXT para evitar una UI y reglas de redondeo adicionales durante el sprint.

**Entre todos:**
- q = totalCents / totalPeople, división entera.
- remainder = totalCents % totalPeople.
- Cada pasajero paga q.
- El conductor paga q + remainder.

**Sólo pasajeros:**
- Se exige al menos un pasajero; deshabilitar la opción en un viaje de una persona.
- q = totalCents / passengerCount.
- Los primeros remainder pasajeros reciben un céntimo adicional.
- Orden estable por TripParticipant.sortOrder; en Free, posiciones “Pasajero 1”, “Pasajero 2”…
- Conductor paga 0.

Así el conductor no absorbe céntimos en la regla que promete que no paga. El mensaje compartido muestra importes distintos cuando el reparto no es exactamente igual; no dice “X cada uno” si alguno paga otro importe.

### 8.2 Contrato

SplitResult contiene únicamente las partes finales, incluido el conductor. **La suma de shares ya es el total.** Puede incluir una nota informativa sobre el redondeo, pero no un driverExtra que deba sumarse otra vez.

Pruebas canónicas:

| Total y regla | Partes finales |
|---|---|
| 3420 céntimos, 7 personas, everyone | Conductor 492; seis pasajeros de 488 |
| 3420 céntimos, 4 personas, passengersOnly | Conductor 0; tres pasajeros de 1140 |
| 1000 céntimos, 4 personas, passengersOnly | Conductor 0; pasajeros 334, 333, 333 |
| 399 céntimos, 4 personas, everyone | Conductor 102; pasajeros 99, 99, 99 |
| 400 céntimos, 4 personas, everyone | 100 por persona |

No exigir que la parte del conductor sea monótona al subir el total: el resto asignado produce el contraejemplo 399→400. Sí exigir total exacto, determinismo, partes no negativas y ausencia de dobles sumas.

Con 0 céntimos: todas las partes son 0 y no se crean asientos.

## 9. Ledger y pagos

### 9.1 Naturaleza del registro

Este es un **ledger de cargos derivados y pagos explícitos**, no un registro inmutable de auditoría.

- Cargos: recalculables desde el viaje, sus gastos, participantes y regla.
- Pagos: creados por el usuario; nunca se regeneran al editar un viaje.
- Saldo: siempre derivado.
- Ediciones y anulaciones permitidas según las reglas descritas.
- No afirmar que este diseño pueda fusionarse automáticamente mediante CloudKit: la sincronización futura requiere resolver identidad, versiones, borrados y conflictos.

### 9.2 Un solo comando transaccional

~~~text
Command: completeTrip | editTrip | deleteTrip
  validate request and product access
  begin database write transaction
    load current trip, participants and expenses
    apply requested mutation
    delete derived charges for that trip
    if completed and named:
      calculate final shares
      insert one positive charge per passenger
    update trip revision / active state as needed
  commit
  publish updated UI / refresh Live Activity or widgets
~~~

No ejecutar el reparto como una reacción asíncrona después de guardar el viaje. Un listener de observación que se dispara tras el commit no comparte esa transacción.

Terminar dos veces, recibir dos callbacks o reabrir durante finishing no debe duplicar cargos. El mismo comando sobre el mismo estado es idempotente desde el punto de vista de importes y cantidad de asientos.

### 9.3 Asignación de pagos

Toda partida de pago tiene persona y grupo. Un pago recibido desde “Trabajo” se imputa a Trabajo.

Desde el saldo global:
1. Mostrar el desglose de pendientes por grupo.
2. Proponer una distribución determinista entre grupos con saldo positivo, ordenados por createdAt y después id. Es una propuesta de interfaz, no una afirmación sobre qué viajes se han pagado.
3. El usuario ve y puede ajustar la distribución antes de guardar.
4. Crear un PaymentBatch y una partida por grupo en una única transacción.
5. Exigir que la suma de partidas sea el importe recibido.

Si se paga por encima del pendiente, se elige expresamente el grupo que recibirá el crédito. No dejar una partida sin grupo. Una opción futura de compensar créditos entre grupos necesitará un movimiento explícito.

Ejemplo: Carlos debe 12 € en Trabajo y 8 € en Universidad. Registra 15 € como 12+3. Trabajo queda 0 y Universidad 5; global 5. Deshacer el pago revierte las dos partidas.

### 9.4 Meses

Para un mes M, calculado en Europe/Madrid:
- opening = movimientos anteriores a inicio(M).
- charges = cargos con fecha en [inicio(M), inicio(M+1)).
- payments = pagos con fecha en ese mismo intervalo.
- closing = opening + charges - payments.

La SQL y el cálculo puro usan los mismos límites y la misma zona. accountingMonth sirve de índice/etiqueta persistida y debe coincidir con esos límites. Pagos futuros no están disponibles en beta; fechas anteriores se muestran claramente.

Un viaje que cruza medianoche o cambio de mes se asigna a su inicio. Cerrar mes no es necesario para trasladar el saldo: el traslado existe por la consulta. PeriodClose queda en NEXT como marcador informativo, sin asiento de apertura adicional.

### 9.5 Casos que no pueden romper saldos

- Editar un viaje ya pagado puede dejar saldo a favor: mostrarlo, no borrar el pago.
- Quitar a Carlos del grupo actual no cambia su participación en viajes pasados.
- Archivar un grupo no oculta sus deudas pendientes.
- Borrar un viaje avisa de que quitará cargos y conservará pagos.
- El detalle del saldo muestra cargos y pagos; no marcar viajes concretos como “pagados” porque la beta no asigna pagos a cargos individuales.
- Un viaje anonymous no genera asientos; asignar participantes lo convierte en named y recalcula.
- Un usuario sin Pro no puede modificar un viaje named de forma que cree nuevos cargos. Puede consultar/exportar datos y eliminar un viaje con confirmación y recálculo, porque borrar datos no depende de una compra.

## 10. Historial y acceso Free/Pro

### 10.1 Free

Ventana visible de **30 días naturales contando hoy** en la zona contable: desde las 00:00 de hace 29 días hasta ahora. Sin límite de número de viajes. Esto permite mostrar completo el mes en curso salvo el día 31: para “Este mes”, consultar el mes completo y explicar que el detalle Free muestra los últimos 30 días. No confundir ventana de detalle con rango de agregación.

Los datos antiguos se conservan. Mensaje: “El detalle de viajes anteriores está disponible con Pro”. Al comprar se desbloquea el historial ya guardado; no inventar nombres ni participaciones de viajes anonymous.

Las estadísticas básicas Hoy/Este mes consultan los datos conservados del periodo completo, no sólo las filas visibles. Su cifra no disminuye al pasar un viaje fuera de la ventana.

No existe enforceFreeLimit que borre filas. El espacio se gestiona mediante borrado manual y, en NEXT, gestión de recorridos, nunca por caducidad comercial.

### 10.2 Pro y revocación

- Pro activo: crear/editar personas, grupos y participaciones, registrar pagos, ver todo el historial.
- Sin Pro: calcular, repartir anónimamente y compartir; teaser de Cuentas.
- Si hubo Pro: los datos named y sus cuentas existentes permanecen consultables y exportables en modo lectura aunque se revoque la compra. No crear nuevos movimientos Pro.
- Una revocación no toca viajes, cargos, pagos, personas o grupos.
- Una indisponibilidad temporal de verificación no equivale a revocación.
- Borrar datos propios sigue disponible; las eliminaciones que afecten a cargos se realizan transaccionalmente y avisan de su efecto.

El límite comercial se aplica al acceso, no a la conservación. Esta política reemplaza todas las variantes de borrado de rev. 4.

## 11. GPS, continuidad y máquina de estados

### 11.1 Proveedor

Implementación inicial: CLLocationManager detrás de LocationProvider, con stream de LocationFix. Mantener delegate y manager en un contexto compatible con el ciclo de vida de Core Location; no crear el manager en un actor sin tratar su ejecución y callbacks.

Configuración inicial de ensayo:
- When In Use, ubicación precisa para tracking.
- Background Modes: Location updates.
- allowsBackgroundLocationUpdates activo durante el viaje.
- Indicador de ubicación visible.
- activityType automotiveNavigation.
- desiredAccuracy Best y distanceFilter 10 m como punto de partida medible.
- No depender de un Timer para recibir ubicaciones.
- No declarar una frecuencia garantizada a partir del distanceFilter.

Pedir ubicación al iniciar la primera función que la necesita. La estimación con origen manual debe ser posible aunque no se dé permiso de ubicación. Si la precisión es reducida, explicar la limitación y solicitar precisión temporal con el purpose key correspondiente; si se deniega, no mostrar tracking preciso ficticio.

### 11.2 Qué se promete

- Continuar un viaje iniciado conscientemente con la app en background: probar en iPhone.
- Recuperar los datos ya persistidos al volver a abrir: requisito de integridad.
- Seguir midiendo durante una terminación o relanzarse automáticamente: **no garantizado** por la configuración elegida.

Apple diferencia la continuación en background, la terminación y los mecanismos de sesiones/relanzamiento. El servicio estándar deja de entregar eventos al terminar el proceso. Si se evalúan CLLocationUpdate y sesiones modernas, hacerlo detrás del mismo protocolo y con prueba de dispositivo, sin ejecutar dos proveedores simultáneamente. [Apple: servicio estándar](https://developer.apple.com/documentation/corelocation/cllocationmanager/startupdatinglocation()). [Apple: actualizaciones en background](https://developer.apple.com/documentation/corelocation/handling-location-updates-in-the-background).

Una Live Activity visible no prueba que el GPS siga midiendo. Debe tener fecha de última actualización y estado obsoleto cuando corresponda.

### 11.3 Filtro

Procesar separadamente validez temporal, posición, distancia y detección de parada:

1. Rechazar datos inválidos, timestamps duplicados/regresivos y saltos físicamente inverosímiles.
2. Distinguir fixes cacheados iniciales de lotes legítimos entregados en background; mantener el orden temporal.
3. Alimentar StationaryDetector con fixes válidos antes de descartar desplazamientos pequeños por ruido.
4. Acumular distancia usando un ancla aceptada; no desplazar el ancla con cada muestra descartada.
5. Clasificar segmentos normales, gaps estimados y no medidos.
6. Persistir contadores de calidad: fixes descartados, distancia estimada en gaps e interrupciones.

Umbrales iniciales de ensayo: hAcc máxima 65 m y velocidad implícita máxima 62 m/s. Son parámetros de beta; modificarlos sólo con un fixture que demuestre el problema y otro que proteja el comportamiento previo.

Un túnel breve puede usar una cuerda entre dos fixes válidos sólo si pasa comprobaciones de tiempo, distancia y velocidad. Para la beta: límite inicial 90 segundos y 3 km, segmentado como gap estimado. No afirmar que los túneles sean rectos ni que esa distancia sea real. Gaps mayores quedan no medidos.

Tras una terminación/reapertura no sumar una recta de hasta 30 minutos como recorrido. Empezar desde una nueva ancla y marcar la interrupción.

### 11.4 Estados

~~~text
idle → planning → ready → starting → tracking
idle → starting
tracking → paused(user|stationary|signalLost)
paused → tracking
tracking/paused → finishing → completed → idle
launch + active persisted state → interrupted → resume | finish | discard
~~~

- Timeout de primer fix: ofrecer esperar o iniciar con “Buscando señal”; coste 0 hasta una medición válida.
- Parado tres minutos: pausa automática sin inferir que el motor está apagado.
- Sin señal: estado visible; no sumar ralentí ni suponer desplazamiento.
- Reanudación después de pausa: obtener precisión suficiente antes de contabilizar de nuevo.
- Si se reduce precisión durante una pausa, las muestras de baja precisión pueden disparar una búsqueda precisa sin añadirse al acumulador. No bloquear la reanudación exigiendo desde el principio la precisión que se ha dejado de pedir.
- Pausa automática de 45 minutos: puede terminar el viaje con fin en la última observación de movimiento; debe distinguirse de una pausa manual.
- Caminar y ferries: beta requiere finalizar/pausar manualmente; no prometer detección fiable por velocidad sola.
- Mantener un único viaje activo; Start repetido no crea otro.

### 11.5 Estado persistido

**SQLite es la única fuente de verdad de recuperación.** ActiveTripState se escribe junto a los totales del viaje en la misma transacción. Se elimina el JSON paralelo como fuente independiente.

Checkpoint al cambiar de estado y como objetivo cada 10 segundos o 100 metros, lo que ocurra primero. Medir coste de escrituras. Un cierre inesperado puede perder el tramo aún no guardado: no prometer recuperación ±0 de muestras no persistidas.

Al relanzar:
1. Leer viaje activo y snapshot coherente.
2. Mostrar importe guardado, hora de última medición e intervalo no medido.
3. Ofrecer continuar, terminar con lo registrado o descartar.
4. Continuar con nueva ancla; recuperar/reutilizar una actividad existente si es posible.
5. Si falla la recuperación de una actividad, la app sigue funcionando.

Terminar el viaje guarda sus cargos y borra el estado activo en una transacción. Si el proceso cae después del commit y antes de cerrar la actividad, el siguiente arranque reconcilia la actividad con el viaje ya completed.

## 12. Planificación y navegadores

RoutingService encapsula autocompletado, resolución y MKDirections. No exponer tipos de MapKit al dominio. Contrato: origen/destino → lista de RouteSummary o error recuperable.

CORE-7 sólo exige una ruta. Distancia, duración y una indicación de peajes cuando esté disponible; **no se obtiene el precio de los peajes del indicador**. El usuario añade ese importe manualmente.

La selección de una alternativa en la app no obliga al navegador externo a usar esa ruta. Conservar la estimación previa y comparar con los kilómetros registrados. No prometer sincronización de destino ni de ruta con Waze/Google Maps.

Navegación:
- Apple Maps por defecto.
- Google Maps/Waze si están instalados, mediante mecanismos públicos verificados en el SDK y sus guías.
- Declarar los schemes consultados y codificar correctamente las URLs.
- Si el navegador configurado desaparece, ofrecer Apple Maps.
- El GPS de EuroGas funciona independientemente del navegador.

Sin red: planificación no disponible; viaje libre, historial, reparto y cuentas locales siguen funcionando. No prometer que MKDirections utilice los mapas offline descargados por Apple Maps.

Sin permiso GPS: permitir estimación con origen manual; iniciar tracking requiere resolver el permiso. Elegir destino no debe iniciar la ubicación en background antes de pulsar Empezar.

## 13. Live Activity, Dynamic Island y CarPlay

### 13.1 CORE-7

Datos mínimos:
- tripID, nombre del vehículo, moneda.
- costCents, distancia, totalPeople, importe orientativo por persona.
- phase, startedAt y lastUpdatedAt.

No mostrar nombres de deudores o saldos personales en la pantalla bloqueada. Si hay importes distintos por redondeo, la actividad puede mostrar “desde X/persona” y remitir al reparto detallado.

Vistas: Lock Screen, compact, minimal y expanded. Priorizar legibilidad del importe. Cuando Maps comparta Dynamic Island, iOS decide la presentación; no se promete que EuroGas ocupe siempre la vista grande.

Inicio desde una interacción admitida en foreground. Actualizaciones locales con throttle inicial de 5–10 segundos, sin prometer una cadencia exacta del sistema. Finalizar con resumen temporal. Si el usuario desactiva/descarta la actividad, no insistir ni reiniciarla en bucle.

La actividad puede quedar obsoleta o terminar antes que un viaje largo. El tracking y la cuenta no dependen de ella. Validar límites de duración y APIs en el SDK usado; no diseñar sobre afirmaciones no comprobadas de iOS 27.

### 13.2 EXTRA-7

Vista pequeña para CarPlay/Watch en versiones que la soporten, con availability guards. Ensayo en coche real y documentación del resultado. Verificar el comportamiento concreto de supplementalActivityFamilies en el SDK.

CarPlay Dashboard y Maps a pantalla completa son superficies distintas. No vender “contador siempre encima del mapa”. No hay overlay sobre otra app. La beta no usa entitlement de app CarPlay ni implementa navegación propia.

Pausar/Terminar mediante intents en la actividad queda como extra si compromete la integración. Los controles dentro de la app son CORE-7.

## 14. Catálogo de vehículos

### 14.1 Semana uno

La selección manual es completamente operativa y no depende de una descarga. Un precio sugerido se etiqueta como tal, incluye fecha/referencia si procede y se edita una vez; no se presenta una constante empaquetada como precio actual de una gasolinera.

Para un catálogo inicial:
- Cada registro debe tener fuente, fecha, ciclo, unidad y licencia identificables.
- Identificar marca, modelo, año/generación y variante; no mezclar automáticamente coches diferentes con cilindrada/potencia parecidas.
- Fuente o licencia sin verificar: no distribuir sus datos.
- Ausencia de modelo: fallback manual visible.
- Seed de tests separado del catálogo de producción; nunca mostrar datos sintéticos como fichas reales.
- Congelar el catálogo inicial en D3 si existe. El sprint no espera una fusión de gigabytes.

### 14.2 Pipeline NEXT conservado

1. Descargar fuentes autorizadas con caché.
2. Normalizar por fuente/año y mantener procedencia.
3. Separar homologación, consumo declarado, consumo derivado y mediciones.
4. Identificar variantes con generación, años, combustible, transmisión y tipo-aprobación cuando estén disponibles.
5. Revisar conflictos; no fusionar sólo por marca/modelo/cc/kW.
6. Generar SQLite de sólo lectura con búsqueda jerárquica y FTS.
7. Validar cobertura real con una lista española y coches aportados por testers.
8. Publicar versión de dataset y atribuciones.

Fuentes candidatas heredadas: EEA, RDW, VCA, ADEME y OpenEV; IDAE si concede acceso. Cobertura, licencia, disponibilidad y campos son **VALIDAR por fuente**, no garantías de que todo coche español esté cubierto.

El cambio de dataset no modifica el consumo de los viajes históricos. Vehicle guarda su ficha/snapshot; el usuario decide actualizar el perfil para viajes futuros.

## 15. Pantallas y recorrido

Cuatro pestañas: **Conducir · Viajes · Cuentas · Ajustes**.

### 15.1 Onboarding

Tres pasos obligatorios breves:
1. Qué hace la app.
2. Vehículo/energía y consumo.
3. Precio sugerido editable.

El navegador se elige mediante una opción sencilla, con Apple Maps preseleccionado; no añadir un paso si no hay otra app instalada. El permiso GPS aparece al usar ubicación, no como condición para explorar la aplicación.

No explicar modelos, tablas, APIs ni pipeline al usuario. “Consumo medio de tu coche” es suficiente; los detalles técnicos pertenecen a “Cómo se calcula”.

### 15.2 Conducir

En reposo: “¿Dónde vas?” y “Empezar sin destino”. Número de personas; en Pro, último grupo propuesto y toggles de quién viene. El owner siempre está incluido.

En marcha: coste estimado grande, km y tiempo secundarios, estado de señal, Pausar y Terminar. Si hubo planificación: estimación inicial separada del acumulado.

Al terminar: energía, extras, total, reparto, compartir. Pro permite ajustar participantes antes de guardar definitivamente el reparto; si el viaje ya se ha completado, ese ajuste usa el mismo comando de edición transaccional.

No obligar a introducir personas para recibir el resultado Free.

### 15.3 Cuentas

Saldo por persona con detalle por grupo. Mes actual con apertura, cargos, pagos y saldo final. “Registrar pago” y “Compartir cuenta”.

Mostrar avances de crédito explícitamente. No construir el teaser Free con un nombre inventado que parezca un contacto real: usar “Una persona de tu grupo” o un ejemplo marcado como ficticio.

### 15.4 Compartir

~~~text
Valencia → Madrid
Combustible estimado: 38,95 €
Peajes/parking añadidos: 4,00 €
Total: 42,95 €
Reparto entre 4 personas:
Conductor: 10,76 €
Pasajeros: 10,73 € cada uno
Calculado con EuroGas
~~~

El ejemplo anterior corresponde a everyone: 4295 / 4 = 1073 y resto 3.

Mensaje de cuenta:
~~~text
Septiembre · Trabajo
Carlos:
Pendiente anterior: 3,10 €
Tu parte de los viajes del mes: 19,20 €
Pagos registrados: 5,00 €
Pendiente: 17,30 €
Calculado con EuroGas
~~~

Texto de ubicación opcional. Compartir abre la hoja del sistema; no se envía automáticamente ningún mensaje. Un evento de apertura de Share Sheet no se registra como “mensaje entregado”.

## 16. Compra Pro y paywall

### 16.1 Producto cerrado

**com.autem.eurogas.pro**, non-consumable, **3,99 € de lanzamiento**, pago único. Sin mensualidad, anualidad, propinas ni segundo producto. Historial ilimitado significa acceso a todo lo conservado, no una garantía de almacenamiento externo infinito.

Precio de la UI obtenido de StoreKit y localizado. El PVP es el objetivo para la tienda española y se configura en App Store Connect; no hardcodear el texto de compra.

Family Sharing: activado para este producto, conservando la decisión de rev. 4. Configurarlo y comprobarlo en App Store Connect antes de comunicarlo en la ficha; compartir la compra no comparte los viajes ni los saldos. La configuración de cuenta es un paso EXTERNO del sprint.

### 16.2 Entitlements

Entitlements en la capa de app, respaldado por StoreKit 2:
- Verificar transacciones.
- Cargar derechos actuales y escuchar actualizaciones.
- Finalizar transacciones procesadas cuando corresponda.
- Gestionar purchased, cancelled, pending y failed.
- Restaurar compras accesible desde Ajustes y paywall.
- Distinguir estado desconocido/error temporal de ausencia o revocación verificada.
- Caché sólo como ayuda para el arranque, no como prueba de compra editable/importable.

La app funciona offline con el estado verificado disponible; una falta de red no borra ni oculta datos. Un error de tienda muestra un mensaje y permite seguir usando Free.

DebugEntitlementProvider existe exclusivamente en DEBUG y tests locales. Para beta distribuida usar compras de prueba de StoreKit/TestFlight; no introducir un código secreto de desbloqueo en Release.

El backup no contiene ni restaura entitlements, recibos, tokens o flags DEBUG.

### 16.3 Política

Un paywall automático como máximo cada 24 horas y sólo después de entregar valor:
- Fin de viaje con al menos dos personas.
- Intento de acceder a detalle histórico fuera de la ventana Free.

Cuentas y acciones Pro abiertas por el usuario muestran el teaser/paywall a petición. No bloquear el resultado ni la hoja de compartir. No lanzar un modal automático durante conducción.

Copy: “Lleva las cuentas con tus compañeros de coche. Personas, grupos y saldos mes a mes. Compra única.”

Tras comprar desde el resumen, abrir el selector de participantes para convertir ese viaje anonymous en named. No crear cargos hasta que se confirme quién iba.

## 17. Backup, privacidad y diagnósticos

### 17.1 Backup CORE-7

Exportación completa versionada, independiente del CSV:
- Formato JSON con schemaVersion, exportedAt, zona contable, vehículos, perfiles, precios, viajes completed, personas, grupos, participaciones, gastos y pagos.
- Decimal serializado como cadena; fechas con formato inequívoco.
- No exportar un viaje activo sin indicar su estado: para beta exigir terminarlo antes de exportar/importar.
- Entitlements, logs y samples GPS crudas excluidos.
- El usuario elige dónde guardar/compartir; puede contener nombres y rutas, por lo que se indica antes de exportar.

Importación beta: **reemplazo completo**, sin merge.
1. Seleccionar archivo y validar versión, tipos, IDs, referencias, rangos y owner único.
2. Previsualizar fecha y número de viajes/personas.
3. Pedir confirmación de reemplazo de datos locales.
4. Importar en una transacción; ante error, rollback completo.
5. Regenerar cargos desde viajes named, preservar pagos importados y verificar invariantes.
6. No restaurar Pro desde el archivo.

Prueba obligatoria: exportar → base vacía → importar → mismos viajes, participaciones, gastos, pagos y saldos. Conservar una copia de seguridad previa al reemplazo mientras dure la operación.

El backup de dispositivo puede ayudar, pero depende de la configuración y restauración del usuario. No escribir “ningún usuario puede perder datos”.

### 17.2 CSV

Exportar trips.csv y accounts.csv con columnas documentadas, separador/escaping correcto y fechas inequívocas. El CSV sirve para lectura y revisión; no sustituye al backup restaurable.

### 17.3 Privacidad

Sin servidor propio ni subida automática de ubicaciones, nombres o saldos. Las peticiones de mapas/búsqueda y servicios de Apple se tratan por sus respectivos proveedores; no afirmar “ningún dato sale nunca del dispositivo” si se usan esas funciones.

Permiso: explicar que se usa ubicación durante el viaje para registrar kilómetros y estimar energía. Precisión temporal con finalidad concreta.

App Privacy se rellena según el flujo real de datos y las definiciones vigentes de Apple. Almacenamiento local no equivale automáticamente a “recopilación” para la ficha; tampoco omitir transferencias que sí se realicen. Revisar componentes y proveedores antes de declarar categorías. [Apple: privacidad de la app](https://developer.apple.com/help/app-store-connect/manage-app-information/manage-app-privacy/).

PrivacyInfo.xcprivacy refleja APIs utilizadas realmente, con motivos válidos y verificados. No copiar una lista preventiva de APIs que el proyecto no usa.

### 17.4 Diagnósticos

Logs locales: estado del engine, tiempos, errores, secuencias y calidad GPS. Nombres de personas, notas y coordenadas precisas no aparecen en logs de uso habitual.

Modo de campo explícito puede guardar samples para exportación voluntaria. Mostrar qué contiene la exportación. No interpretar permiso de ubicación como consentimiento para compartir diagnósticos.

No basar el negocio en vender datos de conducción: no se están recogiendo centralmente y el consumo es estimado.

## 18. Batería, offline y fallos

### 18.1 Batería

Registrar consumo observado por hora con condiciones: modelo de iPhone, batería inicial, pantalla, Maps, conexión/carga y duración. No publicar como hecho un 5–8 %/h tomado de una estimación.

Reducir trabajo de UI en background, limitar updates de Live Activity, parar ubicación al terminar y evitar reverse-geocoding por fix. La precisión reducida durante pausa debe recuperar correctamente al moverse.

No añadir un objetivo ficticio de “0 % batería” después del viaje; comprobar que se ha detenido la sesión y que no queda trabajo innecesario.

### 18.2 Matriz de comportamiento

| Caso | Respuesta requerida |
|---|---|
| Sin internet | Viaje libre y datos locales funcionan; planificación muestra error recuperable |
| Señal GPS perdida | Marcar intervalo no medido o gap estimado según reglas; no inventar distancia |
| Usuario termina proceso | Al abrir, recuperar checkpoint y ofrecer resolver viaje interrumpido |
| Proceso terminado por sistema | Sin promesa de relanzamiento; misma recuperación coherente al ejecutar de nuevo |
| Live Activity descartada | Tracking sigue; no recrear en bucle |
| Permiso revocado | Detener adquisición, conservar acumulado y permitir terminar/resolver |
| Precio cambiado durante viaje | Mantener snapshot; nuevo precio sólo en siguientes viajes |
| Cambio de coche durante viaje | Bloquear hasta terminar |
| App sin Pro después de una compra anterior | Modo lectura de datos existentes; sin borrados |
| Pago superior al pendiente | Elegir grupo para el crédito y mostrar saldo a favor |
| Edición de viaje pagado | Recalcular cargos; conservar pagos y mostrar el resultado |
| Importación inválida | Rechazo claro y base local intacta |
| Viaje A→A | Ofrecer viaje libre; no confundir ruta de 0 km con una vuelta completa |
| Ferry/caminar sin terminar | Limitación explícita; controles manuales de pausa/fin |
| Cambio de hora/DST | Duración monotónica en ejecución y periodos Europe/Madrid consistentes |

## 19. Trabajo con Claude Code y Codex

### 19.1 Responsables iniciales

| Responsable | Propiedad principal | Revisión cruzada |
|---|---|---|
| Claude Code | UI, flujos de producto, integración del proyecto y servicios de sistema | Revisa contratos y uso del dominio |
| Codex | CostCore, reglas monetarias, reparto, ledger, persistencia y tests de integridad | Revisa fallos del engine, datos, compra y recuperación |
| Alejandro | Configuración privada, decisiones de producto, pruebas en iPhone/coche y feedback | Acepta el recorrido real y prioriza bloqueos |

Es una asignación operativa, no una afirmación de superioridad de un modelo. Si uno encuentra una solución mejor puede proponerla; el contrato y el responsable del archivo evitan implementaciones incompatibles.

Si sólo se utiliza un asistente a la vez, conservar los mismos tickets y handoffs. No depender de que ambos procesos puedan modificar simultáneamente un mismo checkout.

### 19.2 Reglas de integración

- Un repositorio y una rama de integración estable.
- Cada asistente trabaja en una rama/worktree separada si trabaja en paralelo.
- Un único responsable de integrar en cada momento.
- Xcode project, AppContainer, migraciones y CONTRACTS.md tienen propietario explícito; no editarlos concurrentemente.
- CostCore no importa frameworks de UI o del sistema.
- La UI trabaja contra los contratos, con fakes claramente identificados mientras llega la implementación.
- No hay acceso directo de ViewModels a tablas o StoreKit.
- Ningún cambio de schema, escala monetaria o regla de reparto se integra sin actualizar contrato y tests relevantes.
- Dos integraciones diarias; al cierre del día debe existir un build integrado.
- Guardar progreso en STATUS.md: commit, ticket, build/test ejecutado, limitaciones, próximo paso.
- No usar resultados de un fake como prueba de una API real.

Los prompts del apéndice se pueden pegar en cada asistente. Este archivo no instala, ejecuta ni coordina automáticamente Claude Code/Codex.

### 19.3 Contratos congelados al finalizar D1

- MoneyCents, UnitPriceMilliEUR y conversión de energía.
- Vehicle/Profile/FuelPrice snapshots.
- Trip y estados; esquema de ActiveTripState.
- SplitRule y SplitResult.
- Comandos de viaje/pago y modelos de consulta.
- Interfaces LocationProvider, RoutingService y PurchaseAccess.
- Propiedad de archivos compartidos y versión del esquema.

Un contrato puede evolucionar para corregir un fallo real; el cambio se acuerda en CONTRACTS.md antes de modificar dos implementaciones.

### 19.4 Definition of Done de un ticket

Código integrado, build verificable, prueba relevante aprobada y limitaciones documentadas. No basta con “archivos creados”.

Cada handoff incluye:
~~~text
Ticket:
Commit/branch:
Archivos modificados:
Contrato consumido o modificado:
Build/test ejecutado y resultado:
Prueba manual necesaria:
Bloqueo o limitación:
Próximo ticket:
~~~

No pedir permiso a Alejandro por cada detalle reversible. Sí involucrarlo para credenciales, decisiones de producto que cambien el alcance y pruebas físicas que el asistente no puede ejecutar.

## 20. Sprint de siete días

### 20.1 Calendario

| Día | Claude Code | Codex | Hito integrado y prueba de Alejandro |
|---|---|---|---|
| D1 | Proyecto, firma inicial, navegación y Drive con proveedor simulado | Contratos, dinero, cálculo, reparto, esquema inicial | App instalada; ejemplo de cálculo y reparto correcto |
| D2 | Core Location, background, Live Activity básica | Persistencia activa, recuperación, ledger y comandos atómicos | Primer trayecto real con pantalla bloqueada/Maps; revisar continuidad |
| D3 | Onboarding, planificación y apertura de navegadores | Consultas por persona/grupo/mes, pagos y tests | Viaje real guardado; primer build útil preparado para TestFlight |
| D4 | Personas, grupos, participantes, Cuentas y resumen | Integración transaccional, gastos manuales, pruebas de edición/borrado | Recorrido completo con Carlos: viaje → deuda → pago parcial |
| D5 | Paywall/StoreKit, Ajustes y estados de error | Backup/importación/CSV, pruebas de compra con interfaz falsa y StoreKit Testing | Free/Pro/restauración/revocación y backup round-trip |
| D6 | Pulido de bloqueos, accesibilidad básica, extras sólo si están listos | Regresiones, fixtures reales, integridad y rendimiento práctico | Campo urbano/autovía, pérdida de señal, cierre de proceso; beta candidata |
| D7 | Corregir bloqueantes, build firmada y paquete de prueba | Revisión del commit final, matriz de aceptación y reporte | MVP usable instalado; pruebas repetibles y límites conocidos documentados |

No retrasar la primera prueba real hasta D6. D2 es el punto donde se descubre si el atractivo del contador funciona con Maps delante.

### 20.2 Gates

**Fin de D1:** compila y se instala. Sin esto, no iniciar extras ni dedicar el día a diseño.

**Fin de D2:** hay medición real en background y una Live Activity ensayada. Si falla, concentrar ambos asistentes en ese bloqueo con propiedad de archivos separada. Mantener pruebas de recuperación aunque no exista relanzamiento automático.

**Fin de D4:** funciona el recorrido de cuentas completo. Si falta, suspender catálogo, mapas decorativos y CarPlay.

**Fin de D5:** congelación de funciones. D6–D7 sólo corrigen problemas de aceptación y terminan distribución/documentación.

**Fin de D7:** declarar uno de dos estados:
- “Beta CORE-7 aceptada”, con matriz aprobada y build instalada.
- “Beta parcial”, con requisitos concretos pendientes y siguiente acción.

Un screenshot o un replay no convierten una beta parcial en un MVP validado.

### 20.3 Orden de recorte si hay desvío

CarPlay pequeño → catálogo inicial → mapa de recorrido → alternativas de ruta → inglés → pulido adicional. NEXT ya está fuera del compromiso.

No recortar: escala monetaria correcta, consistencia de saldos, pagos, conservación de datos, recuperación honesta, pruebas reales mínimas ni distinción entre estimación y medición.

Si estos requisitos no llegan, el objetivo de siete días no se considera cumplido aunque la demo visual funcione.

## 21. Tickets implementables

Cada ticket tiene un resultado comprobable. Los responsables son los iniciales de la sección 19.

| ID | Responsable | Dependencias | Entrega y aceptación |
|---|---|---|---|
| T01 | Claude | — | Proyecto/targets/esquemas y firma; build e instalación inicial |
| T02 | Codex | — | Contratos y CostCore; casos de dinero de sección 5 y reparto de sección 8 |
| T03 | Codex | T02 | GRDB, migración y stores; constraints/FK/owner/grupo técnico correctos |
| T04 | Claude | T01,T02 | LocationProvider real y replay, engine y estados; prueba D2 en background |
| T05 | Claude | T04 | Live Activity; actualización observada con Maps y estado obsoleto |
| T06 | Codex | T03,T04 | Checkpoints/recuperación y fin transaccional; reabrir sin duplicar viaje/cargos |
| T07 | Codex | T03 | Ledger, cargos, pagos por grupo y consultas mensuales; ejemplos completos |
| T08 | Claude | T01,T02 | Onboarding/Plan/navegadores; ruta real o error y viaje libre |
| T09 | Claude | T07,T08 | Personas/grupos/participantes/Cuentas; acciones usan comandos de dominio |
| T10 | Ambos, integración Claude | T06,T07,T09 | Resumen, gastos manuales, editar/borrar y compartir; mismo total en todas las pantallas |
| T11 | Claude | T09 | StoreKit 2/ProGate/paywall; compra/cancelación/pendiente/restauración |
| T12 | Codex | T03,T07 | Backup completo/import/CSV; restauración de saldos exacta y rollback |
| T13 | Codex | T10,T11,T12 | Regresión de Free/Pro/revocación, pérdida de señal y compras de prueba |
| T14 | Claude + Alejandro | T04–T13 | Build final, campo, checklist y preparación de TestFlight |

T04 depende del contrato de persistencia, no de que el ledger esté acabado. T07 no depende de la UI de cuentas. T10 divide archivos: Claude escribe vistas; Codex escribe comandos/tests. Las dependencias indican orden lógico, no obligan a bloquear todos los trabajos hasta terminar una pantalla.

Extras con tickets separados: E01 vista pequeña; E02 catálogo inicial; E03 polilínea; E04 rutas alternativas; E05 inglés. No mezclar extras en commits que arreglan dinero o migraciones.

## 22. Pruebas y aceptación

### 22.1 Automatizadas prioritarias

1. Escala 1,499 €/L y 0,200 €/kWh; redondeo final y ausencia de redondeos por fix.
2. Repartos con resto, 0, 1 y varias personas; conductor 0 en passengersOnly.
3. Cargos sólo para pasajeros named; sumas iguales al reparto.
4. Edición/borrado de viaje y conservación de pagos.
5. Pago global repartido por grupos y deshacer lote sin residuos.
6. Apertura/cargos/pagos/cierre en meses vacíos y fronteras con DST.
7. Recovery de estado persistido y doble callback de fin idempotente.
8. Revocación y error de tienda sin borrados; permisos de escritura correctos.
9. Ventana Free de 30 días y totales completos del mes, incluido día 31.
10. Export/import round-trip; archivo inválido no modifica la base.
11. Filtros GPS con ruido, secuencia temporal, túnel y reanudación después de pausa.
12. Dos pasos concurrentes sobre el mismo viaje no dejan cargos parciales.

Comparar SQL y calculador puro con fixtures que incluyan saldos negativos, varios grupos, pagos parciales y meses sin cargos. No exigir porcentajes arbitrarios de coverage como sustituto de cubrir estos riesgos.

### 22.2 Ensayos de campo

| Ensayo | Evidencia requerida |
|---|---|
| 20–30 min urbano | Hora, distancia de referencia, distancia app, estado de pantalla y pérdidas de señal |
| 20–30 min ronda/autovía con Maps | Continuidad de fixes y actualización visible de actividad |
| Pausa y reanudación | Sin sumar jitter ni perder el arranque por una precisión incompatible |
| Pérdida de GPS/túnel/parking | Marcado correcto de gap/no medido; sin salto de coste inventado |
| Cerrar app y volver a abrir | Checkpoint recuperado, aviso de interrupción, sin duplicar cargos |
| Fin de viaje y pago parcial | Cuentas y mensaje compartido coinciden exactamente |
| BEV con replay | kWh y €/kWh; sin etiquetas de litros/gasolina en el resumen |

Distancia de referencia: odómetro anotado o recorrido medido razonablemente, con sus limitaciones. Objetivos iniciales de ensayo: error dentro del 5 % en carretera y 8 % urbano; si se incumplen, investigar. No publicar esas bandas como garantía general ni extrapolarlas al combustible.

Simular un cierre desde Xcode comprueba recuperación; no demuestra que iOS relance automáticamente tras presión de memoria. Separar las dos afirmaciones en FIELD_TESTS.md.

### 22.3 Checklist final CORE-7

- [ ] Instalada en iPhone y arranca sin configuración de desarrollo accidental.
- [ ] Planificar o empezar sin ruta funciona.
- [ ] Consumo/precio se conservan y no se piden cada viaje.
- [ ] Tracking real con Maps/pantalla bloqueada probado.
- [ ] Live Activity probada donde sea compatible; su fallo no rompe datos.
- [ ] Coste y reparto correctos, incluido gasto manual.
- [ ] Personas/grupos y presencias generan cargos correctos.
- [ ] Pagos parciales por grupo y mensajes de cuenta correctos.
- [ ] Editar/borrar no descuadra saldos.
- [ ] Free/Pro/restore/revocación probados sin borrados comerciales.
- [ ] Backup completo exportado e importado con saldos iguales.
- [ ] Interrupción recuperada con advertencia y sin distancia inventada.
- [ ] Limitaciones y pruebas pendientes escritas.
- [ ] Build/commit final identificados y procedimiento de instalación disponible.

La aceptación la completará el equipo durante el sprint. Las casillas vacías son intencionadas: este documento no constituye evidencia de ejecución.

## 23. Validación de producto y monetización

### 23.1 Qué medir en la beta

Invitar a 10–20 personas que de verdad compartan coche, preferiblemente de varios grupos independientes. El objetivo es observar fricción y fallos, no estimar una tasa comercial precisa.

Registrar con consentimiento y exportación voluntaria:
- Configuración completada.
- Primer viaje real completado.
- Uso en un segundo día y repetición durante la semana.
- Viajes olvidados o iniciados tarde, según lo cuente el tester.
- Uso de participantes y consulta de saldos.
- Registro de pagos para gestionar un intercambio real.
- Apertura de compartir y opinión sobre claridad del mensaje.
- Fallos, batería percibida y confianza en la estimación.

Los contadores locales no llegan mágicamente al desarrollador. Durante beta se recogen mediante exportación voluntaria/entrevista. Producción puede usar informes disponibles en App Store Connect para descargas y ventas; atribución específica por trigger requiere un diseño de medición adicional, no inventar datos.

### 23.2 Qué no valida TestFlight

Las IAP de TestFlight no cobran al tester. Una compra de prueba demuestra el flujo técnico, no voluntad real de pagar. [Apple: pruebas de compras](https://developer.apple.com/videos/play/wwdc2023/10142/).

No poner “éxito ≥3 % de conversión” sobre 15–20 testers. Una sola persona representa 5–6,7 puntos porcentuales y el pago es simulado. Preguntar por intención de compra puede aportar feedback cualitativo, pero no sustituye ventas reales.

Después del lanzamiento, analizar compras reales y retención, con denominadores claros: instalaciones, usuarios activados y usuarios que compartieron coche. No mezclar tasas de esos grupos.

### 23.3 Economía de lanzamiento

PVP objetivo: 3,99 €. Ejemplo bajo **supuestos de cálculo** de IVA 21 % y comisión Apple 15 %:

~~~text
3,99 / 1,21 × 0,85 = 2,80289256 € por venta aproximadamente
~~~

La comisión del Small Business Program requiere elegibilidad/inscripción; confirmar contrato y condiciones aplicables a la tienda antes de presupuestar. [Apple: Small Business Program](https://developer.apple.com/app-store/small-business-program/).

| Compras reales | Importe aproximado bajo esos supuestos |
|---|---|
| 100 | 280 € |
| 500 | 1401 € |
| 1000 | 2803 € |
| 5000 | 14 014 € |

Estas cifras no son beneficio final: faltan costes de herramientas, desarrollo, mantenimiento, adquisición y tributación del negocio. Verificar la cuota vigente de Apple al contratar; no declarar un punto de equilibrio total basado sólo en ella.

Ejemplo de captación: a conversión del 3 %, el ingreso inicial esperado por instalación sería unos 0,084 €. Ese 3 % es una hipótesis. No justifica anuncios ni descargas previstas por sí solo.

Mantener lanzamiento orgánico orientado a grupos reales y a enseñar la experiencia. El tiempo de crear contenido también es un coste. Cada mensaje compartido puede dar visibilidad, pero no garantiza instalaciones.

No incluir una proyección de 30 000 descargas “base” sin evidencia. No asumir que añadir una suscripción duplica ingresos manteniendo casi intacta la conversión. Revisar precio para nuevas compras cuando existan resultados; respetar el desbloqueo de quienes ya pagaron.

## 24. Roadmap después de la primera semana

| Prioridad | Trabajo | Condición para hacerlo |
|---|---|---|
| P1 | Corregir fallos de beta y facilitar repetir viajes | Feedback real de uso |
| P1 | Catálogo verificado y búsqueda fluida | Licencias/procedencia y matching fiables |
| P1 | Calibración mediante repostajes | Flujo sencillo y datos suficientes para evaluarla |
| P2 | Cierre de mes informativo, pesos, varios coches | Necesidad observada; reglas y tests explícitos |
| P2 | Widgets y App Intents/Siri | Núcleo estable y pruebas con hardware/SDK |
| P2 | MITECO y precios cercanos | Verificación de API, licencia, frecuencia y etiquetas de frescura |
| P3 | Sincronización iCloud | Diseño de conflictos y restauración; no promesa de merge automático |
| P3 | PHEV y consumo más sofisticado | Modelo validable, sin falsa precisión |
| P3 | Android | Demanda/coste confirmados; reescritura del dominio guiada por fixtures |
| Posterior | CarPlay nativo/B2B | Permisos, demanda y modelo de negocio propios |

La solicitud IDAE permanece como acción externa opcional. No enviar comunicaciones ni registrar servicios en nombre del usuario como consecuencia de leer este blueprint.

## 25. Referencias y control de afirmaciones

Fuentes consultadas en la revisión del 11-09-2026; volver a comprobar las APIs concretas en el SDK instalado antes de implementar o distribuir.

- [Apple: startUpdatingLocation](https://developer.apple.com/documentation/corelocation/cllocationmanager/startupdatinglocation()) — distinguir actualizaciones, suspensión y terminación.
- [Apple: autorización de ubicación](https://developer.apple.com/documentation/bundleresources/choosing-the-location-services-authorization-to-request) — alcance de When In Use.
- [Apple: ubicación en background](https://developer.apple.com/documentation/corelocation/handling-location-updates-in-the-background) — configuración y sesiones.
- [Apple: probar compras](https://developer.apple.com/videos/play/wwdc2023/10142/) — compras de prueba sin cobro.
- [Apple: testers externos](https://developer.apple.com/help/app-store-connect/test-a-beta-version/invite-external-testers/) — proceso de distribución beta.
- [Apple: privacidad de la app](https://developer.apple.com/help/app-store-connect/manage-app-information/manage-app-privacy/) — declarar según prácticas reales.
- [Apple: Small Business Program](https://developer.apple.com/app-store/small-business-program/) — condiciones del programa.
- [Apple: Xcode](https://developer.apple.com/xcode/) — entorno de construcción nativo.

Las comparativas de competencia, licencias de datasets, cobertura de modelos, consumo de batería, adopción de iOS y APIs nuevas que figuraban como certezas en rev. 4 no se trasladan sin prueba. Las candidatas se conservan como investigaciones del roadmap.

## Apéndice A. Prompt inicial para Claude Code

~~~text
Trabaja sobre ARCHITECTURE_BLUEPRINT_rev5.md como especificación vigente de EuroGas.
Objetivo: una beta CORE-7 instalada y probada en iPhone en siete días.

Tu responsabilidad inicial es proyecto iOS, UI, navegación, servicios de sistema e integración. Codex trabaja en CostCore, persistencia, ledger y pruebas de integridad. Respeta CONTRACTS.md y los propietarios de archivos. Si ambos trabajáis en paralelo, utiliza tu rama/worktree y no edites la migración o el dominio sin coordinar el contrato.

Primero inspecciona el repositorio existente, su estado Git, instrucciones y entorno de Xcode. Conserva trabajo previo útil. Si no existe proyecto, inicia T01. Construye el recorrido mínimo y consigue instalarlo; no dediques el primer día sólo al diseño.

Usa Swift/SwiftUI, iOS 18, GRDB y navegación externa. Pro es una compra única de 3,99 €, sin suscripción. Los precios por unidad usan milésimas de euro y los importes finales céntimos. No elimines historial al pasar a Free. No prometas recuperación automática del GPS ni precisión de consumo no demostrada.

Integra dos veces al día, registra commit/build/pruebas/bloqueos en STATUS.md y pide a Alejandro sólo los pasos privados o de hardware que no puedas ejecutar. Prueba background y Live Activity en D2. En D5 congela funciones. Mantén extras separados de CORE-7 y no declares completado algo probado sólo con mocks.
~~~

## Apéndice B. Prompt inicial para Codex

~~~text
Trabaja sobre ARCHITECTURE_BLUEPRINT_rev5.md como especificación vigente de EuroGas.
Objetivo: una beta CORE-7 instalada y probada en iPhone en siete días.

Tu responsabilidad inicial es CostCore, contratos de datos, GRDB, cálculo monetario, reparto, ledger, backup y pruebas de integridad. Claude Code lleva UI y servicios de sistema. Respeta CONTRACTS.md y los propietarios de archivos. Trabaja en una rama/worktree separada si se ejecutan ambos asistentes a la vez.

Primero inspecciona el código y el estado Git. Conserva implementaciones correctas. Prioriza T02/T03 y deja contratos estables para la UI en D1. El dominio sólo depende de Foundation. No introduzcas capas o dependencias que no resuelvan un problema concreto.

Casos obligatorios: 1,499 €/L no son 1499 céntimos; el ejemplo de 355 km produce 3895 céntimos; los repartos suman exactamente el total; passengersOnly deja al conductor en 0. Cargos y viaje se actualizan juntos; los pagos sobreviven a editar/borrar viajes. Todo pago tiene grupo y los lotes se deshacen atómicamente. No borres datos por límites comerciales o revocación.

La recuperación debe preservar lo guardado y marcar lo no medido. Backup debe restaurar los saldos, pero nunca una compra Pro. Revisa tests por casos de riesgo reales, no por número de archivos o cobertura decorativa.

Entrega commits pequeños con handoff de contrato, pruebas ejecutadas y siguiente paso. Revisa la integración sin modificar simultáneamente los archivos del otro asistente. No declares pruebas de iPhone que no hayas ejecutado; prepara el ensayo para Alejandro.
~~~

## Apéndice C. Guion de demostración del día 7

1. Configurar consumo y precio del coche una sola vez.
2. Planificar un trayecto y ver coste/reparto.
3. Iniciar, abrir Maps y bloquear pantalla; observar actividad y registro.
4. Terminar, añadir un gasto y compartir el reparto Free.
5. Probar la compra Pro en entorno de test; asignar Yo + Carlos al viaje.
6. Consultar el cargo de Carlos y registrar un pago parcial.
7. Editar un gasto/participante y comprobar que el pago permanece.
8. Consultar el mes, exportar backup y restaurar en un entorno de prueba.
9. Mostrar recuperación de un trayecto interrumpido con aviso de lo no medido.
10. Registrar build, commit y checklist; separar extras pendientes del estado CORE-7.

**Resultado buscado:** Alejandro puede usar el MVP para un viaje real y llevar una cuenta real entre compañeros; el equipo sabe qué funciona, qué se ha probado y qué queda fuera.
