# tsk015 — Integraciones con permisos por capacidad

Status: planned
Date: 2026-09-19
Type: feature (11 layers)
Complexity: 9/10
Priority: P3 — ampliar fuentes sin ampliar autoridad implícita
Dependencies: tsk012, tsk013
Owner: cce-backend; cce-ai-engineer; cce-mobile + write-swift para UI y tokens locales
Context: ct012, ct001; contrato común del programa en ct012, sección «Tickets formalizados».

Plan, no implementación. Nombres de archivos nuevos son propuestos; archivos Swift existentes bajo cursy-app/Cursy/, backend bajo cursy-app/worker/src/. Presupuestos son objetivos iniciales a medir, no resultados. Conservar macOS14.2, idioma Swift actual y cambios del usuario; no migrar toolchain en este ticket.

## 1. Contexto estratégico

Permitir a un agente trabajar con fuentes autorizadas sin acceso general a todas las cuentas o archivos.

## 2. Necesidades y experiencia

Conectar, probar, ver permisos y revocar. Estado Checking/Connected/Rejected basado en comprobación real, no en tener un token guardado.

## 3. Requisitos y no objetivos

Registro de conectores y un primer adaptador de lectura elegido por el usuario; soporte de protocolo MCP solo si ese adaptador lo requiere y tras fijar versión/documentación. No catálogo completo, escritura remota ni servidores arbitrarios confiados por defecto.

## 4. Sistema existente y evidencia

Las imágenes muestran sección Integrations, no su catálogo ni implementación. Repo carece de conectores privados; no confundir plugins disponibles en Codex con capacidades de Cursy.

## 5. Arquitectura e impacto de archivos

ConnectorRegistry/ConnectorAuthorization/ConnectorClient en Worker y pantalla de conexiones en Home. Schemas allowlist para herramientas; credenciales servidor o Keychain según OAuth elegido. Namespacing de tool IDs; cambios de toolset exigen revisión.

## 6. Datos, contratos, migración y ciclo de vida

Connection(id,ownerID,provider,scopes,status,expiresAt); ToolDescriptor(capability,inputSchema,sideEffect); Invocation(id,runID,connectionID,capability,argsHash). Versionar schema y manifest, revocar invalida invocaciones pendientes. Token nunca forma parte de conversación ni instrucciones del modelo.

## 7. Seguridad y privacidad

OAuth mínimo privilegio, PKCE/state donde aplique, secretos cifrados en almacenamiento elegido, tokens redactados. Mitigar SSRF/redirects, tool poisoning, cross-tenant y exfiltración por resultados. Herramienta de escritura bloqueada hasta nueva fase con confirmación equivalente a tsk014.

## 8. Fiabilidad, rendimiento y observabilidad

Timeout 15 s por lectura, máximo 1 retry transitorio, resultado 256 KiB inicialmente; paginar explícitamente y descontar quota antes de cada llamada. Revocación efectiva antes de próxima llamada y cancelación de tareas activas cuando sea posible.

## 9. Dependencias e integración

Depende de tsk012/013; escrituras remotas futuras requieren política equivalente tsk014, no previstas aquí. Elección del primer servicio y registro OAuth son decisiones externas: trabajar con mock antes de autorización/configuración real.

## 10. Fases, pruebas, despliegue y rollback

F1 adapter fake/contratos; F2 UI y OAuth del servicio elegido; F3 lectura de datos de prueba; F4 pruebas de revocación y aislamiento. Token inválido/expirado, schema cambia, servidor inyecta instrucciones, timeout, redirección privada y credencial de otro usuario. Rollback deshabilita conexión y deja historial sin tokens.

## 11. Gates, métricas, documentación y responsable

Gate: primer conector lectura usable, revocación comprobada, cero acceso no autorizado y pruebas Worker runtime verdes. Documentar CONNECTOR_QA y scopes visibles. No cerrar ticket hasta elegir y validar servicio real; mocks no cuentan como integración operativa. No conectar cuentas ni desplegar por el solo hecho de aprobar este plan.

Validación común: Swift Testing para contratos; Xcode para UI/build completo, nunca xcodebuild por terminal. Aplicar regresiones de sesiones/visualización y Worker cuando se toquen sus rutas. Pruebas reales con pantallas/datos privados requieren autorización específica. Despliegue, cuentas y compras no autorizados por este plan. Registrar evidencia por fase; no cerrar antes de sus gates.

Dispatch: `$cce-dispatch execute tsk015-scoped-integrations`

