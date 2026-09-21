# tsk007 — Home oficial, notch y ajustes nativos

Status: in-progress — Home oficial y migración del menú anterior implementados; F2/F3/F4 restantes abiertos
Current gate (2026-09-21): port nativo de texto/micrófono/atajos/selección autorizado e integrado; QA física de foco, dispositivos, proveedores y compatibilidad AX pendiente. No cierra F4 ni tsk009/010.
Feedback (2026-09-21): el usuario acepta las animaciones («está como queríamos»).
Aceptación estética registrada; no implica cierre de ajustes/texto, matriz de
accesibilidad/monitores o tsk017. Solicita retirar la elección manual de indicación
visual: eliminada en prototipo, Home y menú anterior; preferencias antiguas ignoradas.
Date: 2026-09-19
Type: feature (11 layers)
Complexity: 8/10
Priority: P1 — segunda entrega
Dependencies: contratos implementados de tsk006; evaluación amplia de tsk006 sigue separada
Owner: cce-mobile; write-swift, apple-design; animate para transiciones
Context: ct017, ct012, ct001; contrato común del programa en ct012, sección «Tickets formalizados».

## Revisión de prototipo F3 — 2026-09-21

### Menús desplazados y de una acción — 2026-09-21

- QA usuario: colocación correcta en GPT, oferta lateral en Claude y superpuesta
  al menú de una acción en Outlook. Solicita corregir sin reglas por aplicación.
- SelectedTextReader sustituye las tres columnas por SelectionMenuSearch, un
  detector compartido con fixtures: barrido horizontal con separación máxima40pt
  y alturas separadas16pt, acotado a ventana/franja,512 probes y300ms off-main.
  Antes de terminar recorre ancestros para obtener el contenedor compacto entero,
  no solamente el botón interceptado. Una acción basta; admite wrappers y roles
  Toolbar/Menu/Popover/Group/Unknown, sin leer etiquetas ni nombres de apps.
- No cambia selección/contexto, permisos, audio, diseño ni separación12pt. Campos
  protegidos y texto estático no califican como controles. Cancelación, ciclos,
  cantidad de nodos y spans patológicos están acotados. Sin OCR ni screenshots.
  Geometría de controles cercanos es una heurística conservadora de obstáculos,
  no prueba semántica de que cualquier control sea un menú; no soporte universal.
- SelectionMenuSearchTests ejecuta el detector de producción, no solo layout:
  geometría de captura Claude, acción única Outlook, wrappers con hit al contenedor,
  texto/protegidos, cobertura de franja, cancelación y display negativo. Ejemplos
  solo como fixtures, nunca como condiciones de runtime.
- Primera ejecución completa232 pruebas/27 suites pasa en
  `/private/tmp/cursy-native-regression.zkfcCp`. La consulta a Xcode agotó el tiempo
  antes de enviar Build/Run; no se confirma una nueva app ejecutándose. Pendiente
  Run desde Xcode y QA física de colocación en ambas aplicaciones.
- Validación final232/27 pasa en `/private/tmp/cursy-native-regression.GQj9O1`,
  incluyendo hit directo al contenedor con wrappers; diff-check limpio también
  para los nuevos archivos. Sin commit/push ni modificaciones de la app anfitriona.

### Ajuste de colocación tras QA visual del usuario — 2026-09-21

- Usuario confirma que aparece la oferta; tres capturas muestran barra sobre
  texto, dentro de selección y superpuesta al menú propio. No equivalen a una
  matriz completa de apps/versiones ni atribuyen cada captura a una app distinta.
- Corrección nativa: conservar inicio/fin del gesto (solo memoria y geometría),
  invalidarlo con entrada/scroll/cambio de app; contrastar rango AX con su banda
  vertical. Una geometría lejana/obsoleta o fallback4×4 usa el arrastre únicamente
  como banda de exclusión para colocación, nunca para inferir texto o contexto.
- Espera cancelable140ms para que rango/menú se estabilicen antes de mostrar.
  Detección AX del menú amplía tres puntos a varias alturas/columnas; admite
  Toolbar/Menu y contenedores compactos con dos controles accionables, incluidos
  wrappers. Presupuesto300ms, sin OCR, screenshots, lectura de títulos/contenido,
  nombres de apps ni permisos nuevos. Menús que no expongan AX siguen siendo límite.
- Layout ancla horizontal al menú cercano,12pt de separación por encima; si no
  cabe usa debajo de selección/menú. Misma política para oferta160×32 e input370×46.
  Respeta bordes/pantallas con origen negativo y descarta geometría no finita.
  Diseño, tintes, morph y motores de voz sin cambios. Apple Design guía separación
  de capas y relación espacial con selección/menú, no nuevas animaciones.
- Seis regresiones nuevas: rangos obsoletos, arrastre inverso/multilínea, rango
  válido/gesto ajeno, menú desplazado/solapado, límite de pantalla y toolbar ajena.
  Runner offline:225 pruebas/26 suites pasan en
  `/private/tmp/cursy-native-regression.rgiqaY`; diff-check limpio, sin warnings
  nuevos de selección en módulo offline. UI Xcode registra Build16:18; detalle
  quedó en build anterior y posteriores controles vencieron por timeout. No se
  confirma Run actualizado ni colocación física corregida; requiere Cmd+R/QA.

### Corrección autorizada de selección con menús — 2026-09-21

Usuario: «vamos a resolver en esas apps». Se implementa sobre este ticket, sin
reglas por nombre de aplicación y sin modificar el diseño compacto aprobado.

- SelectedTextReader prepara AXRole al activar una app y solicita la interfaz
  manual solo cuando es escribible y no está activada. SelectionAccessibilityWarmup
  recuerda solicitudes por PID para no reiniciar el debounce remoto; tres intentos
  cancelables, el último después de2.3s si hubo activación pendiente. No espera2.3s
  cuando la primera lectura funciona. No permiso nuevo ni flags forzados.
- SelectionTreeSearch compartido por producción/tests: prioriza área web de
  hit/foco y rango completo;48 ancestros, DFS paginada32,512 nodos/40 niveles y
  presupuesto800ms por intento, fuera de UI. No lee AXValue/documento completo.
  Los límites siguen siendo deliberados; no garantía de compatibilidad universal.
- Lectura vinculada a PID/ventana principal; revalida ventana antes de entregar.
  Ancla mouse solo dentro de esa ventana y solo con texto AX confirmado; cambios
  de ventana/app, entrada, scroll o voz revocan resultados. Campos seguros podados.
- SelectionReadLifecycle agrupa ráfagas AX sin cancelar una lectura vigente por
  foco a menú. Mouse-up/teclado tienen prioridad sobre sondeos AX previos; no hay
  hide/recreación indiscriminada. Presupuesto de menú separado200ms. Sigue siendo
  geometría de menús expuestos, no reconocimiento de cualquier menú dibujado.
- Logs correlacionan generación/PID/intento, límites/timeout y fallos de ventana/
  colocación; nunca incluyen texto, títulos o URL. Sin portapapeles, OCR ni copy.
- Nueva suite SelectedTextSearchTests cubre búsqueda profunda, hermanos tardíos,
  foco a menú, rango completo, bounds ausentes, ventana ajena, campos protegidos,
  ciclos/límites, cancelación, warmup y prioridad de generaciones.
- Primera validación:219 pruebas/26 suites pasan en
  `/private/tmp/cursy-native-regression.m99QjG`; Xcode UI Build succeeded15:58,
  Running Cursy15:59. Warnings preexistentes, no nuevos en archivos de selección.
- CUA confirma texto seleccionado en Comet (documento local sintético) y Claude
  (encabezado visible, sin envío), pero acciones en segundo plano no reproducen
  con fiabilidad activación/evento global. No se confirma barra visible nativa en
  esas pruebas. Se solicita selección manual. GPT/host requiere QA del usuario;
  no se elude restricción de automatización. Un found=true en logs sin correlación
  física de app no se presenta como aceptación de ninguna de las tres.
- Gate de compatibilidad física permanece abierto; no cierre de tsk007.
- Validación final tras prioridad de mouse-up y revalidación independiente:
  219/26 pasan en `/private/tmp/cursy-native-regression.k8Vukz`, diff-check limpio.
  Xcode UI nueva compilación registrada16:07 y Run posterior confirma Running
  Cursy. El panel de detalle seguía mostrando el build exitoso15:58; no atribuir
  ese timestamp al último build. No prueba manual recibida al cerrar esta pasada.

### Investigación de selección con menús — 2026-09-21

Solicitud actual: investigar fallos persistentes en Comet, GPT y Claude; barra
compacta aceptada. Esta pasada es diagnóstico, no modifica ni recompila la app.

Evidencia y alcance:

- CUA nativo devuelve árbol de Comet y una selección no vacía. No se transcribe
  el contenido al workflow. Prueba que existe una vía AX accesible en ese estado,
  no que Cursy use la misma consulta ni que funcione sin inicialización por CUA.
- Claude expone dos áreas web y una jerarquía profunda, con área web enfocada.
  No se ha reproducido una selección con menú en Claude durante este diagnóstico.
  No se envían mensajes, cambian permisos ni manipulan tareas ajenas.
- GPT/host no se vuelve a intentar por la restricción previa de automatización;
  no se usa shell/otra tecnología para sortearla.
