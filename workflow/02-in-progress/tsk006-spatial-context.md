# tsk006 — Contexto espacial durante la voz

Status: in progress
Date: 2026-09-19
Type: feature (11 layers)
Complexity: 8/10
Priority: P1 — siguiente tras aceptar tsk005
Dependencies: tsk005
Owner: cce-mobile; write-swift, apple-design; cce-ai-engineer para integración/evaluación; animate al implementar la huella
Context: ct012, ct001; contrato común del programa en ct012, sección «Tickets formalizados».

Plan con primera integración implementada (registro al final); aceptación pendiente. Archivos Swift bajo cursy-app/Cursy/, backend bajo cursy-app/worker/src/. Presupuestos son objetivos iniciales a medir, no resultados. Conservar macOS14.2, idioma Swift actual y cambios del usuario; no migrar toolchain en este ticket.

## 1. Contexto estratégico

Permitir «esto que estoy señalando» sin describir una ubicación. Inversión prioritaria porque amplía la comprensión, no solo la apariencia.

## 2. Necesidades y experiencia

El usuario habla y mueve el puntero; recibe huella inmediata y sabe cuándo está compartiendo. Teclado/Escape cancelan; alternativa sin gesto disponible.

## 3. Requisitos y no objetivos

Capturar trayectoria efímera durante Talk con compartir pantalla habilitado; interpretar referencias y devolver señalamiento validado. No dictado universal, clics, vigilancia permanente, OCR ni reglas por app. A falta de evidencia suficiente, pedir una aclaración concreta.

## 4. Sistema existente y evidencia

ct012, imágenes 1–3 y 16: interacción observable, no protocolo interno conocido. La base 97c5406 usa POINT. Actualmente la captura excluye Cursy y showsCursor=false; una huella solo gráfica no llega al modelo.

## 5. Arquitectura e impacto de archivos

Reutilizar CompanionScreenCaptureUtility.swift, VisualObservation.swift, ScreenCoordinateSpace.swift y OverlayWindow.swift. Añadir SpatialContext.swift, SpatialContextRecorder.swift y SpatialTrailView.swift (nombres propuestos). CompanionManager coordina, no almacena el nuevo subsistema. UI/publicación MainActor; valores inmutables entre tareas.

## 6. Datos, contratos, migración y ciclo de vida

SpatialContextPacket v1: sessionID/turnID, segmentos con displayID, captureID, sceneRevision, tamaño raster y puntos normalizados con tiempo monotónico relativo al audio. Máximo tres segmentos/imágenes seleccionadas; muestreo local hasta 30 Hz, simplificación hasta 512 puntos totales. Capturar al armar y tras cambios estabilizados, no pintar trazos pasados en una escena nueva. Separar monitores; gesto sin imagen consistente se descarta con motivo. Campos opcionales versionados en transporte; adaptador validado en VisionAPI/Worker, sin cambiar silenciosamente el localizador aceptado.

## 7. Seguridad y privacidad

Activación explícita, toggle independiente por defecto apagado hasta onboarding; no registrar teclas/texto del sistema ni guardar trazos/audio/frames. Overlay sigue excluido. Contenido de pantalla y trazos son datos, nunca instrucciones privilegiadas. Revocar permiso/cancelar purga buffers.

## 8. Fiabilidad, rendimiento y observabilidad

Presupuesto inicial configurable: hasta 30 s de contexto por petición, 3 MiB de imágenes antes de base64 y un envío de contexto al soltar; no análisis remoto por mousemove. Conservar límites de localización/refresco existentes; comprobar compatibilidad del límite del Worker antes de integrar. Huella p95 ≤50 ms, preparación local adicional p95 ≤300 ms respecto a captura sin gesto; medir en equipo de referencia. Al agotar contexto, avisar, sin terminar forzosamente el audio. Logs solo IDs, tiempos, bytes y motivos.

## 9. Dependencias e integración

Depende de aceptación tsk005; reutiliza tsk002–004. macOS14.2+, monitor externo sin notch. No SCStream obligatorio: decidir por evidencia si capturas selectivas bastan. Proveedor recibe imagen limpia+metadatos; probar imagen auxiliar explícita solo si evaluación demuestra necesidad, siempre mapeada al raster original.

## 10. Fases, pruebas, despliegue y rollback

