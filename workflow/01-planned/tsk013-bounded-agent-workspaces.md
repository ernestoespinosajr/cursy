# tsk013 — Agentes persistentes, adjuntos y resultados

Status: planned
Date: 2026-09-19
Type: feature (11 layers)
Complexity: 9/10
Priority: P3 — trabajo delegado acotado
Dependencies: tsk008, tsk012
Owner: cce-full-stack; cce-ai-engineer; cce-mobile + write-swift, apple-design; cce-backend
Context: ct012, ct001; contrato común del programa en ct012, sección «Tickets formalizados».

Plan, no implementación. Nombres de archivos nuevos son propuestos; archivos Swift existentes bajo cursy-app/Cursy/, backend bajo cursy-app/worker/src/. Presupuestos son objetivos iniciales a medir, no resultados. Conservar macOS14.2, idioma Swift actual y cambios del usuario; no migrar toolchain en este ticket.

## 1. Contexto estratégico

Organizar trabajos largos con nombre, propósito, conversación y resultados, sin convertir Talk en autonomía general.

## 2. Necesidades y experiencia

Crear perfil de agente no inicia una tarea ni consume llamada. Encargar investigación, ver progreso, cancelar, volver luego y abrir resultado/citas. Seleccionar conversación no cambia autoridad.

## 3. Requisitos y no objetivos

Perfil persistente, runs aislados, seguimiento y resultados locales; entrada por archivos elegidos explícitamente (texto/imagen/PDF con tamaños limitados). Primer agente investiga fuentes públicas mediante herramienta de lectura acotada y crea un informe en su carpeta. No shell, navegación/clic del Mac, conectores privados, recurrencia ni envíos.

## 4. Sistema existente y evidencia

No hay runtime de agentes en código; reutilizar ConversationStore tsk008 y presupuestos tsk012, no inventar que múltiples chats son ya múltiples ejecutores. Capturas 4–5/13–15 sustentan experiencia deseada, no SDK de HeyClicky.

## 5. Arquitectura e impacto de archivos

AgentProfileStore/AgentRunCoordinator/ArtifactStore y adaptador de proveedor nuevos; Home presenta estados/resultados. Worker endpoint de ejecución tipado con lectura web de dominio público, validación SSRF y salida de datos acotada. Elegir proveedor de investigación en evaluación, sin cambiar localizador.

## 6. Datos, contratos, migración y ciclo de vida

AgentProfile(id,name,purpose,conversationID,allowedCapabilities); AgentRun(id,profileID,requestID,status,budget,sequence); Artifact(id,runID,type,relativePath,checksum). Estados queued/running/waitingUser/completed/cancelled/failed/interrupted. Eventos idempotentes; reinicio interrumpe, no repite automáticamente. Adjuntos seleccionados y manifest con MIME/tamaño/origen, nunca paths arbitrarios de modelo.

## 7. Seguridad y privacidad

Workspace propio, rutas canonicalizadas sin escapes/symlinks; archivos son entrada no confiable. No permisos heredados de nombres de agente ni instrucciones dentro de documentos. Vista previa de destino de datos antes de primera subida; PDFs no ejecutan contenido. Consentimiento y retención de adjuntos explícitos.

## 8. Fiabilidad, rendimiento y observabilidad

Piloto: 1 run activo, cola 5, máximo 10 llamadas y 5 min/run, 3 adjuntos de hasta 10 MiB cada uno (sujeto a límite menor del proveedor); presupuesto monetario obligatorio antes de llamada real. Un único intento automático de lectura transitoria, contado. Cancelación local ≤250 ms; backend acusa ≤2 s objetivo, no prometer anular costo ya iniciado.

## 9. Dependencias e integración

Depende de tsk008 y tsk012. Herramienta de lectura pública propia no depende de tsk014, que es acciones locales, ni tsk015, conectores privados. Consultar docs oficiales de modelo y soporte de archivos al dispatch; no asumir API de agentes disponible.

## 10. Fases, pruebas, despliegue y rollback

F1 modelos/store/run simulado; F2 herramientas de lectura y extracción segura; F3 proveedor e informe con citas; F4 QA. Reintento, cancelación durante archivo, red caída, cierre app, respuesta tardía, inyección en fuente, archivo corrupto/grande y cruce entre perfiles. Rollback deja resultados accesibles pero desactiva iniciar runs.

## 11. Gates, métricas, documentación y responsable

Gate: tres investigaciones con fuentes verificables y resultados recuperables, cero acceso fuera de workspace/allowlist en pruebas adversarias, gasto y número de llamadas limitados. Usuario acepta flujo real antes de ampliar. Documentar AGENT_QA y catálogo de herramientas. Confirmar límite monetario y política de adjuntos; sin esas decisiones solo mocks.

Validación común: Swift Testing para contratos; Xcode para UI/build completo, nunca xcodebuild por terminal. Aplicar regresiones de sesiones/visualización y Worker cuando se toquen sus rutas. Pruebas reales con pantallas/datos privados requieren autorización específica. Despliegue, cuentas y compras no autorizados por este plan. Registrar evidencia por fase; no cerrar antes de sus gates.

Dispatch: `$cce-dispatch execute tsk013-bounded-agent-workspaces`

