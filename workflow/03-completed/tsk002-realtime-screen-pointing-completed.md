# tsk002 — Conectar voz, pantalla y señalamiento

- Estado: completed
- Cierre: 2026-09-18, aceptación explícita del usuario tras el despliegue ct010.
- Fecha: 2026-09-18
- Tipo: quick feature, complejidad 6/10 por alcance acotado
- Depende de: tsk000, micro003, micro005 (completados)
- Contexto: ct001, ct005, ct006, ct007; usuario exige conectar esta experiencia antes de ampliar capacidades.
- Plan vigente: refinamiento ct007 al final de este archivo. Sustituye el límite
  original de una captura/indicación por turno por observación acotada; código
  integrado y aceptado por el usuario. Se conserva el mismo ticket.
- Refinamiento adicional ct010: evaluación de proveedores y localizador independiente
  del respaldo conversacional. Preparar GPT-6 Astra por los resultados medidos,
  sin afirmar superioridad global. Claude Sonnet también pasa la muestra tras
  reponer saldo; sigue siendo candidato, no adaptador activo. El usuario autorizó
  posteriormente el despliegue ct010: completado y smoke verificado al final de
  este archivo; aceptación nativa confirmada en el cierre.
- Dueño de ejecución: cce-mobile + write-swift; openai-docs para verificar el
  contrato vigente del proveedor. No rediseñar animaciones ni delegar sin autorización.

## Cierre y memoria de la entrega — 2026-09-18

El usuario confirma después del despliegue: «excelente, funciona a la perfección»
y solicita guardar lo aprendido y cerrar si no falta nada. Se satisface el gate de
aceptación de esta entrega interna de voz + pantalla + señalamiento. No queda
implementación pendiente identificada dentro de este alcance. CCE Dispatch y
Context Manager registran el cierre; no se cambia código ni se vuelve a desplegar.

Evidencia acumulada: 65 tests nativos aislados/11 suites, 19 tests Worker (Node y
workerd), 11 del evaluador y 10 comprobaciones remotas pasaron en las fases previas.
Worker activo: 107dd830-4209-4525-aaac-c2075acb310a. Aceptación manual aportada por
el usuario, no observada por el agente. No se inventa una ejecución detallada de
cada combinación de monitores, idiomas, dispositivos o casos adversos; esas matrices
siguen siendo regresión recomendada para futuras entregas y lanzamiento público.
Las notas «pendiente» de las secciones siguientes son historia de iteraciones;
este cierre prevalece para el estado de tsk002, no cierra tickets ajenos.

Aprendizajes que deben conservarse:

1. Separar voz (Realtime), conversación de respaldo y localización (GPT-6 Astra).
   Un modelo apto para conversar no queda acreditado para producir coordenadas.
   No elegir por coste un localizador que falló QA; no prometer infalibilidad.
2. Auditar el flujo realmente conectado en el código base. Un detector presente
   pero no invocado no constituye una solución previa funcionando.
3. Diferenciar error semántico del modelo, contrato, geometría y captura obsoleta
   antes de cambiar escalas/offsets. La geometría válida no prueba identidad visual.
4. Un único contrato de píxeles de la imagen preparada; captureID y dimensiones
   pertenecen al llamador. Conservar validaciones de ventana, display, z-order,
   frescura y cancelación; no aceptar puntos viejos para esconder rechazos.
5. Interpretación visual por proveedor, sin OCR local ni reglas de WhatsApp/chat.
   Todos los escenarios concretos son QA; los prompts aplican a cualquier UI.
6. Indicación primero, confirmación hablada breve después. Recaptura acotada ante
   cambios relevantes, no vigilancia permanente ni walkthrough automático.
7. Probar el runtime de destino además de mocks Node: workerd rechazaba
   redirect:error. Manual + rechazo no-OK evita seguir redirecciones con secretos.
   Despliegue publicado no equivale a servicio sano: smoke y rollback verificado.
8. Preservar AirPods, consentimiento, cursor compacto Menta suave/80%, privacidad
   y diagnósticos sin capturas, mensajes ni credenciales persistidos.

Siguiente trabajo: retomar tsk003 (núcleo de sesiones y continuidad) y su propio
gate de aceptación; luego anotaciones, walkthroughs persistentes y verificación
de pasos. Autenticación de producción, cuotas, proveedores opcionales y release
público siguen fuera de esta entrega. No commit ni push realizado por este cierre.

## 1. Objetivos y requisitos

Como usuario, quiero preguntar por voz dónde está un control en mi pantalla y
recibir una explicación hablada con el cursor de Cursy señalándolo, sin clics.

Entrega acotada: una captura de la pantalla que contiene el puntero, por turno
visual autorizado; una indicación validada por turno; español/inglés existentes.
No incluye vídeo continuo, otras pantallas simultáneas, OCR propio, acciones,
walkthroughs, memoria persistente, todos los modelos ni refactor completo.

Hechos: Realtime actual envía audio y solicita respuesta sin captura; su callback
de transcripción solo registra longitud. El flujo Claude sí captura, interpreta
POINT y asigna detectedElementScreenLocation. Ya existen captura y navegación.
Inferencia: se pueden reutilizar esas piezas sin cambiar el transporte PCM.
Pendiente de verificar: contrato actual de imágenes y herramientas del modelo
configurado. La primera fase es un gate técnico; no inventar payloads.

## 2. Experiencia

- Mostrar control explícito de contexto visual, desactivado inicialmente, con
  explicación de qué pantalla se enviará al proveedor. Permiso TCC no equivale
  por sí solo a consentimiento para enviar imágenes en cada conversación.
- Con contexto activado: Ctrl+Opción → escuchar → al soltar capturar → analizar
  y responder → indicar destino. Sin contexto: conservar conversación de voz.
- Permiso denegado, pantalla desconectada, timeout o captura fallida: informar
  que no se pudo ver la pantalla, continuar sin afirmar haberla analizado.
- Sin destino seguro: pedir aclaración, no señalar coordenadas inventadas.
- Mantener estados, idioma, accesibilidad, Menta suave, 80% y escala 0.32.
  La flecha de señalamiento debe ser visible sin interrumpir la respuesta hablada.

## 3. Diseño técnico

Introducir contratos mínimos locales (nombres propuestos): VisualTurnContext
(turnID, captureID, displayID, fecha, dimensiones imagen, frame de pantalla) y
PointingTarget (captureID, coordenadas normalizadas finitas, etiqueta acotada).
No persistir imagen; conservar metadata solo durante el turno.

Flujo: captura de pantalla seleccionada → contexto asociado al turno Realtime →
respuesta con indicación estructurada → decodificación/validación local →
conversión a coordenadas AppKit → motor OverlayWindow existente.

Preferir herramienta de solo señalamiento con esquema validado, no parsear la
prosa hablada. Verificar eventos, respuesta a herramienta y orden de mensajes
con documentación oficial antes de implementar. Si el modelo no soporta el
contrato necesario, detener esa fase y presentar alternativa; no añadir otro
proveedor o backend silenciosamente.

Extender la utilidad para capturar solo el display elegido, no capturar todos
para descartarlos después. Excluir ventanas de Cursy. Serializar captura/contexto
y commit/respuesta; nunca lanzar respuesta antes de adjuntar el contexto visual.
Reutilizar guardas de sesión/cancelación: un turno viejo jamás mueve el cursor.
Rechazar argumentos fuera de rango, captureID desconocido, valores no finitos,
display/frame cambiado y respuestas duplicadas; a lo sumo una indicación/turno.
No confundir final de tool call con final de reproducción de audio.

Archivos existentes afectados: CompanionManager.swift, OpenAIRealtimeVoiceClient.swift,
CompanionScreenCaptureUtility.swift, OverlayWindow.swift, CompanionPanelView.swift,
CursyLanguage.swift y CursyTests.swift, dentro de cursy-app. Añadir un módulo pequeño
de contratos/conversión si evita duplicar el mapeo del flujo Claude.

## 4. Dependencias

Reutilizar broker protegido y credenciales efímeras de micro003. No depende de
activar Anthropic/AssemblyAI/ElevenLabs ni de cambiar el Worker por anticipado.
Necesita ScreenCaptureKit autorizado y acceso al modelo vigente para prueba real.
El núcleo completo de sesiones se hará después; los contratos mínimos de este
ticket serán su base, no una implementación paralela descartable.