F1 contratos/reloj falso y fixtures; F2 recorder/huella detrás de flag; F3 transporte real y evaluación general; F4 QA en Xcode. Casos: señalar, rodear, comparar dos regiones, silencio, scroll, ventana movida, dos monitores/Retina/orígenes negativos, cancelación y AirPods. Repetir 20 casos balanceados tres veces (60 ensayos autorizados con imágenes sintéticas); separar rechazo seguro de fallo de localización. Rollback desactiva contexto, conserva Talk y señalamiento.

## 11. Gates, métricas, documentación y responsable

Gate: cero publicación de objetivo incorrecto en conjunto de admisión, ≥90% de peticiones no ambiguas resueltas; resto rechazo explícito, no garantía universal. Ninguna llamada/captura por este feature en reposo; tests de cancelación y límites pasan. QA visual aceptada por usuario. Crear scripts/SPATIAL_CONTEXT_QA.md y actualizar protocolo/privacidad. Decisión pendiente de prototipo: huella siempre al mantener Talk o modificador adicional; no bloquear pruebas de contratos.

Validación común: Swift Testing para contratos; Xcode para UI/build completo, nunca xcodebuild por terminal. Aplicar regresiones de sesiones/visualización y Worker cuando se toquen sus rutas. Pruebas reales con pantallas/datos privados requieren autorización específica. Despliegue, cuentas y compras no autorizados por este plan. Registrar evidencia por fase; no cerrar antes de sus gates.

Dispatch: `$cce-dispatch execute tsk006-spatial-context`

## Ejecución — 2026-09-19

- El usuario autorizó comenzar tsk006 estando remoto, sin aceptar todavía tsk005.
  Se levanta solo la dependencia de inicio; la aceptación visual del cinco queda pendiente.
- Dispatch + cce-mobile/write-swift/apple-design; animate guía feedback inmediato,
  sin animación de apertura del atajo. cce-ai-engineer separa contrato de evaluación.
- Compatibilidad verificada: el Worker de localización admite exactamente una
  imagen. Primera integración conserva ese contrato/modelo: trayectoria normalizada
  de la escena actual, asociada a una captura nueva y verificada. Al cambiar escena
  se descarta la trayectoria anterior; no se comparan aún escenas de varios monitores.
  El paquete viaja como datos versionados dentro del contexto existente, no requiere
  despliegue. Máximo 128 puntos enviados (por debajo del techo de 512), 30 s.
- Pendientes tras esta fase: evidencia multimomento/multisegmento, evaluación de
  proveedor (60 ensayos autorizados), latencias físicas y aceptación visual en Xcode.
  No equivaler compilación/tests aislados a aceptación completa.

### Resultado de la primera integración

- F1: valores versionados, reloj monotónico desde input-ready, AppKit → normalizado
  top-left, cap 512 muestras locales/128 exportadas, regiones y metadatos acotados.
- F2: recorder MainActor y huella menta inmediata en overlay existente. Toggle
  independiente OFF; no animación de apertura. Preparación visible, input hasta30s,
  Escape durante Talk cancela turno, no historial. Reset/opt-out/revocación purgan;
  suspensión/bloqueo cancela el turno. Sin cambios de micrófono ni proveedor.
- Capturas locales al armar y tras cambios estabilizados (500ms); comprobación
  periódica hasta1Hz en escena estable, sin llamadas de modelo por movimiento.
  Geometría/z-order y luminancia de región invalidan trazos, no interpretan texto.
  Captura final fresca antes de adjuntar; escenas/monitores anteriores se descartan.
  VisualCaptureSlot evita solapar la operación nativa incluso si vence su wrapper.
- F3 parcial: datos conectados a Realtime, respaldo y localizador, rebajando el
  raster declarado al que realmente recibe este último sin alterar normalizados.
  Conserva una imagen y modelo aprobado. El añadido opcional se omite íntegro si
  no cabe en el prompt existente; no truncar JSON. Contexto nuevo no hereda gestos.
- Archivos: SpatialContext.swift, SpatialContextRecorder.swift, SpatialTrailView.swift;
  CompanionManager, CompanionPanelView, OverlayWindow, CompanionScreenCaptureUtility,
  VisualTurnContext, OpenAIRealtimeVoiceClient y ElementLocationDetector; tests
  SpatialContextTests/VisionAPITests. Documentación en AGENTS.md y scripts QA/README.
