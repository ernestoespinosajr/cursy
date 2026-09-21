# ct017 — Investigación aportada: modelos, routing y Home

- Fecha: 2026-09-19. Estado: análisis previo a tsk007; app sin modificar.
- Petición: trabajar después en tsk007, pero primero analizar la utilidad del
  documento «Resumen de modelos en HeyClicky». No ejecutar su pseudocódigo.

## Evidencia y límites

Se leyó el documento completo aportado, logbook, dependencies, tsk007, ct015,
la matriz de especialistas y configuración local de Worker/VisionAPI/Realtime,
además de ConversationSession. El documento mezcla afirmaciones sobre una sesión
de HeyClicky con propuestas de PRD, prompts y contratos; no aporta trazas del
proveedor que certifiquen su routing o modelos actuales.

Se consultaron https://www.heyclicky.com/changelog y
https://www.heyclicky.com/trust. El changelog anuncia Realtime 2.1 y derivación
de preguntas de pantalla/detalle a un modelo profundo; la búsqueda de «5.6» no
obtuvo coincidencias. No se confirma la afirmación de GPT-5.6 Sol en esa sesión.
La autoidentificación conversacional no sustituye configuración o trazas.
Sus notas públicas también describen Home redimensionable/desacoplable y evitar
adjuntar capturas del propio Home. Son declaraciones públicas, no auditoría interna.

Código local: worker/src/index.ts fija gpt-realtime-2.1 y marin; el cliente también
configura marin. VisionAPI elige gpt-6-astra para localization; Worker permite
Astra/Sol para ese propósito y GPT-4.1/mini para conversación de respaldo.
Esto confirma separación de rutas, no un router profundo general equivalente
al descrito en el documento. No se comprobó nuevamente producción.

## Utilidad concreta y reutilización

1. Para tsk007: separar presentación (oculto/compacto/expandido/desacoplado) de
   actividad (escucha/proceso/respuesta/error). El notch refleja eventos reales
   de la sesión existente, no decide cómo razona el modelo. No generar estados
   mediante otra llamada remota ni mantener una sesión competidora.
2. Correlacionar eventos con sesión/turno, descartar eventos cancelados/tardíos y
   priorizar errores recuperables o intervención necesaria. No cerrar por timer
   mientras el usuario escribe o debe responder. Evitar autoexpandir por cada
   marca visual; la guía continúa en el cursor/overlays.
3. Aplicar VoiceOver, teclado, Reduce Motion y alternativa sin notch, ya previstos.
   Reutilizar ConversationSession, CompanionManager, menú, diseño e idioma.
   Preservar contexto de la app externa antes de Home y un solo dueño del micrófono.
4. Conservar proveedores y ruta de localización aceptada. Una explicación sobre
   contenido no debe forzar un localizador de controles; señalar sí requiere
   evidencia actual y publicación validada. La derivación profunda general sería
   otro incremento evaluable, no requisito implícito de Home.

## Qué no copiar literalmente

- Routing por palabras clave: intención más conversación/evidencia, no reglas de
  nombres de apps ni una condición rígida para «mostrar».
- Pedir aclaración ante toda ambigüedad inicial: primero resolver con contexto;
  preguntar solo cuando siga existiendo ambigüedad relevante.
- Modelo más potente no equivale a búsqueda web ni a información actualizada.
- Objetivos visuales del PRD no sustituyen captura/revisión/display/dimensiones,
  validación de geometría y rechazo de evidencia antigua existentes.
- Reintentos no reparan por sí mismos pérdida de contexto. Ser acotados, conservar
  propiedad del turno y no repetir escrituras sin control de idempotencia.
- Permisos declarados en JSON no autorizan acciones. Ejecución arbitraria local,
  inserciones, agentes e integraciones quedan en tsk011–015 según alcance vigente.
- «Menos de un segundo» es una meta sin mediciones, no una garantía.

## Opciones, complejidad y ruta

A. Reutilizar arquitectura e incorporar estados/feedback en tsk007: recomendado.
B. Añadir router profundo general ahora: exigiría contrato explicativo separado,
   evaluación de calidad/latencia/coste y alcance adicional; posponer.
C. Sustituir modelos o rehacer backend según PRD: no justificado por evidencia.

Complejidad del incremento Home: técnica 7, integración 8, pruebas 8, rollout 5;
global 8/10, CCE Feature sobre el ticket existente, sin duplicarlo. Responsable
recomendado cce-mobile con write-swift/apple-design; animate al implementar
transiciones. cce-ai-engineer solo si se amplía realmente el routing/API.
Herramientas disponibles: inspección local, fuentes web oficiales, tests nativos
aislados y futura QA en Xcode. Sin llamadas pagadas, claves, capturas o despliegue.

El usuario solicita primero este análisis; tsk007 permanece planned. No se cierran
gates pendientes de tsk005/006 ni se ejecutan nuevas pruebas por esta revisión.

Siguiente prompt: `$cce-feature Refina el tsk007 existente con ct017: prototipo
Home/notch que refleje estados reales de sesión, conserve foco y contexto externo,
sin cambiar modelos ni añadir agentes o acciones locales.`
