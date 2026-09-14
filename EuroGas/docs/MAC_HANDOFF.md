# EuroGas — handoff al primer Mac

## Identidad exacta

- Repositorio: `C:\Users\mrani\Documents\Codex\Projects\CodexClaudeOrchestrate` en Windows; conservar la raíz Git al trasladarlo.
- Rama: `feature/prepare-eurogas-ios-app-for-mac`.
- Commit de implementación Windows: `e219e2e`.
- Obtener el HEAD documental final trasladado con `git rev-parse HEAD` y comprobar que desciende de `e219e2e`.
- No hubo push, deploy ni acciones Apple.

## Qué abrir

Abrir `EuroGas/EuroGas.xcodeproj` con Xcode 16.0 o posterior que incluya el SDK de iOS 18. El proyecto usa Swift 6, iOS 18, grupos sincronizados con el sistema de archivos y un esquema compartido `EuroGas`.

Targets esperados:

1. `EuroGas` — aplicación SwiftUI.
2. `EuroGasWidgets` — extensión Live Activity.
3. `EuroGasTests` — tests de aplicación.

Paquetes locales:

- `Packages/CostCore` — sin dependencias externas.
- `Packages/Persistence` — depende de CostCore y de GRDB exacto `7.10.0`.
- `Packages/EuroGasShared` — atributos ActivityKit.

## Identificadores provisionales

Cambiar todos estos valores en `EuroGas/Config/Project.xcconfig`:

```text
PRODUCT_BUNDLE_IDENTIFIER = com.example.EuroGas
TEST_BUNDLE_IDENTIFIER = com.example.EuroGas.Tests
WIDGET_BUNDLE_IDENTIFIER = com.example.EuroGas.TripLiveActivity
APP_GROUP_IDENTIFIER = group.com.example.EuroGas
PRO_PRODUCT_IDENTIFIER = com.example.EuroGas.pro
DEVELOPMENT_TEAM =
```

Actualizar además `productID` en `EuroGas/App/Resources/EuroGas.storekit` si se desea que StoreKit Testing refleje el identificador definitivo. No poner un precio de producción en Swift; el visible llega de StoreKit.

En Signing & Capabilities, seleccionar el mismo Team para app y extensión. Crear/seleccionar el App Group definitivo en ambos targets. No reutilizar los identificadores `com.example` para distribuir.

## Primera apertura, paso a paso

1. Copiar/clonar el repositorio sin perder archivos ocultos ni la rama.
2. Ejecutar `git status --short --branch` y `git log --oneline -5`.
3. Abrir `EuroGas/EuroGas.xcodeproj`.
4. Si Xcode propone actualizar el formato, guardar esa normalización en un commit separado después de revisar el diff.
5. File → Packages → Reset Package Caches solo si falla una resolución previa; normalmente usar Resolve Package Versions.
6. Confirmar que GRDB resuelve en `7.10.0`; no cambiar de versión para ocultar un error de código.
7. Seleccionar un simulador iOS 18 y el esquema `EuroGas`.
8. Compilar primero los paquetes como indica el checklist; luego la app; después tests.
9. Corregir errores de API/actor isolation detectados por el compilador, sin cambiar escalas monetarias, el DDL canónico ni reglas de reparto.
10. Añadir Team/Bundle IDs definitivos solo después de que la compilación sin firma esté entendida.

## Archivos principales

- Proyecto: `EuroGas.xcodeproj/project.pbxproj`, `xcshareddata/xcschemes/EuroGas.xcscheme`, `ProjectDefinition.json`.
- Configuración: `Config/*.xcconfig`.
- Composición: `App/AppContainer.swift`, `App/Services/ServiceContracts.swift`.
- Recorrido: `App/RootView.swift`, `App/Features/*`.
- Tracking: `App/Services/Trip/TripController.swift`, `App/Services/Location/AppleLocationProvider.swift`, `Packages/CostCore/Sources/CostCore/GPS`.
- Persistencia: `Packages/Persistence/Sources/Persistence/AppDatabase.swift`, `Records`, `Stores`.
- DDL único: `Packages/Persistence/Sources/Persistence/Migrations/v1_initial.sql`.
- Actividad: `Packages/EuroGasShared`, `Widgets/TripLiveActivity.swift`.
- Compra: `App/Services/Store/StoreKitPurchaseAccess.swift`, `App/Services/Store/ProGate.swift`, `App/Resources/EuroGas.storekit`.
- QA: `Packages/*/Tests`, `Tests/ServicesTests`, `Tools/validate-windows.mjs`.

## Diagnóstico reproducible

Desde la raíz del repositorio:

```bash
git status --short --branch
git log --oneline -5
node --test EuroGas/Packages/Persistence/Tests/PersistenceTests/schema_v1.test.mjs
npm test
xcodebuild -resolvePackageDependencies -project EuroGas/EuroGas.xcodeproj -scheme EuroGas
xcodebuild -list -project EuroGas/EuroGas.xcodeproj
xcodebuild -showBuildSettings -project EuroGas/EuroGas.xcodeproj -scheme EuroGas
xcodebuild build -project EuroGas/EuroGas.xcodeproj -scheme EuroGas -destination 'platform=iOS Simulator,name=iPhone 16' CODE_SIGNING_ALLOWED=NO
xcodebuild test -project EuroGas/EuroGas.xcodeproj -scheme EuroGas -destination 'platform=iOS Simulator,name=iPhone 16'
```

Cambiar el nombre de simulador por uno instalado (`xcrun simctl list devices available`).

## Errores probables en la primera build

- Xcode puede normalizar `project.pbxproj` o el esquema por usar grupos sincronizados de Xcode 16.
- Swift 6 puede exigir ajustes de aislamiento en delegates de Core Location, tareas StoreKit o callbacks ActivityKit.
- APIs MapKit/ActivityKit concretas pueden haber cambiado o estar deprecadas en el SDK instalado.
- Xcode puede pedir corregir el formato exacto de `EuroGas.storekit`.
- App Group provisional no existe en el portal; usar contenedor Application Support hasta configurar el definitivo.
- La extensión puede requerir que Xcode regenere/complete settings de firma o Info.plist.
- El arnés confirma que el icono es PNG de 1024×1024 sin alfa; aun así debe revisarse en el asset inspector y en dispositivo.

Cada corrección debe quedar en un commit pequeño, con el error literal y el test/build que lo verifica.

## Sigue sin verificarse

Todo Swift y el proyecto: **UNVERIFIED-BUILD**. Xcode, simulador, firma, iPhone, background tracking, navegación real, Live Activity real, StoreKit Testing y TestFlight: **EXTERNO**.

## Antes de conectar el iPhone

- [ ] CostCore y sus tests compilan/pasan.
- [ ] Persistence resuelve GRDB 7.10.0 y sus tests pasan.
- [ ] App y extensión compilan en simulador.
- [ ] Tests de aplicación pasan.
- [ ] Team, Bundle IDs y App Group definitivos configurados coherentemente.
- [ ] Textos de ubicación revisados.
- [ ] No hay credenciales, logs sensibles ni datos personales de fixture.
- [ ] El viaje fake/replay está claramente separado de la configuración Release.
- [ ] Se ha leído `FIELD_TESTS.md` y la conducción se hará de forma supervisada.
