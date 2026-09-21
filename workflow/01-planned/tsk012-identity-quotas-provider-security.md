# tsk012 — Identidad, cuotas y seguridad del servicio

Status: planned
Date: 2026-09-19
Type: feature (11 layers)
Complexity: 9/10
Priority: P0 de lanzamiento; ejecutar antes de agentes remotos
Dependencies: ningún ticket nuevo; base actual
Owner: cce-backend; cce-ai-engineer para límites de proveedores; cce-mobile + write-swift para credenciales cliente
Context: ct012, ct001; contrato común del programa en ct012, sección «Tickets formalizados».

Plan, no implementación. Nombres de archivos nuevos son propuestos; archivos Swift existentes bajo cursy-app/Cursy/, backend bajo cursy-app/worker/src/. Presupuestos son objetivos iniciales a medir, no resultados. Conservar macOS14.2, idioma Swift actual y cambios del usuario; no migrar toolchain en este ticket.

## 1. Contexto estratégico

Evitar exponer credenciales internas, gastos ilimitados o datos entre usuarios cuando Cursy deje de ser prototipo personal.

## 2. Necesidades y experiencia

Inicio/cierre de sesión comprensible, estado de consumo y errores claros; ninguna compra o uso extra aprobado implícitamente.

## 3. Requisitos y no objetivos

Autenticación por usuario/dispositivo revocable, autorización por ruta, reservas/consumo de cuota idempotentes, rate limits y límites de payload/tiempo. Proteger o retirar /tts y /transcribe-token. No implementar cobros/precios ni elegir proveedor comercial de identidad sin aprobación.

## 4. Sistema existente y evidencia

Worker index.ts protege Realtime/vision con bearer interno; rutas legadas y provisión son limitaciones registradas en dependencies.md. Node tests no bastan: workerd tuvo incompatibilidad real de redirect:error.

## 5. Arquitectura e impacto de archivos

AuthVerifier/UsageLedger/ProviderPolicy separados del router; cliente mantiene tokens en Keychain. Un almacenamiento de cuota con transacciones/serialización real evita carreras entre requests; evaluar Durable Object frente a BD transaccional en fase 1. Contrato independiente del proveedor de identidad.

## 6. Datos, contratos, migración y ciclo de vida

Principal(userID,deviceID,scopes,expiry), UsageReservation(requestID,purpose,ceiling,status), UsageReceipt. Validar firma/issuer/audience/exp/nonce según proveedor. Reservar antes de emitir secreto o llamada; no confiar en costo/autorización mandados por app. Realtime directo requiere límite de duración/uso verificable por proveedor o proxy; si no puede imponerse, no habilitar cuota comercial como garantizada.

## 7. Seguridad y privacidad

Revocación/rotación, aislamiento, secretos en servidor, errores redactados y Cache-Control:no-store. Rechazar redirects externos y SSRF, tamaños excesivos y scopes incorrectos. Borrar cuenta tiene alcance documentado; no guardar audio/images por defecto.

## 8. Fiabilidad, rendimiento y observabilidad

Reservas atómicas y devolución de reservas fallidas según uso conocido; retries no duplican gasto. Rate policy inicial interna: 1 sesión voz y 2 llamadas visuales concurrentes por usuario, configurable. Auth+quota p95 objetivo ≤150 ms en región de prueba; fallar cerrado si ledger no disponible.

## 9. Dependencias e integración

Reutiliza Worker vision.ts/index.ts y tests contract/runtime. Sin prerequisito nuevo: puede ejecutarse antes por necesidad de lanzamiento, aunque ID siga secuencia. Bloquea tsk013/015/016 reales y toda distribución multiusuario de nuevas capacidades.

## 10. Fases, pruebas, despliegue y rollback

F1 ADR sobre identidad/ledger/Realtime metering con documentación oficial vigente y decisión del usuario; F2 mocks/contratos; F3 implementación; F4 staging y migración. Tests sin auth, expirado/revocado, tenant ajeno, reservas concurrentes, caída, replay y proveedor timeout. Migración mantiene modo interno separado temporalmente, nunca bypass público.

## 11. Gates, métricas, documentación y responsable

Gate: suite negativa completa y runtime workerd, sin ruta paga anónima ni gasto fuera de reserva en escenarios probados. Revisión de seguridad y aprobación separada de despliegue. Rollback deshabilita rutas nuevas sin reabrir auth ni borrar ledger. Documentar runbook de revocación, uso y límites; decisiones pendientes de identidad, hosting y presupuesto monetario son gates reales.

Validación común: Swift Testing para contratos; Xcode para UI/build completo, nunca xcodebuild por terminal. Aplicar regresiones de sesiones/visualización y Worker cuando se toquen sus rutas. Pruebas reales con pantallas/datos privados requieren autorización específica. Despliegue, cuentas y compras no autorizados por este plan. Registrar evidencia por fase; no cerrar antes de sus gates.

Dispatch: `$cce-dispatch execute tsk012-identity-quotas-provider-security`

