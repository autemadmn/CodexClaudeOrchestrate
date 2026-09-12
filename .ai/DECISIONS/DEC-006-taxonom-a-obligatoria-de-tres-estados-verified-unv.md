# DEC-006 Taxonomía obligatoria de tres estados: VERIFIED / UNVERIFIED-BUILD / EXTERNO

## Context
El objetivo exige registrar como EXTERNO lo que depende de Apple y no declarar probado nada que este Windows no pueda verificar. Existe un tercer caso distinto: código que no se compila aquí por falta de toolchain, sin relación con Apple.

## Decision
Cada entregable se etiqueta con exactamente uno de los tres estados en docs/STATUS.md. VERIFIED exige salida de comando real. UNVERIFIED-BUILD cubre la falta de toolchain local. EXTERNO se reserva a Apple, hardware y credenciales.

## Reason
Sin esta distinción, 'no hay compilador aquí' se disfraza de 'depende de Apple', lo que convierte una deuda resoluble en un bloqueo externo aparentemente inevitable y falsea el inventario de cierre.

## Alternatives
- Usar sólo las etiquetas del blueprint (CORE-7/EXTERNO/VALIDAR)
- Etiquetado binario probado/no probado

## Consequences
Los informes de cierre son más honestos y accionables. Obliga a que cada tarea declare su estado y a que el QA rechace afirmaciones sin salida de comando.

_Recorded by product-architect-manager in run 20260911-174246._
