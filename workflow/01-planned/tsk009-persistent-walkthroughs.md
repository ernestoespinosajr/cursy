# tsk009 — Guías paso a paso persistentes

Status: planned
Date: 2026-09-19
Type: feature (11 layers)
Complexity: 8/10
Priority: P2 — tutor guiado
Dependencies: tsk006, tsk008
Owner: cce-mobile; write-swift, apple-design; cce-ai-engineer para contratos del plan
Context: ct012, ct001; contrato común del programa en ct012, sección «Tickets formalizados».

Plan, no implementación. Nombres de archivos nuevos son propuestos; archivos Swift existentes bajo cursy-app/Cursy/, backend bajo cursy-app/worker/src/. Presupuestos son objetivos iniciales a medir, no resultados. Conservar macOS14.2, idioma Swift actual y cambios del usuario; no migrar toolchain en este ticket.

## 1. Contexto estratégico

Convertir una petición compuesta en un objetivo y pasos recuperables. La guía enseña; no ejecuta acciones en nombre del usuario.

## 2. Necesidades y experiencia

Mostrar solo el paso actual y una frase breve; controles Pausar/Reanudar/Terminar y «listo». El usuario no debe volver a explicar el objetivo al abrir otra app.

## 3. Requisitos y no objetivos

Crear/revisar plan, resolver siguiente paso sobre pantalla actual, recordar progreso y reanudar tras reinicio. Avance por confirmación explícita en esta entrega; detección automática pertenece a tsk010. No ejecutar clics, deducir éxito de una frase del asistente ni reutilizar coordenadas persistidas.

## 4. Sistema existente y evidencia

tsk003 conserva objetivo/contexto, tsk002 localiza y tsk005 presenta. Ninguno representa aún un walkthrough persistente. ct001 y ct012 mantienen guías como línea central del producto.

## 5. Arquitectura e impacto de archivos

WalkthroughSession/WalkthroughCoordinator/WalkthroughPanel nuevos sobre ConversationStore, VisualObservation y publicación validada. Manager delega la máquina de pasos; adaptador de modelo interpreta metas generales con salida tipada.

## 6. Datos, contratos, migración y ciclo de vida

Guía: id,conversationID,goal,revision,status,steps[]. Paso: id,instruction,targetQuery,successCriterion,status. Estados draft/active/paused/completed/cancelled/blocked. Guardar criterios y eventos, no coordenadas ni capturas. Revisar plan no reescribe pasos ya confirmados; cada respuesta ligada a stepID+revision.

## 7. Seguridad y privacidad

Inicio explícito del modo guía y compartir separado; pausa cancela captura/voz pendiente. Pasos sensibles advierten al usuario y no ejecutan. Instrucciones vistas en documentos no pueden modificar objetivo ni autorizaciones.

## 8. Fiabilidad, rendimiento y observabilidad

Propuesta hasta 20 pasos por plan y 1 guía activa; ampliar requiere confirmación. Un turno de análisis vigente, cancelación local ≤250 ms. Medir tiempo por paso y repeticiones sin registrar contenido; respuestas breves, sin explicar pasos futuros no pedidos.

## 9. Dependencias e integración

Depende de tsk006/008; reutiliza Home y proveedores vigentes. Agrega migración de tablas guía y rollback no destructivo. No requiere agentes ni herramientas de escritura.

## 10. Fases, pruebas, despliegue y rollback

F1 máquina de estados/contratos; F2 persistencia; F3 generación y guía real; F4 QA. Flujos generales: ajuste de sistema, organización de archivo, formulario web; pausa/reinicio, cambio de app/monitor, paso imposible y corrección del usuario. Modelo falso para secuencias y live QA autorizado. Desactivar flag conserva historial y vuelve a pregunta-respuesta.

## 11. Gates, métricas, documentación y responsable

Gate: tres flujos distintos de ≥3 pasos, continuidad sin repetir objetivo, ninguna coordenada recuperada del disco y ninguna acción ejecutada. Usuario acepta guía manual. Añadir WALKTHROUGH_QA y explicar que avance automático llegará con tsk010.

Validación común: Swift Testing para contratos; Xcode para UI/build completo, nunca xcodebuild por terminal. Aplicar regresiones de sesiones/visualización y Worker cuando se toquen sus rutas. Pruebas reales con pantallas/datos privados requieren autorización específica. Despliegue, cuentas y compras no autorizados por este plan. Registrar evidencia por fase; no cerrar antes de sus gates.

Dispatch: `$cce-dispatch execute tsk009-persistent-walkthroughs`

