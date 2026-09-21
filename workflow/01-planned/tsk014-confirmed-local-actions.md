# tsk014 — Acciones locales verificadas y autorizadas

Status: planned
Date: 2026-09-19
Type: feature (11 layers)
Complexity: 10/10
Priority: P3 — después de estabilizar agentes de lectura
Dependencies: tsk010, tsk012, tsk013
Owner: cce-mobile; write-swift, apple-design; cce-ai-engineer para intención y herramientas
Context: ct012, ct001; contrato común del programa en ct012, sección «Tickets formalizados».

Plan, no implementación. Nombres de archivos nuevos son propuestos; archivos Swift existentes bajo cursy-app/Cursy/, backend bajo cursy-app/worker/src/. Presupuestos son objetivos iniciales a medir, no resultados. Conservar macOS14.2, idioma Swift actual y cambios del usuario; no migrar toolchain en este ticket.

## 1. Contexto estratégico

Pasar de indicar a ejecutar únicamente cuando el usuario lo solicita y autoriza, manteniendo guía como modo sin acciones.

## 2. Necesidades y experiencia

Previsualizar app/objetivo/acción y efectos; confirmar, cancelar o preferir guía. Parada inmediata visible y ninguna casilla global de permiso ilimitado en MVP.

## 3. Requisitos y no objetivos

Catálogo inicial mínimo: abrir app identificada, enfocar ventana, clic y escribir texto en destino verificable. Secuencia observar→proponer→aprobar→revalidar→actuar→verificar. No shell, compra, envío de mensajes, borrado, credenciales, bypass TCC ni acciones ambiguas.

## 4. Sistema existente y evidencia

NativeTargetPolicy/ScreenWindowGrounding validan geometría; eso no prueba por sí solo identidad semántica. Localizador aceptado tiene gate empírico, no 100% garantizado. Mantener separación entre seguridad de destino e interpretación.

## 5. Arquitectura e impacto de archivos

ActionPolicy/ApprovalStore/LocalActionExecutor nuevos; propuestas por adaptador, ejecución native aislada. Reutilizar coordenadas y verificación tsk010. CompanionManager no acepta verbos arbitrarios ni ejecuta JSON directamente.

## 6. Datos, contratos, migración y ciclo de vida

ActionProposal(id,runID,tool,args,targetIdentity,sceneRevision,risk,expiresAt); Approval liga hash exacto a alcance/duración; ActionReceipt con outcome verified/uncertain/failed. Confirmación de usuario es evento nativo, jamás generado por modelo. Después de await revalidar destino/versión; cambio invalida aprobación.

## 7. Seguridad y privacidad

Fail closed para secure fields, ventanas del sistema o propósito fuera de catálogo. No reenviar datos fuera del destino aprobado; contenido web nunca autoriza acciones. Límite de privilegios por run y revocación inmediata. Undo solo donde técnicamente exista; mostrar efectos no reversibles.

## 8. Fiabilidad, rendimiento y observabilidad

Una acción a la vez, aprobación vence a 30 s propuesta, sin reintento automático de escritura/clic de resultado incierto. Verificación antes de siguiente acción; stop local ≤250 ms. Log ID/tipo/resultado sin contenido escrito.

## 9. Dependencias e integración

Depende de tsk010/012/013, reutiliza validación aceptada. No depende de universal dictation: este usa intención de dictar, no mandato de agente. Plan requiere revisión de seguridad antes de habilitar ejecutor real.

## 10. Fases, pruebas, despliegue y rollback

F1 políticas fake executor; F2 panel aprobación; F3 abrir/enfocar; F4 clic/escritura solo tras QA de fase previa. Casos movimiento entre aprobación/ejecución, popup oclusivo, monitor desconectado, doble confirmación, replay, prompt injection y user stop. Rollback corta ejecución, conserva señalar/manual.

## 11. Gates, métricas, documentación y responsable

Gate: cero acciones sin aprobación vigente en matriz adversaria; ningún reintento de operación incierta; usuario acepta cada clase de herramienta. Documentar LOCAL_ACTION_QA, catálogo y limitaciones. Añadir nuevas herramientas requiere otra revisión de riesgo, no ampliar un enum y asumir autorización.

Validación común: Swift Testing para contratos; Xcode para UI/build completo, nunca xcodebuild por terminal. Aplicar regresiones de sesiones/visualización y Worker cuando se toquen sus rutas. Pruebas reales con pantallas/datos privados requieren autorización específica. Despliegue, cuentas y compras no autorizados por este plan. Registrar evidencia por fase; no cerrar antes de sus gates.

Dispatch: `$cce-dispatch execute tsk014-confirmed-local-actions`

