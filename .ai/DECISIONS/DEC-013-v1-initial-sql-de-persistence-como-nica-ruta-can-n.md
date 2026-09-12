# DEC-013 v1_initial.sql de Persistence como única ruta canónica citada en la documentación

## Context
CONTRACTS.md declaraba el DDL canónico en EuroGas/Packages/CostCore/v1_initial.sql, ruta que no existe, y lo daba por no entregado, mientras el fichero real y verificado (18/18 sobre SQLite) vive en EuroGas/Packages/Persistence/Sources/Persistence/Migrations/v1_initial.sql. DEC-005 encarga precisamente a CONTRACTS.md evitar esa deriva.

## Decision
Fijar EuroGas/Packages/Persistence/Sources/Persistence/Migrations/v1_initial.sql como única ruta canónica en CONTRACTS.md y STATUS.md, eliminar toda mención a la ruta inexistente y declarar que cualquier binding futuro debe ejecutar ese mismo texto SQL.

## Reason
Un consumidor que siguiera el contrato escrito concluiría que no hay esquema y lo redefiniría, el riesgo exacto que DEC-005 y DEC-008 pretenden cerrar.

## Alternatives
- Mover el fichero a la ruta documentada: rompería el arnés SQLite verificado y el layout del paquete Persistence sin beneficio.
- Documentar ambas rutas: perpetúa la ambigüedad que causó el defecto.

## Consequences
La documentación deja de mencionar rutas de CostCore para el esquema; cualquier movimiento futuro del fichero obliga a actualizar CONTRACTS.md y STATUS.md en el mismo cambio.

_Recorded by product-architect-manager in run 20260912-111714._