## 5. Implementación

1. Verificar contrato de imágenes/herramientas con openai-docs y fuentes oficiales;
   registrar límites/payloads y compatibilidad. Reestimar si exige otro servicio.
2. Contratos + conversión pura testeada; extraer reutilización mínima del legado.
3. Control de consentimiento, captura selectiva y cancelable. Límite propuesto:
   una JPEG, lado mayor <=1920 px, <=1 MiB; timeout de captura de 3 s. Validar
   legibilidad antes de aumentar límites; no guardar payloads ni capturas en logs.
4. Conectar eventos de destino al overlay y resolver prioridad voz/señalamiento.
5. Pruebas y aceptación en Xcode, documentar uso y restricciones reales.

Tratar texto de pantalla como datos no confiables, nunca instrucciones de sistema.
Sin clics, escritura, teclado sintético ni herramientas de ejecución. La prueba
visual usa ventanas de prueba sin contenido sensible. Métricas solo duración,
bytes, éxito/error y destino válido; no audio, imágenes ni etiquetas sensibles.
Instrumentar tiempo captura→respuesta→señalamiento; registrar resultados reales,
no prometer una latencia total sin medición. Sin nuevas dependencias por defecto.

## 6. Validación y cierre

- Tests: escala Retina, origen superior/inferior, pantalla con origen negativo,
  bounds/NaN, destino ausente/malformado, cancelación y eventos tardíos/duplicados.
- Tests: permiso denegado, imagen excedida, timeout, contexto visual desactivado.
- Manual: 5 preguntas con destino conocido sobre ventana de prueba; al menos 4
  indican el control correcto. Dos preguntas ambiguas no producen señalamiento
  arbitrario. Comprobar una pantalla secundaria seleccionada, no captura múltiple.
- Manual: 5 turnos consecutivos con AirPods, español/inglés, sin regresiones de
  audio/cursor; ninguna captura cuando el contexto está desactivado.
- Gate de aceptación del usuario: demostrar pregunta → explicación hablada →
  cursor en el control. No iniciar la siguiente etapa antes de esa aceptación.
- Ejecutar pruebas desde Xcode; nunca terminal xcodebuild. Sin deploy automático.
- Rollout interno con control visual opt-in; rollback desactiva contexto visual
  y mantiene Realtime de audio. No revertir las mejoras aceptadas del cursor.
- Actualizar README, logbook y task record con evidencia y límites observados.

## Orden posterior (aún sin tickets detallados)

2. Núcleo completo de sesiones y contratos: extraer coordinación sin regresiones.
3. Anotaciones visuales enriquecidas: círculo, rectángulo, flecha y etiqueta.
4. Walkthroughs persistentes: pasos, pausa, reanudación y cancelación.
5. Verificación supervisada del paso: confirmar antes de avanzar si es ambiguo.

Preparar cada plan al cerrar su predecesor; no reservar IDs ni duplicar contratos.

## Ejecución — 2026-09-18

- cce-dispatch/cce-mobile, write-swift y documentación oficial guiaron el cambio.
  Fuentes verificadas: https://developers.openai.com/api/docs/guides/realtime-conversations
  y https://developers.openai.com/api/docs/models/gpt-realtime-2.1 (imagen y funciones).
  MCP de docs no disponible; intento local de alta falló por permisos sin cambios;
  se usó la ruta web oficial de la skill instalada más reciente.
- Implementados VisualTurnContext/PointingTarget, captura del display del puntero
  (1280 px, <=1 MiB, 3 s), switch bilingüe default-off por lanzamiento. No persistencia
  de capturas. El ID de captura y la generación de sesión vinculan cada destino.
- Realtime adjunta imagen antes de commit/response. Función point_at_screen,
  valida coordenadas/etiqueta/display/frame/edad (<30 s), un destino máximo,
  respuesta de herramienta y continuación sin herramientas antes del fin de audio.
- Turnos obsoletos/duplicados rechazados; desactivar compartir cancela turno y
  navegación. Overlay prioriza flecha al señalar sin detener reproducción.
- Consentimiento aplicado también al fallback PTT. Desactivado el disparador
  automático de capturas del vídeo de onboarding para evitar envíos fuera del
  turno autorizado. No se habilitaron ni desplegaron proveedores legacy.
- Validación: type-check y módulo temporal de fuentes app excepto entry point
  Sparkle pasan con warnings existentes. Tests nuevos VisualTurnTests pasan
  type-check con framework/plugin Testing explícitos. Ejecutable aislado pasa
  coordenadas/origen negativo, destinos inválidos/caducados, timeout y cancelación.
  git diff --check pasa. No se accedió a micrófono/pantalla ni se llamó API en tests.
- Intento de type-check de suite completa encontró fallos preexistentes en
  CursyTests.swift: imports de geometría/Foundation y macros sobre métodos mutantes.
  No afirmar suite completa verde; corregir/verificar antes de su ejecución global.
- Pendiente: eventos reales de API, calidad del señalamiento 4/5, preguntas ambiguas,
  display secundario, consentimiento apagado, turnos AirPods/idiomas, aceptación
  explícita. También ampliar fixtures de protocolo para errores y duplicados.
  Ticket NO cerrado; no continuar al siguiente hito sin aceptación.

## Corrección tras señalamiento erróneo de cerrar ventana

- Usuario reportó destino derecho incorrecto; captura real del turno/modelo no
  registrada, por lo que causa semántica es hipótesis, no diagnóstico definitivo.
- ElementLocationDetector ahora participa en captura y resolución mediante una
  extensión local de solo lectura AX: apps visibles, foco, ventanas y botones
  cerrar/minimizar/zoom. Datos limitados al display autorizado; lectura acotada.
- Realtime recibe metadata de ventana, distingue app explícita de ventana activa,
  y devuelve intent/nativeControlID. Controles de ventana requieren ID verificado;
  se consulta su posición actual y se rechazan cambios, no se ejecutan acciones.
- La rama antigua Claude Computer Use NO está activada: exige clave Anthropic
  directa y no tiene broker protegido configurado. No se introdujo una clave en
  la app ni se declaró esa rama operativa. Requiere migración al Worker y verificar
  disponibilidad/credencial antes de activarla; pendiente comunicar elección.
- Auditoría: captura/overlay/Reatime ya conectados; no hay seguimiento continuo,
  ventanas ocultas ni captura de otra pantalla por nombrar una app. AssemblyAI y
  voz ElevenLabs siguen con configuración pendiente; updater desactivado por diseño.
- Type-check de app (sin entry point Sparkle) pasa con warnings existentes;
  validación real AX/modelo y regresión del botón cerrar aún pendientes.
- Validación final: emisión del módulo Swift sin CursyApp.swift pasa; type-check
  de VisualTurnTests pasa. Ejecutable aislado pasa rechazo de intent nativo sin
  control, ID desconocido e intent ausente, coordenadas genéricas, caducidad,
  deadline y cancelación. No usa micrófono ni captura real. Sandbox de macros
  requirió ejecutar compilador fuera de sandbox; no se usó xcodebuild.

## OpenAI parity follow-up (supersedes inactive-Claude decision above)

- User requires existing Claude-dependent capabilities to run with OpenAI now,
  with provider choice separated from app behavior later.
- Replaced ClaudeAPI with provider-neutral VisionAPI (protected /vision contract:
  instructions, prompt, images, history; neutral delta/done/error SSE).
- Worker OpenAI adapter uses GPT-4.1 by default, GPT-4.1 mini optional, explicit
  model allowlist, bounded request, internal bearer, no-store, redacted errors,
  rejects truncated streams. Old /chat retired with HTTP 410 in local code.
- Removed direct Anthropic Computer Use implementation. ElementLocationDetector
  now requests normalized JSON through VisionAPI for fallback and shares AX/
  freshness validation with Realtime's existing OpenAI pointing tool.
- Picker migrated from Sonnet/Opus to supported OpenAI vision models; no silent
  loading of old Claude preference. This picker remains fallback-specific;
  Realtime model remains gpt-realtime-2.1. No audio/cursor changes.
