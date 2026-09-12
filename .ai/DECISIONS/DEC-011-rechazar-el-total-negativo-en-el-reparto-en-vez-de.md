# DEC-011 Rechazar el total negativo en el reparto en vez de devolver un reparto vacío

## Context
SplitEngine.split con total.cents < 0 caía en la guarda `total.cents > 0` y devolvía shares vacío, de modo que suma(shares) = 0 != total, rompiendo la invariante central de §8.2. La prueba de propiedad no lo detectaba porque sólo generaba totales 0..100000.

## Decision
Lanzar CostCoreError.negativeTotal cuando total.cents < 0, manteniendo shares vacío únicamente para total.cents == 0, y extender la prueba de propiedad con al menos un caso de total negativo que espera el error.

## Reason
Un total negativo no es un reparto representable: silenciarlo produce una salida que viola la invariante que el resto del sistema da por cierta. Rechazarlo explícitamente mantiene «la suma de shares ya es el total» como verdad sin excepciones.

## Alternatives
- Repartir el negativo proporcionalmente: introduce semántica de reembolso que el blueprint beta no define.
- Saturar a cero y seguir devolviendo vacío: conserva el defecto, sólo lo documenta.
- Validar únicamente en la capa superior: deja el núcleo con una rama incorrecta alcanzable.

## Consequences
total == 0 y total < 0 dejan de ser el mismo caso, lo que los llamantes deben distinguir. La distinción queda cubierta por tests y congelada en CONTRACTS.md.

_Recorded by product-architect-manager in run 20260912-111714._