- `log show` filtrado exclusivamente a Cursy/SelectedText (15:35–15:36) registra
  peticiones de interfaz accesible seguidas por `found=false`, y varios resultados
  `candidates=48, selectedCandidates=0`. Los logs no identifican la app fuente ni
  correlacionan generaciones: NO permiten asignar cada resultado a Comet/Claude.
  Esos fallos son previos a presentación, no evidencia de z-order del menú.

Hallazgos de código y fuentes primarias:

1. SelectedTextReader:35–38 espera120ms tras activar AXManualAccessibility. El
   código upstream de Electron llama enableScreenReaderCompleteModeAfterDelay y
   aplica debounce2s; nuevas activaciones pueden reiniciar ese plazo. Nuestra
   política no representa pendiente/readiness ni reintenta después de la activación.
   Es una incompatibilidad confirmada con ese comportamiento upstream, no prueba
   de la versión/runtime exacto instalado en cada app.
   https://github.com/electron/electron/blob/main/shell/browser/mac/electron_application.mm
2. Activación Manual es específica de capacidad Electron, no garantía Chromium.
   Chromium también inicializa soporte al consultar AXRole de la aplicación;
   nuestro lector no hace esa consulta de entrada. No resolver forzando flags
   privados indiscriminadamente ni modificando permisos del sistema.
   https://chromium.googlesource.com/chromium/src/+/refs/heads/main/chrome/browser/chrome_browser_application_mac.mm
3. SelectedTextReader:113–199: máximo8 ancestros,48 nodos expandidos,5 niveles,
   primeros16 hijos por nodo y650ms. No prioriza área web propietaria del gesto;
   puede gastar el presupuesto en controles/contenedores. Los48 de logs son
   compatibles con agotamiento, pero aún falta correlación exacta de la ruta.
4. En foco/subárbol pasa pointerAnchor:nil. Si recupera texto pero no bounds,
   descarta el resultado aun con gesto vigente. El contador selectedCandidates
   cuenta solo AXSelectedText, no texto recuperado por rangos/markers; cero no
   prueba ausencia de todos los tipos de texto seleccionado.
5. SelectedTextPanelController:92–105 llama hide/cancela lectura por cada evento
   AX de foco/selección antes de revalidar; un menú puede interrumpir una lectura
   válida. Esto está demostrado como posibilidad por código, no aún como causa
   específica de las tres apps. Falta distinguir cambio de foco y selección vacía.
6. Detección de menú solo ocurre tras encontrar texto y comparte el presupuesto
   de650ms. Tres probes geométricos no son detección universal de menús. Separar
   este problema de lectura/foco antes de cambiar nivel de ventana.

Corrección recomendada (no implementada en esta investigación):

- Diagnóstico correlacionado por gesto: estado de activación, roles y ruta,
  límites/timeout/cancelación, texto-presente, bounds-presentes, razón de no mostrar;
  sin texto, títulos, URL ni documento completo.
- Preparar interfaz AX al entrar a la app por capacidades; estado pendiente por
  proceso, sin reactivar en cada evento. Leer readiness/reintentar de forma acotada
  sin bloquear UI ni añadir2s a cada selección.
- Vincular gesto al documento/área web y mantenerlo frente a cambios de foco del
  menú dentro de la misma ventana. Búsqueda estructural priorizada, paginada y
  acotada; contexto solo del rango seleccionado, no recorrido de contenido.
- Separar evidencia de texto y colocación; ancla del gesto válida solo en la misma
  ventana/app, caducidad e invalidaciones explícitas. No adivinar contexto.
- Revalidar antes de retirar; invalidar inmediatamente nueva entrada, scroll,
  cambio de app/ventana, cancelación o selección confirmada vacía. Evitar barra vieja.
- Tests del lector/coordinador con backend AX simulado: árbol profundo, siblings,
  inicialización diferida2s, foco a menú, bounds ausentes, cancelación y campo seguro;
  luego matriz física Comet/Claude/GPT/manual y editor nativo de control. Los208
  tests previos no cubrían este contrato y no prueban compatibilidad universal.

### Barra compacta y compatibilidad de selección — seguimiento

- Usuario confirma que la oferta funciona en otra app, pero sigue ausente en
  GPT. No hay evidencia de un bloqueo de seguridad ni confirmación de su causa.
- Oferta nativa pasa de204×44 a160×32 (96×32 en inglés), fuente12 y sin logo;
  prototipo refleja160×32. Editor, contexto aislado y acciones se conservan.
- Reader solicita `AXManualAccessibility=true` solo al proceso activo, con
  permiso AX previo, atributo escribible y estado aún no activado. Espera120ms
  cancelables únicamente cuando la activación tuvo éxito; IPC sigue fuera de UI.
  Interfaz documentada: https://www.electronjs.org/docs/latest/tutorial/accessibility
  No usa nombres de apps ni fuerza AXEnhancedUserInterface. No clipboard/OCR,
  permisos nuevos, documento completo ni datos de contexto enviados en esta prueba.
- Corregida pérdida del punto mouse-up cuando AX notificaba la selección después:
  anclaje válido máximo1s, mismo PID, invalidado por nuevo input/scroll/cambio de app.
  Esa ruta no inventa texto ni extents; requiere selección AX confirmada.
- Cinco regresiones nuevas (capacidad/estado/error de activación y anclaje tardío).
  `bash cursy-app/scripts/test-native-regressions.sh`:208/25 pasan en
  `/private/tmp/cursy-native-regression.yAKfwI`; Node28/28; diff-check limpio.
  Xcode UI Build succeeded15:09 (warnings existentes), Run confirmado.
  Navegador: barra sin logo arriba del menú sintético y click abre input enfocado.
- Caso físico GPT pendiente: la herramienta de automatización no permite operar
  la app host. No se intenta eludir esa restricción ni afirmar soporte universal;
  el usuario debe repetir selección en la nueva app ejecutándose.

### Corrección de selección y prueba de micrófono — QA del usuario

- Reporte: selección en ChatGPT no ofrece entrada contextual ANTES del bloqueo;
  probar micrófono integrado congela la app. Son regresiones independientes.
  Consola: AudioUnit -10877 (elemento inválido), CoreAudio1852797029 (`nope`).
  No hay muestra del hang original; la sesión anterior terminó con SIGKILL.
- Ruta de audio: un motor nuevo conserva el predeterminado sin asignar su HAL;
  elegir explícitamente ese mismo dispositivo tampoco lo reasigna. Otros UID
  usan AUAudioUnit, sin cambiar la entrada global de macOS. Legacy reconstruye
  el motor para no conservar una ruta personalizada al volver al predeterminado.
- Prueba local: grafo/tap/start/stop en actor separado, watchdog de entrada5s,
  confirmación por muestras reales, cierre asíncrono con propiedad exclusiva.
  PTT mientras cierra pide reintento, nunca abre un segundo capturador. Cancelar
  permiso/inicio y callbacks tardíos están invalidados por identidad.
- Selección: observador AX más eventos globales; búsqueda acotada desde hit/foco
  y sus ancestros/subárbol, rangos nativos y text-marker ranges web. IPC de lectura
  fuera de MainActor, timeout por llamada35ms y presupuesto650ms. App/turno/evento
  nuevos descartan resultados tardíos. Solo atributos de selección/estructura;
  no texto completo, portapapeles, OCR, capturas ni ramas por nombre de app.
- Si hay texto confirmado y faltan bounds, el ratón aporta un ancla de colocación
  de4pt, NO un supuesto rectángulo del texto; por teclado no se inventa geometría.
  Menús expuestos siguen evitando superposición. Apps sin selección accesible o
  campos protegidos no pueden prometer compatibilidad universal.
- Diagnóstico registra presencia/cantidad de candidatos, nunca contenido.
  Verificación física sigue abierta: herramienta no permite controlar el host
  ChatGPT; intentos automatizados en TextEdit no verificaron aparición de oferta.
  No se afirma corregido ese escenario en vivo ni prueba física de audio.
- Validación:203 tests/25 suites pasan en
  `/private/tmp/cursy-native-regression.veQZvJ`; rutas y ciclo de vida con capturador
  simulado, geometría/alcance de selección y regresiones existentes. Las primeras
  esperas fijas de40ms produjeron carreras en tests; reemplazadas por espera
  acotada del estado real. No son pruebas de hardware. Xcode compila la app con
  su aislamiento MainActor real; el contrato de captura exige actor y el lector
  AX mantiene helpers explícitamente no aislados. No commit/push/deploy.
- Revalidación final tras guard previo al permiso:203/25 pasan en
  `/private/tmp/cursy-native-regression.tH2Xes`; diff check limpio. Xcode UI
  Run final muestra `Cursy Running Cursy` y monitores instalados con eventos/AX
  true. Se deja la app abierta; no se activó micrófono ni se envió contexto.

### Port nativo autorizado y superficies neutras

- Petición: retirar strokes decorativos de color y llevar los flujos aprobados a
  la app. Se conservan colores en iconos/cursor/figuras, no en input, etiquetas,
  foco de controles ni borde de muestras. Prototipo y caption nativo actualizados.