- Validation: full Swift module emission (except Sparkle entry) passes with
  existing warnings; VisualTurnTests and VisionAPITests type-check. Worker npm
  test: 5/5 fixture tests pass. Wrangler dry-run passes; no upload or live API
  request. Native tests added but not executed in Xcode.
- PENDING: deploy Worker with user authorization, run app from Xcode, validate
  fallback/model access and live screen pointing. Not accepted or complete.
- Future providers need a server adapter and capability validation, not just
  arbitrary model names. AssemblyAI/ElevenLabs remain separate optional legacy
  audio services; this change removes Claude dependencies, not those services.

## Multiple monitors follow-up

- User explicitly requires cursor-display capture across two or more monitors.
- Existing one-overlay-per-display and display-ID coordinate mapping retained.
  Added screen-configuration observation to rebuild overlays on hotplug/layout
  changes and clear old pointing targets. Hosting view now uses local zero origin.
- Cursor display sampled after asynchronous ScreenCaptureKit enumeration.
  Reject capture if pointer crosses displays or selected display changes during
  capture; next turn samples fresh. Sharing still captures one monitor per turn,
  not all monitors or continuous video. Response stays bound to captured monitor.
- Swift module check passes (except Sparkle entry, existing warnings); added
  five test layouts (primary/left/right/above/below), including negative origins
  and rearranged-display rejection. Physical multi-monitor validation pending.

## Authorized deployment and remote verification

- User confirmed multimonitor works and explicitly approved deployment.
- Re-ran npm test: 5/5 pass. Deployed cursy-proxy version
  da28d78e-f2f9-49a3-9ffd-a124763c8dac successfully.
- Remote smoke tests with internal bearer obtained in-process from existing
  Keychain item, never printed: /vision unauthenticated 401; unsupported model
  authenticated 400; GPT-4.1 and GPT-4.1 mini nonstream 200; streaming 200 with
  delta and done, no error. Only synthetic text sent, no screenshots/audio.
- App runtime visual/fallback acceptance still pending. These checks establish
  deployed transport/model availability, not screen interpretation accuracy.
  Keep tsk002 in progress until remaining acceptance gates are verified.

## Active-window context refinement

- User confirms visual flow works but needs repeated attempts because model asks
  which window/tab. Code evidence: focused window could be excluded by prefix(4);
  existing instructions also encouraged clarification broadly. No captured failing
  payload exists, so these are concrete weaknesses, not a proven sole root cause.
- Metadata now JSON with frontmost app identity even if absent from visiblePIDs,
  explicit activeWindowID/status, title, role/subrole, normalized bounds, native
  control IDs, pointer and captured display identity. Focused window is enumerated
  first, including when missing from AXWindows. JSON escapes window titles.
- Shared ScreenContextPolicy tells Realtime/fallback that "this window" means
  active native window; multiple visible windows alone do not require clarification.
  Explicit named app/tab/panel still wins; missing focus/other display remains honest.
- Capture rejects changes of frontmost app/focused AX window during capture.
  No hidden-window imagery, text-field values, persistent screenshots or new upload.
- Eight isolated tests pass (six session, two focus priority). App Swift module
  and relevant test type-check pass; no xcodebuild, live screenshot or deployment.
  User must validate reduced clarification against multiple visible windows.

## Dock application guidance correction

- User confirmed native window closing works; reported refusal to guide opening
  WhatsApp and target near VS Code instead of WhatsApp. Screenshot confirms wrong
  visual destination; original model coordinates were not recorded.
- Added bounded read-only Dock AX traversal (application Dock items only, SDK
  kAXApplicationDockItemSubrole). Metadata includes names and IDs on authorized
  display; excludes document/URL/folder/minimized-window items.
- Candidate must be on captured display and pass center hit-test. At pointing,
  revalidate AX element frame, app name, subrole and hit-test to reject hidden,
  moved/magnified, occluded or stale Dock items. No AX actions performed.
- Both vision paths now support dock_application intent requiring matching native
  ID. Generic coordinates over known Dock app frames rejected. Missing Dock
  evidence leads to verbal Spotlight guidance, not pixel guessing.
- Shared prompt explicitly distinguishes guidance from opening an app, does not
  refuse "show me how", and requests a new voice turn after the user opens the app
  to inspect a conversation. No autonomous app launch or continuous walkthrough.
- Swift module emission excluding Sparkle entry passes with existing warnings.
  Isolated session/context/native policy suite: 10 tests pass. Relevant tests
  type-check against full module. Live Dock accessibility/WhatsApp test pending.
  No deployment needed: native-only change; preserve audio/cursor rendering.

## Visible chat row / out-of-window pointing correction

- User authorized correction after successful continuity but wrong search guidance
  and pointer outside WhatsApp. Scope now includes bounded local Apple Vision OCR
  of the already-authorized image (supersedes original no-OCR scope).
- ScreenTextGrounding reads up to 180 text observations (es/en, confidence >=0.5),
  maps Vision bottom-left boxes to full-image top-left coordinates. Text linked to
  AX window identity via center hit-test; hidden/other-window evidence excluded.
- Generic pointing requires windowID; evidenceID uses the exact local OCR center,
  not model coordinates. Unknown/mismatched IDs, moved windows, points outside the
  window/display and current occlusion are rejected. Unlabeled controls still use
  model coordinates with window/hit-test guards; semantic accuracy not guaranteed.
- Both Realtime and fallback receive visible-text guidance and updated contract.
  Visible named items take precedence over search; no hard-coded WhatsApp name.
- OCR runs away from main actor, optional 800 ms deadline, one in-flight request
  even after timeout. No stored images/text or new remote endpoint/deployment.
  Screen capture still has 3-second outer deadline. Cold Vision initialization
  measured 36 s on attachment; subsequent run 0.35 s. Timeout safely omits OCR.
- Attachment-only local test found exactly one requested chat at expected row.
  This does NOT verify live AX association or model selection. Scrolling content
  within an unmoved window after capture remains subject to snapshot staleness.
- Module emission excluding Sparkle entry passed with existing warnings. Geometry,
  wrong-window/unknown-ID/outside-window tests pass; live Xcode acceptance pending.

## General visual policy clarification

- Removed chat-specific and WhatsApp wording from shared runtime guidance.
  Visible target first applies to buttons, files, settings, tabs, fields, list
  items and icons in the relevant app. Search/navigation is a fallback when the
  target is absent or cannot be reliably identified; missing OCR is not absence.
- Follow-ups retain requested target, application and constraints; new capture
  verifies visible progress without assuming the whole task is complete.
- Added prompt-contract regression test, not a behavioral model evaluation.
  No transport, geometry, audio or animation change; live acceptance still pending.

## Multimonitor capture/grounding reliability follow-up

- User reported verbal-only guidance and search fallback while the requested target
  was already visible on the pointer's second display. Recent local logs proved
  conversation replay, but older instrumentation did not record capture display or
  rejection cause; do not claim whether that specific turn uploaded display 2.
- Root implementation weakness fixed: local OCR evidence previously required an AX
  element-to-window association. Apps with incomplete accessibility trees could
  therefore lose all text grounding despite a valid screenshot.
- Capture now records front-to-back, layer-zero ScreenCaptureKit window IDs, app,
  frame and display; OCR binds geometrically to the topmost captured window. Generic
  model coordinates use the same window IDs when OCR times out or misses a visual
  control. This is application-independent.
- Before pointing, current CGWindow data must retain the same window ID, owner and
  frame, and it must remain topmost at the point. Native controls keep stricter AX
  validation. Cursy windows and desktop elements are excluded.
- Added content-free diagnostics: display ID, bytes, captured-window/OCR counts and
  stable rejection codes. Menu notice distinguishes successful capture, verified
  target and capture-with-rejected-target. No screen text, labels or images logged.
- Pure suite: 21/21 tests pass, including AX-independent frontmost-window grounding,
  OCR geometry, raw-coordinate fallback and no application-specific prompt rules.
  Full source module emits with existing warnings. A read-only CGWindow smoke check
  parsed 20/20 visible records. Live second-display Xcode acceptance remains.

## Mandatory cursor decision before spoken guidance

