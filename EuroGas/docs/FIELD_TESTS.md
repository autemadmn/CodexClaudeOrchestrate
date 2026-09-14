# EuroGas — pruebas de campo

Todos los procedimientos de este archivo son **EXTERNO**. No se han ejecutado en Windows y un replay/fake no los sustituye.

## Preparación segura

- Mac con Xcode 16 o posterior compatible con iOS 18.
- iPhone compatible, cable/carga y equipo Apple Development seleccionado.
- Vehículo estacionado para configurar la app. Durante la conducción, quien conduce no manipula el móvil.
- Anotar modelo de iPhone, versión iOS, batería inicial, conexión/carga y si Apple Maps está en primer plano.

## Matriz mínima

| Ensayo | Procedimiento | Evidencia |
|---|---|---|
| Apertura/build | Resolver paquetes, compilar CostCore, Persistence, app y tests | Log de Xcode y commit |
| 20–30 min urbano | Iniciar, bloquear pantalla, pausar/reanudar y finalizar | Hora, odómetro/referencia, km app, coste, señal, batería |
| 20–30 min autovía con Maps | Abrir navegación externa y mantener EuroGas en background | Continuidad de fixes y actualizaciones visibles |
| Túnel/parking | Atravesar una pérdida breve y una prolongada | Gap estimado separado de intervalo no medido; sin salto ficticio |
| Pausa | Parar manualmente y probar pausa estacionaria | Sin sumar jitter; nueva ancla al reanudar |
| Cierre/reapertura | Terminar proceso desde Xcode y abrir de nuevo | Pantalla interrumpida; continuar/terminar/descartar; sin duplicados |
| Permiso revocado | Revocar ubicación durante el viaje | Acumulado conservado y finalización posible |
| Live Activity | Lock Screen y Dynamic Island compatible | Inicio/update/fin; stale visible; fallo no detiene tracking |
| BEV replay + dispositivo | Perfil kWh/100 km y €/kWh | Ninguna etiqueta de litros/gasolina en resultado |
| Cuenta completa | Viaje named, gasto, pago parcial, editar/borrar | Cargos recalculados; pago permanece; crédito visible |
| Backup | Exportar, importar en base de ensayo y comparar | Mismos viajes, gastos, pagos y saldos; Pro no restaurado |
| StoreKit Testing | Comprar, cancelar, pending, restaurar y revocar | Precio StoreKit; datos intactos; Free tras revocación |

## Continuidad y límites

Objetivos iniciales de investigación: diferencia de distancia menor del 5 % en carretera y 8 % en urbano. Son umbrales de diagnóstico, no una garantía comercial. Comparar contra odómetro o recorrido de referencia y registrar sus limitaciones.

Probar por separado:

1. app en background con Maps delante;
2. pantalla bloqueada;
3. proceso terminado por el usuario;
4. proceso terminado por el sistema cuando sea reproducible;
5. regreso tras más de 90 segundos.

La configuración no promete relanzamiento automático. Tras interrupción, comprobar que EuroGas crea una ancla nueva y marca lo no medido.

## Live Activity

Verificar Lock Screen, compact, minimal y expanded. Confirmar que no aparecen nombres ni saldos personales. Esperar más de 30 segundos sin update para inspeccionar `staleDate`. Descartar manualmente la actividad y confirmar que no se recrea en bucle y que el viaje continúa.

## StoreKit

Usar primero `App/Resources/EuroGas.storekit`; no crear ni cobrar un producto real durante esta fase. Probar `success`, cancelación, pendiente, fallo temporal, restore y revocación. Confirmar que un fallo temporal no se interpreta como revocación y que el backup no contiene producto, recibo ni entitlement.

## Registro de cada ensayo

```text
Fecha/hora:
Commit/build:
iPhone/iOS:
Escenario:
Pantalla/Maps/carga:
Distancia de referencia:
Distancia aceptada:
Gap estimado/no medido:
Coste y parámetros:
Resultado:
Logs no sensibles:
Incidencias y siguiente acción:
```
