# tsk011 — Dictado universal seguro

Status: planned
Date: 2026-09-19
Type: feature (11 layers)
Complexity: 8/10
Priority: P2 — productividad independiente de agentes
Dependencies: tsk007
Owner: cce-mobile; write-swift, apple-design; cce-ai-engineer para STT
Context: ct012, ct001; contrato común del programa en ct012, sección «Tickets formalizados».

Plan, no implementación. Nombres de archivos nuevos son propuestos; archivos Swift existentes bajo cursy-app/Cursy/, backend bajo cursy-app/worker/src/. Presupuestos son objetivos iniciales a medir, no resultados. Conservar macOS14.2, idioma Swift actual y cambios del usuario; no migrar toolchain en este ticket.

## 1. Contexto estratégico

Escribir por voz en el destino elegido, separado de pedir ayuda al asistente.

## 2. Necesidades y experiencia

Mantener atajo para dictar; modo manos libres explícito con indicador y stop. Preview/recuperación si no se puede insertar; no perder texto ni enviarlo a la conversación.

## 3. Requisitos y no objetivos

Transcripción, idioma automático/manual y vocabulario personal opcional, inserción verificada, atajos independientes. No lectura de pantalla por defecto, cambios de significado creativos, envío automático, pulsación Enter ni ejecución de comandos.

## 4. Sistema existente y evidencia

BuddyDictationManager ya entrega borradores mediante callbacks; no es un inyector universal. Reutilizar proveedores y recuperación AirPods, coordinados con AudioInputCoordinator de tsk007.

## 5. Arquitectura e impacto de archivos

DictationCoordinator/FocusedTextTarget/TextInsertionPolicy nuevos. Capturar identidad del destino AX al comenzar y revalidar antes de insertar; AX primero cuando verificable. Portapapeles solo fallback explícito, con snapshot/changeCount y restauración si nadie lo modificó; si no puede comprobar resultado, no reintentar a ciegas.

## 6. Datos, contratos, migración y ciclo de vida

DictationSession: id,targetPID,elementIdentity,state,text,insertAttemptID. Estados recording/transcribing/preview/inserting/completed/cancelled/uncertain. Texto efímero salvo guardar explícito; diccionario local versionado. Conservar preferencias de STT existentes.

## 7. Seguridad y privacidad

Bloquear secure text/password y destino cambiado/no verificable; Terminal/consola recibe preview y copia explícita, no auto-inserción multilínea. No almacenar contenido de clipboard o audio en logs; no sobrescribir cambios del usuario. Permiso AX no equivale a autorizar cualquier destino.

## 8. Fiabilidad, rendimiento y observabilidad

Una captura de audio global y una inserción por intento. Propuesta 120 s máximo por sesión manos libres con aviso; texto final vacío no produce escritura. Preparación de inserción p95 ≤200 ms excluyendo STT; medir tiempo total y tasa de duplicados.

## 9. Dependencias e integración

Depende de tsk007, no de guías; puede adelantarse sin cambiar contratos de persistencia. Proveedores configurados deben verificarse: no activar rutas placeholder. tsk012 antes de distribución de brokers multiusuario.

## 10. Fases, pruebas, despliegue y rollback

F1 políticas y destinos falsos; F2 captura/STT; F3 inserción/clipboard; F4 QA en editor nativo, navegador, formulario, app sin AX y Terminal protegido. Casos contraseña, silencio, foco cambia, desconexión, clipboard cambia, atajo duplicado y cancelación. Rollback desactiva inserción y ofrece solo preview/copia autorizada.

## 11. Gates, métricas, documentación y responsable

Gate: cero escritura en destino distinto, duplicados o envíos automáticos en matriz; aceptación manual de dictado y AirPods. Documentar DICTATION_QA, idiomas realmente probados, límites y fallback. No prometer compatibilidad universal si una app no expone destino verificable.

Validación común: Swift Testing para contratos; Xcode para UI/build completo, nunca xcodebuild por terminal. Aplicar regresiones de sesiones/visualización y Worker cuando se toquen sus rutas. Pruebas reales con pantallas/datos privados requieren autorización específica. Despliegue, cuentas y compras no autorizados por este plan. Registrar evidencia por fase; no cerrar antes de sus gates.

Dispatch: `$cce-dispatch execute tsk011-safe-universal-dictation`