- HomeComposer: foco explícito, Enter/Shift+Enter, IME, borradores por chat, stop,
  respuesta progresiva con VisionAPI existente; texto nunca captura pantalla/audio.
- SelectedTextPanelController: selección AX exacta y bounds tras mouse-up/teclado;
  sin portapapeles, OCR, screenshot ni documento completo. Omite campos seguros,
  ausencia de bounds y texto >6000 UTF16. Sondeo acotado de menús/toolbars/grupos
  cercanos; arriba/abajo u ocultar, sin reglas por app. No detecta menús que no
  expongan geometría accesible: compatibilidad real sigue como gate.
- Oferta→editor370×46/radio12: morph250ms del material, contenido sin escala,
  teclado directo/Reduce Motion sin viaje; Escape/cambio externo cancela.
  Envío/mic crea chat nuevo con SelectedTextContext, sin historial previo/pantalla.
- Voz: saludo output-only por Realtime actual; reproducción completada inicia
  captura, no timer simulado. Notificación compacta bajo notch/retirada400ms.
  Enviar voz con botón/PTT; ruta de selección no captura pantalla/gestos.
- HomeMicrophone: UID CoreAudio aplicado a recorder Realtime/legacy; prueba local
  máxima15s sin subir/grabar/reproducir audio. Desconectado requiere elegir entrada;
  no fallback silencioso. Talk/cierre/navegación/cambio de ruta detienen la prueba.
- Ajustes Voz (Marin/velocidad actuales, lectura opcional), Micrófono, Atajos
  (grabador/presets/reset/reservados, liberación por tecla/modificador), aviso
  de escucha opcional. No promete detectar todos los conflictos globales.
- Validación intermedia:28 Node y191 Swift/24 suites; Xcode UI Build Succeeded13:01,
  Run sin activar micrófono/proveedor. Últimos ajustes se vuelven a compilar.
  Navegador confirma input neutro sobre menú simulado. La automatización nativa
  no logró abrir Home/selección; no se afirma QA física del foco o morph.
- Guías múltiples/avance visual/regiones genéricas siguen tsk009/010/tsk005.
  No se trasladan controles de simulación a producción. Modelo/Worker sin cambios.
- Validación final:191 Swift/24 suites en `/private/tmp/cursy-native-regression.nnGOSQ`,
  28 Node; `git diff --check` limpio. Xcode UI Build Succeeded13:15 y Running Cursy
  13:16. App dejada abierta para QA del usuario, sin enviar contenido ni activar
  audio real. Reservas de compatibilidad/foco/dispositivos siguen abiertas.

### Entrada desde selección — ampliación de diseño del mismo ticket

- Morph solicitado botón→input: material compartido FLIP250ms ease-in-out,
  texto saliente100ms/entrante150ms sin escala; foco inmediato. Teclado directo,
  Reduce Motion fade; cerrar/reseleccionar elimina capas y animaciones. Si el
  anclaje cambia de lado por obstáculos, fundido sin atravesar el menú.28 tests
  Node; navegador verifica frame intermedio, campo final, Escape y teclado.

- Refinamiento posterior del usuario: input en una línea370×46px/radio12px;
  aviso340px (89px en escucha) con iconosSF y controles de simulación fuera.
  Slot recortado bajo notch44/52px; movimiento/opacidad400ms ease simétricos,
  apertura tras activación del notch, teclado sin viaje y Reduce Motion fade.
  Cancelar quita interacción/semántica inmediatamente mientras anima la salida.
- Menú externo simulado opcional: medir rectángulos ocupados, preferir12px encima
  del menú, debajo del grupo si falta altura, ocultar si no hay espacio. Función
  genérica sin reglas por app; no detección real de ventanas/menús ni IA añadida.
  26 testsNode, sintaxis/diff y navegador (menú/no menú, input, saludo/escucha,
  salida intermedia); contexto aislado conserva el fragmento completo.

- Usuario solicita seleccionar texto → «Preguntarle a Cursy» → input contextual
  con micrófono; en voz, Cursy inicia antes de escuchar. Solo prototipo autorizado.
- `selection-model.js` conserva copia exacta e inmutable del fragmento y token de
  saludo; `selection.js` conecta el documento de muestra con popover/input/Home
  y notch. Cada entrada crea un chat nuevo sin historial previo ni pantalla.
  Un borrador no enviado permanece borrador al elegir voz. `selection.css` usa
  tintes/SF Symbols y entrada breve200ms; teclado inmediato/movimiento reducido.
- Saludo como subtítulo explícitamente simulado, seguido a los3s por escucha
  simulada; no micrófono ni síntesis. Terminar/Escape/cambio de modo invalida el
  timer. Abrir el notch lleva al mismo chat con el fragmento visible. No TCC/AX,
  captura global, red ni cambios en Swift; no automatización de otras apps.
- 22 pruebas Node y sintaxis/diff limpias. Navegador verifica selección real,
  input, envío a chat aislado, saludo/escucha, cancelación temprana y apertura
  desde notch; consola sin errores. Corregido conflicto de flechas con picker.
- Para implementar nativamente hará falta diseñar extracción AX acotada,
  compatibilidad de apps, selección no disponible, foco/destino y finalización
  real del audio antes de escuchar. No equivale a permiso para observar todo
  el texto/pantalla ni a implementación de tsk009/010.

- Petición: continuar texto, selección/prueba de micrófono y ajustes restantes
  primero como prototipo. CCE Frontend + Emil Design Engineering; sin tocar Swift.
- Se amplía `prototypes/notch-voice/` con `home-input-model.js`,
  `home-input-model.test.cjs`, `home-input.js` y `home-input.css`; integración en
  index.html/workspace.js y documentación en README. Reutiliza notch, tintes,
  símbolos SF y sidebar aceptados; no nuevas animaciones ni dependencias.
- Compositor con Enter/Shift+Enter, borradores por chat en memoria, escape de
  contenido/títulos, respuesta de ejemplo y cancelación por revisión/token.
  No objetivo manual, selección de herramienta ni captura adjunta al escribir.
- Ajustes Voz/Micrófono/Atajos con lectura automática de muestra, dispositivos
  ficticios, medidor controlable, estados sin permiso/desconectado y captura de
  atajo con Escape/restablecer. La prueba cesa al salir/cambiar dispositivo/voz.
  Voz/velocidad no se ofrecen como selectores sin capacidad del proveedor.
- Privacidad y Ayuda mantienen el gradiente compartido. Todo es simulación
  explícita: sin getUserMedia, permisos, red, persistencia ni atajos del sistema.
- Validación: 17 pruebas Node (4 nuevas de estado +13 geometría/movimiento),
  sintaxis y diff limpios; navegador verifica respuesta, borradores multilínea,
  chat nuevo, prueba y fallos de micrófono, captura/cancelación/reset de atajo,
  toggle de voz y layout. Sin errores de consola observados.
- Pendiente: aceptación de diseño; implementación nativa del compositor con foco
  explícito y contexto de destino, coordinador de audio, dispositivos reales,
  permisos y conflictos de atajo. No se cierra tsk007 ni se afirma QA nativa.

Plan refinado e inicio autorizado el 2026-09-19 («incorpora y vamos a comenzar»). Se mantiene el mismo ticket. Archivos Swift bajo cursy-app/Cursy/, backend bajo cursy-app/worker/src/. Presupuestos son objetivos iniciales a medir, no resultados. Conservar macOS14.2, idioma Swift actual y cambios del usuario; no migrar toolchain en este ticket.

## 1. Contexto estratégico

Dar una superficie reconocible a conversación/estados/ajustes sin sustituir el cursor menta ni convertir cualquier petición en un agente.

ct017 se incorpora como diseño de presentación, no como migración de modelos:
conservar Realtime/Astra y no añadir un router profundo general.

## 2. Necesidades y experiencia

Home accesible desde menú/atajo; notch opcional y cápsula superior en pantalla sin notch. Ventana desacoplable. Hablar no roba foco; escribir sí activa el compositor por acción expresa.

F1 se abre desde «Probar Home · Beta» o al acercar el ratón al notch real
(dwell 180 ms), según refinamiento autorizado del usuario. Se oculta al salir
800 ms si está inactivo; ratón dentro, voz activa, arrastre y VoiceOver lo retienen.
Separado no se autooculta. X/Escape requieren salir y volver para reabrir por hover.
Refinamiento aprobado 2026-09-20: PTT muestra isla compacta automáticamente;
cierre explícito suprime reapertura durante ese turno. QA física pendiente.

## 3. Requisitos y no objetivos

Estados compacto/expandido/desacoplado, compositor de texto y voz usando sesión existente, preferencias organizadas General/Voz/Micrófono/Atajos/Cursor/Privacidad. Voz/velocidad solo si el proveedor vigente las soporta, preview explícito; selector de micrófono y medidor, idioma y atajos configurables con conflictos. Ocultar cursor y preferencias de avisos. Persistencia múltiple, dictado universal, agentes y rutinas aún no operativos: no botones que finjan esas capacidades.

F1 muestra actividad real e historial acotado actual, sin compositor ficticio;
Talk conserva el atajo existente. El refinamiento explícito del 2026-09-20 incorpora
sidebar/ajustes General, Cursor y Privacidad dentro de Home; resto de F2/F3 pendiente.

## 4. Sistema existente y evidencia

