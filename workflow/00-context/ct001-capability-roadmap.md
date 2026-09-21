# Ruta de capacidades para Cursy

- **ID:** ct001-capability-roadmap
- **Fecha:** 2026-09-18
- **Estado:** analizado
- **Solicitud:** convertir la comparación entre Cursy y HeyClicky en una ruta recomendada de tickets implementables.

## Resumen de la solicitud

Definir una secuencia de trabajo que lleve a Cursy desde su flujo actual de
voz, visión y señalamiento hasta una experiencia con voz realtime, routing,
walkthroughs, memoria, dictado universal y acciones locales seguras, sin intentar
replicar de una vez todo el producto de referencia.

## Evidencia inspeccionada

- Conversación adjunta y comparación funcional aportada por el usuario.
- `AGENTS.md`, `cursy-app/AGENTS.md`, `README.md` y `cursy-app/README.md`.
- `CompanionManager.swift`: máquina de estado central, historial temporal de 10
  intercambios, captura de pantallas, Claude, TTS y tags `[POINT:...]`.
- `BuddyDictationManager.swift` y proveedores de transcripción: captura de audio
  y abstracción reutilizable para STT.
- `OverlayWindow.swift`: overlays por pantalla y animación hacia un único punto.
- `WindowPositionManager.swift`: comprobación y solicitud de Accessibility y
  Screen Recording; ya existe una base de permisos.
- `worker/src/index.ts`: proxy Cloudflare con `/chat`, `/tts` y
  `/transcribe-token`, sin autenticación de usuario, cuotas ni ruta realtime.
- `Cursy.entitlements`: app no sandboxed, red y audio habilitados.
- `CursyTests.swift`: cobertura actual limitada al comportamiento de permisos.
- `workflow/logbook.md`, `workflow/dependencies.md` y tarea bootstrap pendiente.

## Hechos verificados

- La coordinación principal está concentrada en `CompanionManager`; añadir más
  modos directamente aumentaría acoplamiento y dificultaría las pruebas.
- El flujo actual es secuencial: STT -> captura -> Claude -> ElevenLabs.
- Cancelar una respuesta detiene la tarea y el playback, pero no existe una
  sesión speech-to-speech ni barge-in real.
- El protocolo visual solo representa cero o un punto y no modela pasos,
  figuras, progreso ni evidencia de cumplimiento.
- Accessibility ya se solicita, pero no existe una capa tipada de herramientas
  para clic, escritura o apertura con políticas de confirmación.
- La memoria conversacional no persiste y se limita a diez turnos.
- La captura de audio y los proveedores STT ofrecen una base reutilizable para
  dictado, aunque todavía no existe inserción segura en la app enfocada.
- El Worker todavía usa una URL placeholder en el cliente y no implementa la
  infraestructura requerida por sesiones realtime o herramientas.
- El bootstrap `tsk000` sigue pendiente, por lo que el inventario persistente del
  repositorio aún no está completo.

## Inferencias y supuestos

- La identidad prioritaria de Cursy seguirá siendo ayuda visual guiada en macOS,
  no automatización general sin supervisión.
- Memoria y registros sensibles deben ser local-first y explícitamente
  controlables por el usuario.
- Las acciones que cambian estado fuera de Cursy requerirán una política común de
  riesgo y confirmación antes de habilitar agentes autónomos.
- El proveedor realtime exacto y su protocolo deben validarse con documentación
  oficial vigente al planificar la implementación; el roadmap no depende de un
  nombre de modelo concreto.

## Áreas afectadas y reutilización

- **Orquestación:** extraer sesiones/modos desde `CompanionManager` conservando
  su integración con el overlay y el shortcut.
- **Audio:** reutilizar captura, conversión y niveles de
  `BuddyDictationManager` y `BuddyAudioConversionSupport`.
- **Visión:** reutilizar `CompanionScreenCaptureUtility` y la conversión de
  coordenadas ya probada conceptualmente por el señalamiento.
- **UI:** extender `OverlayWindow` con un modelo de anotaciones y pasos, sin
  duplicar ventanas por capacidad.
- **Permisos:** ampliar `WindowPositionManager` para autorización contextual y
  estado de capacidades.
- **Backend:** evolucionar el Worker como frontera única de secretos y sesiones.

## Alternativas consideradas

### A. Voz realtime primero, integrada al manager actual

Entrega una mejora perceptible rápida, pero acopla otro transporte a una clase
ya centralizada y obliga a rehacer routing, memoria y herramientas después.

### B. Walkthroughs primero sobre el pipeline actual

Valida la diferenciación visual del producto con menor dependencia externa. Es
útil como entrega temprana, pero necesita antes contratos estructurados para no
convertir tags de texto en un protocolo frágil.

