# Persistence

`Sources/Persistence/Migrations/v1_initial.sql` es la definición autoritativa del esquema v1 (DEC-005). Este tramo no incluye capa Swift ni GRDB: las capas futuras deben ejecutar este mismo texto y no redefinir las tablas.

`Group.createdAt` es obligatorio y, junto con `id` como desempate, proporciona el orden determinista que consume `PaymentAllocationProposal`. Las referencias de `LedgerEntry` a `Trip` y `PaymentBatch` usan RESTRICT: borrar un registro referenciado por el ledger falla.
