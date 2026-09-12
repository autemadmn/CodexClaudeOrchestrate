# DEC-012 Eliminar SplitRejection/rejectionReason al introducir el error tipado

## Context
El par interno SplitRejection + rejectionReason existía sólo para que un test pudiera comprobar la condición que después provocaba un precondition no capturable.

## Decision
Eliminar ambos y hacer que SplitEngine.split lance directamente passengersOnlyWithoutPassengers, adaptando SplitEngineTests a XCTAssertThrowsError.

## Reason
Con un error capturable el andamio pierde su razón de ser; mantener dos representaciones del mismo rechazo invita a que divergan.

## Alternatives
- Conservar rejectionReason como API de validación previa: duplica la fuente de verdad del rechazo.
- Hacer público SplitRejection: añade un segundo tipo de error público redundante con CostCoreError.

## Consequences
Desaparece un símbolo interno usado por un test existente, que debe reescribirse. No afecta a ninguna API pública previamente documentada.

_Recorded by product-architect-manager in run 20260912-111714._