- Validación final ejecutada: `bash cursy-app/scripts/test-native-regressions.sh`:
  módulo nativo compilado y **101 tests/13 suites aprobados** (16 tests más que base).
  Artefactos: `/private/tmp/cursy-native-regression.u1yGdF/`. Primer intento dentro
  del sandbox falló por macros Swift (`sandbox_apply`); repetición autorizada fuera
  del sandbox pasó. Sin xcodebuild, lanzamiento de app, claves ni tráfico externo.
  `git diff --check` también pasó. Suite excluye entrada Sparkle/CursyTests amplio/UI.
- Límite conocido: huella empieza tras preparar imagen, no se conservan muestras
  de esa espera ni selección arrastrando. Latencias y comprensión real NO medidas.
  Guía: `cursy-app/scripts/SPATIAL_CONTEXT_QA.md`; no cierre de tsk005 ni tsk006.
- Próximo gate: probar interacción de esta beta y decidir activación antes de
  extender historial multisegmento; luego completar evaluación semántica/autorizada,
  QA física y métricas. No despliegue realizado ni requerido por este incremento.

## Refinamiento ct013 — 2026-09-19 (plan, no ejecutado)

Solicitado por el usuario tras ver la huella pero recibir una petición de descripción.
CCE Quick Feature, complejidad 5/10 para este incremento. Se refina este mismo
ticket; no se crea otro ni se modifica su estado. Los once niveles y gates del
alcance completo siguen vigentes. Este incremento precede a ampliar multiescena.
Responsable: cce-mobile + write-swift; cce-ai-engineer para evaluación semántica.

### 1. Objetivos y requisitos

- Como usuario, puedo referirme a «esto» señalándolo, sin tener que describirlo
  cuando imagen y gesto aportan evidencia suficiente.
- Verificar por separado captura del gesto, inclusión en cada solicitud,
  interpretación del modelo y validación/publicación de un destino.
- Hechos ct013: cuatro providerNoTarget recientes; el localizador sí se invocó.
  No hay prueba retrospectiva de entrega del gesto. El Bool del callback oculta
  la causa y produce un mensaje genérico de validación fallida.
- No objetivos: sustituir proveedor, eliminar validaciones, OCR, reglas por app,
  vigilancia continua, multiescena en este incremento ni nuevas acciones de ratón.
- Aceptación técnica: todo gesto iniciado tiene un desenlace trazable; ningún
  providerNoTarget se comunica como coordenadas inválidas; el contexto correcto
  llega íntegro a los clientes simulados o se declara explícitamente su omisión.

### 2. Experiencia

- Conservar activación, huella menta, accesibilidad y cancelación existentes.
- Distinguir petición explicativa («qué es esto») de indicación («resalta esto»).
  No forzar una respuesta explicativa a pasar por un localizador solo de controles.
- Si falta el gesto o cambia la escena: explicar ese motivo y pedir repetir el
  señalamiento solo cuando sea necesario. Si hay ambigüedad visual real, pedir
  una aclaración concreta. No anunciar ausencia solo porque hubo un error técnico.
- No verbalizar detalles internos ni una confirmación de resaltado sin publicación.
  Un turno sustituido/cancelado no puede hablar ni modificar el turno nuevo.

### 3. Diseño técnico

- Recorder: representar desenlace de adjunción con motivos cerrados (sin muestras,
  límite temporal, permiso revocado, propietario incorrecto, cambio geométrico,
  cambio de región o fallo de captura). Evitar un guard agregado sin diagnóstico.
- Preparación del contexto: devolver texto más un estado de inclusión del paquete;
  distinguir tamaño excedido, paquete adjunto y gesto invalidado por refresco.
  Medir presupuesto según el contrato real del receptor y no truncar JSON.
- Diagnóstico sin contenido: correlacionar session/turn/capture, etapa, revisión,
  display, cantidad de muestras, tamaño, duración y motivo. Emitir en transiciones,
  no por movimiento. No registrar puntos, imágenes, nombres, audio ni transcripciones.
  «Incluido/enviado» describe transporte, no prueba comprensión del proveedor.
