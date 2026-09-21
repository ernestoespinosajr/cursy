// Extend the accepted Home lab; production Swift and real devices are untouched.
const inputLab = new HomeInputLab();
const escapeHomeText = value => String(value).replace(/[&<>"']/g, character => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[character]));
let replyTimer, microphonePermission = 'allowed', shortcutCapture = false, shortcutNotice = '';
Object.assign(preferences, {readAloud:true, listeningHint:true, refresh:true, shortcut:'Control + Opción'});
const inputBaseContent = contentMarkup;
const deviceNames = {system:'Predeterminado del sistema', builtin:'Micrófono del Mac', headset:'Auriculares · Ejemplo', missing:'Dispositivo desconectado · Ejemplo'};
const demoNote = '<span class="demo-note">Prototipo interactivo · Sin audio ni red</span>';
function contentMarkupWithInput() {
 if (section === 'chats') {
  const record = inputLab.chat(selectedChat, chats[selectedChat]);
  return `<div class="thread-scroll" tabindex="0" aria-label="Mensajes de la conversación">${record.messages.length ? record.messages.map(message => `<div class="message ${message.role === 'user' ? 'user' : ''}"><small>${message.role === 'user' ? 'Tú' : 'Cursy · Ejemplo'}</small><p>${escapeHomeText(message.text)}</p></div>`).join('') : `<div class="chat-welcome">${sf('cursorarrow.motionlines')}<h2>¿Qué hacemos hoy?</h2><p>Escribe o mantén Control + Opción para hablar.<br>El contexto lo construimos conversando.</p><button data-example-message>Probar con un mensaje de ejemplo</button></div>`}${inputLab.pending?.id === selectedChat ? '<p class="reply-status" role="status">Preparando respuesta de ejemplo…</p>' : ''}</div>
  <form class="composer" aria-label="Mensaje a Cursy"><label class="sr-only" for="home-message">Escribe a Cursy</label><textarea id="home-message" rows="2" maxlength="4000" placeholder="Escribe a Cursy…">${escapeHomeText(record.draft)}</textarea><div class="composer-actions"><button type="button" data-composer-voice title="Ver escucha simulada">${sf('mic')}<span>Hablar</span></button><small>Enter envía · ⇧ Enter nueva línea</small>${inputLab.pending ? '<button type="button" class="send-button" data-stop-reply aria-label="Detener respuesta de ejemplo">'+sf('xmark')+'</button>' : '<button type="submit" class="send-button" aria-label="Enviar mensaje de prueba" '+(!record.draft.trim()?'disabled':'')+'>'+sf('chevron.up')+'</button>'}</div></form><div class="composer-disclosure">${demoNote}<span>Sin adjuntar pantalla al escribir</span></div>`;
 }
 if (section === 'microphone') return `<h2>Micrófono</h2><p>Tu voz, con claridad.</p>${demoNote}<div class="settings-list"><div class="setting-row"><label for="input-device">Entrada de audio</label><select id="input-device">${Object.entries(deviceNames).map(([id,name])=>`<option value="${id}" ${inputLab.microphone === id?'selected':''}>${name}</option>`).join('')}</select></div></div><div class="input-test-card"><div class="test-heading">${sf('mic')}<div><h3>Prueba de nivel</h3><p>En la app será local, sin subir audio.</p></div></div><div class="level-track" role="meter" aria-label="Nivel de entrada simulado" aria-valuemin="0" aria-valuemax="100" aria-valuenow="${inputLab.testState === 'testing' ? 55 : 0}"><div style="transform:scaleX(${inputLab.testState === 'testing' ? .55 : 0})"></div></div><p id="input-test-status" role="status">${{idle:'La prueba está detenida.',testing:'Prueba simulada activa. Ajusta el nivel de muestra.',denied:'Sin permiso de micrófono. Revisa el acceso antes de probar.',missing:'Ese dispositivo ya no está disponible. Elige otra entrada.'}[inputLab.testState]}</p><button id="input-test-button" data-test-input>${sf(inputLab.testState === 'testing'?'xmark':'waveform')}${inputLab.testState === 'testing'?'Detener prueba':'Probar micrófono · Simulación'}</button></div><details class="scenario-controls"><summary>Escenarios de prueba</summary><label for="input-permission">Permiso simulado</label><select id="input-permission"><option value="allowed" ${microphonePermission==='allowed'?'selected':''}>Permitido</option><option value="denied" ${microphonePermission==='denied'?'selected':''}>Denegado</option></select><label for="input-level">Nivel simulado</label><input id="input-level" type="range" min="0" max="100" value="55" ${inputLab.testState==='testing'?'':'disabled'}><p>Los dispositivos son ejemplos, no una lista detectada en tu Mac.</p></details>`;
 if (section === 'voice') return `<h2>Voz</h2><p>Hablar y escribir, una sola conversación.</p><div class="settings-list">${toggleRow('readAloud','Leer respuestas en voz alta')}<div class="setting-row"><span>Voz actual</span><span class="setting-value">Marin</span></div><div class="setting-row"><span>Velocidad</span><span class="setting-value">La del proveedor</span></div></div><p class="explanation">La lectura automática es una preferencia de muestra. La voz actual se conserva; no ofrecemos voces ni velocidades que todavía no estén conectadas al proveedor.</p><button data-section="microphone">${sf('mic')}Configurar micrófono</button>`;
 if (section === 'shortcuts') return `<h2>Atajos</h2><p>Cursy, a un gesto de distancia.</p><div class="settings-list"><div class="setting-row"><label for="talk-shortcut">Mantener para hablar</label><button id="talk-shortcut" data-record-shortcut aria-pressed="${shortcutCapture}">${shortcutCapture?'Pulsa una combinación…':escapeHomeText(preferences.shortcut)}</button></div></div><p id="shortcut-notice" class="explanation" role="status">${shortcutNotice || 'Haz clic para ensayar otro atajo. Escape cancela; no cambia el atajo del Mac.'}</p><button data-reset-shortcut>${sf('arrow.clockwise')}Restablecer Control + Opción</button><p class="explanation">El prototipo valida combinaciones reservadas de muestra. Los conflictos reales con otras apps se comprobarán en la implementación nativa.</p>`;
 if (section === 'help') return `<h2>Ayuda</h2><p>Lo esencial, sin salir de Home.</p><div class="help-card"><h3>Habla, escribe o señala</h3><p>Usa el atajo para hablar. Para una pregunta por texto, escribe abajo en tu chat. Si compartes pantalla, puedes señalar mientras hablas.</p><button data-section="chats">${sf('bubble.left.and.bubble.right')}Volver a la conversación</button></div><p class="explanation">Esta versión solo prueba el diseño. No envía comentarios, no reproduce audio y no cierra Cursy.</p>`;
 if (section === 'privacy') return `<h2>Privacidad</h2><p>Siempre sabes qué compartes.</p><div class="settings-list">${toggleRow('screen','Compartir pantalla al hablar')}${toggleRow('refresh','Actualizar indicación')}${toggleRow('spatial','Señalar mientras hablas')}${toggleRow('listeningHint','Mostrar aviso «Señala mientras hablas»')}</div><p class="explanation">Escribir no adjunta la pantalla automáticamente. En esta demo no se captura ni se envía nada. La prueba de micrófono es simulada y los chats desaparecen al recargar.</p>`;
 return inputBaseContent();
}
contentMarkup = contentMarkupWithInput;
const inputBaseRender = renderWorkspace;
renderWorkspace = function() {
 const activeID = stage.contains(document.activeElement) ? document.activeElement.id : '';
 inputBaseRender();
 stage.querySelector('.workspace-content')?.classList.toggle('with-composer',section === 'chats');
 if (section === 'microphone' && ['connecting','listening','processing','responding'].includes(mode)) {
  document.getElementById('input-test-button').disabled = true;
  document.getElementById('input-test-status').textContent = 'Primero termina la interacción de voz simulada (Conversación o En reposo en el laboratorio).';
 }
 if (activeID) document.getElementById(activeID)?.focus({preventScroll:true});
};
function cancelExampleReply() { clearTimeout(replyTimer); inputLab.cancel(); }
function sendExampleMessage() {
 const id = selectedChat, token = inputLab.send(id);
 if (!token) return;
 if (!chats[id].request) chats[id].title = inputLab.chat(id).messages[0].text.slice(0,38);
 renderWorkspace();
 document.getElementById('home-message')?.focus({preventScroll:true});
 replyTimer = setTimeout(() => {
  const response=inputLab.chat(id).selectionContext?'Respuesta de ejemplo: esta conversación se limita al fragmento seleccionado y a tus preguntas sobre él. No incluye la pantalla ni otros chats.':'Esta es una respuesta de ejemplo para probar el diseño. En la app, Cursy responderá usando tu mensaje y el contexto de la conversación.';
  if (!inputLab.answer(id,token,response)) return;
  renderWorkspace();
  const thread=stage.querySelector('.thread-scroll'); if(thread)thread.scrollTop=thread.scrollHeight;
 }, 650);
}
stage.addEventListener('submit', event => { if(event.target.matches('.composer')) {event.preventDefault();sendExampleMessage();} });
stage.addEventListener('input',event => {
 if(event.target.id === 'home-message') {
  inputLab.setDraft(selectedChat,event.target.value);
  const button=stage.querySelector('.send-button[type="submit"]');if(button)button.disabled=!event.target.value.trim();
 }
 if(event.target.id === 'input-level') {
  const level=Number(event.target.value), meter=stage.querySelector('.level-track');
  meter.setAttribute('aria-valuenow',level);meter.firstElementChild.style.transform=`scaleX(${level/100})`;
 }
});
stage.addEventListener('click',event => {
 if(event.target.closest('[data-chat],[data-new]')) { cancelExampleReply(); renderWorkspace(); }
 if(event.target.closest('[data-section]')) {inputLab.stopTest();shortcutCapture=false;renderWorkspace();}
 if(event.target.closest('[data-example-message]')) {inputLab.setDraft(selectedChat,'Ayúdame a organizar estas ideas.');renderWorkspace();document.getElementById('home-message').focus();}
 if(event.target.closest('[data-stop-reply]')) {cancelExampleReply();renderWorkspace();}
 if(event.target.closest('[data-composer-voice]')) {cancelExampleReply();inputLab.stopTest();stopDemo();setMode('listening');}
 if(event.target.closest('[data-test-input]')) {inputLab.testState==='testing'?inputLab.stopTest():inputLab.startTest(microphonePermission);renderWorkspace();}
 if(event.target.closest('[data-record-shortcut]')) {shortcutCapture=!shortcutCapture;shortcutNotice='';renderWorkspace();}
 if(event.target.closest('[data-reset-shortcut]')) {preferences.shortcut='Control + Opción';shortcutCapture=false;shortcutNotice='Atajo de muestra restablecido.';renderWorkspace();}
});
stage.addEventListener('change',event => {
 if(event.target.id==='input-device') {inputLab.selectMicrophone(event.target.value);renderWorkspace();}
 if(event.target.id==='input-permission') {microphonePermission=event.target.value;inputLab.stopTest();renderWorkspace();}
});
document.addEventListener('keydown',event => {
 if(shortcutCapture) {
  event.preventDefault(); event.stopImmediatePropagation();
  if(event.key==='Escape') {shortcutCapture=false;shortcutNotice='Cambio cancelado.';}
  else if(['Control','Alt','Meta','Shift'].includes(event.key))return;
  else if(!(event.ctrlKey||event.altKey||event.metaKey)||((event.metaKey||event.ctrlKey)&&['q','w','r','c','v','x','a','t','l','n'].includes(event.key.toLowerCase())))shortcutNotice='Combinación reservada o incompleta. Prueba Control + Mayúsculas + K.';
  else {preferences.shortcut=[event.ctrlKey?'Control':'',event.altKey?'Opción':'',event.metaKey?'Comando':'',event.shiftKey?'Mayúsculas':'',event.key.toUpperCase()].filter(Boolean).join(' + ');shortcutCapture=false;shortcutNotice='Atajo guardado solo en la demo.';}
  renderWorkspace();return;
 }
 if(event.target.id==='home-message' && event.key==='Enter' && !event.shiftKey && !event.isComposing) {event.preventDefault();sendExampleMessage();}
},true);
const inputBaseShow = showConversation;
showConversation = function(show) {if(!show){inputLab.stopTest();shortcutCapture=false;cancelExampleReply();} inputBaseShow(show);renderWorkspace();};
const inputBaseMode = setMode;
setMode = function(next) {inputLab.stopTest();cancelExampleReply();inputBaseMode(next);renderWorkspace();};
const inputBaseHint = updateHint;
updateHint = function() {inputBaseHint(); if(!preferences.listeningHint){const hint=stage.querySelector('.spatial-hint');hint?.classList.remove('visible');hint?.setAttribute('aria-hidden','true');}};
document.addEventListener('visibilitychange',()=>{if(document.hidden){inputLab.stopTest();cancelExampleReply();renderWorkspace();}});
document.querySelector('.tag').textContent='Cursy / Texto y ajustes · F3';
