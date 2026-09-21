# tsk008 — Conversaciones persistentes y memoria controlada

Status: planned
Date: 2026-09-19
Type: feature (11 layers)
Complexity: 7/10
Priority: P1 — fundamento para guías y agentes
Dependencies: tsk007
Owner: cce-mobile; write-swift; apple-design para navegación/borrado
Context: ct012, ct001; contrato común del programa en ct012, sección «Tickets formalizados».

Plan, no implementación. Nombres de archivos nuevos son propuestos; archivos Swift existentes bajo cursy-app/Cursy/, backend bajo cursy-app/worker/src/. Presupuestos son objetivos iniciales a medir, no resultados. Conservar macOS14.2, idioma Swift actual y cambios del usuario; no migrar toolchain en este ticket.

## 1. Contexto estratégico

Extender continuidad aceptada a reinicios y conversaciones separadas sin mezclar objetivos.

## 2. Necesidades y experiencia

Crear, renombrar, buscar, archivar, reabrir y eliminar conversaciones; modo temporal visible. Mostrar qué se conserva y permitir borrar historial.

## 3. Requisitos y no objetivos

Persistir texto/objetivo y estado terminal; lista paginada y borrador por conversación. Contexto enviado al modelo sigue acotado. No sincronización cloud, memoria inferida oculta, almacenamiento automático de pantallas/audio ni agentes.

## 4. Sistema existente y evidencia

ConversationSession.swift y RealtimeConversationMemory.swift son base aceptada, con historial de diez intercambios. No reescribir su máquina de estados; separar historial duradero de ventana de contexto del modelo.

2026-09-20: tsk007 añade HomeChatLibrary (hasta 20 chats solo en memoria), sidebar
y snapshots terminales con ID de sesión nuevo al restaurar. Reutilizar esa
navegación y aislamiento; no confundirlos con persistencia, búsqueda o archivo.
Este ticket y su elección opt-in siguen pendientes; no hay texto guardado a disco.

## 5. Arquitectura e impacto de archivos

Añadir ConversationStore/ConversationRecord y adaptador a ConversationSession; integrar HomeView y CompanionManager. Propuesta: SQLite local mediante biblioteca del sistema, acceso serial y consultas fuera del trabajo de render; confirmar enlace/toolchain en fase 1 sin paquete externo.

## 6. Datos, contratos, migración y ciclo de vida

Schema v1: Conversation(id,title,objective,mode,createdAt,updatedAt,archived), Message(id,conversationID,turnID,role,text,status,sequence), Draft. Transacciones y migraciones versionadas; imports de sesión actual solo tras opt-in. Reinicio marca operaciones no terminadas como interrupted, nunca vuelve a enviarlas automáticamente. Mensajes inmutables por ID, borrar cancela callbacks de esa conversación.

## 7. Seguridad y privacidad

Persistencia local opt-in en primera apertura; modo temporal por defecto hasta elegir. Archivo no cifrado a nivel app debe explicarse, protegido por permisos del usuario; no alegar cifrado propio. Borrado incluye índices/WAL/backups controlados por app; no prometer borrado forense ni de backups del sistema. Secretos solo Keychain.

## 8. Fiabilidad, rendimiento y observabilidad

Paginación 50 mensajes; presupuesto 10 000 mensajes sintéticos, búsqueda p95 ≤200 ms y primera página ≤250 ms en equipo de referencia. No cargar todo en UI ni reenviar todo al modelo; mantener límites existentes y presupuestar resumen si se añade posteriormente.

## 9. Dependencias e integración

Depende de tsk007 y contratos tsk003. Interfaces para guías y agentes por conversationID; aún sin esas tablas. No migración global a Swift6 ni cambio de proveedor.

## 10. Fases, pruebas, despliegue y rollback

F1 migraciones/store y pruebas de crash; F2 bridge de sesión; F3 lista/búsqueda/borrado; F4 QA. Aislamiento entre dos conversaciones, respuesta tardía tras borrado, escritura truncada, esquema más nuevo, reinicio y espacio insuficiente. Rollback usa modo temporal y conserva BD intacta; no downgrade destructivo.

## 11. Gates, métricas, documentación y responsable

Gate: 100 reinicios/migraciones simulados sin pérdida de transacciones confirmadas ni contaminación entre conversaciones; suite de sesión verde y aceptación manual de reanudación/borrado. Documentar esquema, retención y recuperación. Confirmar con usuario opt-in/retención antes de habilitar almacenamiento de conversaciones reales.

Validación común: Swift Testing para contratos; Xcode para UI/build completo, nunca xcodebuild por terminal. Aplicar regresiones de sesiones/visualización y Worker cuando se toquen sus rutas. Pruebas reales con pantallas/datos privados requieren autorización específica. Despliegue, cuentas y compras no autorizados por este plan. Registrar evidencia por fase; no cerrar antes de sus gates.

Dispatch: `$cce-dispatch execute tsk008-persistent-conversations`