- User confirmed target interpretation but reported verbal location instead of a
  cursor indication. Concrete cause in Realtime: the only visual function used
  response-level `tool_choice: auto`, so the model was allowed to answer without
  calling it. This explains the bypass; it does not imply the target was invalid.
- Replaced the optional point call with one mandatory per-turn decision tool,
  `resolve_visual_guidance`, and response-level `tool_choice: required`. With one
  eligible function the model must choose `point` or a bounded `no_point` reason
  before it may produce audio. Official Realtime tool guidance documents required
  tool choice and function-call output continuation.
- Location/show/find requests are contractually cursor-first. After a locally
  accepted point, the continuation may only confirm briefly, never replace the
  cursor with spatial directions. Missing, ambiguous, stale or rejected targets
  produce an honest limitation/clarification without invented verbal coordinates.
- The fallback path now also replaces spatial prose with a short confirmation when
  its independently validated detector actually positioned the cursor. This is a
  general UI-target rule; no application, chat or contact special case was added.
- Added value-typed decision decoding, capture binding and contradictory-state
  rejection tests. Full Swift module emits successfully with existing warnings;
  VisualTurnTests type-check with Xcode's Testing framework/macros; isolated pure
  suite remains 21/21 green; `git diff --check` passes. Live Xcode acceptance of
  target → cursor-before-audio remains pending, so tsk002 stays in progress.

## Hybrid visible-target recovery

- User authorized the general ct005 correction after a live turn returned
  `target_missing` while the requested named list item was visibly present. The
  supplied QA screenshot is not an application-specific product rule.
- Realtime's mandatory decision now includes `targetQuery`: the shortest distinctive
  label the user means. A `target_missing` decision supplies that query and the
  relevant captured visual-window ID when available.
- Added a conservative local lexical resolver over already-grounded OCR. It folds
  case/diacritics, removes request-language noise, requires all meaningful query
  tokens and accepts only one sufficiently distinct candidate. Duplicate matches,
  wrong-window matches, native controls and non-`target_missing` outcomes are not
  overridden.
- A recovered candidate still passes the existing current-window, frame, z-order,
  capture-age and display validation before the cursor can move. OpenAI interprets
  intent; local code owns evidence identity and geometry.
- Corrected a prompt defect where the post-tool response received literal text
  `(voiceInstructions(for: language))` instead of the interpolated base policy.
  Visual metadata headings now align with the contract (`visualWindows` and
  `visibleText`). Runtime diagnostics remain content-free.
- Official Realtime guidance confirms the existing client-owned function pattern:
  send `function_call_output`, then create a continuation response. No provider
  endpoint, Worker deployment, audio engine or cursor rendering changed.
- Validation: complete native source type-check passes with pre-existing warnings;
  VisualTurn/ScreenContext/ScreenText tests type-check with Xcode's Testing framework
  and macro plugin; synthetic executable passes unique recovery and duplicate-label
  ambiguity; the same executable runs local Apple Vision against the supplied QA
  attachment and recovers its requested visible target; `git diff --check` passes.
  Live Xcode acceptance remains required, so tsk002 stays in progress.

## Canonical visual-window identity follow-up

- The next live QA run captured the cursor's second display correctly on every
  relevant turn (33–34 grounded OCR items), but two model-produced point decisions
  were rejected as `visual_window_stale_or_missing`. One intervening tool result
  also surfaced the client's generic `cannotParseResponse` error (`-1017`).
- Read-only live enumeration confirmed that ScreenCaptureKit and CoreGraphics
  agreed on the WhatsApp window number, owner and frame. The failure was therefore
  not missing imagery, the second display, or a recreated window.
- Root cause: the prompt exposed AX window IDs (`pid-index`) and captured visual
  IDs (`visual-window-CGWindowID`) simultaneously. OpenAI could select a valid AX
  identity while generic local validation accepted only the visual namespace.
- Capture now correlates AX windows to captured windows by owner plus bounded frame
  agreement and exposes the canonical visual ID wherever a unique match exists.
  Decision normalization also translates a legacy AX ID locally and lets verified
  OCR evidence own the final window ID and geometry. This applies to every app and
  visible text target; no WhatsApp/contact behavior was added.
- Model tool decoding now defaults nonessential missing fields safely while still
  requiring action, reason and capture identity. Content-free diagnostics separate
  invalid envelope/arguments/context from window-ID, disappeared-window and
  moved-window failures.
- Validation: all Swift sources parse; complete app-source type-check passes with
  only pre-existing warnings; VisualTurn and ScreenTextGrounding test suites
  type-check with official Swift Testing macros; an executable regression that
  reproduces AX `3441-0` versus visual `visual-window-7520` canonicalizes to local
  evidence and passes. `git diff --check` passes. Live Xcode acceptance remains.

## Provider-vision restoration and external-display fidelity

- The user rejected the interim local Apple Vision OCR/lexical resolver after a
  source audit. The original repository contained no local OCR: its visual
  localization asked Claude to interpret a screenshot and return coordinates.
  The base main flow also used screenshot-to-coordinate model output. The local
  OCR work described in earlier historical sections is therefore superseded and
  has been removed from the runtime and tests.
- OpenAI now owns the complete current visual interpretation path. Realtime sends
  the authorized screenshot and requires `resolve_visual_guidance`; the fallback
  uses `VisionAPI` through the protected Worker's OpenAI adapter and decodes the
  same `PointingTarget` semantics. Native code does not read screen text: it only
  correlates AX/ScreenCaptureKit window identities and validates capture age,
  display, current window frame, z-order and returned coordinates.
- The client contract remains provider-neutral and the Worker isolates provider
  payloads. A future Claude adapter must return the same normalized response/tool
  contract; adding it must not introduce Claude-specific logic into UI, session,
  capture or pointing validation code. Current selectable models remain OpenAI.
- A live external-monitor trace showed display 2 was selected correctly but the
  old 1280×720 image was suspected to leave insufficient visual detail (not proven
  by that trace). Cursor-display
  captures now preserve aspect ratio up to 1920 pixels on the long side, without
  upscaling, and use bounded JPEG compression to remain within 1 MiB. This is
  provider input fidelity, not local image interpretation.
- Successful validated points now force an exact one-sentence continuation:
  `Ahí está.` / `There it is.` The turn ends immediately without previewing later
  walkthrough steps. Missing or unsafe targets get one concise limitation or
  clarification, never unverified spatial directions.
- Replaced `ScreenTextGrounding` with content-free `ScreenWindowGrounding` and
  removed `textEvidence`, `evidenceID`, `targetQuery` and local target-recovery
  branches from the decision contract. Live Xcode acceptance on the external
  monitor remains required before completing tsk002.
- Validation after removal: all app and test sources parse; complete app-source
  type-check succeeds with only documented pre-existing warnings; focused
  `VisualTurnTests` and `ScreenWindowGroundingTests` type-check with Swift Testing;
  an executable external-display geometry regression passes; and
  `git diff --check` reports no whitespace errors. Repository search confirms no
  Apple Vision OCR APIs or direct Anthropic client remain in current runtime code.

## Pixel-localization audit and correction — 2026-09-18

### ct006 refinement: approved implementation plan (six layers)

1. Goal: classify every localization/validation rejection without reading local
   screen text. Reuse tsk002, not a duplicate ticket. Complexity 5/10.
2. UX: preserve cursor-before-audio, no clicks, brief failure reply and all native
   safety guards. No animation, language or audio changes. No forced point when
   Realtime decides ambiguous/missing.
3. Design: typed rejection reasons, capture-correlated numeric-only diagnostics,
   one coherent current-window snapshot, and a testable generic pointing pipeline
   shared by production and integration fixtures. Keep provider interpretation.
4. Dependencies: existing VisionAPI, VisualTurnContext, session validity and overlay
   coordinate mapper. No backend contract change, model change or deployment.
5. Implementation: split decoder/geometry/refinement failures; instrument before
   rejection; extract the minimal async orchestration seam; test with realistic
   overlapping window rectangles and mocked provider/I/O boundaries, including
   stale session and revoked sharing. cce-mobile + write-swift own execution.
