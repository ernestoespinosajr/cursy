# Contexto espacial y espacio de trabajo de Cursy

- ID: ct012
- Fecha: 2026-09-19
- Estado: investigación formalizada en tsk006–016 por solicitud del usuario; sin implementación ni nueva aceptación QA.
- Ruta: CCE Ask → CCE Feature (11 tickets independientes de 11 capas).

## Solicitud

Comparar las 16 capturas y la prueba de HeyClicky aportadas por el usuario con
nuestro código y proponer una versión propia: notch, conversaciones/agentes,
dictado, ajustes y contexto espacial durante la voz. No copiar identidad gráfica
ni asumir que la apariencia de respuesta en vivo implica transmisión de vídeo.

## Evidencia

### Capturas aportadas

| Imágenes | Observación directa |
|---|---|
| 1–3 | Onboarding por voz, estados en notch y cursor con respuesta textual |
| 4–5 | Home y lista de asistentes nombrados, conversación, progreso y resultados |
| 6, 12 | Atajos separados para hablar, texto, dictado y dictado manos libres |
| 7 | Preferencias generales, visibilidad en Dock/grabaciones; versión 1.0.51 (61) |
| 8–10 | Voz/velocidad, idiomas de dictado, elección y prueba de micrófono |
| 11 | Colores y opción de ocultar/acoplar el cursor |
| 13–14 | Carpeta de agentes, permisos/autonomía y preferencias de anuncios |
| 15 | Compositor compacto de texto con adjuntos y opción de voz |
| 16 | Trazo rojo que se desvanece junto al puntero e indicador de voz |

Las capturas no revelan el modelo exacto, frecuencia de envío de imágenes,
implementación de agentes ni protocolo de vídeo. La experiencia temporal procede
del relato del usuario; las imágenes son estáticas. No se copian datos personales
visibles ni se envían estas capturas a proveedores en esta investigación.

### Fuentes públicas oficiales consultadas

