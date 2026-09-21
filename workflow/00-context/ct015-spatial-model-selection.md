# ct015 — Modelos para comprensión espacial

- Fecha: 2026-09-19
- Estado: investigación; sin cambios de app, proveedor, despliegue ni evaluación pagada.
- Relacionados: tsk006, ct014 (fallos de integración), ct012 (research), ct010 (localización).

## Petición y evidencia

Investigar qué declara HeyClicky y qué modelo conviene para comprender contenido
señalado: texto, ilustraciones, objetos y controles; no solo devolver coordenadas.
CCE Ask organiza el análisis; CCE AI Engineer y OpenAI Docs orientan la selección.
Se revisaron memoria, dependencias, routing matrix y configuración/prompt locales.

Fuentes oficiales consultadas hoy:

- [HeyClicky changelog](https://www.heyclicky.com/changelog): v1.0.31 (1 julio)
  anuncia Claude Fable 5 como predeterminado destacando comprensión de pantalla;
  v1.0.33 (6 julio) anuncia gpt-realtime-2.1 para voz y contexto espacial.
  v1.0.45 describe selección entre modelos rápidos y profundos; actualizaciones
  posteriores mantienen derivación de preguntas visuales a un modelo profundo,
  sin identificar aquí su versión exacta. Son declaraciones del fabricante,
  no trazas de su producción ni evaluación independiente.
- [Trust](https://www.heyclicky.com/trust): declara captura al activar el atajo,
  no observación continua, y procesamiento remoto con Anthropic/OpenAI.
- [Privacidad](https://www.heyclicky.com/privacy-policy): declara Anthropic,
  OpenAI, Deepgram y Cerebras; lista proveedores, no una asignación completa
  modelo-función. No demuestra streaming de vídeo ni cómo codifican el gesto.
- [Claude Fable 5.1](https://platform.claude.com/docs/en/models/fable-5-1/overview):
  modelo vigente con entrada de texto/imágenes, latencia comparativa más lenta;
  $10/$50 por millón de tokens entrada/salida. Recomienda Opus 5 para la mayoría
  de cargas y Fable para exigencias superiores. Atención: forced tool use falla
  en 5.1; no es compatible sin adaptación con un contrato de herramienta forzada.
- [Anuncio Fable 5.1](https://www.anthropic.com/claude-fable-and-mythos-5-1):
  reporta mejoras sobre Fable 5, incluidas pruebas de computer use. Estos
  benchmarks no miden nuestro gesto+captura ni garantizan precisión perfecta.
- [GPT-6 Astra](https://developers.openai.com/api/docs/models/gpt-6-astra):
  entrada de imagen, razonamiento configurable y computer use; candidato vigente
  que ya utiliza nuestro localizador.
- [GPT Realtime 2.1](https://developers.openai.com/api/docs/models/gpt-realtime-2.1):
  admite audio, texto e imagen y herramientas; mantenerlo para voz es una decisión
  arquitectónica propuesta, no una afirmación de que carece de visión.

No hay evidencia pública revisada de que HeyClicky haya migrado específicamente
a Fable 5.1. El modelo anunciado Fable 5 y el candidato nuevo Fable 5.1 no deben
confundirse. No se comprobó acceso de nuestra cuenta a 5.1.

## Contraste con Cursy

`VisionAPI.swift:7` selecciona Astra; `worker/src/index.ts:91` configura Realtime
2.1. `ElementLocationDetector.swift:311` y `worker/src/vision.ts:47` definen un
localizador de UI con punto/null, no un analizador explicativo general. ct014
demuestra un conflicto de enrutamiento y pérdida de evidencia tras refrescos.
Cambiar de proveedor sin corregir esta frontera no prueba ni garantiza solución.

ct010 obtuvo Astra 12/12 y Sonnet 5 12/12 en repeticiones sobre cuatro objetivos
de una sola captura. No era una evaluación de gestos, anatomía, lectura ni
comprensión general. No extrapolar a 100% ni descartar Astra por el fallo actual.

## Alternativas y recomendación

1. Corregir contrato/routing y conservar Astra: menor cambio de infraestructura.
2. Corregir lo mismo y comparar Astra con **Fable 5.1**: recomendado para priorizar
   calidad, usando este último como primer candidato alternativo, no ganador
   declarado. Sonnet 5 puede ser candidato posterior de latencia/coste; su
   evaluación de coordenadas no lo califica todavía para comprensión espacial.
3. Sustituir todo, incluida voz, por Claude: no justificado; perdería aislamiento
   y no resuelve los errores de integración demostrados.

Reutilizar captura y geometría, sesión, recorder y frontera Worker. Separar
resultado semántico (referencia resuelta + explicación) de publicación opcional.
Evaluar imagen limpia+trayectoria frente a representación visual auxiliar y
región ampliada, sin alterar arbitrariamente coordenadas ni introducir OCR.
El segundo formato requiere planificar el contrato actualmente de una imagen.
No interpretar contenido de pantalla o marcas como instrucciones privilegiadas.

Medir comprensión, región elegida, indicación errónea, ambigüedad, latencia y
coste por petición resuelta. Mantener conjunto general 20 casos × 3 repeticiones
por configuración: texto, diagramas, objetos, controles, negativos, scroll y dos
monitores. Registrar por separado fallos de transporte/routing/modelo/publicación.
No rebajar el gate pendiente de tsk006 ni pedir QA sin corregir la integración.
Datos sintéticos por defecto; cualquier captura privada y gasto de comparación
requieren autorización específica y presupuesto antes de llamadas pagadas.

## Ruta y límites

Complejidad global 6/10: contrato semántico 6, integración 5, evaluación 6,
rollout 4. Refinar tsk006 mediante CCE Quick Feature; no otro ticket.
Owner de ejecución recomendado: cce-ai-engineer; write-swift en cambios nativos,
cce-backend si cambia Worker, openai-docs para la ruta OpenAI.
Capacidades disponibles: lectura de código, documentación oficial, pruebas
locales; futuras comparaciones API y despliegue solo con autorización.

No se cargaron claves, enviaron capturas, ejecutaron modelos de pago ni cambió
la app. La investigación no cuenta como aceptación de tsk006.

Siguiente prompt: `$cce-quick-feature Refina tsk006 con ct014 y ct015: separa
comprensión espacial de señalamiento y prepara una comparación controlada entre
GPT-6 Astra y Claude Fable 5.1, conservando voz, validaciones y privacidad.`