6. Validation: compile source module, run existing and new Swift Testing suites,
   check whitespace. Tests must exercise decode→refine→current-window/z-order→
   publication→overlay conversion; explicitly distinguish these from live API/UI
   acceptance. User runs Xcode to reproduce ct006 and confirm logged reason.
   Rollback: disable visual sharing; do not remove guards. No private payload logs.


- User QA: correct concise response/label, but the indicator landed several rows
  above the requested visible list item. This is a generic localization failure;
  the attached app/contact are test data only, not runtime rules.
- Compared HEAD's original detector, manager and overlay with the working tree.
  The base detector resized to a declared Computer Use raster, consumed pixel
  coordinates, scaled to display points and inverted Y. The base manager used
  model-generated POINT tags rather than invoking that specialized detector.
  Our normalized conversion is algebraically equivalent; the existing +8/+12 pt
  overlay offset cannot explain the several-row displacement. No evidence that
  the original unused detector was an already-integrated precision guarantee.
- Latest live trace (PID 83279, 20:28–20:29) captured display 1 at 1728×1117 and
  accepted points; this particular run was not a missing second-display capture.
  Historical logs lacked raw target coordinates, so they cannot conclusively
  distinguish semantic selection from provider pixel-scale error.
- Controlled OpenAI evaluation against the supplied attachment reproduced wrong
  coordinates at a 1920×1401 raster. Preparing the same aspect-preserving image
  at 1052×768 produced correct target regions for three distinct visible targets
  (lower list item, search field, tab). The absent-target response was prose,
  which strict decoding rejected safely; removed conflicting conversational
  instructions from the detector prompt so it asks only for JSON or target:null.
- Added VisionLocalizationImage: preparation compatible with current OpenAI vision
  adapters (768 short side/2048 long side, no upscaling or OCR). Full-resolution
  conversational capture remains separate. Provider pixel results include exact
  raster dimensions and normalize once; retained generic capture/window bounds,
  current z-order, stale-turn, permission and cancellation guards.
- Connected the existing ElementLocationDetector/VisionAPI to generic Realtime
  targets. Realtime chooses intent; the detector independently localizes from the
  current screenshot without being supplied the earlier coordinate guess. Native
  AX controls still use their verified geometry directly. Generic refinement must
  retain the requested canonical window; failure does not reuse the old estimate.
  Cursor placement completes before the exact short audio confirmation. This adds
  one OpenAI call for generic targets, not clicks or another capture.
- Centralized pixel→global AppKit→overlay conversion in ScreenCoordinateSpace.
  Content-free diagnostic logs now include numeric image/global coordinates for
  future discrepancy audits; no screenshots, transcripts, labels or credentials.
- Validation: Swift app sources except Sparkle entry point compile into a temporary
  module/library (existing warnings only); 22 Swift Testing tests in five suites
  execute successfully, including multi-monitor layouts, exact prepared raster
  size, coordinate round-trip, malformed dimensions, native guards, capture timeout,
  policy and mocked protected VisionAPI. No xcodebuild or deployment.
- Live model timings in the controlled compatible-scale run: positive targets
  9.65 s, 1.59 s and 1.07 s. These are detector calls, not end-to-end voice latency.
  Final four-case run against integrated preprocessing PASSED 4/4: lower list item,
  search field and tab fell within predeclared visible target regions; nonexistent
  button returned target:null. User authorized the temporary binary's Keychain
  access. First case's 112.11 s wall time includes waiting for that authorization
  and is not a model-latency measurement. Remaining cases took 1.52/1.32/1.25 s.
- Sources: OpenAI images/vision guide (high-detail resizing and spatial limitations)
  https://developers.openai.com/api/docs/guides/images-vision and computer-use guide
  https://developers.openai.com/api/docs/guides/tools-computer-use. This implements
  the existing vision adapter, NOT OpenAI's specialized Computer Use tool.
- Gate remains open: user must rebuild/run from Xcode and validate real cursor
  alignment, both displays and repeated voice turns. Passing geometric tests or
  four image fixtures is not proof of perfect localization across arbitrary UI.

## ct006 diagnostic implementation — 2026-09-18

- User approved the recommendation. CCE Quick Feature's six-layer refinement
  above reuses this active ticket instead of creating duplicate planned work.
  cce-mobile + write-swift guided typed recoverable errors and checks after await.
- Added PointingRejection / PointingDiagnostics and GenericPointingPipeline.
  Production CompanionManager now uses the same async orchestration exercised
  by tests: locator → intent/window agreement → OS validation → publication.
  Current turn, sharing and cancellation are checked before/after awaiting, and
  stale replies cannot publish or modify a replacement turn's status notice.
- Decoder separates explicit target:null, invalid JSON/missing target, dimensions,
  coordinate range, capture and unknown window. Model-owned native controls retain
  existing AX checks. Realtime no_point now explicitly logs locatorInvoked=false
  with capture correlation; no semantic override/retry was added in this phase.
- Generic validation uses a single front-to-back OS window snapshot, eliminating
  separate current-window and z-order reads. Distinct failures identify missing/
  reused/moved windows, out-of-window points and occluding window IDs. No validation
  was relaxed; historical rejection cause remains unproven until reproduction.
- Provider numeric dimensions/pixels are logged before validation; rejected
  candidates include normalized/global point, expected/current numeric window IDs,
  bounds and age where available. Capture correlation uses only app-created UUIDs.
  No app titles, target labels, transcripts, screenshots, credentials or raw errors.
- Validation: full source module/library excluding CursyApp Sparkle entry point
  compiles with existing warnings; focused Swift Testing executable passes 27 tests
  in 7 suites. New pipeline suite includes three monitor placements, 16 distinct
  rejection scenarios and a stale-turn preflight proving no provider invocation.
  Initial test compilation needed explicit try inside #require; initial geometric
  equality assertions exposed floating rounding (440.00000000000006), corrected
  with a 0.00001-point tolerance in tests, not by changing production geometry.
  Final executable exits 0. git diff --check passes. No xcodebuild or deployment.
- Test boundary: real app decoder/refinement/geometry/publication seam/overlay
  mapper, but controlled model responses and window snapshots. No actual speech,
  provider call, physical monitor capture or NSPanel animation in this run. This
  does not claim end-to-end live acceptance. The next required step is Xcode QA
  reproducing the visible target case and capturing its precise reason code.
- tsk002 remains in progress at its manual acceptance gate. No OCR, application-
  specific matching, audio/cursor redesign, broad capture or forced pointing added.

## Refinamiento ct007 — ciclo visual bajo demanda (plan, 2026-09-18)

Estado de esta fase: implementación integrada; aceptación manual en Xcode pendiente.
Ruta: Cce Quick Feature, complejidad 6/10 por limitarse a una petición y su destino.
Dueño: cce-mobile; companion write-swift para estado, cancelación y pruebas.
En ejecución, consultar openai-docs para el contrato de continuación de herramientas.
No delegación, despliegue ni cambios del transporte de micrófono/AirPods.

### 1. Objetivos y requisitos

Como usuario, quiero que una indicación siga siendo correcta si desplazo el
contenido mientras Cursy analiza o mientras muestra brevemente el destino, sin
tomar capturas manuales ni repetir mi objetivo.

Hechos actuales: cada PTT terminado captura de nuevo; el localizador independiente
reutiliza esa imagen. La validación de geometría no prueba que el contenido no haya
cambiado. ConversationSession no acepta modificaciones de turnos completados;
OverlayWindow puede finalizar/cancelar navegación al mover el ratón.
Inferencia: scroll posterior a la captura puede invalidar el destino sin cambiar
el frame. No explica por sí solo todos los fallos tras una NUEVA petición.

Alcance: conservar objetivo semántico; recapturar tras cambios de escena; verificar
versión antes de publicar; retirar puntos obsoletos; aplicar al camino Realtime y
fallback con los mismos límites. OpenAI interpreta, contratos neutrales al proveedor.
No incluye OCR, seguimiento permanente, clics/escritura, avance de pasos,
walkthroughs, captura simultánea de monitores ni reglas por app o nombre.
Zoom solicitado por el modelo queda como mejora posterior: no es requisito para
corregir frescura y no se introducirá otro sistema de coordenadas en esta fase.

Criterios medibles:

