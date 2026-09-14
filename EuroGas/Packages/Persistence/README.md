# Persistence

`Sources/Persistence/Migrations/v1_initial.sql` es la definición autoritativa del esquema v1 (DEC-005/DEC-013). `AppDatabase` ejecuta ese recurso mediante GRDB; no redefine tablas en Swift. SwiftPM fija GRDB 7.10.0 exactamente. La resolución y compilación del paquete quedan **UNVERIFIED-BUILD** hasta el primer Mac.

`Group.createdAt` es obligatorio y, junto con `id` como desempate, proporciona el orden determinista que consume `PaymentAllocationProposal`. Las referencias de `LedgerEntry` a `Trip` y `PaymentBatch` usan RESTRICT: borrar un registro referenciado por el ledger falla.

`EuroGasStore` proporciona bootstrap, configuración de vehículo, viaje/checkpoint/recuperación, cargos derivados, pagos, saldos, extractos, backup transaccional y CSV. La base in-memory se reserva para tests/previews. El arnés Node ejecuta el mismo DDL con SQLite real y no sustituye los tests Swift.
