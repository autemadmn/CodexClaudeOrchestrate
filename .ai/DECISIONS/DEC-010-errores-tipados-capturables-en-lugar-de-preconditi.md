# DEC-010 Errores tipados capturables en lugar de precondition en el núcleo CostCore

## Context
CostInputs.init, ambas rutas de CostEngine y SplitEngine.split validaban con `precondition`/`preconditionFailure`, que aborta el proceso: una entrada inválida mata la app y no puede cubrirse con un test. El blueprint §5.1 exige validar rangos con mensajes que permitan corregir, y la QA ronda 5 lo registró como defecto de spec.

## Decision
Introducir un enum público `CostCoreError: Error, Equatable, LocalizedError` en CostCore/Models y convertir CostInputs.init, ambas sobrecargas de CostEngine.calculate y SplitEngine.split en APIs `throws`, eliminando los precondition de validación de entrada. Los mensajes de error van en errorDescription, como ya hace MoneyParsingError.

## Reason
Es la única forma de que la capa de presentación pueda mostrar un mensaje corregible y de que las condiciones inválidas queden cubiertas por tests; también homogeneiza el núcleo con el resto del módulo, que ya usa errores tipados (MoneyParsingError, PaymentAllocationError, AccountingPeriodError, FreeWindowError).

## Alternatives
- Mantener precondition y documentar las precondiciones como contrato del llamante: rechazado por la QA y por §5.1; deja la app expuesta a aborto y las ramas sin test.
- Devolver Optional/Result en lugar de throws: menos idiomático en este módulo, que ya usa throws con errores tipados, y obligaría a dos estilos de manejo de errores.
- Exponer un validador separado que devuelva un motivo (extensión del actual rejectionReason): duplica la validación y permite construir valores inválidos si no se llama.

## Consequences
Cambio incompatible en la API pública del núcleo; todos los llamantes (hoy sólo los tests) necesitan `try`. CONTRACTS.md debe congelar las firmas `throws`. La propagación de `throws` a helpers internos (energy) no se puede verificar aquí por falta de toolchain Swift: queda UNVERIFIED-BUILD.

_Recorded by product-architect-manager in run 20260912-111714._