- Ninguna respuesta de una revisión invalidada publica punto o confirma su éxito.
- Al recibir señal de cambio relevante, se retiran punto/etiqueta en la siguiente
  actualización del MainActor; recuperación solo con captura y validación nuevas.
- Scroll con objetivo aún visible lo relocaliza; si desaparece o es ambiguo no
  reutiliza coordenadas ni cambia silenciosamente de objetivo.
- Máximo una operación de análisis visual en curso; dos ciclos adicionales por
  petición, tres en total. Cada ciclo como máximo decisión + localización, sin
  reintentos ocultos que eludan el presupuesto (hasta seis llamadas visuales).
- Deadline absoluto inicial propuesto: 30 s desde iniciar observación. Tras primer
  punto, seguimiento hasta 5 s, sin extender ninguno de los plazos al recapturar.
  Al expirar, retirar marcador y detener observación. Valores configurables para
  QA; no promesa de latencia del proveedor.
- Compartir apagado, cancelar, nueva petición/conversación o detener app: ninguna
  nueva captura/envío; callbacks ya en vuelo no publican. No se puede deshacer un
  envío al proveedor que ya comenzó; cancelar su espera y descartar su resultado.

### 2. Experiencia de usuario

Compartir pantalla sigue siendo opt-in. Actualizar su explicación en español e
inglés: capturas automáticas durante la petición y un seguimiento breve, no
solo una imagen. Mostrar estado bilingüe «Analizando», «Actualizando indicación»,
«Indicación actualizada» y finalización, usando controles existentes accesibles.
No usar animaciones nuevas, anuncios repetitivos de VoiceOver ni color como única
señal. Preservar cursor, menta, escala y modos de voz aceptados.

Flujo: petición → captura → analizar → señalar → breve seguimiento → terminar.
Cambio: retirar punto → esperar estabilidad → capturar → relocalizar → señalar.
No pedir otra captura al usuario. Una sola confirmación hablada concisa después
de aceptación vigente; actualizaciones posteriores silenciosas, sin repetir
«ahí está» cada vez. Si un cambio invalida éxito aún pendiente de voz, suprimirlo.
Si ya se reprodujo, no fingir que se puede retirar audio pasado; limpiar indicador.

Ausencia/ambigüedad en imagen fresca: detener con explicación breve y sin punto.
Inestabilidad continua/presupuesto agotado: terminar con «La pantalla sigue
cambiando; vuelve a pedirme la indicación cuando se estabilice», no bucle infinito.
La cancelación deliberada del indicador termina su seguimiento: no reaparece sola.
Separar esta causa de la retirada temporal por escena sucia. Definir esa señal
en el seam overlay/coordinador antes de conectar recaptura.

### 3. Diseño técnico y reutilización

Agregar coordinador pequeño de observación con estado explícito y política pura
testeable; no crecer toda la orquestación dentro de CompanionManager.
Estados sugeridos: idle, observing, analyzing, pointing, waitingForStability,
ended(reason). Contrato mínimo: observationID, sessionID, originatingTurnID,
sceneRevision, captureID, displayID/frame, semanticTarget, deadline, refreshCount.
Objetivo y bytes son efímeros; nunca historial de coordenadas ni capturas en disco.

- Reusar VisualCaptureRequest, VisualTurnContext, VisionLocalizationImage,
  GenericPointingPipeline, VisionAPI y las validaciones nativas existentes.
- Un solo propietario MainActor serializa estado/publicación. Valores para
  identidad/estado, reloj inyectable. Comprobar generación, sharing, cancelación
  y deadline después de cada await y justo antes de enviar/publicar.
- La observación tiene una vida acotada propia: la respuesta de voz puede haber
  completado su turno durante los 5 s de seguimiento. No reabrir turnos terminados,
  añadir intercambios ficticios ni debilitar ConversationSession.isActive. La
  autorización para actualizar overlay exige observationID/sessionID vigentes y
  ausencia de petición posterior. Antes de completar voz, mantener guardas de turno.
- Versionar cada captura; un cambio incrementa revisión y anula resultados en
  vuelo aunque captureID/ventana todavía parezcan válidos. Cancelación cooperativa
  más guardas de revisión; no confiar solo en Task.cancel().
- Señales locales de scroll/ventana/display invalidan de inmediato cuando estén
  disponibles, sin interceptar eventos ni sintetizar entradas. Complementar con
  comparación visual local de frames reducidos del display autorizado, no OCR:
  solo detectar diferencia, nunca reconocer texto, objetos o intención localmente.
- Muestreo local inicial 2 Hz, serial, durante la observación; no enviar muestras
  de vigilancia al proveedor. Conservar solo referencia y muestra actual en memoria.
  Excluir ventanas Cursy y cursor como en captura existente; comparar por regiones
  de ventana para no invalidar por un vídeo en otra ventana. Cambio dentro de la
  ventana objetivo invalida conservadoramente; no prometer distinguir cada animación.
- Gate técnico: medir captura/comparación y falsos positivos antes de integrar.
  Si no puede vigilar cambios con permisos existentes, informar incapacidad y no
  declarar fresco el destino usando solo edad/frame. No solicitar TCC/reset extra
  silenciosamente. No introducir SCStream permanente por defecto.
- Tras última señal, estabilidad propuesta >=500 ms y dos muestras consistentes;
  antes de publicar, comparar nuevamente con la imagen analizada. Diferencias se
  evalúan sobre imagen, no hashes de JPEG comprimido; umbral calibrado con fixtures
  de pequeños scrolls y animación. Registrar tolerancia/límites reales.
- Selección de display se mantiene por cursor: al cambiar monitor, invalidar y
  recapturar solo el display actual, sin escanear todos buscando el objetivo. No
  reutilizar IDs de ventana del monitor previo. Reinterpretar el mismo objetivo
  con metadata fresca; si ya no está visible, devolver ausencia sin inventarlo.
- Si cambia escena ANTES de decidir objetivo, repetir decisión con nueva imagen
  y la misma petición, no obedecer una etiqueta de navegación de la imagen vieja.
  Tras objetivo aceptado, relocalizar ese objetivo con VisionAPI; no avanzar pasos.
- Realtime: resolver cada tool call exactamente una vez. Un resultado obsoleto
  devuelve estado de actualización, adjunta imagen nueva y requiere decisión
  vigente antes de audio de éxito. Serializar/correlacionar respuestas; verificar
  contrato oficial al ejecutar. No duplicar audio commit ni reabrir el micrófono.
- Reutilizar geometría/píxeles y validación ventana/z-order sin relajar rechazos.
  Una referencia antigua de ventana no debe imponerse como identidad de la nueva
  captura; validar cada resultado únicamente contra su contexto correspondiente.

Archivos previstos (cursy-app/Cursy): CompanionManager, captura, Realtime client,
VisualTurnContext, PointingDiagnostics, OverlayWindow y texto de panel/idioma;
coordinador/política nuevos solo si no existe equivalente al comenzar ejecución.
ConversationSession solo necesita seam de identidad/cancelación si falta; no
modificar sus transiciones terminales. Tests Swift Testing en CursyTests.

### 4. Dependencias y compatibilidad

Usa ct007, corrección ct006 y núcleo ya integrado de tsk003; no espera completar
walkthroughs ni sustituye la aceptación pendiente de sesiones. tsk002 debe aceptar
este refresco antes de ampliar guía continua. macOS mínimo 14.2, Swift del proyecto
en modo 5; no migrar concurrencia global/toolchain para esta tarea.
No paquetes nuevos, backend/deploy ni credenciales nuevas por anticipado.
OpenAI sigue activo; futuras implementaciones Claude consumen captura/objetivo/
resultado neutrales, nunca ramas por app. Audio físico queda fuera del refactor.

### 5. Implementación por fases

1. Política/reductor puro: identidad, deadline, presupuesto, estabilidad,
   invalidación, fin de seguimiento y callbacks tardíos. Tests primero.
2. Adaptador nativo de señales/muestras: exclusión overlay, display del cursor,
   permisos/cancelación; medir coste y ruido. No llamadas al modelo en esta fase.
3. Integrar recaptura y resultados tipados con pipeline real, Realtime y fallback;
   preservar objetivo, recambiar metadata y separar éxito verbal de refrescos.
