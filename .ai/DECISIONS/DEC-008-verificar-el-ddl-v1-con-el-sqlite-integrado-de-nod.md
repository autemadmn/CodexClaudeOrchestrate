# DEC-008 Verificar el DDL v1 con el SQLite integrado de Node, sin añadir dependencias

## Context
DEC-005 fija el esquema v1 como DDL SQL canónico y deja abierta la elección de la herramienta de verificación. El host es Windows sin Xcode; el repositorio declara Node >= 22 y no tiene dependencias de runtime. Las partes más frágiles de §7.3 (índices únicos parciales de owner y de viaje activo, CHECKs del ledger, FKs) sólo se comprueban ejecutándolas.

## Decision
El arnés de verificación del esquema ejecuta v1_initial.sql contra el módulo SQLite integrado de Node (node:sqlite) con foreign keys activadas, mediante `node --test` sobre ficheros dentro de EuroGas/Packages/Persistence/Tests/, sin instalar paquetes ni modificar package.json. Si ese módulo no está disponible en el Node instalado, el esquema se etiqueta UNVERIFIED con la causa registrada y no se añade ninguna dependencia.

## Reason
Es SQLite real, el mismo motor que usará la app, con cero dependencias nuevas y sin tocar ficheros que requieren aprobación Brain (package.json). Evita escribir código Swift/GRDB que nadie puede compilar aquí para probar justamente la parte más delicada.

## Alternatives
- Añadir better-sqlite3 u otra dependencia npm (dependencia nueva, requiere aprobación y compilación nativa en Windows)
- Instalar el binario sqlite3 CLI (modificación del sistema, requiere aprobación humana)
- Probar el esquema desde Swift con GRDB (no compila en Windows, contradice DEC-005)
- Dejar el DDL sin verificar (pierde la única prueba real posible del tramo si no hay toolchain Swift)

## Consequences
El esquema puede quedar VERIFIED aunque no haya Swift en el host. El arnés de pruebas del esquema vive en JavaScript y no en Swift, por lo que habrá que portarlo o complementarlo cuando exista la capa GRDB; CONTRACTS.md debe declarar que el .sql es la única definición para evitar deriva. node:sqlite es experimental: su salida debe registrarse literalmente, incluidos avisos.

_Recorded by product-architect-manager in run 20260911-174246._