CursyApp.swift tiene Settings vacío; panel existente contiene preferencias y estado. Capturas 4,6–12,15 describen superficies, no APIs. Worker y cliente fijan marin: cambiar un picker local no es suficiente.

ConversationSession ya publica turnos e intercambios y CompanionManager expone
voiceState. Captura excluye todas las ventanas del bundle: conservar esa regla.

## 5. Arquitectura e impacto de archivos

Reutilizar CursyApp.swift, CompanionPanelView.swift, MenuBarPanelManager.swift, DesignSystem.swift y CursyLanguage.swift. Nuevos HomePanelController/HomeView/SettingsStore/InteractionModeCoordinator/AudioInputCoordinator propuestos. Este último arbitra Talk, prueba de micrófono y futuro Dictate; no dos motores simultáneos. Añadir configuración tipada validada a cliente/broker donde proceda.

F1: HomePresentation.swift (política/geometry/proyección), HomeView.swift (vista
observadora), HomePanelController.swift (un único panel sin activación), entrada
en CompanionPanelView/MenuBarPanelManager y HomePresentationTests. No modificar
CompanionManager ni crear otro cliente de voz para esta superficie.

## 6. Datos, contratos, migración y ciclo de vida

HomePresentation enum y InputMode enum; preferencias v1 migran claves existentes sin borrar sus valores. Geometría por display con fallback al desconectar. VoicePreference por capacidad; AudioInputPreference por identificador estable y fallback informado. Capturar contexto de app antes de abrir Home; no enviar captura de Home con texto por defecto. Historial visual sigue solo en memoria hasta tsk008.

Separar HomePresentation de HomeActivity. Derivar actividad/historial del manager
vigente, no almacenar eventos o mensajes duplicados. Así un reset se refleja sin
replay propio. F1 sin persistencia nueva; la ventana no puede ser key ni main,
por lo que no cambia la app externa activa. F3 debe diseñar captura de destino
antes de introducir un compositor que sí tome foco. Fallo/cancelación se proyectan
desde el turno; no mantener «pensando» tras terminalidad.

## 7. Seguridad y privacidad

Permiso TCC no autoriza envío; indicador de compartir separado. La prueba de micrófono no sube audio. No prometer invisibilidad frente a cualquier grabador: preferencia de visibilidad externa solo tras ensayo en versiones soportadas; captura propia siempre excluye Cursy.

Abrir/cambiar presentación nunca captura ni inicia red/audio. Mensajes solo en
memoria; prototipo sin acceso a credenciales ni ejecución de comandos del modelo.

## 8. Fiabilidad, rendimiento y observabilidad

Home caliente p95 ≤150 ms hasta primer contenido local; ninguna espera remota para abrirlo. Ajustes no reconstruyen audio mientras captura sin transición serializada. Registrar errores de dispositivo, no contenido. Foco regresa al destino correcto y Escape interrumpe transición.

F1 refinado por petición del usuario: apertura/cierre con máscara desde el borde
superior en 150 ms; expansión/compactación nativa y fundido de 150 ms con Reduce
Motion. Sin polling ni animación por cambio de estado de voz. El
refinamiento autorizado añade feedback de voz real con Reduce Motion, sin bucle.
Un único panel reutilizado; observadores retirados al terminar; geometría
con origen negativo y límites visibleFrame/safeArea. Latencia física pendiente.

## 9. Dependencias e integración

Depende de tsk006 por integración de modos/estados; reutiliza tsk003. Conservar macOS14.2 y materiales con availability. NSScreen safe areas/visibleFrame orientan layout, no tamaños de notch hardcoded. Confirmar contratos oficiales de voz al dispatch; valores no soportados se rechazan explícitamente.

El usuario acepta experiencia multiescena y autoriza iniciar Home; no se declara
cerrado tsk006 ni su evaluación. F1 no altera contratos externos volátiles.

## 10. Fases, pruebas, despliegue y rollback

F1 prototipo con estado real; F2 shell y preferencias; F3 rutas de texto/voz y micrófono; F4 compatibilidad. Probar notch/no notch, fullscreen/Spaces, monitor retirado, VoiceOver, teclado, Reduce Motion/Transparency, AirPods cambio de ruta, conflicto de atajos, preferencia previa. Abrir/cerrar 50 veces sin duplicar ventanas/taps. Flag vuelve al menú original sin perder preferencias.

- F1: CCE Mobile + Write Swift + Apple Design; prueba offline de estados/frames
  y compilación nativa, luego gate manual de diseño. Cerrar Home devuelve al flujo
  original; se añade hover expresamente autorizado, sin reemplazar el menú.
- F2: mismos especialistas; shell/preferencias persistentes tras aceptar diseño.
- F3: CCE Mobile; añadir AI Engineer/OpenAI Docs solo al tocar contratos de voz.
- F4: QA física, accesibilidad y mediciones. Animate solo al incorporar movimiento.
Sin agentes paralelos. No desplegar Worker por este prototipo.

## 11. Gates, métricas, documentación y responsable

Gate manual de diseño y uso con ambos monitores; cero pérdida de foco involuntaria, cero doble micrófono y regresiones verdes. Documentar SETTINGS_QA y capacidades no disponibles. Prototipo debe confirmar ubicación predeterminada y activación por clic/atajo frente a hover; no copiar assets de HeyClicky ni cambiar marca.

Incluir onboarding breve y repetible de Talk/Texto/contexto espacial, con prueba
de micrófono local y permisos en el momento necesario. No exigir entrevista
personal ni mostrar Dictate/Agentes como funcionales antes de sus tickets.
Cambiar la apariencia nunca altera el tamaño óptico aceptado del cursor.

Decisiones abiertas del gate F1: validar ancho/altura, anclaje superior frente a
ventana separada y sensibilidad del hover ya autorizado. No bloquear la construcción con estas
preferencias: presentarlas mediante controles de prueba reversibles. No continuar
F2/F3 antes de aprobación del diseño. Riesgos principales: foco, ocultación por
notch, datos duplicados y audio doble; mitigar con proyección, panel no-key y
pruebas del flujo existente. Precisión de modelos queda fuera de este incremento.

Validación común: Swift Testing para contratos; Xcode para UI/build completo, nunca xcodebuild por terminal. Aplicar regresiones de sesiones/visualización y Worker cuando se toquen sus rutas. Pruebas reales con pantallas/datos privados requieren autorización específica. Despliegue, cuentas y compras no autorizados por este plan. Registrar evidencia por fase; no cerrar antes de sus gates.

Dispatch: `$cce-dispatch execute tsk007-home-notch-settings`

## Promoción a Home oficial — 2026-09-21

Refinamiento posterior del usuario: no desea introducir un objetivo manual.
Retirados el campo de General y del código legacy, buffer y callbacks de edición.
Home vuelve a ser non-key/non-main; se conserva la protección de setup/autohide.
La intención se interpreta desde petición e historial acotado existentes; no se
añade extracción remota extra, persistencia inferida ni autorización implícita.
Los contratos internos opcionales de objetivo se conservan por compatibilidad,
sin borrar sesiones. Esto sustituye el editor descrito en el registro histórico
de promoción de abajo. Validación: 184 pruebas/22 suites pasan en
`/private/tmp/cursy-native-regression.3fiQqA`; Xcode UI Build Succeeded11:21 y
`git diff --check` limpio. Sin ejecución de la app ni inferencia remota de prueba.

Esta decisión explícita sustituye las referencias históricas a Home opcional,
entrada «Probar Home · Beta», rollback de menú y panel exclusivamente no-key.
No declara terminadas las fases restantes del ticket.

- MenuBarPanelManager conserva únicamente status item y un HomePanelController:
  clic abre/expande/cierra Home; inicio con configuración pendiente abre Privacidad.
  CompanionPanelView queda sin instanciar, sin ruta de acceso ni fallback de ajustes.
- General incorpora objetivo temporal del chat con buffer de edición separado
  del valor normalizado y límite de 2.000 caracteres. Nueva conversación sigue en +.
  Privacidad incorpora micrófono/accesibilidad/grabación/contenido de pantalla y
  sus acciones existentes. Ayuda añade inicio/replay, comentarios y salir.
- Sin cambios de defaults, modelos o consentimiento. No se reinstaura selector
  de herramienta visual. Todos los pictogramas nuevos son SF Symbols; misma
  superficie degradada, sin panel opaco adicional.
- Home admite key por interacción explícita con ajustes; orderFrontRegardless
  conserva apertura pasiva sin makeKey. Auto-hide se retiene durante edición
  activa o configuración pendiente; cerrar limpia foco. PTT deja de emitir el
  cierre del menú retirado para no suprimir la isla automática. Introducción sí
  cierra Home por la notificación existente.
- CCE Mobile + Write Swift + Apple Design guiaron reutilización del estado,
  permisos explícitos y separación de hover/foco, sin tocar animación aceptada.
- Validación final: 184 pruebas/22 suites pasan en
  `/private/tmp/cursy-native-regression.sN2SNT`; Xcode UI Build Succeeded11:16
  tras ajuste final del buffer. Build inicial11:12 tenía27 warnings existentes.
  `git diff --check` limpio; no construcción de CompanionPanelView en fuentes.
  No Run, reset TCC, Worker, commit ni push. Edición/hover/permisos en equipo real
  quedan como QA manual; las pruebas de política no acreditan el foco físico.