### C. Plataforma mínima y luego dos verticales de producto (recomendada)

Primero crea contratos, sesiones y políticas; después entrega walkthroughs y voz
realtime en paralelo lógico, seguidos por memoria, dictado y acciones. Reduce
retr trabajo y establece límites de seguridad antes de automatizar.

## Ruta recomendada de tickets

### Estado vigente — 2026-09-19

**Programa formalizado:** ct012 incorpora las 16 capturas
de HeyClicky aportadas por el usuario. El usuario autorizó crear los tickets
tsk006–016; están en 01-planned, con contexto espacial primero, Home/notch
opcional y conversaciones persistentes después. Ver
`workflow/00-context/ct012-heyclicky-spatial-workspace-research.md` para comparación,
orden completo y límites. Esta planificación no implementa capacidades ni cierra
tsk005. La sección «Tickets formalizados» de ct012 y dependencies.md son la
prioridad vigente y sustituyen los órdenes históricos que aparecen abajo.

tsk003 sesiones aceptado por el usuario (continuidad, interrupción y reset),
tsk004 intención/ventana también aceptado. Próxima entrega en ejecución:
`workflow/02-in-progress/tsk005-visual-annotations.md`. Después se planificarán
walkthroughs persistentes y verificación de pasos como capacidades separadas.
HeyClicky revisado nuevamente: anuncia dibujar sobre la pantalla para orientar;
el código original 97c5406 solo integra POINT + cursor/etiqueta en este flujo.

### Prioridad vigente del usuario — conexión antes de expansión

El usuario requiere primero voz + pantalla + señalamiento funcionando juntos.
Entrega aceptada y cerrada: `workflow/03-completed/tsk002-realtime-screen-pointing-completed.md`.
Incluye contratos mínimos, no el refactor completo. El usuario confirmó que funciona
tras el despliegue ct010; se libera el gate para retomar tsk003. Orden vigente:
núcleo completo de sesiones → anotaciones enriquecidas → walkthroughs
persistentes → verificación supervisada. Este orden sustituye la prioridad inicial
de la tabla histórica; el resto del programa sigue como backlog, no como entregado.

### Actualización de progreso — 2026-09-18

Se adelantaron la configuración del Worker, autenticación interna, cliente
OpenAI Realtime push-to-talk, idioma español/inglés y cursor de voz aprobado
(micro001–micro005). No equivalen por sí solos al ticket 5 completo: quedan por
evaluar barge-in, reconexión, fallback y métricas contra sus criterios originales.
La evidencia inicial de este documento es histórica, anterior a esas entregas.
Siguiente tarea ya planificada: tsk000. Después, crear el plan de núcleo de
sesiones/contratos tipados (1), seguido de anotaciones (2) y walkthroughs (3–4).
No repetir la infraestructura de voz ya construida; integrarla con ese núcleo.

| Orden | Ticket | Resultado verificable | Dependencias | Complejidad / ruta |
|---:|---|---|---|---|
| 0 | Ejecutar bootstrap de contexto | Logbook, dependencias, comandos y mapa técnico confiables | Ninguna | existente `tsk000`, `$cce-dispatch` |
| 1 | Núcleo de sesiones y contratos tipados | `CompanionManager` delega conversación, eventos y resultados estructurados; conserva el comportamiento actual | 0 | 6, `$cce-quick-feature` |
| 2 | Protocolo de anotaciones visuales | Soporta punto, círculo, rectángulo/flecha, etiqueta y pantalla mediante salida estructurada; parser y coordenadas testeados | 1 | 5, `$cce-quick-feature` |
| 3 | Motor de walkthroughs persistentes | Lista de pasos, paso activo, pausar/reanudar/cancelar y progreso persistido localmente | 2 | 7, `$cce-feature` |
| 4 | Verificación del paso | Observa interacción/cambio de pantalla, evalúa cumplimiento con confianza y pide confirmación cuando es ambiguo | 3 | 8, `$cce-feature` |
| 5 | Voz realtime y barge-in | Sesión bidireccional, interrupción real, reconexión, fallback al pipeline actual y métricas de latencia | 1 y Worker configurado | 8, `$cce-feature` |
| 6 | Router de intención/capacidad | Decide conversación rápida, análisis visual, walkthrough o acción; explica fallback y permite override de diagnóstico | 3 y 5 | 7, `$cce-feature` |
| 7 | Memoria local explícita | Perfil, contexto actual y conversaciones con edición, borrado, límites de inyección y controles de privacidad | 1 | 6, `$cce-quick-feature` |
| 8 | Dictado universal seguro | Modo separado, inserción por Accessibility, fallback de portapapeles y protección para terminales/campos sensibles | 1 y política de permisos | 7, `$cce-feature` |
| 9 | Herramientas locales con confirmación | Registro tipado para abrir, clicar y escribir; previsualización, niveles de riesgo, confirmación, cancelación y auditoría local | 4, 6 y 8 | 9, `$cce-feature` |
| 10 | Adjuntos y contexto documental | Ingesta local de archivos, extracción por tipo, selección de fragmentos, ciclo de vida y límites de privacidad | 1 y 7 | 7, `$cce-feature` |
| 11 | Agente de tareas largas (beta) | Ejecución acotada en segundo plano usando solo herramientas autorizadas, checkpoints y parada inmediata | 9 y 10 | 10, `$cce-feature` |

