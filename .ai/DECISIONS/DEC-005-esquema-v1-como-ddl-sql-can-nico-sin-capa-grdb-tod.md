# DEC-005 Esquema v1 como DDL SQL canónico, sin capa GRDB todavía

## Context
§4.1 fija GRDB/SQLite y §7.3 detalla constraints, índices parciales y FKs. GRDB no tiene soporte oficial en Windows, por lo que su código no compilaría ni se probaría aquí.

## Decision
Definir el esquema v1 como un fichero SQL canónico único (`Migrations/v1_initial.sql`) que sea la definición autoritativa, y verificar sus constraints ejecutándolo contra un SQLite real disponible en este host. El binding GRDB (AppDatabase, Records, Stores) se difiere al tramo siguiente y deberá ejecutar ese mismo texto SQL.

## Reason
Permite verificar de verdad lo más frágil del §7.3 (índices únicos parciales de owner y viaje activo, CHECKs de ledger, FKs) con el mismo motor que usará la app, en lugar de escribir código Swift que nadie puede compilar. No es un mock: es SQLite real ejecutando el SQL de producción.

## Alternatives
- Escribir la capa GRDB completa y marcarla UNVERIFIED-BUILD (mucho código no verificado sobre la parte más delicada)
- Definir el esquema en Swift dentro de GRDB migrator y no verificar nada
- Aplazar toda la persistencia a un tramo posterior (contradice la prioridad explícita del objetivo)

## Consequences
El esquema queda verificado antes de que exista código de acceso a datos. Riesgo de deriva si alguien redefine tablas en Swift: CONTRACTS.md debe declarar el .sql como única definición. Requiere elegir y aprobar la herramienta SQLite de verificación.

_Recorded by product-architect-manager in run 20260911-174246._
