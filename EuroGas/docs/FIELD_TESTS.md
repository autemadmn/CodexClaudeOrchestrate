# Procedimientos externos — EXTERNO

## Apertura en Xcode — EXTERNO

**Se necesita:** un Mac con una versión compatible de Xcode y el repositorio.

**Cómo se comprobará:** abrir el paquete `EuroGas/Packages/CostCore` en Xcode y verificar que el paquete resuelve sin dependencias externas y que su esquema de tests aparece disponible.

## Instalación en iPhone — EXTERNO

**Se necesita:** un Mac con Xcode, un iPhone compatible, Apple ID/equipo de firma y la configuración de firma correspondiente.

**Cómo se comprobará:** compilar una build de la app desde Xcode, instalarla en el iPhone y confirmar que se abre correctamente.

## Tracking de campo — EXTERNO

**Se necesita:** un iPhone instalado, un vehículo real, configuración de consumo y precio, y dos sesiones de conducción supervisada; quien conduce no manipula el móvil.

**Cómo se comprobará:** durante un recorrido real, iniciar, pausar, reanudar y finalizar el viaje con la pantalla bloqueada y el navegador delante; comparar la distancia y el coste registrados con los datos observados y revisar los errores recuperables.

## StoreKit real — EXTERNO

**Se necesita:** Apple ID de pruebas, configuración de StoreKit/App Store Connect y un producto Pro configurado.

**Cómo se comprobará:** en el entorno de pruebas, ejercitar compra, restauración, cancelación, estado pendiente y revocación, y comprobar que el estado Pro y los datos locales quedan coherentes.

## Live Activity — EXTERNO

**Se necesita:** un iPhone compatible con Live Activity y una build firmada que incluya la actividad.

**Cómo se comprobará:** iniciar un viaje y verificar en la pantalla bloqueada y, cuando corresponda, en Dynamic Island que la actividad inicia, actualiza y finaliza; confirmar también que un fallo de la actividad no detiene el viaje.
