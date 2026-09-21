# ct016 — Deepgram y Cerebras: función y prioridad

- Fecha: 2026-09-19
- Estado: contraste de investigación; sin implementación ni llamadas pagadas.
- Relación: ct015, ct014, tsk006; posibles evaluaciones futuras para tsk011.

## Petición y evidencia

El usuario aportó un documento que propone Deepgram para escuchar/hablar y
Cerebras para razonamiento rápido. Se leyó completo como material de investigación,
no como autorización de implementación. Se contrastó con documentación oficial,
logbook, dependencias, ct015 y BuddyTranscriptionProvider. CCE Ask organiza el
análisis, con CCE AI Engineer para separar prestaciones de evidencia evaluada.

## Hechos comprobados y matices

- Deepgram y Cerebras son proveedores/plataformas, no nombres de modelos únicos.
- [Deepgram STT](https://developers.deepgram.com/docs/models-languages-overview)
  distingue Nova-3 (transcripción general) de Flux (streaming con detección de
  turnos). Flux Multilingual incluye español. Para dictado push-to-talk el usuario
  ya delimita el turno; no se demuestra ventaja por añadir otro detector.
- [Deepgram TTS](https://developers.deepgram.com/docs/tts-models-languages-overview)
  recomienda Flux TTS para inglés; hoy es solo inglés. Para español ofrece Aura-2.
  Flux STT y Flux TTS son productos distintos: no confundir sus idiomas.
- [Anuncio Flux TTS](https://deepgram.com/learn/text-to-speech-comes-of-age-deepgram-launches-conversation-native-speech)
  publica inicio de síntesis tan bajo como 80 ms. No incluye capturar/subir pantalla,
  comprender gestos, inferencia del LLM, red y reproducción en nuestro Mac.
- [Cerebras Inference](https://www.cerebras.ai/inference) anuncia hasta 30× más
  velocidad, condicionada por carga/modelo/configuración. Tokens/s, primer token,
  primer audio y tiempo hasta indicación correcta son métricas distintas.
- [Catálogo público Cerebras](https://inference-docs.cerebras.ai/models/overview)
  lista hoy GPT OSS 120B y Qwen 3.8 27B. Su
  [guía de selección](https://inference-docs.cerebras.ai/models/choose-a-model)
  incluye Qwen 3.8 27B público en visión y otros modelos en endpoints dedicados.
  No basta con elegir el proveedor para obtener capacidad visual.
- [Anuncio Gemma 4](https://www.cerebras.ai/blog/gemma-4-on-cerebras-the-fastest-inference-is-now-multimodal)
  confirma inferencia multimodal, incluidas capturas. El anuncio de junio decía
  preview pública temporal; no prueba acceso público actual. La documentación de
  [endpoints dedicados](https://inference-docs.cerebras.ai/dedicated/overview)
  también conserva menciones de multimodalidad futura, mientras la guía lista
  modelos visuales. Verificar endpoint, modalidad, esquema y acceso antes de integrar;
  la página específica Qwen extraída no expuso especificaciones suficientes.
- [Privacidad HeyClicky](https://www.heyclicky.com/privacy-policy) identifica los
  cuatro proveedores, sin revelar la asignación exacta. «Deepgram escucha y
  Cerebras responde» es una arquitectura plausible, no un hecho demostrado sobre
  HeyClicky. No se verificaron popularidad, cuotas de mercado ni claims de reseñas.

## Consecuencias para Cursy

El problema de ct014 sigue siendo comprensión/routing/preservación de evidencia,
no una insuficiencia demostrada de transcripción o velocidad de generación.
Deepgram no es el analizador de capturas que sustituiría esa pieza. Cerebras sí
merece evaluación visual con un modelo multimodal concreto, pero aún no demuestra
mayor precisión que la comparación Astra/Fable propuesta en ct015.

Reutilizar el protocolo BuddyTranscriptionProvider para evaluar dictado aislado;
su factory solo integra AssemblyAI/OpenAI/Apple actualmente. Eso no sustituye el
canal speech-to-speech Realtime. Migrar Talk a STT → LLM → TTS exige planificar
cancelación, interrupciones, sincronía de voz/gesto, sesiones y errores entre servicios.
Transcribir tampoco implementa por sí solo inserción segura en el campo activo.

Alternativas:
1. Mantener voz y corregir comprensión espacial primero: recomendado ahora.
2. Añadir candidato multimodal de Cerebras al mismo banco de pruebas, sujeto a
   acceso y presupuesto; admisión por precisión, no por tokens/s publicitados.
3. Migrar simultáneamente voz, análisis y síntesis: diferir; amplía variables y
   no resuelve por sí sola el contrato UI-only. Evaluar Deepgram por separado
   para dictado/español, y voz continua si se prioriza posteriormente.

Medir errores en nombres/español, pausas e interrupciones para voz; referencias
resueltas y marcas erróneas para visión; latencia extremo a extremo y coste por
petición correcta para ambos. Sintéticos por defecto, sin enviar datos privados
ni añadir llamadas comerciales sin consentimiento/presupuesto. Sin promesa de 100%.

## Ruta

Refinamiento tsk006: 6/10 (contratos 6, integración 5, evaluación 6, rollout 4),
CCE Quick Feature sobre ct014–016, sin nuevo ticket. Migración completa STT/LLM/TTS
sería 8/10 y requeriría CCE Feature separado cuando se autorice; no se planifica aquí.
Owner recomendado: cce-ai-engineer; write-swift para cambios nativos y backend
si cambia el proxy. Herramientas disponibles: lectura local, web oficial y pruebas
locales; no se usaron claves, API de inferencia ni despliegues.

Siguiente prompt: `$cce-quick-feature Refina tsk006 con ct014–016, manteniendo la
voz actual; separa comprensión y señalamiento, y diseña la comparación visual
por precisión antes de optimizar proveedores, latencia o coste.`