- Reutilizar Result de GenericPointingPipeline y PointingRejection; preservar un
  resultado tipado en callbacks del manager → Realtime en lugar del Bool actual.
  Incluir publicación confirmada, no-target del proveedor, evidencia ausente,
  invalidación de escena/turno, rechazo geométrico y fallo técnico. Mantener rutas
  de controles nativos, fallback y comportamiento sin contexto espacial.
- Clasificación semántica: evaluar primero fixtures explicativos y de indicación.
  Según evidencia, ajustar instrucciones/ruta para referentes visuales generales
  (regiones de imagen, diagramas, texto y controles). No inferir significado local
  ni retornar ciegamente el último punto. No inventar un bounding box del gesto.
- Archivos previstos: SpatialContext.swift, SpatialContextRecorder.swift,
  PointingDiagnostics.swift, VisualTurnContext.swift, CompanionManager.swift,
  OpenAIRealtimeVoiceClient.swift y, si lo justifica evaluación,
  ElementLocationDetector.swift/ScreenContextPolicy.swift. Tests existentes de
  contexto espacial, transporte, pipeline y puerta de respuestas como puntos de extensión.

### 4. Dependencias y compatibilidad

- Reutiliza tsk002–004 aceptados y primera beta tsk006; tsk005 sigue pendiente.
- Conservar API de localización de una imagen, modelo aprobado y límites actuales;
  no requiere de entrada cambio de Worker, nuevas credenciales ni despliegue.
- Preservar macOS14.2/Swift5, AirPods, geometría multimonitor y validación de escena.
- No se necesita información adicional del usuario para instrumentación y tests
  offline. Antes de evaluación remota, acordar autorización y tope de coste.
  Usar imágenes sintéticas; datos privados necesitarían autorización separada.

### 5. Implementación por fases

1. Tests deterministas de adjunción/omisión y presupuesto; añadir diagnósticos
   acotados en recorder y preparación real de solicitudes Realtime/localizador/fallback.
2. Migrar resultados tipados hasta la continuación de voz. Tests de cada causa,
   rechazo seguro, silencio en cancelación, ausencia de falsa confirmación y paridad
   con indicación nativa/sin gesto. No alterar políticas de validación para pasar tests.
3. Construir fixtures generales de punto, círculo, comparación en una escena,
   botón, imagen, diagrama y texto; casos ambiguos, sin gesto y escena cambiada.
   Simulados prueban entrega; no prueban comprensión. Evaluación real posterior
   autorizada sobre conjunto original de 20 casos × 3 repeticiones.
4. Ajustar semántica solo con evidencia de la frontera que falla; reevaluar antes
   de solicitar otra prueba manual. Mantener explícita cualquier evaluación bloqueada.
5. Ejecutar regresiones nativas y preparar prueba en Xcode. Nunca xcodebuild por
   terminal, nueva captura privada, lectura de claves o despliegue para diagnosticar.

### 6. Validación, documentación y rollback

- Runner `bash cursy-app/scripts/test-native-regressions.sh`: conservar las 101
  pruebas previas y añadir cobertura de estados/resultados sin asumir un total futuro.
- Comprobar en mocks de solicitud que captura, raster y paquete corresponden;
  timeout, cancelación, refresco y tamaño excesivo no dejan un gesto viejo vigente.
- En evaluación real, separar entrega, referente interpretado, localización y
  publicación. Mantener ≥90% de no ambiguos resueltos y cero objetivos erróneos
  publicados en muestra, no una garantía universal. Registrar rechazos y latencia.
- QA física posterior: dos monitores, escena estable/cambiante, señalamiento y
  explicación. Solicitar al usuario esa prueba después del incremento, no usarla
  para suplir pruebas de código. Rendimiento original sigue sin medir.
- Actualizar SPATIAL_CONTEXT_QA.md, tarea/logbook y guía de motivos. No conservar
  contenido privado en evidencias. Rollback: toggle espacial OFF conserva Talk.
- No cerrar tsk006 por resolver ct013: faltan multisegmento, elección de interacción,
  evaluación completa, mediciones físicas y aceptación. No cerrar tsk005 tampoco.

Siguiente ejecución: `$cce-dispatch execute tsk006-spatial-context`.

### Ejecución del refinamiento ct013 — 2026-09-19