4. Integrar cancelación overlay/menú y vida breve posterior al turno; textos
   accesibles es/en y switch interno de rollout del refinamiento.
5. Validación determinista, módulo Swift y QA real en Xcode; documentar límites
   medidos en este registro/README/logbook. Sin terminal xcodebuild.

Privacidad: no pantalla/audio/texto/etiquetas ni credenciales en logs. Solo IDs
propios, revisiones, motivos, contador, bytes y duración. Tratar contenido visual
como datos no confiables. Respetar límite de imagen existente; no subir resolución
ni capturar aplicaciones ocultas para compensar reconocimiento. Detener tareas,
timers y monitores en todos los caminos terminales. Retener memoria acotada.

### 6. Validación, rollout y cierre

Tests deterministas con reloj/captura/proveedor/senalización controlados, sin sleep
real ni llamadas pagadas: flujo producción captura→decisión→localización→ventanas
actuales→publicación→invalidación→recaptura. Cubrir también fallback, no solo reducer.

| Caso | Resultado exigido |
|---|---|
| Pantalla estable | Una decisión inicial; ningún refresco de proveedor innecesario |
| Scroll antes de petición nueva | Captura nueva, no coordenadas heredadas |
| Scroll durante análisis/localización | Respuesta anterior descartada, recaptura tras estabilidad |
| Scroll durante vuelo/indicador visible | Punto anterior retirado; relocaliza mismo objetivo en plazo |
| Objetivo ausente/ambiguo | Sin punto, sin búsqueda genérica o destino alternativo silencioso |
| Captura cambia durante validación | No publica éxito de revisión anterior |
| Scroll continuo/eventos duplicados | Respeta un trabajo activo, deadline y dos refrescos |
| Modelo lento/fallo/malformed | Error tipado; sin reintentos ilimitados ni audio de éxito |
| Ratón descarta indicador | No resucita por un callback o muestra posterior |
| Voz termina antes de seguimiento | Historial una vez; observación expira sin reabrir turno |
| Compartir off/reset/nuevo PTT/salida | Sin nueva captura/envío/punto; descarta eventos tardíos |
| Otro monitor/origen negativo/Retina | Nueva metadata, conversión correcta, solo pantalla del cursor |
| Ventana movida/oculta/display desconectado | Invalidación segura; conserva validaciones originales |
| Cursor/overlay o vídeo en otra ventana | No causan bucle de recapturas |

QA manual Xcode: lista, archivo y ajuste/botón en dos monitores; scroll con destino
visible e invisible, cambio durante análisis y tras punto, nueva petición, cancelar
y compartir off. Los escenarios particulares son fixtures; ninguna regla por app.
Exigir cero puntos aceptados sobre revisiones conocidas como obsoletas en la matriz;
cada destino publicado debe caer dentro del control visible esperado. Si el modelo
falla identificación, registrar separado de frescura; no declarar precisión absoluta.
Medir invalidación (eventos vs muestreo), CPU/memoria, latencia captura→punto y número
real de envíos. Cinco turnos AirPods y es/en sin regresión. Aceptación manual del
usuario requerida antes de cerrar; tests puros no prueban integración OS/modelo.

Rollout interno con flag de refinamiento y consentimiento visual explicado.
Rollback del flag conserva captura por petición y rechazo seguro, cancela todas
las observaciones activas y retira indicadores; no revierte cursor/audio aprobados.
La evidencia de implementación se registra debajo. Mantener ticket abierto hasta QA.

Siguiente comando: `$cce-dispatch execute tsk002-realtime-screen-pointing`.

## Ejecución ct007 — 2026-09-18

- Cce Dispatch + Cce Mobile y Write Swift: lease visual independiente del turno
  terminal, valores para presupuesto/revisión, MainActor, verificaciones después
  de await y tests Swift Testing. No agentes, commit, deploy ni cambios del engine
  de entrada/AirPods. OpenAI Docs confirmó function_call_output → imagen nueva →
  response.create: https://developers.openai.com/api/docs/guides/realtime-conversations.
  MCP configurado pero no disponible en herramientas; se usó documentación oficial web.
- VisualObservation mantiene revisión/captureID, deadline monotónico de 30 s,
  máximo dos refrescos y límite de 5 s desde el primer punto. Deadline separado
  del muestreo; cancelar detiene monitores/tareas y libera imágenes propias.
- Scroll global de solo escucha retira indicador; comparación de luminancia
  320×200 detecta cambios adicionales, sin OCR. Umbral inicial: delta >18/255 en
  max(12, 0.4% de píxeles de región). Tras elegir destino compara su ventana;
  antes de conocerla compara display completo conservadoramente. Verifica IDs,
  frames y orden de ventanas, además de comprobar la escena antes de publicar.
- Ajuste de implementación: reutiliza la captura existente completa con metadata
  también para muestras locales, en lugar de crear otro capturador miniatura/stream.
  Reduce después para comparar; muestreo serial a intervalo 500 ms + coste captura,
  compartido entre monitor/validación. Solo se envían imágenes seleccionadas para
  análisis/refresco; no subir cada muestra. Su coste físico aún debe medirse en QA.
  Sin promesa de 2 fps exactos ni precisión perceptual absoluta. Eventos de scroll
  conocidos invalidan aun si la diferencia de píxeles está bajo el umbral.
- Realtime devuelve una sola salida por tool call obsoleto, adjunta nueva imagen
  y exige decisión sobre la misma petición. No repite audio commit ni reinicia
  micrófono. Guardas de generación entre mensajes, continuación reentrante segura;
  las confirmaciones ya obsoletas no se reproducen/conservan como respuesta oída.
- GenericPointingPipeline añade verificación async de frescura antes de geometría
  y publicación. Fallback usa la misma observación y presupuesto; al cambiar la
  imagen repite el análisis con metadata nueva. TTS verifica vigencia antes de
  reproducir y detiene confirmaciones cuando se retira un punto.
- Después de voz, relocalización silenciosa conserva destino/app, sin reabrir
  ConversationSession ni añadir turnos. No fuerza IDs/coordenadas de la captura
  anterior en el nuevo monitor. Ausencia/ambigüedad/rechazo mantiene indicador vacío.
- El panel explica alcance/tiempos en es/en y permite desactivar Actualizar
  indicación. Cancelación/nueva petición/reset/sharing off/salida revocan lease;
  finalizar/descartar navegación también lo revoca. Invalidez temporal solo retira
  punto, no cancela recuperación. Modo transitorio espera lease para no ocultarse
  mientras el proveedor relocaliza. Sin rediseño de animaciones.
- Tests: suite aislada 54 tests en 10 suites pasa (0.276 s): presupuesto/deadlines,
  estabilidad/ruido/regiones/orientación raster, cambios durante proveedor,
  ausencia/cancelación, dos monitores/origen negativo, terminalidad de voz,
  protocolo de refresco sin duplicar commit, recuperación de captura interrumpida
  al cruzar monitores y regresiones de geometría/sesiones.
  Fixtures ejercitan coordinador/pipeline/payloads reales con capturas/proveedor
  controlados; no es prueba del socket/OS/overlay físico ni de cada rama del manager.
- Compilación de fuentes Swift en modo 5 con swiftc emite módulo/library temporal
  excluyendo solo entry point Sparkle. Sandbox bloqueó macros; compilador fuera
  del sandbox autorizado, sin xcodebuild. Primer build de tests necesitó ruta
  TestingMacros y variables previas para aserciones mutantes; corregidos, suite verde.
  Artefactos de validación: /private/tmp/cursy-observation.jrqBUa (sin capturas reales,
  micrófono, Keychain ni llamadas pagadas). git diff --check pasó.
- Gate pendiente: usuario ejecuta Xcode, valida objetivos diferentes/listas/botones,
  scroll antes/durante/después, ambos monitores, cancelar/sharing off, cinco turnos
  AirPods e idiomas. Medir latencia/CPU reales y falsos positivos de animaciones.
  Resultados precisos del modelo y tolerancia de pequeños cambios requieren QA;
  no se declara tsk002 cerrado. No se añadió OCR ni regla específica de aplicación.

## Corrección ct008 — 2026-09-18