- Archivos: MenuBarPanelManager, HomePanelController, HomePresentation,
  HomeHoverPolicy, HomeView, HomeSettingsView, CompanionManager (solo cierre PTT),
  HomeHoverPolicyTests, RenderHomePrototype (firma), SETTINGS_QA y AGENTS.
- Siguiente alcance: completar compositor de texto, selección/prueba local de
  micrófono y ajustes restantes; tsk008 añade persistencia opt-in; tsk009/010
  agregan guías y verificación real. tsk005 mantiene contrato de regiones pendiente.

## Ejecución F1 — 2026-09-19

- CCE Feature incorpora ct017 en las 11 capas y conserva ID; CCE Dispatch mueve
  el mismo registro a in-progress. CCE Mobile + Write Swift mantienen proyección
  de valores, propiedad MainActor y un solo panel. Apple Design orienta activación
  explícita, feedback real, preservación de foco y presentación reversible.
  No nuevas animaciones ni agentes paralelos.
- Añadidos HomePresentation.swift, HomePanelController.swift y HomeView.swift;
  entrada opt-in en CompanionPanelView y propiedad lazy en MenuBarPanelManager.
  Modelos, CompanionManager, captura, audio, Worker y cursor no se modifican.
  Panel compacto/expandido debajo de safe area (no cubre notch físico), separable
  y arrastrable; cambiar pantallas reajusta límites. Cerrar no termina la sesión.
  Esc se observa sin consumirlo ni sustituir la cancelación de Talk existente.
- Estado e intercambios salen del manager vigente, sin cola de eventos ni memoria
  secundaria. Dedupe por turnID y reset inmediato. Error/cancelación tienen
  prioridad sobre una fase transitoria antigua. Ninguna llamada al abrir Home.
  Ajustes vuelve al panel original, sin controles ficticios de funciones futuras.
- F1 es lectura y controles por ratón/VoiceOver pendiente de QA; no compositor,
  foco de texto ni navegación Tab completa. El indicador de pantalla refleja
  habilitación, no afirma grabación continua. Historial acotado no persistente.
- HomePresentationTests: ocho tests (con casos parametrizados) de historial,
  reset/late event, terminalidad, permisos, notch/orígenes negativos y clamping.
  `bash cursy-app/scripts/test-native-regressions.sh`: 127 tests/15 suites pasan
  (0.913 s), módulo nativo compila, artefactos
  `/private/tmp/cursy-native-regression.zcaNV4/`. Sin warnings en archivos Home;
  warnings preexistentes preservados. Sandbox inicial bloqueó macros; runner
  autorizado fuera del sandbox. Se corrigió una aserción mutante antes del verde.
- RenderHomePrototype.swift genera light/dark con mensajes sintéticos. Se cambió
  ImageRenderer por hosting AppKit en ventana no ordenada: ImageRenderer omitía
  el ScrollView, por lo que esa primera imagen no fue aceptada como revisión.
  La revisión estática no equivale a ejecutar la app firmada ni validar foco real.
- Manual gate `scripts/SETTINGS_QA.md`: aprobar dimensiones/anclaje, probar con
  ambos monitores y confirmar que no roba foco. F2/F3 en pausa en ese gate;
  métricas físicas p95, accesibilidad completa y 50 aperturas siguen pendientes.
  Sin Xcodebuild, despliegue, claves, contenido privado o llamadas pagadas.

Siguiente dispatch, tras aceptar F1: `$cce-dispatch execute tsk007-home-notch-settings`.

## Refinamiento F1 — feedback «Te escucho» — 2026-09-19

- Petición directa autorizada: ondas de voz y luz difuminada desde abajo, dentro
  de la cápsula existente. Se mantiene tsk007; no nuevo ticket ni avance F2/F3.
- HomeView pasa currentAudioPowerLevel al componente HomeVoiceFeedback: cinco
  barras de volumen (no espectro FFT), piso de ruido 0.025 igual al cursor,
  valores finitos acotados y actividad únicamente durante listening. El medidor
  existente cubre Realtime y fallback; no se modifica su ganancia ni captura.
- CCE Mobile/Write Swift mantienen la proyección sin estado de audio adicional.
  Apple Design/Animate orientan feedback causal con transform/opacity suavizados
  en 150 ms, sin temporizador, oscilación artificial, bounce ni apertura animada.
  Luz menta/azul/violeta bajo el contenido, contenida en el header; se conserva
  tamaño, botones, legibilidad, foco y cursor. No cambios de modelos o Worker.
- Reduce Motion conserva geometría estática y permite feedback de opacidad;
  Reduce Transparency usa fondo opaco, sin glow. Adornos click-through y ocultos
  a VoiceOver: se conserva el estado textual accesible.
- Cuatro tests nuevos cubren ruido/silencio, NaN/infinito, saturación, respuesta
  proporcional, valores antiguos fuera de listening y geometría reducida.
  Render offline ahora compara silencio y voz sintética 0.75 en ambas apariencias;
  no usa capturas privadas, micrófono, red ni credenciales.
- Gate pendiente: ejecutar desde Xcode, probar hablar/silencio/cancelación y
  preferencias de accesibilidad; renders y tests no equivalen a QA física.
- Validación final: `bash cursy-app/scripts/test-native-regressions.sh`, módulo
  compilado y 131 tests/16 suites verdes (0.912 s). Artefactos finales en
  `/private/tmp/cursy-native-regression.dGs0Ux/`; revisión visual light/dark de
  home-light.png y home-dark.png. Se sustituyeron manchas con blur por gradientes
  elípticos transparentes en los extremos para eliminar bandas y cortes visibles.
  `git diff --check` limpio; warnings previos preservados, sin cambios de build
  firmado ni ejecución de Xcodebuild. El gate de diseño F1 sigue abierto.

## Reparación de build Xcode — 2026-09-19

- Usuario reporta 18 errores. Inspección del Issue Navigator confirma que todos
  los visibles corresponden a miembros CGRect sin import CoreGraphics en
  HomePresentation.swift. Se añade el import explícito, sin cambiar geometría.
- La validación offline omitía SWIFT_UPCOMING_FEATURE_MEMBER_IMPORT_VISIBILITY
  (activado en el proyecto). Al habilitar el equivalente del compilador en el
  runner se reproduce otro fallo: @Published/ObservableObject requieren Combine
  en HomeView.swift. Corregido explícitamente; no debilitar ajustes del proyecto.
- test-native-regressions.sh aplica MemberImportVisibility a app y tests; README
  registra la brecha y los límites del runner, que no reemplaza el build firmado.
  La regla detectó también CoreGraphics ausente en HomePresentationTests y
  ScreenWindowGroundingTests; se añaden solo los imports, sin modificar aserciones.
- Verificación real mediante Xcode UI, Command+B: «Cursy Build Succeeded»,
  3:38 p. m.; Issue Navigator filtrado por errores queda vacío. Sin Run, cambios
  de permisos, xcodebuild, despliegue o acceso a credenciales. Gate F1 sigue abierto.
- Runner estricto final: 131 tests/16 suites pasan (0.926 s), artefactos en
  `/private/tmp/cursy-native-regression.LbMwhC/`. `bash -n` y `git diff --check`
  pasan. Esta evidencia sustituye la confianza anterior en imports implícitos;
  las pruebas de UI/voz continúan siendo manuales.

## Refinamiento F1 — unión al notch y superficie negra — 2026-09-19

- Usuario aporta fotos de Clicky y del Home actual, y referencia de esfera negra
  transparente (sin destello). Se inspeccionaron ambos HEIC mediante copias PNG
  temporales locales; no se enviaron fotos a proveedores. Son referencias de UX,
  no evidencia de la arquitectura interna de Clicky ni de una versión oficial de Siri.
- CCE Mobile/Write Swift mantienen la sesión/audio/modelos; Apple Design/Animate
  guían el anclaje espacial y movimiento breve. Investigación primaria: Apple
  NSScreen.safeAreaInsets y auxiliaryTopLeftArea/auxiliaryTopRightArea, contrastada
  con NSScreen.h del SDK instalado. No dependencia nueva ni tamaño de cámara fijo.
  Fuente: https://developer.apple.com/documentation/appkit/nsscreen/safeareainsets
- HomePanelLayout obtiene el hueco de cámara entre las áreas auxiliares: panel
  compacto y conversación alineados con su centro y pegados a su borde inferior,
  sin invadir la cámara/menú. Sin notch conserva margen superior de 12 puntos;
  separado conserva arrastre y reanclaje en el monitor alcanzado. Tamaños con
  franja de desvanecimiento: 320×70 y 620×506, acotados al espacio disponible.
- HomeReveal abre/cierra mediante máscara superior y opacidad, sin escalar letras.
  Duración 250 ms ease-out; NSPanel anima cambios de tamaño/posición manuales.
  Identidad de transición invalida aperturas/cierres tardíos. Cierre deja de
  interceptar mouse inmediatamente. Cambios de monitor no animan el reposicionado.
  Reduce Motion: fundido de 150 ms, sin máscara móvil ni resize animado.