- Despachado a petición del usuario; trabajo serial, sin agentes ni despliegue.
  CCE Mobile/Write Swift guiaron valores tipados y aislamiento; CCE AI Engineer
  separa evidencia de transporte de comprensión real. No se cambia proveedor.
- Implementadas fases locales 1–2: estados de adjunción/omisión explícitos,
  correlación por IDs y registros numéricos sin contenido. Preparación/salida de
  Realtime, fallback y localizador exponen inclusión y tamaño UTF-16; el raster
  adaptado conserva las coordenadas normalizadas y actualiza dimensiones.
- El resultado del pipeline llega tipado al cliente Realtime, incluidas rutas
  nativas; providerNoTarget ya no se convierte en validation_failed. Solo una
  publicación permite «Ahí está»; un turno obsoleto no obtiene continuación.
  Fallback conserva su respuesta explicativa y ahora instrumenta preparación y
  respuesta; no se fuerza cada respuesta sin punto a convertirse en error.
- Capturas de refresco transportan explícitamente sceneRefreshed sin reutilizar
  puntos anteriores. El presupuesto del prompt usa UTF-16 como el Worker, no
  cantidad de grafemas Swift; omisiones se comunican sin partir JSON.
- Hallazgo adicional comprobable en código: visualContinuationInstructions
  obligaba a dar una limitación para todo pointed=false, incluso la ruta
  pointing_not_requested. Se corrige ese conflicto y la descripción de la
  herramienta: una explicación/comparación puede responder normalmente sin
  resaltado, conservando la necesidad de evidencia para referencias deícticas.
  No se amplía a ciegas el prompt de localización de controles ni se afirma
  mejora semántica medida. Ese ajuste requiere evaluación con modelo real.
- Fase 3 parcial: fixtures sintéticos de botón, detalle de imagen y diagrama
  pasan por detectElementLocation → VisionAPI → URLProtocol simulado, verificando
  imagen única, raster 768x768, paquete y omisión por presupuesto. La respuesta
  null es simulada, no resultado de un proveedor. Realtime usa una función común
  para construir el mensaje de imagen/contexto, probada con captura y paquete.
- Archivos: SpatialContext, SpatialContextRecorder, VisualTurnContext,
  PointingDiagnostics, CompanionManager, ElementLocationDetector,
  OpenAIRealtimeVoiceClient; tests SpatialContext/VisionAPI/VisualGuidanceOutcome;
  AGENTS.md y SPATIAL_CONTEXT_QA.md.
- Validación final: `bash cursy-app/scripts/test-native-regressions.sh`, módulo
  nativo compilado y **110 tests/14 suites aprobados**, artefactos
  `/private/tmp/cursy-native-regression.12YDcA/` (0.874 s de ejecución de tests).
  Dos iteraciones intermedias fallaron al compilar tests nuevos por macros
  anidados y aislamiento MainActor; corregidas antes de la pasada final.
  Advertencias previas del proyecto conservadas. `git diff --check` pasa.
- Sin Xcode launch/build completo, micrófono, captura privada, claves, APIs reales,
  cambio de Worker o despliegue. No cierre del ticket ni aceptación inferida.
- Siguiente gate: autorización/tope de gasto para evaluación real con imágenes
  sintéticas. Falta completar el conjunto semántico de 20×3, medir interpretación
  y luego ajustar localización si corresponde; QA física y multisegmento siguen
  pendientes. La instrumentación no demuestra retrospectivamente qué perdió el
  intento histórico, ni resuelve por sí sola providerNoTarget.

### Reparación ct014 autorizada — 2026-09-19

- Petición: reparar la implementación actual sin Deepgram/Cerebras ni cambiar
  modelos. Incremento nativo bajo CCE Dispatch + AI Engineer + Write Swift;
  sin nueva tarea, agentes, despliegue ni evaluación pagada.
- Decisión explícita `requestMode`: explain, locate, explain_and_locate. Explicar
  contenido no requiere localizar un control, aunque targetQuery no esté vacío o
  el juicio preliminar sea ambiguous/missing. Payloads antiguos conservan la ruta
  previa; modos desconocidos, capturas ajenas y decisiones inválidas se rechazan.
- Continuación explicativa devuelve pointing_not_requested sin inventar fallo de
  resaltado. La petición combinada permite explicación tras publicación; localizar
  solamente conserva la confirmación puntual. Ninguna validación geométrica,
  temporal, nativa o de publicación fue eliminada.
