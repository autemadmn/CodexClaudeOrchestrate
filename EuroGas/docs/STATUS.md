# Estado inicial de EuroGas

## Gate G0

Comando ejecutado en este host Windows 11 (PowerShell):

`swift --version 2>&1; if (-not $?) { exit 1 }`

Código de salida: `1`.

```
swift: 
Line |
   2 |  swift --version 2>&1; if (-not $?) { exit 1 }
     |  ~~~~~
     | The term 'swift' is not recognized as a name of a cmdlet, function, script file, or executable program.
Check the spelling of the name, or if a path was included, verify that the path is correct and try again.
```

No hay toolchain Swift disponible en este host y no se instalará ninguno, conforme a DEC-009.

## Taxonomía de verificación (DEC-006)

- **VERIFIED** — comando ejecutado aquí con salida real.
- **UNVERIFIED-BUILD** — código escrito sin compilar aquí por falta de toolchain.
- **EXTERNO** — depende de Apple, hardware o credenciales.

La ausencia de toolchain local no es **EXTERNO**.

## Consecuencia del gate G0

Todo el código Swift de este tramo, incluido `CostCore` y cualquier código Swift que se escriba posteriormente en el tramo, queda **UNVERIFIED-BUILD**: se ha escrito código, pero no puede compilarse ni probarse en este host. Esto **NO es EXTERNO**. No se ejecutan `swift build` ni `swift test`. La verificación del esquema en G2 será la única prueba **VERIFIED** posible del tramo en este host.