## Hitos de producto

1. **Fundación (tickets 0-2):** arquitectura extensible y guía visual enriquecida.
2. **Tutor guiado (tickets 3-4):** walkthroughs que saben dónde están y cuándo
   avanzar. Este es el primer hito diferenciador publicable.
3. **Conversación natural (tickets 5-7):** realtime, routing y continuidad local.
4. **Hacer con supervisión (tickets 8-10):** dictado, herramientas y documentos
   bajo controles comunes.
5. **Autonomía limitada (ticket 11):** solo después de validar permisos,
   confirmaciones, cancelación y trazabilidad.

Los tickets 3 y 5 pueden desarrollarse en paralelo una vez cerrado el ticket 1.
El ticket 7 también puede avanzar después del 1. Los tickets 9 y 11 no deben
adelantarse: son la frontera de mayor riesgo del producto.

## Criterios transversales para todos los tickets

- Preservar un fallback funcional al pipeline actual durante la migración.
- Añadir pruebas de contratos, máquina de estados y políticas; no depender solo
  de pruebas UI manuales.
- Medir latencia, fallos, cancelaciones y fallback sin registrar audio, capturas
  ni contenido sensible por defecto.
- Separar claramente observación, recomendación y acción.
- Toda acción externa debe ser cancelable y aplicar el principio de mínimo
  privilegio.
- Diseñar migración/borrado de datos antes de persistir memoria o documentos.

## Riesgos y preguntas para la planificación detallada

- Definir si el MVP comercial exige voz realtime o si el primer lanzamiento
  debe concentrarse en walkthroughs sobre el pipeline existente.
- Elegir qué datos puede procesar el Worker y cuáles deben permanecer locales.
- Validar capacidades, costos, autenticación efímera y límites vigentes del
  proveedor realtime con documentación oficial.
- Determinar qué señales son fiables para completar un paso: clic global,
  Accessibility, diferencia visual o confirmación del usuario.
- Diseñar comportamiento para SecureTextEntry, Terminal, diálogos del sistema y
  acciones irreversibles antes de implementar escritura/clic.

## Complejidad global

| Dimensión | Puntuación | Motivo |
|---|---:|---|
| Técnica | 9/10 | Audio bidireccional, overlays, AX, persistencia y agentes |
| Integración | 9/10 | App macOS, Worker y varios proveedores/modelos |
| Pruebas | 9/10 | Permisos TCC, múltiples apps/pantallas y estados realtime |
| Rollout | 8/10 | Privacidad, costos, fallbacks y acciones sobre otras apps |

**Complejidad global recomendada: 9/10.** El programa completo corresponde a
`$cce-feature`; cada fila debe convertirse después en su propio plan CCE, no en
un único ticket de implementación.

## Especialización recomendada

- **Dueño del programa:** `cce-full-stack`.
- **Tickets macOS/UI/permisos:** `cce-mobile` + `write-swift`; añadir
  `apple-design` para walkthroughs y confirmaciones.
- **Voz, routing y evaluación:** `cce-ai-engineer` + `openai-docs` cuando se
  decida usar capacidades OpenAI vigentes.
- **Worker, persistencia remota o integraciones:** `cce-backend`.

Capacidades útiles disponibles: inspección/edición local, ejecución de pruebas
no destructivas, consulta de documentación oficial y automatización UI para
validación manual. No se presupone ninguna integración externa instalada.

## Siguiente prompt listo para ejecutar

`$cce-feature Diseña el programa de evolución de Cursy descrito en workflow/00-context/ct001-capability-roadmap.md. Conserva la ruta por hitos y descompón el programa en tickets independientes con contratos, dependencias, criterios de aceptación, estrategia de pruebas, privacidad, rollout y gates de seguridad. Prioriza Fundación y Tutor guiado; deja agentes autónomos fuera del MVP.`

## Recomendación

Planificar el programa con `$cce-feature`, pero ejecutar primero `tsk000` y luego
crear planes independientes para los tickets 1 y 2. El primer hito de producto
debe ser walkthroughs persistentes con verificación supervisada; voz realtime
debe apoyarse en el mismo núcleo de sesiones, no precederlo.