- Se añade representación visual del gesto a Realtime: captura limpia intacta y
  copia auxiliar con trazo magenta/endpoint hueco, identificada como input no fiable,
  no como resaltado verificado. No nueva captura ni vídeo. Mismos píxeles/escena,
  propietario/monitor/revisión comprobados, puntos finitos/acotados/ordenados,
  máximo 128, dimensiones <=2048 y total imágenes codificadas <=3 MiB. Refrescar
  elimina el gesto; no se intenta aplicarlo sobre otra escena.
- Es una corrección candidata de representación, NO mejora semántica demostrada:
  desaparece la dependencia exclusiva de coordenadas en Realtime, pero falta medir
  interpretación real y coste/latencia de la imagen adicional. El localizador y el
  fallback mantienen sus contratos de imagen única y metadatos; no se afirma paridad
  visual nueva para el fallback ni resolución del gate multiescena.
- Trazabilidad sin contenido: modo semántico y referencePrepared (ID/display/bytes).
- Cambios: VisualTurnContext, SpatialContext, OpenAIRealtimeVoiceClient,
  PointingDiagnostics; tests VisualTurn/SpatialContext/VisualGuidanceOutcome;
  AGENTS, QA, logbook y dependencies.
- Validación offline: 115 tests/14 suites pasan en
  `/private/tmp/cursy-native-regression.JGklwQ/` (pasada final; 0.854 s), incluyendo orientación top-left,
  imagen limpia preservada, monitor externo, propiedad/revisión, puntos inválidos,
  refresco y rutas explícitas. Primera ejecución bajo sandbox bloqueada por macros
  SwiftUI; repetida fuera del sandbox con autorización. Advertencias previas siguen.
- Sin micrófono, capturas privadas, credenciales, APIs reales ni Xcode completo.
  Recompilar/ejecutar desde Xcode para QA, no se necesita desplegar el Worker.
  Pendientes: evaluación semántica autorizada 20×3, QA física, rendimiento,
  multisegmento y aceptación; tsk006 y tsk005 siguen abiertos.

### Validación del usuario — 2026-09-19

- Tras probar la reparación ct014, el usuario confirma: «excelente, esta funcionando
  perfectamente». Se acepta la corrección de la interacción probada; no se infieren
  escenarios, monitores, idiomas ni métricas que el usuario no haya especificado.
- Lección: separar comprensión de contenido y publicación de marcas, y entregar
  el gesto como evidencia visual asociada a su captura, antes de atribuir el fallo
  al proveedor. El resultado valida este incremento, no demuestra causalidad aislada
  de cada cambio ni precisión universal. Mantener los modelos actuales.
- No se cambió código ni se ejecutaron nuevas pruebas en este registro. Sigue
  pendiente el alcance completo: multisegmento, evaluación semántica 20×3 y
  mediciones de rendimiento/coste. tsk006 continúa en progreso; esta aceptación
  no cierra tampoco la prueba independiente de anotaciones de tsk005.

### Continuación multiescena y rendimiento local — 2026-09-19

- Autorización: el usuario pide continuar el alcance pendiente anotado. Dispatch
  mantiene este ticket; CCE Mobile + Write Swift guían valores/propiedad/async,
  Apple Design conserva feedback directo y separación espacial, AI Engineer y
  OpenAI Docs separan transporte, medición local y calidad del modelo. Sin agentes.
- Ajuste del plan a la versión aceptada: mantener su par limpio+referencia actual.
  Hasta tres escenas implica ahora hasta SEIS imágenes, no tres; todas comparten
  el techo de 3 MiB antes de base64. Se prioriza el par actual; omisiones de pares
  anteriores se comunican y no se reduce silenciosamente la imagen ya aceptada.
- Recorder conserva un checkpoint solo tras captura periódica consistente con
  geometría/región. Excluye muestras posteriores al inicio de esa captura. Ante
  scroll/cambio de app/monitor/escena, termina el segmento y borra el trazo vivo;
  puede conservar el último checkpoint verificado, nunca el tramo no verificado.
  Un gesto muy corto puede faltar: no se afirma grabación continua ni completitud.
