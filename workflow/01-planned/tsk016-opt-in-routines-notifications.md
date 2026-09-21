# tsk016 — Rutinas y avisos proactivos controlados

Status: planned
Date: 2026-09-19
Type: feature (11 layers)
Complexity: 9/10
Priority: P4 — última fase
Dependencies: tsk012, tsk013, tsk015
Owner: cce-full-stack; cce-backend; cce-mobile + write-swift, apple-design
Context: ct012, ct001; contrato común del programa en ct012, sección «Tickets formalizados».

Plan, no implementación. Nombres de archivos nuevos son propuestos; archivos Swift existentes bajo cursy-app/Cursy/, backend bajo cursy-app/worker/src/. Presupuestos son objetivos iniciales a medir, no resultados. Conservar macOS14.2, idioma Swift actual y cambios del usuario; no migrar toolchain en este ticket.

## 1. Contexto estratégico

Hacer trabajo recurrente autorizado sin convertir Cursy en observador permanente ni generar gastos sorpresivos.

## 2. Necesidades y experiencia

Crear rutina desde un trabajo probado con resumen de alcance/frecuencia/costo; pausa/borrar, próxima ejecución y resultados. Avisos por voz y cursor independientes; modo discreto siempre accesible.

## 3. Requisitos y no objetivos

Rutinas opt-in de herramientas de lectura; cola persistente, resultados y avisos. Sugerencias solo desde fuentes autorizadas y habilitación específica. No capturas de pantalla programadas, acciones locales sin presencia/confirmación, inicio por defecto ni autoaprobación de gasto extra.

## 4. Sistema existente y evidencia

Capturas 13–14 muestran preferencias de agentes y avisos, no mecanismos de scheduling. Cursy no posee scheduler propio. Se implementará dentro del producto, no creando automatizaciones de esta tarea Codex.

## 5. Arquitectura e impacto de archivos

RoutineStore/Scheduler/NotificationPolicy sobre AgentRunCoordinator y UsageLedger. MVP scheduler local mientras app esté abierta; UI declara esa limitación. Suspensión no provoca ráfaga de catch-up. Ejecución cloud posterior fuera de alcance y requiere otro diseño.

## 6. Datos, contratos, migración y ciclo de vida

Routine(id,profileID,schedule,timeZone,capabilities,budget,status,lastSlot,nextSlot,failureCount); slotID idempotente por ocurrencia; NotificationEvent deduplicado. Schema versionado; al reiniciar confirmar permisos vigentes, no repetir runs terminales.

## 7. Seguridad y privacidad

Opt-in a cada rutina y fuente; no emitir voz no solicitada en modo discreto. Integración con llamada/DND/screenshare solo por APIs públicas verificadas; si no hay señal fiable, defaults silenciosos, no inspección invasiva. Desconectar fuente pausa rutina. Pantalla/micrófono nunca se activan por scheduler.

## 8. Fiabilidad, rendimiento y observabilidad

Máximo 1 run activo y cola 5; 3 fallos consecutivos pausan, retries dentro de presupuesto; offline espera sin consumo. Despertar ejecuta como máximo una ocurrencia vencida según política visible, no todas. Notification badge local p95 ≤250 ms; sin solicitud remota para mostrarlo.

## 9. Dependencias e integración

Depende de tsk012/013/015; Home tsk007. Cambios de hora/DST, sueño y red son dependencias de ejecución. Límites monetarios y cadencia elegidos por usuario antes de activar cada rutina.

## 10. Fases, pruebas, despliegue y rollback

F1 reloj falso/scheduler; F2 política de avisos; F3 UI/control; F4 prueba programada autorizada. DST, suspensión, cierre app, red ausente, event replay, run cancelado, revocación y cambio de cuota. Rollback pausa scheduler y conserva resultados/configuración, no borra historial.

## 11. Gates, métricas, documentación y responsable

Gate: ninguna doble ejecución por slot ni gasto sin reserva en simulación; pausa tras fallos y revocación verificadas. Usuario acepta una rutina de prueba; ninguna rutina se crea ahora. Documentar ROUTINE_QA, límites de scheduler local y modo discreto; no afirmar ejecución con Mac apagado.

Validación común: Swift Testing para contratos; Xcode para UI/build completo, nunca xcodebuild por terminal. Aplicar regresiones de sesiones/visualización y Worker cuando se toquen sus rutas. Pruebas reales con pantallas/datos privados requieren autorización específica. Despliegue, cuentas y compras no autorizados por este plan. Registrar evidencia por fase; no cerrar antes de sus gates.

Dispatch: `$cce-dispatch execute tsk016-opt-in-routines-notifications`

