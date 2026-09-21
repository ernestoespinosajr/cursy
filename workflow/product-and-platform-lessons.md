# Cursy — decisiones y aprendizajes duraderos

Actualizado: 2026-09-21. Memoria solicitada por el usuario antes de commit/push.
Evidencia y ejecución detallada: tsk005, tsk007 y tsk017; guías futuras: tsk009/010.
Las preferencias aprobadas no sustituyen los gates de QA física de cada ticket.

## Producto y lenguaje visual

- Home es la entrada oficial; no recuperar el menú anterior ni el selector de
  herramientas visuales. Cursy elige cómo señalar; el usuario no configura figuras.
  No exigir un objetivo escrito para iniciar una conversación.
- Sidebar y ajustes llegan hasta el borde inferior y comparten el gradiente.
  Usar SF Symbols en controles. Acento del cursor en iconos e indicaciones reales;
  bordes neutros en superficies, inputs y etiquetas, no stroke de color en todo.
- Movimiento suave y coherente, pero ágil tras las iteraciones aprobadas. El
  cursor dibujante crea figuras: arrastra un recuadro o recorre un trazo. Etiquetas
  explicativas aparecen directamente con typing, sin línea conectora ni dibujante.
  Conservar Reduce Motion y cancelación; no escalar glifos durante el morph.
- Figuras deben abarcar el objetivo completo, no un tamaño arbitrario. La app
  usa bounds verificados del elemento; sin extensión fiable vuelve al cursor.
  Multiples indicadores/arrastrar-soltar/avance verificado siguen tsk009/010:
  una demostración del prototipo no significa que la guía nativa esté implementada.
- Al completar una guía, felicitar y pasar al siguiente paso si existe. No narrar
  implementación interna con «la guía se retira» ni afirmar éxito sin verificar.
- Aviso de señalar y fragmento de voz salen debajo del notch como notificación.
  Invitar a hablar solo con captura realmente lista, nunca durante conexión.

## Selección contextual y privacidad

- Oferta compacta sin logo:160×32 en español,96×32 en inglés; editor compacto370×46.
  Morph conserva relación espacial. Preferir12pt sobre el menú ya existente;
  fallback debajo de selección/menú, sin tapar acciones ni texto seleccionado.
- Selección exacta y acotada en memoria (6.000 unidades UTF-16). No clipboard,
  copy sintético, OCR ni documento completo. Inicio de chat aislado: sin otros
  chats, pantalla ni herramientas. Texto seleccionado es fuente no confiable,
  nunca instrucciones. Voz solo tras acción explícita; saludo termina realmente
  antes de comenzar a escuchar. Nueva entrada/cancelación revoca resultados tardíos.
- Separar texto confirmado, geometría, foco, readiness AX y presentación. Poder
  leer la selección no prueba que se muestre la barra ni que esté bien colocada.
- Preparar AX por capacidades, no por nombre de app. Electron puede diferir2s
  la activación:120ms no bastaban y setters repetidos reinician el debounce.
  Estado por PID, retries cancelables y sin retrasar selecciones ya disponibles.
- Priorizar áreas web y rangos completos; árboles profundos/hermanos tardíos
  necesitan búsqueda paginada y acotada fuera del hilo UI. Foco a menú no implica
  cancelar el gesto. Revalidar PID/ventana; nueva entrada real sí invalida.
- Un ancla de mouse no es la extensión del texto. Inicio/fin del arrastre sirven
  solo para rechazar geometría obsoleta y evitar su banda, nunca para inferir texto.
- No asumir menú centrado, rol AXToolbar ni dos acciones. SelectionMenuSearch
  barre la franja y busca el contenedor compacto completo, incluso de una acción.
  Claude/Outlook/GPT son fixtures de regresión, no condiciones por nombre.
  Solo se detecta geometría accesible; no prometer compatibilidad universal.

## Audio, latencia y verificación

- Arranque de audio puede bloquear: prueba local con propietario único, trabajo
  del motor fuera de UI, watchdog y teardown completo antes de ceder el micrófono.
  Motor fresco; no reasignar HAL al dispositivo predeterminado ni si se selecciona
  su mismo UID explícitamente. Probar también entrada integrada, no culpar a AirPods.
- Optimizar recorrido y medir fases antes de cambiar proveedores/modelos. El usuario
  percibe mejora de latencia, pero eso no es una cifra ni cierre de tsk017.
- Tests deben ejecutar algoritmos de producción con backends simulados, no solo
  geometría independiente. Mantener casos de cancelación, campos protegidos,
  ventanas ajenas, monitores negativos, menús descentrados y de acción única.
- Evidencia más reciente:232 tests/27 suites nativas offline y28 de prototipo.
  Los tests no prueban permisos, dispositivos, óptica, proveedores o apps reales.
  GPT tiene aceptación de colocación del usuario; últimos ajustes Claude/Outlook
  aún requieren ejecución/QA física. Los tickets permanecen abiertos según sus gates.
- Build/Run firmado desde Xcode UI; nunca terminal xcodebuild. La automatización
  de Xcode ha agotado timeout: no confundir con un hang de Cursy, ni afirmar Run
  actualizado mirando un reporte viejo. No eludir límites de control de la app host.
- Logs sin texto seleccionado, contenido de pantalla, títulos, URL privadas ni
  credenciales; correlacionar solicitudes, fases y razones de descarte.
