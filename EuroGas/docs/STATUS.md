# EuroGas — estado preparado para Mac

Fecha de cierre Windows: 2026-09-14.

## Clasificación obligatoria

- **VERIFIED**: comando ejecutado realmente en este Windows con salida observada.
- **UNVERIFIED-BUILD**: código Swift o proyecto Xcode escrito, pero no compilado aquí.
- **EXTERNO**: requiere Mac, Xcode, Apple Developer, App Store Connect, iPhone, vehículo o revisión de Apple.

No se usa ninguna cuarta categoría de evidencia.

## Resumen

| Entregable | Estado | Evidencia o límite |
|---|---|---|
| Proyecto `EuroGas.xcodeproj`, targets app/tests/widget y esquema compartido | **UNVERIFIED-BUILD** | Estructura y referencias comprobadas por arnés estático; Xcode no está disponible |
| CostCore: dinero, coste, reparto, ledger, periodos, GPS y estados | **UNVERIFIED-BUILD** | Fuentes/tests escritos; no se ejecutó Swift |
| DDL canónico SQLite v1 | **VERIFIED** | `node --test ...schema_v1.test.mjs`: 18 pass, 0 fail |
| Persistence GRDB 7.10.0 | **UNVERIFIED-BUILD** | Carga el SQL canónico; stores, transacciones, memoria/tests y backup escritos; SwiftPM no resuelto aquí |
| Recorrido SwiftUI y AppContainer | **UNVERIFIED-BUILD** | Navegación/fakes inspeccionados y estructura validada; no compilados |
| Core Location y routing Apple | **UNVERIFIED-BUILD** | Implementaciones escritas detrás de protocolos; sin ejecución iOS |
| Live Activity | **UNVERIFIED-BUILD** | App, atributos compartidos y extensión escritos; sin build |
| StoreKit 2 y Free/Pro | **UNVERIFIED-BUILD** | StoreKitPurchaseAccess, ProGate, ventana de detalle y configuración local escritos; sin StoreKit Testing |
| Backup/import/CSV | **UNVERIFIED-BUILD** | Implementación/tests Swift escritos; no ejecutados |
| Validación estructural Windows | **VERIFIED** | `npm run test:eurogas:static`: 1 pass, 0 fail |
| Suite del repositorio | **VERIFIED** | `npm test`: 35 pass, 0 fail |
| Whitespace/diff | **VERIFIED** | `git diff --check`: código 0 |
| Xcode/Swift build | **EXTERNO** | Ejecutar checklist en Mac |
| Simulador/iPhone/background/Live Activity real | **EXTERNO** | Ejecutar `FIELD_TESTS.md` |
| Firma/TestFlight/App Store Connect | **EXTERNO** | No ejecutado |

## Preparado en fuentes

- iOS 18, Swift 6, versión 0.1.0 (1), Bundle ID y App Group provisionales, Team vacío.
- Un composition root con repositorio, location, routing, trip, ledger, compra, backup, Live Activity y reloj.
- Onboarding español; configuración de energía, consumo y precio.
- Planificación opcional, viaje libre, navegadores externos, tracking, pausa/reanudación, cierre, gastos, reparto y mensajes.
- Personas/grupos, owner en índice 0, cargos por grupo, saldos, extracto mensual, pagos parciales y deshacer lote.
- Edición transaccional preparada en repositorio y borrado que conserva pagos.
- Ventana Free de 30 días aplicada al detalle; ProGate separa creación Pro de lectura histórica y conserva lectura/exportación tras revocación.
- Backup JSON v1 validado antes de reemplazar, rollback transaccional, entitlement excluido y CSV separado.
- Checkpoints SQLite, recuperación honesta, nueva ancla tras interrupción, gaps no medidos, espera real de autorización y conservación del acumulado si se revoca ubicación.
- Fakes/replays deterministas y tests Swift de dominio, persistencia y recorrido.

## Evidencia Windows

Los comandos finales y sus códigos de salida se ejecutan desde la raíz del repositorio:

```powershell
npm test
node --test EuroGas/Packages/Persistence/Tests/PersistenceTests/schema_v1.test.mjs
npm run test:eurogas:static
git diff --check
```

Resultados observados: 35/35, 18/18, 1/1 y código 0 respectivamente. Estos comandos no compilan Swift ni prueban iOS.

## Límites honestos

- Todo Swift permanece **UNVERIFIED-BUILD** hasta resolver paquetes y compilar en Xcode.
- El `project.pbxproj` fue construido y validado estáticamente; que Xcode lo abra y normalice es **EXTERNO**.
- Core Location, background location, MapKit, ActivityKit, StoreKit, firma, app icon final y accesibilidad real son **EXTERNO**.
- No se promete relanzamiento automático por iOS ni distancia durante intervalos sin medición.
- No hubo push, deploy, App Store Connect, TestFlight, certificados, perfiles ni credenciales.

## Handoff

Rama: `feature/prepare-eurogas-ios-app-for-mac`.

Commit de implementación Windows: `e219e2e` (`Handle EuroGas location authorization lifecycle`). La documentación de cierre se añade encima en un commit local posterior; el HEAD exacto debe obtenerse con `git rev-parse HEAD` al abrir el repositorio.

Continuar con [MAC_HANDOFF.md](MAC_HANDOFF.md), [XCODE_FIRST_BUILD_CHECKLIST.md](XCODE_FIRST_BUILD_CHECKLIST.md) y [TESTFLIGHT_PREPARATION.md](TESTFLIGHT_PREPARATION.md).
