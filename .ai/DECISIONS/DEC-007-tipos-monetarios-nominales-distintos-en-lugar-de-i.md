# DEC-007 Tipos monetarios nominales distintos en lugar de Int64 desnudo

## Context
§5.1 obliga a que precio (milésimas) e importe (céntimos) tengan tipos y nombres distintos para no confundir escalas, y señala que 1,499 €/L no son 1499 céntimos.

## Decision
MoneyCents y UnitPriceMilliEUR son structs distintos, no alias de Int64, y ninguna API pública de CostCore acepta Int64 desnudo para dinero o precio. El parsing localizado rechaza entradas ambiguas en vez de normalizarlas.

## Reason
Es el error monetario que el blueprint señala explícitamente como corregido respecto de rev. 4; el compilador debe impedirlo, no una convención de nombres.

## Alternatives
- typealias sobre Int64 (no da seguridad de tipos)
- Un único tipo Money con campo de escala (invita a conversiones implícitas)

## Consequences
Algo más de código de conversión en los bordes (persistencia, UI, backup). A cambio, la confusión de escalas se vuelve un error de compilación.

_Recorded by product-architect-manager in run 20260911-174246._