Usuario autorizó corregir los dos intentos que agotaron refrescos sin señalar.
CCE Dispatch mantiene el mismo ticket; CCE Mobile + Write Swift orientaron estado
por respuesta, comprobaciones tras suspensión y pruebas de cancelación. Se ajusta
ct007: no invalidar píxeles de toda la pantalla antes de conocer el destino del modelo.

- RealtimeResponseGate separa visualDecision/spokenReply por token en metadata y
  response_id. Decisiones iniciales/refrescos usan output_modalities=[text]; solo
  continuación final usa [audio]. Audio y transcripción intermedios/tardíos no pasan
  a reproducción ni ConversationSession/replay. No modifica captura PCM/AirPods.
- Consultada documentación oficial de Realtime para modalidades por respuesta y
  correlación con metadata: https://developers.openai.com/api/docs/guides/realtime-conversations
  Herramientas MCP docs no disponibles en esta sesión; fallback web oficial.
- Realtime transmite el candidato a prepareScope ANTES del primer refresco.
  Fallback espera al localizador antes de su comprobación de contenido. Se conserva
  la referencia inicial para detectar cambios reales mientras esperaba al modelo.
- Scope usa ventana elegida por el modelo o región de control nativo; conserva
  identidad/propietario al refrescar y la descarta al cruzar pantalla. Geometría
  considera destino y ventanas delante que lo intersectan, no ventanas ajenas.
  Antes del destino se retienen muestras/scroll, sin gastar retries por píxeles.
  Sin destino verificable, comprobación conservadora de pantalla completa.
- Scroll ajeno al scope se ignora; scroll relevante, destino movido/desaparecido,
  oclusión y cambio de monitor siguen invalidando. Capturas compartidas se vuelven
  a evaluar al cambiar el scope, aunque su captureID ya se haya procesado.
- Quitado log por muestra. Causas scroll/pixels/geometry/captureInterrupted y
  métricas numéricas se acumulan en memoria (máximo 12) y emiten AL TERMINAR,
  evitando que la consola genere sus propias invalidaciones periódicas.
- Conservados 2 refrescos, 30 s/5 s, OpenAI y validación geométrica; sin OCR,
  reglas por app, acciones automáticas, persistencia de conversaciones o despliegue.

Validación: fuentes Swift emiten módulo/library temporal (swiftc modo 5; excluye
entry point Sparkle, no xcodebuild). Suite ejecutada: 62 tests/11 suites, 0.801 s;
git diff --check limpio. Artefactos: /private/tmp/cursy-ct008.krLz1W. Fixtures
cubren gate de respuestas, modalidad silenciosa, otra app animada/movida, scroll
relevante/ajeno, scope persistente, oclusión y sample compartido. No prueba socket
real, captura del escritorio, reproducción audible ni interpretación de OpenAI.

Pendiente: repetir desde Xcode quieto y con scroll, ambos monitores, consola
visible y oculta; una sola respuesta hablada final, señalamiento vigente, ausencia
real/ambigüedad segura. Animaciones DENTRO de la ventana objetivo todavía pueden
invalidar por prudencia. Mantener tsk002 abierto hasta aceptación real.

## Refinamiento ct010 — evaluación e integración local

El usuario autorizó elegir un proveedor/modelo más adecuado y suministró claves
locales. CCE AI Engineer + Backend + Write Swift guían la comparación y el cambio.
Mismo ticket; sin OCR, excepciones por app, clics, cambios de audio ni del cursor.

1. Evaluador aislado, captura aportada por el usuario, rectángulos de aceptación
   declarados antes de las llamadas; tres objetivos visibles y uno inexistente.
2. Baseline GPT-4.1: 1/4; DeepSeek Flash: 3/4 (falla el objetivo reportado).
   GPT-5.6 Sol: 8/8 en dos rondas; GPT-6 Astra: 12/12 en tres rondas.
   Claude Sonnet: 12/12 tras reponer saldo. Opus: 3/4 respuestas válidas.
3. Preparar localizador GPT-6 Astra mediante Responses/original y función estricta;
   conservar GPT-4.1/mini para conversación de respaldo. Separar instancias/configuración.
4. La identidad de captura y dimensiones se ligan en el llamador, no se piden al
   modelo como eco. La salida conserva píxeles absolutos, ventana e intención.
   Mantener validaciones de turno, coordenadas, geometría, oclusión y frescura.
5. Probar contratos Worker/Swift, salida nula/malformada, captura vieja, independencia
   de modelo y errores. Sin fallback silencioso a un localizador no evaluado.
6. Despliegue coordinado y QA físico de dos monitores/scroll/AirPods siguen pendientes.
   Esta muestra en una sola captura no acredita precisión universal ni cierre del ticket.

Ejecución: cliente localizador independiente en los tres caminos, Responses
original + función estricta, metadata ligada al contexto inmutable del llamador.
Selección de ventana explícita para el refinamiento Realtime; validadores conservados.
65 tests Swift/11 suites, 14 Worker y 11 evaluador pasan; módulo nativo y bundle
Worker dry-run compilan. handleVision real contra API resuelve los 4 fixtures con
el nuevo contrato. No equivale al flujo completo de la app ni a seguridad semántica
absoluta. Usuario exige cero fallos observados; se excluyen configuraciones fallidas
del señalamiento, sin prometer 100% futuro. Fuente preparada, NO desplegada;
dependencia de actualizar Worker antes de ejecutar nuevo cliente. Evidencia en ct010.

## Despliegue autorizado ct010 — 2026-09-18

Usuario solicita explícitamente «despliega». CCE Backend/Dispatch: preflight,
compatibilidad, secretos por nombre, despliegue y smoke remoto sin contenido privado.
Se conserva este ticket y el gate de aceptación nativa, no se declara completado.

- Preflight: 14 tests Worker pasan; revisión independiente no encuentra desajuste
  de contrato; secretos OPENAI_API_KEY/CURSY_INTERNAL_API_TOKEN existen. Sin
  modificar sus valores. Versión previa: da28d78e-f2f9-49a3-9ffd-a124763c8dac.
- Primer despliegue: 511129ab-802b-41ad-80dc-c0bf477ca2ce. Publicación correcta,
  pero smoke remoto /vision devuelve502 tanto para localización como respaldo.
  Realtime mint200, rechazos auth401 y entrada400 correctos. Tests Node no
  reprodujeron una incompatibilidad del runtime; investigación local workerd.
- Retirada inmediata mediante rollback a da28d78e-f2f9-49a3-9ffd-a124763c8dac;
  /vision legacy comprobado HTTP200 de nuevo. No cambios de secretos, voz o app.
  El estado de publicación de código por sí solo no acredita salud del servicio.
- Causa confirmada en workerd: redirect:error no es admitido y falla antes de
  enviar la petición. Cambiado a redirect:manual con rechazo no-OK existente;
  nunca sigue redirecciones con la credencial del proveedor. request.signal y
  AbortSignal.any funcionan; no era necesario cambiar la fecha de compatibilidad.
- Añadida src/runtime.test.ts para ejecutar index.ts empaquetado en workerd con
  credenciales sintéticas y upstream simulado, sin llamadas externas. npm test
  incluye contrato y runtime:19/19 pasan (0.457 s). git diff --check limpio.
- Versión corregida desplegada:107dd830-4209-4525-aaac-c2075acb310a,
  tag tsk002-ct010-r2. Conservadas variables/secretos mediante --keep-vars.
- Smoke remoto10/10 pasa: auth401 de visión/Realtime; modelo/stream inválidos400;
  Astra objetivo visible200 dentro del rectángulo esperado (2018 ms), ausente200
  con target:null (2090 ms); respaldo conversacional200 texto/SSE; mint Realtime200
  con no-store; /chat410. Solo imagen sintética256×256 y prompts sin datos privados.
  Credencial interna del Llavero usada en memoria, nunca impresa ni persistida.
- Actualizados README, instrucciones de arquitectura, ct010 y memoria de proyecto.
  No compilar/relanzar app, xcodebuild, TCC, audio ni secretos modificados.
  Despliegue completado, tsk002 permanece abierto: ejecutar fuente nativa actual
  desde Xcode y validar controles variados, ambos monitores, scroll y AirPods.
