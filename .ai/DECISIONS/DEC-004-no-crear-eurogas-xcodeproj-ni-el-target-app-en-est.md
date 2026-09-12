# DEC-004 No crear EuroGas.xcodeproj ni el target App en este entorno

## Context
§4.3 describe un proyecto Xcode con target App, Widgets y recursos. El host es Windows, sin Xcode ni Mac. Un .xcodeproj escrito a mano no se puede abrir, compilar ni validar aquí.

## Decision
Este tramo crea únicamente paquetes SwiftPM (CostCore y, como DDL, Persistence). EuroGas.xcodeproj, el target App, Widgets, Resources y entitlements quedan diferidos y se registran como EXTERNO con procedimiento pendiente en el Mac.

## Reason
El blueprint prohíbe generar estructura vacía para aparentar avance (§4.3) y prohíbe declarar probado lo que sólo se ha escrito (§19.4). Un pbxproj no verificable es exactamente eso, y además es una fuente de conflictos de integración.

## Alternatives
- Generar un pbxproj a mano y marcarlo UNVERIFIED-BUILD
- Generar el proyecto con XcodeGen/Tuist (dependencia nueva, tampoco verificable aquí)
- Esperar al Mac para todo, incluido CostCore (bloquearía trabajo perfectamente implementable)

## Consequences
El tramo no puede demostrar el gate de fin de D1 (§20.2, compila e instala). La primera sesión en el Mac deberá crear el proyecto y enlazar los paquetes; los contratos ya congelados reducen ese riesgo.

_Recorded by product-architect-manager in run 20260911-174246._
