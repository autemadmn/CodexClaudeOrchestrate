# EuroGas — checklist de primera build Xcode

Marcar solo con salida real de Xcode. Hasta entonces todo Swift es **UNVERIFIED-BUILD**.

## CostCore

- [ ] Abrir `EuroGas/Packages/CostCore/Package.swift` o usar `swift test --package-path EuroGas/Packages/CostCore`.
- [ ] Compilar CostCore con Swift 6.
- [ ] Ejecutar todos los tests, incluidos dinero, 355 km, split, ledger, periodos, GPS y estados.
- [ ] Confirmar que no enlaza SwiftUI, UIKit, CoreLocation, MapKit, StoreKit, ActivityKit ni GRDB.

## Persistence

- [ ] Resolver GRDB exactamente en 7.10.0.
- [ ] Confirmar que `Bundle.module` encuentra `Migrations/v1_initial.sql`.
- [ ] Ejecutar tests in-memory de bootstrap, cargos, pagos, edición/borrado y backup.
- [ ] Confirmar foreign keys y WAL en una base de archivo.
- [ ] Verificar rollback ante backup inválido y saldos idénticos en round-trip.
- [ ] Verificar protección de archivo después del primer desbloqueo en iPhone.

## Aplicación

- [ ] Abrir `EuroGas.xcodeproj` y comprobar targets `EuroGas`, `EuroGasWidgets`, `EuroGasTests`.
- [ ] Resolver paquetes locales.
- [ ] Compilar `EuroGas` para un simulador iOS 18 sin firma.
- [ ] Corregir únicamente errores reales registrados por Xcode.
- [ ] Navegar onboarding → conducir → finalizar → viajes → cuentas → ajustes.
- [ ] Comprobar estados vacíos, errores, Dynamic Type, VoiceOver y targets táctiles.

## Tests de aplicación

- [ ] Ejecutar `EuroGasTests`.
- [ ] Confirmar AppContainer único, fakes, recorrido vertical, checkpoint/recuperación, routing, Live Activity fake, Store fake, ProGate y backup inválido.
- [ ] Añadir test de regresión por cada corrección de primera build que pueda aislarse.

## Simulador

- [ ] Probar permisos permitido/denegado/restringido/reducido.
- [ ] Probar viaje libre y planificación A→A.
- [ ] Probar reparto everyone/passengersOnly y gasto manual.
- [ ] Probar Free, Pro fake/local, revocación y datos conservados.
- [ ] Exportar/importar documentos con file exporter/importer.

## Firma

- [ ] Sustituir todos los identificadores `com.example` en `Config/Project.xcconfig`.
- [ ] Seleccionar Apple Development Team en app y extensión.
- [ ] Configurar App Group definitivo en ambos targets.
- [ ] Confirmar firma automática y perfiles válidos.
- [ ] No guardar certificados, perfiles ni credenciales en Git.

## Dispositivo físico

- [ ] Instalar en iPhone iOS 18 compatible.
- [ ] Confirmar arranque, persistencia y exportación.
- [ ] Ejecutar la matriz de `FIELD_TESTS.md` sin manipular el móvil al conducir.

## Background location

- [ ] Maps delante con EuroGas en background.
- [ ] Pantalla bloqueada.
- [ ] Pausa/reanudación y precisión temporal.
- [ ] Permiso revocado, túnel/gap y cierre/reapertura.
- [ ] Confirmar que no se promete relanzamiento automático.

## Live Activity

- [ ] Inicio/update/fin en Lock Screen.
- [ ] Compact/minimal/expanded en hardware compatible.
- [ ] `staleDate` y descarte manual.
- [ ] El tracking continúa si ActivityKit falla.

## StoreKit Testing

- [ ] Seleccionar `App/Resources/EuroGas.storekit` en el esquema.
- [ ] Precio mostrado proviene de `Product.displayPrice`.
- [ ] Compra, cancelación, pending, fallo, restore y revocación.
- [ ] Pérdida de Pro conserva datos y bloquea nuevas operaciones Pro.
- [ ] El backup no restaura entitlement.