- Home negro arriba, ligeramente translúcido debajo y transparente en el borde
  inferior vacío; texto claro y burbujas oscuras. No flare, borde claro ni sombra
  nativa que delaten la unión. Conserva las ondas/glow suave solo al escuchar.
  Reduce Transparency usa negro opaco y elimina el glow/desvanecimiento.
- Validación: runner estricto, 134 tests/16 suites verdes (0.890 s), incluidos
  notch real/origen negativo, fallback externo y límites de máscara. Xcode UI
  Command+B: «Cursy Build Succeeded», 4:00 p. m., sin Run. Renders light/dark
  revisados con mensajes y cámara sintéticos en
  `/private/tmp/cursy-native-regression.JKgGdq/`; git diff --check limpio.
- Sigue pendiente aceptación física: unión exacta, animación rápida/reversible,
  foco, Escape/reabrir, modo separado, dos monitores y accesibilidad (ver QA).
  No se declara aceptado F1 ni se inicia F2/F3 con estos checks offline.

## Refinamiento F1 — vidrio con densidad degradada — 2026-09-19

- Nueva referencia aclara que el negro debe transformarse en vidrio en toda la
  superficie, no desaparecer solo en una franja inferior. Sustituye ese detalle
  del refinamiento anterior; conserva dimensiones, anclaje, apertura y voz.
- Investigación en fuentes primarias Apple: glassEffect(_:in:), Glass.clear,
  NSVisualEffectView.BlendingMode.behindWindow y Materials HIG; availability
  contrastada con SDK. Reutiliza el patrón glassEffect(.clear) que ya tiene el
  cursor, sin alterar su escala/animación. HomeGlassSurface es independiente.
  https://developer.apple.com/documentation/swiftui/view/glasseffect(_:in:)
  https://developer.apple.com/documentation/appkit/nsvisualeffectview/blendingmode-swift.enum/behindwindow
- macOS 26+: Liquid Glass nativo claro; 14/15: NSVisualEffectView, hudWindow,
  behindWindow, active y darkAqua. Sin APIs privadas, shaders, muestreo de pantalla,
  captura adicional o timers. No promesa de óptica idéntica entre versiones.
- Encima del material: negro 1/0.98/0.78/0.42/0.18 a lo largo del alto; parte
  superior negra une cámara y Home. Se elimina la máscara de franja transparente.
  Borde inferior sutil y estático, sin flare añadido. Mensajes, avisos, bienvenida
  y footer tienen protección local de contraste; secundarios blancos al 85%.
- Apple Design orienta material real + densidad y legibilidad; CCE Mobile/Write
  Swift mantienen APIs públicas y availability. Reduce Transparency o Increase
  Contrast omiten vidrio y usan negro opaco; política cubierta con tres tests.
- Validación final: 137 tests/17 suites (1.020 s), compilación nativa estricta y
  Xcode UI Command+B «Build Succeeded» 16:07. Renders light/dark con fondos de
  color sintéticos revisados: `/private/tmp/cursy-native-regression.yBrd7J/`.
  El cache bitmap comprueba composición/gradiente, NO óptica del compositor en
  vivo. Faltan prueba física del vidrio/reflejo, accesibilidad y macOS antiguos.
  Sin Run, cambios de modelos/Worker, despliegue ni modificación de originales.

## Refinamiento F1 — hover, silueta y cabecera — 2026-09-19

- Petición explícita sustituye la decisión inicial de apertura solo manual:
  abrir al acercar el puntero al notch y ocultar al dejar de utilizarlo.
  Referencia IMG_2256 inspeccionada mediante copia PNG temporal; originales intactos.
- CCE Mobile + Write Swift mantienen propietario único, APIs públicas y política
  aislada; Apple Design + Animate orientan dwell/cancelación, máscara sin escalar
  texto, Reduce Motion y unión al alojamiento real, sin librerías ni nuevos assets.
- HomeHoverPolicy/HomePanelController: monitores pasivos locales/globales arrancan
  con MenuBarPanelManager; panel creado bajo demanda. Dwell 180 ms, gracia de salida
  800 ms y reveal 150 ms. Movimientos dentro no reinician dwell; cancelación y UUID
  invalidan callbacks viejos. Reentrada revierte cierre automático. X/Escape no
  reabre hasta salir; captura/voz no empiezan por hover. No registro de trayectorias.
- Voz no-idle, puntero dentro, arrastre o VoiceOver impiden autocierre; modo
  separado queda visible. Monitores y trabajo pendiente se retiran al destruirse.
  No notch físico: menú manual y superficie flotante; no zona invisible gigante.
- HomeSurfaceShape añade cuello del ancho real y hombros cóncavos de 14 pt;
  todo debajo de cámara/menú. Material óptico RoundedRectangle independiente de la
  máscara: el primer render con lente cóncava mostró artefactos cromáticos; no usar
  la silueta compleja como lente. Negro superior cubre el cuello, vidrio debajo.
- Footer eliminado: cabecera contiene atajo mic/Control+Option, estado de pantalla
  con help/AX label y «Temporal» con explicación. Fuera copy de funciones futuras.
  Conversación 430 pt (+14 conectado) frente a 506; compacto 70 (+14 conectado).
- Nuevos siete tests cubren hover, exclusiones, intención de reversión y forma;
  el runner completo pasa 144 tests/18 suites. Son políticas/geometry aisladas,
  no prueba de monitores físicos, temporizadores reales ni lectura VoiceOver.
- QA actualizada en SETTINGS_QA.md. Gate manual F1 sigue abierto; F2/F3 no iniciado,
  sin despliegue/Run, cambios de proveedor, permisos o pipeline aceptado.
- Validación final: runner estricto 144 tests/18 suites (0.932 s), sin diagnósticos
  de compilación en Home; Xcode UI Command+B «Build Succeeded» 22:38. Renders finales
  light/dark revisados en `/private/tmp/cursy-native-regression.QspBg6/`: sin bordes
  cromáticos del primer intento, cuello continuo, cabecera legible y sin footer.
  `git diff --check` limpio. Renders sintéticos no prueban óptica/animación física.

## Exploración de diseño — cápsula automática — 2026-09-20

- Usuario reporta negro contaminado por degradado y pequeña separación física;
  pide cápsula menor, próxima a cámara, automática con entrada de voz incluso
  con Home cerrado. Luego detiene implementación: ver prototipo y elegir primero.
- No cambios nativos en esta iteración. Prototype + Apple Design guían exploración
  aislada; Animate limita movimiento de controles frecuentes (sin transición de
  geometría por atajo). No micrófono, captura, datos privados ni modelos reales.
- `prototypes/notch-voice/index.html`: HTML autónomo, picker 1–3/flechas, estados
  simulados reposo/entrada/respuesta/conversación, nivel manual y fondo claro/oscuro.
  Comparación a escala CSS 1:1 con cámara ficticia de 192×31; no medición del notch
  físico. Mínima 192×29 bajo cámara; Con estado 236×37; Lateral 336×31 al nivel de
  cámara (requiere reservar barra de menú; no afirmación de compatibilidad nativa).
- En todos: cámara y unión negro sólido, sin vidrio en el cuello; conversación
  conserva degradado inferior. Esc/recoger, apertura hover y cambio de variante
  operativos en el prototipo. Elegir una dirección antes de portar a Swift.
- Revisión en navegador: las tres variantes inspeccionadas con capturas; controles
  de estado, recoger, nivel y fondo responden; consola sin errores/warnings.
  No build necesario: solo prototipo/documentación. Pendiente selección del usuario
  y posterior validación física Retina, foco/voz real/monitores en la app.

## Refinamiento del prototipo — isla envolvente — 2026-09-20

- Usuario rechaza separación del cuello y cápsulas bajo cámara. Sustituimos las
  tres exploraciones por Compacta (388×44 CSS px) y Ampliada (444×52): contenido
  exclusivamente lateral, centro reservado de 208 px para cámara simulada 192×31.
  Estas dimensiones son del laboratorio, no tamaños universales del hardware.
- Una silueta SVG negra envuelve la cámara en voz. Home usa una sola silueta desde
  el borde superior, cuello de 232 px y hombros cóncavos hasta el cuerpo; degradado
  comienza en y=112, fuera de cuello y cabecera. Desenfoque solo en cuerpo inferior;
  Reduce Transparency/Increase Contrast usan negro opaco sin desenfoque.
- Prototype + CCE Frontend mantienen cambios aislados. Apple Design y Emil Design
  orientan zona de cámara libre, espaciado lateral y separación entre negro opaco
  y material translúcido. No cambios Swift, modelos, micrófono ni permisos.
- Verificación en navegador: capturas de ambas islas y Home claro/oscuro; geometría
  de Compacta confirma laterales fuera de cámara (8 px de margen interior).
  Reposo oculta voz; entrada simulada la muestra con conversación cerrada;
  respuesta cambia estado; nivel 65→66 actualiza control; Escape recoge.
  Consola sin errores/warnings. No build nativo necesario para HTML/documentación.
- Pendiente elección del usuario antes de implementar; luego QA física de unión,
  barra de menú, escalas Retina, autoaparición con voz real y monitores externos.

## Movimiento del prototipo — cursor y notch como una unidad — 2026-09-20

- Usuario autoriza incorporar la secuencia aprobada al prototipo, no a Swift.
  Se conservan Compacta/Ampliada y el gate de selección/aceptación manual.
