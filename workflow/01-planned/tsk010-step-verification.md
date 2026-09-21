# tsk010 — Verificación visual y avance supervisado

Status: planned
Date: 2026-09-19
Type: feature (11 layers)
Complexity: 9/10
Priority: P2 — continuidad sin repetir el atajo
Dependencies: tsk009
Owner: cce-full-stack; cce-mobile + write-swift; cce-ai-engineer para evidencia y evaluación
Context: ct012, ct001; contrato común del programa en ct012, sección «Tickets formalizados».

Plan, no implementación. Nombres de archivos nuevos son propuestos; archivos Swift existentes bajo cursy-app/Cursy/, backend bajo cursy-app/worker/src/. Presupuestos son objetivos iniciales a medir, no resultados. Conservar macOS14.2, idioma Swift actual y cambios del usuario; no migrar toolchain en este ticket.

## 1. Contexto estratégico

Continuar una guía cuando el usuario realiza la acción, con observación temporal explícita y evidencia fresca.

## 2. Necesidades y experiencia

Usuario activa seguimiento de la guía; indicador permanente de observación, pausa inmediata, actualización breve del siguiente paso. Incertidumbre pide confirmar, no inventa progreso.

## 3. Requisitos y no objetivos

Evaluar criterio del paso, detectar cambios y presentar siguiente indicación validada. No observación fuera de guía, vigilancia al arrancar, avance solo porque ocurrió un clic, ni inferencia de éxito de operaciones irreversibles sin evidencia.

## 4. Sistema existente y evidencia

VisualObservation actual tiene lease de 30 s/dos refrescos: no alargarla silenciosamente. Crear un controlador de seguimiento de guía separado que abra observaciones acotadas y respete límites de proveedor.

## 5. Arquitectura e impacto de archivos

StepVerificationCoordinator usa eventos de app/ventana/scroll y comparación local sin OCR, genera evidencia para modelo y entrega VerificationDecision. Comparte capturador single-flight con Talk; una pregunta nueva pausa verificación y no compite por micrófono/red.

## 6. Datos, contratos, migración y ciclo de vida

Decision: guideID,stepID,revision,observationID,outcome(pending/confirmed/uncertain/blocked),evidenceSummary. El cliente asigna IDs/tiempos; aceptar solo revisión actual. Evento confirmed avanza atómicamente una vez. Guardar resultado textual mínimo, descartar imagen; tras reinicio siempre paused.

## 7. Seguridad y privacidad

Opt-in específico a seguimiento; revocar pantalla, bloquear Mac o pausar detiene captura/envío. Pantallas sensibles se omiten por política; no elevar permisos automáticamente. Modelo no puede ampliar duración/alcance ni marcar él mismo autorizaciones.

## 8. Fiabilidad, rendimiento y observabilidad

Presupuesto inicial: captura estabilizada por evento y fallback local como máximo 1 Hz durante lease; análisis remoto como máximo 1 cada 3 s, 10 por paso y 30 por guía, 5 min por lease. Al límite pausa y explica, no cobra/reintenta indefinidamente. Medir p50/p95 cambio→decisión; objetivo p95 ≤5 s, no garantía de proveedor. Cancelar/publicar-stop local ≤250 ms.

## 9. Dependencias e integración

Depende de tsk009; reutiliza tsk006 y store. tsk012 es gate antes de lanzamiento multiusuario; presupuesto local no sustituye cuota de servidor. APIs de eventos no fiables tienen fallback manual.

## 10. Fases, pruebas, despliegue y rollback

F1 evidencia/decisión/reloj falso; F2 observación y límites; F3 integración con plan; F4 matriz live. Falsos cambios de animación, acción no completada, contenido similar, cambio de monitor, evento duplicado, respuesta fuera de orden, red lenta, sueño y reinicio. Flag off mantiene avance manual tsk009.

## 11. Gates, métricas, documentación y responsable

Gate: cero avances falsos en 60 ensayos negativos/ambiguos y ≥90% detección de positivos inequívocos; el resto pide confirmar. No presentar estas cifras como precisión universal. Usuario acepta tres guías completas y pausa/cancelación. Documentar presupuesto/costo real y evidencia sin guardar screenshots.

Validación común: Swift Testing para contratos; Xcode para UI/build completo, nunca xcodebuild por terminal. Aplicar regresiones de sesiones/visualización y Worker cuando se toquen sus rutas. Pruebas reales con pantallas/datos privados requieren autorización específica. Despliegue, cuentas y compras no autorizados por este plan. Registrar evidencia por fase; no cerrar antes de sus gates.

Dispatch: `$cce-dispatch execute tsk010-step-verification`