- SpatialSceneEvidence conserva imagen/paquete/tiempo, sin geometría de publicación
  ni IDs de ventanas/controles. Conserva dos escenas anteriores recientes y hasta
  128 puntos por escena. Propietario, revisión y tiempos se revalidan al enviar.
  La secuencia v2 solo existe en el mensaje Realtime; el paquete por escena sigue v1.
- Los pares HISTORICAL llegan en orden y la escena CURRENT al final. Se usan para
  explicar/comparar, nunca para señalar sobre una pantalla cambiada. La imagen
  actual sigue siendo la única autoridad para localización. Los buffers anteriores
  se purgan en consumo/cancelación/caducidad/nuevo turno; tras enviar no se retienen
  en el contexto local Realtime ni entran en VisualObservation. Refrescar invalida
  toda la secuencia. Fallback/localizador conservan imagen única y explicitan que
  no tienen evidencia histórica: no se afirma paridad multiescena de esas rutas.
- UI conserva la huella inmediata e indica el número de escenas anteriores
  retenidas. Diagnóstico historyPrepared solo registra IDs, cantidades, bytes y ms.
- Pruebas añadidas: dos monitores/origen negativo y scroll, orden actual/histórico,
  límites y omisiones, muestras durante await, consumo único, propietario, revisión,
  cancelación/revocación/30 s/nuevo turno, rechazo de coordenadas históricas y
  exclusión del historial del lease. Validación final: 119 tests/14 suites pasan;
  artefactos `/private/tmp/cursy-native-regression.e6G2u2/` (0.929 s). `git diff --check`
  y `bash -n cursy-app/scripts/benchmark-spatial-preparation.sh` pasan. Advertencias
  previas conservadas; sin advertencias nuevas en los archivos espaciales.
- Benchmark reproducible con 30 muestras por modalidad, 1920x1200/128 puntos:
  una escena p50 12.05 ms / p95 12.73 ms; tres escenas p50 36.14 ms / p95 42.69 ms.
  JSON WebSocket: 535072 / 1604234 bytes. Medido con el módulo anterior en el mismo
  equipo; solo preparación/raster/serialización, NO captura, UI física, red, voz,
  inferencia, coste o precisión. No se declara cumplido el p95 end-to-end de 300 ms.
- Scripts nuevos SpatialPreparationBenchmark.swift y benchmark-spatial-preparation.sh;
  cambios en SpatialContext/Recorder, VisualTurnContext, OpenAIRealtimeVoiceClient,
  SpatialTrailView, VisualObservation, tests y documentación. Fuentes sincronizadas
  por Xcode; no cambio manual del proyecto, toolchain, modelo, Worker ni despliegue.
- Fuente de contrato consultada: documentación oficial Realtime, sección image inputs,
  https://developers.openai.com/api/docs/guides/realtime-conversations#image-inputs.
  El esquema permite partes input_image; no constituye evidencia de calidad con seis
  imágenes. No se inspeccionaron claves, capturas privadas ni historial real.
- Se solicitó autorización opcional de hasta US$5/60 ensayos con imágenes sintéticas;
  no respuesta recibida ni consumo remoto realizado durante este incremento.
  Pendientes: evaluación semántica 20×3 y coste autorizado, QA de esta extensión en
  Xcode, mediciones físicas/captura/red/modelo y decisión final de interacción.
  La corrección de escena única sigue aceptada; tsk006 y tsk005 NO se cierran.

### Aceptación multiescena del usuario — 2026-09-19

- Tras este incremento, el usuario confirma: «esta bien, esta funcionando
  perfectamente. Que sigue?». Se registra aceptación de la experiencia probada;
  no se infieren casos, monitores, idiomas o métricas no especificados.
- El ticket conserva pendientes la evaluación semántica 20×3, autorización de
  consumo para ensayos remotos y mediciones físicas/end-to-end. Esta aceptación
  no acredita precisión universal ni cierra la validación separada de tsk005.
- Próximo paso recomendado para validar experiencia e interfaz: prototipo de
  tsk007 (Home, notch opcional y ajustes), preservando cursor y voz existentes.
  El usuario pide orientación; no se inicia implementación de tsk007 ni se
  modifican sus dependencias con este registro.
- Solo memoria actualizada; sin cambios de app, nuevas pruebas o despliegue.