- Cursor ficticio con pointer-events:none viaja desde reposo al centro superior
  al entrar en escucha y permanece oculto durante escucha/procesamiento. Sale
  para señalar una línea de ejemplo al responder, luego vuelve a reposo. Estado
  de escucha cambia inmediatamente, sin esperar el movimiento (no audio real).
- Isla y conversación revelan/recogen su recorte desde la cámara en 250 ms con
  ease-out existente; textos no se escalan, opacidad 150 ms. Cámara opaca siempre.
  Animate/Apple Design orientan consistencia espacial y cancelación; movimiento
  solicitado explícitamente para explorar, no política final de atajos frecuentes.
- CSS transitions retargetean desde la presentación actual. Los temporizadores
  de cursor y demo se cancelan al cambiar estado/variante, detener o pulsar Escape;
  contenido recogido usa inert/aria-hidden y devuelve foco al disparador si procede.
- Reproducir/Detener secuencia y R/↻ recorren escucha, procesamiento, señalización,
  reposo y conversación. Pausas de la demo son ilustrativas, no latencia real.
  Movimiento reducido (sistema o control de preview) elimina desplazamientos
  animados y conserva opacidad. Notch fijo al viewport, incluso al desplazar el lab.
- Validación: sintaxis JavaScript con Node correcta; prueba en navegador de escucha
  oculta, procesamiento, salida/señalización, regreso y nueva escucha durante salida
  (sin callback tardío: cursor dock/opacity 0, sin highlight). Variante reducida
  verifica transición de superficie none y cursor solo opacity 150 ms.
  Demo completa termina en idle/rest con superficies recogidas; Escape cancela
  en Compacta. Ambas variantes revisadas en navegador; consola sin errores/warnings
  y `git diff --check` limpio.
  No modelos, permisos, app nativa o build modificados. Falta aceptación visual
  del movimiento por el usuario antes de integrar.

## Integración nativa del diseño aprobado — 2026-09-20

- Usuario: «bien, vamos a implementarlo». Se autoriza pasar el prototipo a la app;
  no implica aceptación física de la implementación ni iniciar F2/F3. Se adopta
  la isla Ampliada envolvente, ajustada a geometría real en vez de ancho fijo.
- CCE Mobile + Write Swift + Apple Design conservan panel no-key, foco externo,
  sesión/micrófono/modelos existentes y controles fuera de la cámara. Animate
  orienta consistencia espacial, recorte sin escala de texto y cancelación. La
  animación del atajo es petición explícita del usuario y prima sobre la regla
  genérica de no animar atajos frecuentes; voz comienza sin esperar a la UI.
- HomePresentation/HomeSurfaceShape/HomeGlassSurface/HomeView: top real del
  monitor, isla ancho de cámara +252 pt y alto máximo(52, cámara+14), centro
  reservado cámara+16. Cuello ampliado 20 pt por lado y negro opaco hasta cabecera;
  vidrio/degradado solo debajo. Compacto negro sin flare; ondas usan medidor real.
- HomePanelController/HomeReveal: voz muestra compacto automáticamente con Home
  cerrado. X/Escape suprimen ese turno; siguiente turno puede mostrarlo. Hover
  expande compacto; ocio conserva gracia 800 ms/VoiceOver/ratón. Pantallas externas
  flotan, separado no se acopla. ConstrainFrameRect no deja que AppKit vuelva a
  bajar el panel bajo menú; posiciones ya limitadas por HomePanelLayout. Hit test
  de silueta deja pasar eventos por hombros transparentes. Recorte 250 ms por fase,
  cambia layout con superficie recogida, sin estirar texto; UUID evita cierre tardío.
- HomeNotchInteraction nuevo comparte solo geometría/política con OverlayWindow.
  Cursor visual entra en 250 ms en escucha/conexión, oculto mientras procesa sin
  destino validado. Sale al destino o al seguimiento cuando responde; nuevo turno
  invalida navegación/burbujas anteriores. Timer existente usa tiempo monotónico,
  Reduce Motion omite vuelos. Ningún movimiento del ratón real, captura extra,
  motor de audio, llamada pagada o Worker/deploy. El caso multimonitor conserva
  un solo cursor en monitor destino; continuidad visual física pendiente de QA.
- Fuentes afectadas: HomePresentation, HomeSurfaceShape, HomeGlassSurface,
  HomeView, HomeReveal, HomeHoverPolicy, HomePanelController, CompanionManager
  (solo anchor publicado), OverlayWindow y HomeNotchInteraction. Tests existentes
  ajustados al contrato envolvente; nueva suite HomeNotchInteractionTests.
- Validación: `bash cursy-app/scripts/test-native-regressions.sh` pasa **150 tests
  /19 suites**, 0.955 s; compila módulo con MemberImportVisibility. Primer intento
  sandbox bloqueó plugins de macros; repetición autorizada fuera de sandbox pasa.
  Artefactos finales: `/private/tmp/cursy-native-regression.K3muGB/`.
  RenderHomePrototype usa vistas de producción, cámara superpuesta y datos
  sintéticos; PNG claro/oscuro revisados en `/private/tmp/cursy-native-regression.OK4CwD/`.
  Esto no demuestra geometría/óptica del notch físico ni temporización real.
- SETTINGS_QA.md actualizado: voz con menú cerrado, entrada/salida/interrupción,
  cierre/desacople, transparencia/movimiento reducidos, foco, monitor externo,
  desconexión y respuesta señalada/no señalada. F1 permanece abierto para esta
  aceptación manual. No ejecución de app ni cambios de permisos para validar.
- Xcode UI Command+B final: **Build Succeeded**, 2026-09-20 17:49. No Run ni
  xcodebuild terminal. `git diff --check` sin errores. Se conserva el laboratorio
  como referencia de diseño hasta aceptación física de F1.

## Sidebar, color y activación curva — 2026-09-20

- Nueva petición explícita autoriza este subconjunto F2 dentro del mismo ticket:
  chats laterales, ajustes en esa navegación, tintes/sombra y entrada más lenta
  con curvas y clic visual. No equivale a aprobar todos los gates F1/F2/F3.
- HomeView muestra chats y permite crear/seleccionar; engranaje cambia navegación
  a General/Cursor/Privacidad y «Volver a chats» recupera lista. HomeSettingsView
  reutiliza setters/preferencias existentes, sin controles ficticios de voz/agentes.
  Ancho deseado 840 pt y altura 540 + cámara, limitados al monitor; sidebar ocultable.
- HomeChatLibrary conserva hasta 20 chats temporales con contexto acotado existente
  de 10 intercambios. No escribe texto a disco. Pregunta sobre persistencia enviada,
  sin respuesta al implementar: se conserva privacidad previa. tsk008 sigue pendiente.
  ConversationSession.resumableSnapshot elimina captura/turno activo y renueva ID.
  Cambiar de chat cancela voz, tareas, observación y reproducción antes de restaurar;
  callbacks del turno anterior no se aceptan como parte del chat nuevo.
- CursyCursorTint: menta, azul, coral, dorado y violeta; preferencia local validada
  en AppStorage. Liquid Glass tint en macOS26+, material compatible en 14/15 y
  color sólido con Reduce Transparency; sombra a juego. Escala óptica .32 intacta.
  Muestras de ajustes usan geometría estática coloreada: el cache AppKit omite
  capas ópticas de glass. No se añadió una segunda forma al cursor real.
- Animate/Apple Design: vuelo S de 800 ms, presión visual 140 ms, ocultación 180 ms
  y reveal 250 ms. ID de activación correlaciona clic/panel; fallback acotado 1,6 s
  evita ocultación indefinida si falta overlay. Cancelación/reentrada invalida callbacks;
  Reduce Motion omite vuelo. Audio arranca sin esperar UI; no clic ni movimiento real.
  Duración mayor es petición explícita, no regla general para atajos frecuentes.
- Write Swift/CCE Mobile orientan separación de valores, snapshots terminales y
  retención acotada. Sin agentes paralelos, proveedores nuevos, red, audio de prueba
  o despliegue. Fuentes nuevas: HomeChatLibrary, HomeSettingsView, CursyCursorTint;
  nueva suite HomeWorkspaceTests, renderer actualizado para chats/ajustes.
- Validación offline final: 155 tests/20 suites pasan (0,943 s), módulo con
  MemberImportVisibility compila; artefactos `/private/tmp/cursy-native-regression.eWPSjI/`.
  Pruebas cubren aislamiento/reanudación, límite sin borrado silencioso, tintes,
  orden/IDs de activación y curva. No demuestran temporización/foco/óptica física.
  Xcode UI Build Succeeded final 2026-09-20 19:51; sin Run. QA física sigue pendiente.
  PNGs claro/oscuro en `/private/tmp/cursy-native-regression.EIo0rN/` de chats y
  ajustes revisados: muestras visibles, layout sin
  clipping. Estos renders no reproducen óptica nativa de compositor; el selector
  usa muestras estáticas y el cursor real conserva glass tint.

## Corrección de diseño primero — revisión 3

- Usuario reporta sidebar/ajustes que rompen el degradado, corte inferior, exige
  todos los iconos SF Symbols y mover «Señala mientras hablas» bajo el notch.
  Pide explícitamente actualizar prototipo para ver antes los cambios. No se
  modificó producción ni se infiere aprobación del último incremento nativo.