- [Changelog](https://www.heyclicky.com/changelog): v1.0.51, del 18 de septiembre,
  confirma Home redimensionable desde el notch; v1.0.49 introdujo asistentes
  persistentes. v1.0.33 documenta el trazo espacial mientras se habla. Es contexto
  de Talk, no evidencia de que el modo Dictate tenga esa misma función.
- [Trust](https://www.heyclicky.com/trust): el fabricante declara observación al
  pulsar el atajo, no vigilancia continua; procesamiento remoto y conservación
  del análisis/prompt, no de capturas crudas. No es una auditoría independiente.
- [Privacidad](https://www.heyclicky.com/privacy-policy): describe capturas y audio
  activados por push-to-talk enviados al backend. No determina la cadencia de
  fotogramas dentro de una petición.
- [Producto](https://www.heyclicky.com/): distingue conversación y trabajo de
  agentes. Una conversación no equivale necesariamente a una tarea autónoma.

### Repositorio y memoria

Inspeccionados logbook, dependencias, ct001 y tsk005, estado Git y código actual;
contrastadas búsquedas contra la base 97c5406. El árbol contiene trabajo previo
sin commit y debe preservarse.

| Componente reutilizable | Capacidad y límite comprobado |
|---|---|
| `ConversationSession.swift` | Sesión/turnos tipados, cancelación y objetivo; historial acotado en memoria, no almacén multiconversación duradero |
| `CompanionScreenCaptureUtility.swift` | Captura con SCScreenshotManager del monitor del puntero, contexto/ventanas y validación; excluye ventanas de Cursy y desactiva cursor en imagen |
| `VisualObservation.swift` | Observación temporal con comparación visual local sin OCR; presupuesto de 30 s, hasta dos refrescos y seguimiento acotado tras señalar; no vídeo permanente al modelo |
| `VisualTurnContext.swift`, `ScreenCoordinateSpace.swift` | Identidad de captura, monitor, ventanas y transformación de coordenadas |
| `OverlayWindow.swift`, `VisualAnnotation.swift` | Salida visual hacia el usuario; figuras alrededor de puntos validados, no caja semántica del elemento |
| `GlobalPushToTalkShortcutMonitor.swift` | Activación por teclado mediante escucha de eventos; no grabación de recorridos del ratón |
| `BuddyDictationManager.swift` | Audio/transcripción y callbacks de borrador; no inserción universal segura en otras aplicaciones |
| `CursyApp.swift`, panel y menú | Ciclo de vida de app de barra de menú; sin Home/notch ni gestor persistente de trabajos |
| `VisionAPI.swift`, Worker | Frontera de proveedores reutilizable; no obliga a que voz y localización usen el mismo modelo |

La base no contiene una implementación de notch/contexto espacial que baste con
activar. Tampoco equivale su transcripción de borradores a dictado universal.
Reutilizar estas piezas evita reconstruir voz, geometría y sesiones ya aceptadas.

## Diferencia funcional decisiva

**Anotación de salida:** Cursy encuentra algo y se lo señala al usuario.
**Contexto espacial de entrada:** el usuario señala una región para explicar a
Cursy a qué se refiere con «esto», «aquí» o «compara estas partes».

Pintar una huella en el overlay actual no se la mostraría al modelo: nuestras
ventanas se excluyen de la captura. Debe viajar como contexto explícito, asociado
a la imagen correcta. No eliminar la exclusión global: produciría contaminación
con respuestas anteriores y elementos de nuestra propia interfaz.

## Propuesta técnica, todavía no implementada

1. Armar contexto espacial solo durante interacción explícita y con pantalla
   compartida. Separarlo de Dictate, que por defecto solo transcribe al destino.
2. Recoger recorrido acotado con tiempo, monitor y revisión de escena; conservar
   suficiente relación temporal con el audio para interpretar referencias.
3. Formar un paquete efímero con imagen limpia y trayectoria/región normalizada.
   Evaluar un canal visual auxiliar si el proveedor lo necesita, manteniendo
   transformación única y sin convertir la huella en una orden del sistema.
4. Si cambia la escena o hay scroll, no superponer automáticamente el recorrido
   antiguo en la imagen nueva. Segmentar o invalidar evidencia; dividir por
   monitor cuando el gesto cruza pantallas.
5. Enviar evidencia seleccionada al resolver la petición. Más adelante, evaluar
   refrescos durante la interacción por eventos: muestrear localmente no exige
   enviar todos los fotogramas ni mantener al modelo mirando en segundo plano.
6. Reutilizar localización independiente y validaciones antes de publicar la
   respuesta. Un gesto reduce ambigüedad; no garantiza acierto del 100 %.

Diseñar límites de puntos/imágenes/duración/costo, cancelación, una operación
vigente a la vez y descarte de resultados obsoletos. Indicador visible al recoger
contexto y borrado al terminar/cancelar; no registrar capturas/audio por defecto.
No introducir OCR ni reglas para una app específica.

## Nuestra experiencia de producto

- Mantener el cursor de vidrio menta suave, compacto, aceptado por el usuario.
- Añadir Home opcional accesible desde notch; usar una cápsula superior o menú en
  monitores sin notch. No perder acceso al trabajar en otra pantalla.
- Separar estado compacto (escucha/procesamiento/respuesta) del panel expandido
  (conversaciones, resultados, ajustes). Evitar robo de foco mientras se guía.
- Distinguir cuatro funciones: conversar/guiar, escribir a Cursy, dictar a otra
  app y encargar trabajo. Compartir núcleo no significa compartir permisos.
- Modelar agentes futuros como identidad/objetivo/conversación/recursos/trabajos
  persistentes; un agente no es simplemente otro nombre de modelo.

## Orden propuesto y dependencias

No sustituye silenciosamente la aceptación pendiente de tsk005 ni crea tickets.

| Orden | Entrega | Dependencia y resultado comprobable |
|---|---|---|
| 0 | Aceptar anotaciones tsk005 | Ejecutar QA pendiente; este research no equivale a aprobación |
| 1 | Contexto espacial al hablar | Reutilizar captura/voz/geometría; resolver referencias acompañadas de gesto en distintas apps y monitores |
| 2 | Home opcional + ajustes organizados | Reutilizar estado actual; entrada por voz/texto, fallback sin notch y sin alterar foco |
| 3 | Conversaciones persistentes | Extender tsk003, no rehacerlo; restauración, aislamiento, migración y borrado explícito |
| 4 | Guías persistentes, luego verificación | Dos entregas: objetivo/pasos/pausa/reanudación; después observar evidencia de cumplimiento durante sesión autorizada |
| 5 | Dictado universal seguro | Reutilizar STT; arbitrar micrófono/modos, destino enfocado, campos sensibles y fallback controlado |
| 6 | Trabajos de agentes acotados | Historial persistente, progreso, cancelación, resultados; comenzar investigación/lectura, con límites de uso |
| 7 | Integraciones y acciones con confirmación | Autenticación, cuotas y permisos por herramienta antes de escritura/clic o trabajos autónomos |

El dictado es una línea independiente de las guías y puede adelantarse por
decisión de producto; el orden no autoriza delegación ni desarrollo paralelo.
No convertir agentes/autonomía en requisito para una simple pregunta visual.

## Alternativas

1. **Notch primero:** resultado visible rápido, pero no mejora «esto que señalo».
2. **Agentes primero:** amplía utilidad, pero multiplica persistencia, permisos,
   seguridad y costos antes de consolidar la interacción contextual.
3. **Contexto espacial primero, Home después (recomendado):** aprovecha la base
   aceptada y añade una capacidad nueva, medible, antes de expandir autonomía.

## Riesgos, QA y preguntas de diseño

- Desfase audio/gesto/imagen, scroll, escalado y dos monitores: fixtures de contrato
  y QA general con documentos, controles, imágenes y listas, no un chat especial.
- Cambios de ruta de audio y atajos: conservar regresiones de AirPods y sesión;
  nunca iniciar dos capturas de micrófono al cambiar de modo.
- Dictado: no insertar en otro destino si cambia el foco; proteger campos secretos
  y no ejecutar contenido dictado en Terminal por una pulsación automática.
- Persistencia/agentes: definir retención, eliminación, recursos y autoridad de
  cada trabajo; endurecer autenticación/cuotas antes de exposición comercial.
- Notch: accesibilidad, reducción de movimiento, pantalla completa, menú del
  sistema y monitores sin notch; no asumir espacio disponible fijo.
- Medir latencia percibida y real, llamadas/bytes/costo y errores, no solo fluidez
  de animación. Reconfirmar APIs de proveedores al planificar la implementación.
- Pendiente de elegir en diseño: modo de activación del trazo, duración máxima,
  persistencia local inicial y ubicación preferida del Home multimonitor.

## Complejidad y ruta

Técnica 9/10, integración 8/10, pruebas 9/10, rollout 8/10: programa **9/10**.
Ruta `$cce-feature`; no un único ticket gigante. El primer contexto espacial
debe descomponerse por contratos/captura/presentación/integración y aceptación.

Dueño recomendado: `cce-full-stack`. Native: `cce-mobile` + `write-swift`, añadir
`apple-design` para superficies y `animate` solo al implementar movimiento.
Contexto/modelos/evaluación: `cce-ai-engineer`. Servicios y permisos remotos:
`cce-backend`. No asumir plugins instalados ni autorizar agentes paralelos.

Herramientas disponibles relevantes: lectura/diff local, pruebas locales,
documentación web oficial, imágenes aportadas y validación UI cuando se acuerde.
Esta fase solo leyó fuentes y actualizó memoria; no ejecutó tests ni modificó
la app, no capturó la pantalla actual, no envió imágenes a modelos ni desplegó.

## Siguiente prompt

La planificación solicitada ya está creada. Una vez aceptado tsk005:
`$cce-dispatch execute tsk006-spatial-context`.

## Tickets formalizados — 2026-09-19

El usuario pide tickets en plural; se crea un archivo por capacidad, sin duplicar
un ticket paraguas ni crear micro-tasks. Las secciones anteriores conservan la
investigación inicial; esta sección fija el orden formal. Complejidad global 9/10;
cada ticket puntúa 7–10 y desarrolla las once capas de context-levels.md.
La creación de planes no autoriza implementación, despliegue o acceso a cuentas.

| Orden | Ticket | Entrega | Evidencia de interacción / dependencia |
|---|---|---|---|
| 0 | tsk005, ya activo | Aceptación de anotaciones | Gate manual pendiente, no crear duplicado |
| 1 | [tsk006](../02-in-progress/tsk006-spatial-context.md) | Contexto espacial al hablar | Inicio autorizado remotamente sin aceptar tsk005; primera integración de escena actual |
| 2 | [tsk007](../01-planned/tsk007-home-notch-settings.md) | Home/notch, texto, modos y ajustes | Imágenes 1–4,6–12,15; depende tsk006 |
| 3 | [tsk008](../01-planned/tsk008-persistent-conversations.md) | Conversaciones duraderas | Imágenes 4–5; extender tsk003 sobre Home |
| 4 | [tsk009](../01-planned/tsk009-persistent-walkthroughs.md) | Guías persistentes | Necesidad histórica; tsk006+008 |
| 5 | [tsk010](../01-planned/tsk010-step-verification.md) | Avance supervisado por evidencia | Sensación de continuidad; depende tsk009, no implica vídeo continuo |
| 6 | [tsk011](../01-planned/tsk011-safe-universal-dictation.md) | Dictado a otras apps | Imágenes 6,9,12; depende solo tsk007 entre tickets nuevos |
| 7 | [tsk012](../01-planned/tsk012-identity-quotas-provider-security.md) | Identidad, cuotas y seguridad | Brecha propia comprobada del Worker; gate de lanzamiento, adelantable |
| 8 | [tsk013](../01-planned/tsk013-bounded-agent-workspaces.md) | Agentes, adjuntos y resultados | Imágenes 4–5,13,15; depende tsk008+012 |
| 9 | [tsk014](../01-planned/tsk014-confirmed-local-actions.md) | Acciones locales con aprobación | Imagen 13 + límites propios; depende tsk010+012+013 |
| 10 | [tsk015](../01-planned/tsk015-scoped-integrations.md) | Conectores de lectura | Sección observada, servicio aún por elegir; tsk012+013 |
| 11 | [tsk016](../01-planned/tsk016-opt-in-routines-notifications.md) | Rutinas y avisos controlados | Imágenes 13–14; tsk012+013+015 |

### Reconstrucción funcional, no acceso al código privado

La secuencia inferida para nuestra implementación es:

1. Activación explícita establece modo, conversación, permisos y dueño de audio.
2. Voz y gesto producen evidencia temporal; un selector de contexto decide qué
   imagen corresponde, sin confundir la pantalla con el Home del asistente.
3. La intención decide entre conversar, orientar, dictar o proponer un trabajo.
4. Localización, verificación y acciones son operaciones distintas. La aprobación
   de una acción proviene del usuario, no de la respuesta del modelo.
5. Home presenta sesiones/trabajos/resultados; no es el motor ni el almacén.

Esto es una arquitectura propuesta a partir de comportamiento observable,
no una afirmación de que HeyClicky use estos componentes. No inspeccionamos su
binario, tráfico autenticado ni servidores. La base disponible 97c5406 tiene
POINT y transcripción; no es el código de su producto actual.

Reconsultados [changelog](https://www.heyclicky.com/changelog) y
[Trust](https://www.heyclicky.com/trust) el 19 de septiembre. Para límites nativos,
referencias oficiales de [SCScreenshotManager](https://developer.apple.com/documentation/screencapturekit/scscreenshotmanager)
y [NSScreen.safeAreaInsets](https://developer.apple.com/documentation/appkit/nsscreen/safeareainsets).
Las páginas de Apple requieren renderizado adicional para detalles; no se asumen
firmas o disponibilidad nuevas a partir de sus títulos. El dispatch debe validar
SDK/API exacta antes de implementar; no se presupone una API pública de notch.

### Contrato común del programa

- Hechos, propuestas y decisiones abiertas deben seguir etiquetados. Budgets
  numéricos de tickets son límites iniciales propuestos, no mediciones alcanzadas.
- Sesión, turno, captura, paso y run tienen identidad propia. Toda operación async
  comprueba pertenencia/cancelación tras suspenderse antes de publicar o escribir.
- DTOs de valor; estado de UI en MainActor, persistencia serializada, transporte
  sin objetos AppKit. No cambiar modo Swift/SDK mínimo como efecto secundario.
- El contexto de imagen no es memoria persistente. Ni historial del Home ni
  archivos de resultados deben arrastrar capturas antiguas en cada petición.
- Proveedores independientes por función; conservar localizador evaluado. No
  elegir un modelo por precio si falla admisión, ni prometer precisión universal.
- Captura, micrófono, inserción, acciones de agente, conectores y recurrencia tienen
  permisos distintos. No activar todos por compartir una interfaz o conversación.
- Una sesión dueña del micrófono; una operación de captura compartida en vuelo;
  límites distintos para muestras locales, imágenes enviadas y llamadas remotas.
- No OCR local ni reglas por app/persona. Casos de usuario son QA; fixtures de
  documentos, controles, imágenes, listas, idiomas y pantallas prueban generalidad.
- Cursor menta/escala 0.32/morph aceptado, neutral en navegación; el Home es
  opcional. Accesibilidad y contraste sin depender solo de color/movimiento.
- Features detrás de flags, esquemas versionados y fallback explícito. Rollback
  no borra datos ni revierte autenticación. No reset destructivo del worktree.
- Pruebas de contrato/modelo simulado primero; live QA con consentimiento sobre
  datos enviados y costo. Xcode para build/UI completo, nunca xcodebuild terminal.
  Pruebas simuladas no equivalen a aceptación de proveedor/hardware/usuarios.

### Matriz transversal de aceptación

| Riesgo | Cobertura mínima | Gate |
|---|---|---|
| Geometría y contexto | Retina/no Retina, monitores en cinco disposiciones, scroll/mover/ocultar/desconectar | Nunca publicar evidencia de otra revisión/monitor |
| Sesión y audio | interrupción/reset, cambio de chat, AirPods, silencio y reconexión | No mezcla de conversaciones ni micrófonos simultáneos |
| Privacidad | permiso revocado, pantalla bloqueada, pausa, modo temporal | Nada nuevo capturado/enviado fuera del consentimiento vigente |
| Fiabilidad | offline, timeout, respuesta tardía, duplicados, reinicio y corrupción | Estado recuperable; sin duplicar acción/gasto |
| Seguridad | instrucciones maliciosas en pantalla/archivo/herramienta, paths y scopes ajenos | No amplía autoridad; operación denegada verificablemente |
| Experiencia | VoiceOver/teclado, reducción de movimiento/transparencia, ES/EN, sin notch | Flujos utilizables y salida segura/visible |

Para cada fase guardar comando, alcance y resultado real en su ticket; medir
latencia p50/p95 sobre al menos 30 interacciones en hardware anotado, excluyendo
fixtures sintéticos cuando se afirme rendimiento real. No afirmar 100% por una
matriz pequeña. Detener rollout ante cualquier regresión de destino/autoridad.

### Responsabilidad y decisiones

Coordinación del programa: cce-full-stack; cada ticket designa dueño y compañeros
según routing matrix. cce-mobile+write-swift para contratos/ciclo de vida;
apple-design guía foco/superficies y animate solo al implementar movimiento.
cce-ai-engineer evalúa interpretación; cce-backend protege servicios. No se
autoriza delegación ni edición paralela de archivos compartidos.

Decisiones que requieren usuario antes de habilitar capacidades: aceptación
tsk005; diseño Home/activación de gesto tras prototipo; opt-in y retención de
historial; proveedor de identidad/infraestructura y gasto monetario; primer
conector/cuenta; activación de cada rutina. No impiden planificar contratos o
tests falsos, pero sus gates no pueden darse por aprobados por este documento.

Estado de este turno: solo documentación. Sin pruebas de runtime, cambios de app,
altas de servicios, secretos, subagentes, subidas de capturas ni despliegue.

Validación documental ejecutada: script Node de solo lectura verificó IDs únicos
en todas las carpetas, once capas en cada uno de los once planes, prerequisitos
existentes, grafo sin ciclos, referencias del índice y enlaces locales. Resultado:
11 planned, 1 in progress, 10 completed. `git diff --check` pasó para archivos
rastreados; no equivale a pruebas de app ni cubre por sí solo archivos untracked.
Se inspeccionaron además las suites existentes de observación, sesiones,
geometría/anotación y runtime Worker como puntos de extensión de los planes.
