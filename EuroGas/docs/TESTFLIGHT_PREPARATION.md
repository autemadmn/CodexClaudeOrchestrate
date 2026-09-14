# EuroGas — preparación de TestFlight

Este documento prepara el procedimiento. Nada de aquí se ejecutó: todo es **EXTERNO**.

## Requisitos

- Inscripción vigente en Apple Developer Program.
- Acceso legítimo a App Store Connect con el rol necesario.
- Bundle ID definitivo registrado y App Group asociado.
- Apple Development/Distribution administrado mediante firma automática cuando sea posible.
- Nombre, soporte, privacidad y datos de contacto decididos por el titular.

## Identificadores y compra

1. Sustituir los valores provisionales en `Config/Project.xcconfig`.
2. Confirmar que app, extensión, entitlements e Info.plist expanden los valores definitivos.
3. Crear el registro de app en App Store Connect con el Bundle ID definitivo.
4. Crear un único IAP non-consumable Pro con el product ID definitivo.
5. Configurar precio de lanzamiento y Family Sharing en App Store Connect; no comunicarlo hasta verificarlo.
6. Actualizar `EuroGas.storekit` solo como configuración local equivalente.

## Versión y privacidad

- Marketing Version inicial: `0.1.0`.
- Build inicial: `1`; incrementar cada subida rechazada o sustituida.
- Completar App Privacy según el flujo real: ubicación/nombres/saldos locales, peticiones MapKit y servicios Apple.
- Revisar `PrivacyInfo.xcprivacy` contra APIs realmente usadas y motivos exigidos por el SDK.
- Responder Export Compliance según el binario real; no adivinar criptografía.
- Preparar descripción beta, instrucciones para probar ubicación/Live Activity/compra y limitaciones de estimación.

## Antes del Archive

- [ ] Suite completa verde en simulador.
- [ ] Pruebas de campo mínimas registradas.
- [ ] StoreKit Testing completado sin cobro.
- [ ] Firma app/extensión consistente.
- [ ] App Group y capabilities correctos.
- [ ] No hay IDs `com.example`, Team vacío, credenciales ni datos personales de prueba.
- [ ] Icono, nombre, textos de permisos y accesibilidad revisados.
- [ ] Build Release no usa fakes ni desbloqueos DEBUG.

## Archive y subida

1. Seleccionar `Any iOS Device (arm64)` y esquema `EuroGas`.
2. Product → Archive.
3. En Organizer, ejecutar Validate App y resolver cada error literal.
4. Distribuir mediante App Store Connect → Upload.
5. Esperar procesamiento; revisar emails/avisos de Apple y símbolos.
6. Asociar la build a la versión beta y completar cumplimiento/exportación si se solicita.

## Testers

- Testers internos: usuarios legítimos de App Store Connect con permisos adecuados.
- Testers externos: crear grupo, añadir build e instrucciones, enviar a Beta App Review y esperar aprobación.
- No convertir a amigos en administradores para evitar la revisión.
- Las compras TestFlight no demuestran voluntad real de pago ni cobran al tester.

## Evidencia de cierre

Registrar App record, versión/build, commit Git, fecha de Archive, resultado de validación, fecha de subida/procesamiento, grupos de testers y resultado de Beta App Review. No registrar contraseñas, tokens, certificados, perfiles ni datos personales.