- CCE Frontend, Apple Design y Emil Design: una superficie/gradiente común con
  navegación transparente y clip exterior único, sidebar de altura completa,
  ajustes integrados y tipografía legible. Se refina la exploración existente,
  no se crean variantes ni tickets duplicados. Write Swift para exportador local
  de SF Symbols; Animate conserva movimiento reducido/cancelación en la demo.
- `prototypes/notch-voice/workspace.css/js` extienden el laboratorio existente;
  `RenderSymbols.swift` produce 21 SF Symbols reales de AppKit como máscaras PNG
  locales. No emojis o iconos dibujados a mano en UI renderizada. El medidor es
  visualización de nivel, no iconografía. README especifica límite de óptica web.
- Chats/categorías/colores y controles son simulados, sin cambios UserDefaults,
  captura, audio, red o modelos. Aviso y=54/62 frente a cámara inferior y=31;
  con conversación expandida y=38 en cuello negro. Vuelo800/clic140/reveal250
  reproduce la secuencia anterior, sin retrasar entrada real ni mover puntero.
- Browser: sidebar y panel terminan a igual altura; sidebar y contenido transparentes.
  Revisión visual de chats, General, Cursor, variante compacta/ampliada y fondos.
  Interrumpir entrada deja isla cerrada, cursor en reposo, aviso oculto; Reduce
  Motion llega a dock sin vuelo. Consola sin errores/warnings; sintaxis JS válida.
  Exportador compila/ejecuta con swiftc y cache en tmp; no Xcodebuild/Run ni pruebas
  nativas nuevas porque este cambio solo afecta el prototipo.
- Usuario responde «me gusta» y pide que el aviso salga del notch como notificación.
  Se incorpora SOLO al prototipo: slot recortado bajo el borde de isla, translateY
  de -100% a 0 durante250 ms + opacidad150 ms, misma ruta de salida sin escalar
  texto. Espera al clic visual; variante reducida solo funde. Navegador verifica
  origen slot44/cámara31, transform inicial -42,5 y final0, aviso finaly54;
  cancelación/reentrada no deja aviso tardío. Falta autorización para portar esta
  revisión de diseño a producción; aprobación estética no es orden de implementación.

## Aviso ligado a escucha y diagnóstico de latencia — 2026-09-20

- Solicitud: no anunciar «Señala mientras hablas» durante conexión; revisar
  espera del micrófono y de la respuesta. Se modifica el prototipo y se analiza
  producción, sin portar la revisión visual ni cambiar audio/modelos/proveedores.
- Prototipo: Conectando y Escuchando son controles/estados independientes.
  Connecting no tiene aviso ni ondas de entrada; escucha lista sí. El clic
  decorativo nunca equivale a input-ready. Secuencia incluye ambas fases y
  declara tiempos ficticios. Conserva salida reversible y movimiento reducido.
- Evidencia nativa: `startPushToTalk` espera `broker.createSession`, WebSocket,
  session.update e historial antes de `startMicrophoneCapture`. Cada turno
  vuelve a iniciar sesión y al completarse cancela la conexión. El primer PCM
  notifica `onInputReady(true)`; la animación del cursor no bloquea la captura.
  No hay timestamp de PTT→broker→primer PCM, por lo que no se cuantifica aún
  la espera inicial total ni se atribuye toda ella al dispositivo.
- Consulta read-only de Unified Log, categoría RealtimeCapture, última hora;
  no nuevos audios/capturas/peticiones. Tres turnos existentes con captura de
  78/121/84 ms; captura lista→decisión visual 3.112/4.377/2.665 s. El turno de
  localización agregó 4.347 s entre invocación de revisión semántica y publicación.
  Son intervalos del pipeline observado, no inferencia pura ni TTFA completo.
  Una muestra registra 86 ms entre historial enviado y motor iniciado, pero
  no mide desde pulsar el atajo hasta recibir el primer buffer. Sin contenido,
  IDs de capturas, credenciales o transcripciones guardados en esta nota.
- Con pantalla habilitada siempre hay decisión visual obligatoria antes de
  continuación hablada; locate añade localizador y validación, explain no lo
  invoca. El audio de respuesta ya se reproduce por bloques; la espera de
  transcripción de hasta 3 s sucede al final, no antes del primer audio.
- Corrección nativa futura del aviso: usar voiceState == listening junto con
  el estado del recorder; actualmente comienza con input-ready pero un cambio
  de ruta puede devolver voz a connecting sin limpiar el recorder. No mostrar
  «preparando» como invitación a hablar. Esta revisión deja producción intacta.
- Orden recomendado de optimización: medir fases/primer audio con tiempos
  monotónicos y sin contenido; capturar PCM acotado en memoria al PTT mientras
  conecta la red (sin micrófono en reposo, cancelación/errores/liberación temprana
  seguros); después evaluar ruta corta de conversación sin saltar validación de
  señalamientos. Reutilizar conexión solo tras definir inactividad, privacidad y
  consumo. Mantener modelos actuales hasta tener comparación medida.
- Validación del prototipo: sintaxis JS y diff-check; navegador verifica
  connecting oculto, listening visible, reconexión oculta y cancelación. No se
  afirma mejora de latencia nativa ni se ejecuta Xcode/Run en esta revisión.

### Suavizado del aviso solicitado por el usuario

- Solo prototipo: entrada de 250/150 ms con ease-out fuerte pasa a movimiento
  y opacidad sincronizados de 400 ms `ease`, siguiendo la receta de notificación
  de Animate. La petición explícita de suavidad justifica superar el presupuesto
  habitual; no añade espera previa ni bloquea la escucha. CCE Frontend conserva
  el estado real como condición, no la finalización de la animación.
- Salida hacia el notch de 200 ms, opacidad150 ms para no prolongar un aviso
  obsoleto. Reduce Motion conserva solo fade150 ms; sin escalado de texto.
- Browser confirma entrada400/400, delay0, salida200/150, connecting oculto y
  modo reducido sin transform. No cambios nativos ni de latencia/modelo.
- Seguimiento: el usuario pide salida tan suave como entrada. Se unifican ambas
  en CSS compartido: transform/opacity400 ms `ease`, sin retraso ni timers nuevos;
  la retirada comienza al salir de listening y no retrasa la cancelación lógica.
  Reduce Motion sigue fade150 ms simétrico. Solo prototipo, no producción.

## Port de revisión 3 a nativo — 2026-09-20

- Autorización: «antes de probar, también aplica los cambios que hicimos en el
  prototipo al app para probar todo de una vez». Se conserva este ticket, sin
  micro-task ni ampliación de modelos, proveedores, backend o fases de ajustes.
- HomeView elimina el padding inferior externo y las capas negras internas:
  sidebar y ajustes ocupan el alto completo sobre HomeGlassSurface compartida.
  HomeSettingsView mantiene su contenido desplazable, sin fondo independiente.
  Atajo Control/Option y muestras de color usan SF Symbols. La identidad del
  cursor vivo, sus tintes/sombra y el vuelo curvo aprobado se conservan.
- HomeSpatialHint separa política, geometría y presentación: invita a señalar
  únicamente con voz escuchando y recorder recording/limited; nunca preparing,
  connecting, released o cancelled. Conectando muestra ellipsis, no ondas de entrada.
  HomePanelController publica un anclaje derivado del panel visible/cámara/display;
  la isla automática no lo publica antes del clic de activación. Expandido coloca
  el aviso bajo la cámara; compacto bajo la isla; separado/externo usa el panel
  real y limita su posición a la pantalla. No se amplía la región interactiva.
- SpatialTrailView conserva el trazo inmediato sin animación y presenta el aviso
  en el overlay existente, click-through. Slot recortado con desplazamiento y
  opacidad400 ms ease en entrada/salida; Reduce Motion fade150 ms. El contenido
  saliente sigue montado para invertir sin timers ni callbacks tardíos; el estado
  lógico de escucha termina inmediatamente, sin esperar al efecto visual.
- No nuevos motores, captura, red ni esperas de audio. Se conserva la captura
  temprana y buffer acotado de tsk017; su evaluación física de latencia sigue abierta.
- Validación: suite offline 173 pruebas/22 suites en
  `/private/tmp/cursy-native-regression.LjdJRm`; cuatro renders nativos sintéticos
  light/dark de chats/cursor revisados en esa carpeta. Muestran continuidad y
  sidebar hasta el borde, no prueban óptica del compositor ni animación en vivo.
  HomeSpatialHintTests cubre cámara, orígenes negativos, fallback, estado y símbolos.
- Repetición final tras sustituir el icono de conexión: 173 pruebas/22 suites
  pasan en `/private/tmp/cursy-native-regression.HXBOLM`. Xcode UI (Cmd+B):
  Build Succeeded 22:26, sin Run ni micrófono; `git diff --check` limpio.
- Afectados: HomeView, HomeSettingsView, HomePanelController, CompanionManager
  (solo anclaje publicado), OverlayWindow, SpatialTrailView; nuevo HomeSpatialHint
  y tests. QA física combinada en SETTINGS_QA.md y VOICE_LATENCY_QA.md.
