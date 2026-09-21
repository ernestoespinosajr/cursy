// Selection is observed only inside this synthetic document, never other apps.
const selectionContext = new SelectionContext();
const selectionSource = document.querySelector('.note p');
const selectionEntry = document.createElement('button');
selectionEntry.textContent='Probar texto seleccionado';
document.querySelector('.lab .controls').prepend(selectionEntry);
const selectionControls=document.createElement('div');
selectionControls.className='selection-lab-controls';
selectionControls.innerHTML=`<h2>Selecciona. Pregunta. Sigue.</h2><p>Selecciona una frase del documento y pulsa «Preguntarle a Cursy». Después escribe o prueba el micrófono.</p><div class="controls"><button data-sample-selection>Seleccionar una frase de ejemplo</button><button data-selection-exit>Volver a Home</button></div><p>Solo texto seleccionado · Sin pantalla ni historial previo · Voz simulada, sin audio.</p><span id="selection-feedback" class="sr-only" role="status"></span>`;
selectionControls.querySelector('.controls').insertAdjacentHTML('beforeend','<button data-menu-sample aria-pressed="true">Menú de otra app · Simulado</button><button data-selection-finish disabled>Simular mi respuesta por voz</button>');
document.querySelector('.lab').append(selectionControls);
const selectionAppMenu=document.createElement('div');
selectionAppMenu.className='selection-app-menu';selectionAppMenu.dataset.selectionObstacle='';selectionAppMenu.hidden=true;
selectionAppMenu.setAttribute('aria-label','Menú de otra app simulado');
selectionAppMenu.innerHTML='<span>Agregar al chat</span><span>Más detalles</span><span>Preguntar en chat lateral</span>';
document.body.append(selectionAppMenu);
let selectionMenuEnabled=true;
const selectionPopover=document.createElement('div');
selectionPopover.id='selection-popover';selectionPopover.className='selection-pop';
selectionPopover.setAttribute('popover','auto');selectionPopover.setAttribute('role','region');selectionPopover.setAttribute('aria-label','Preguntar por el texto seleccionado');
document.body.append(selectionPopover);
const selectionVoiceCard=document.createElement('section');
selectionVoiceCard.className='selection-voice-card';selectionVoiceCard.inert=true;selectionVoiceCard.setAttribute('aria-hidden','true');
selectionVoiceCard.setAttribute('aria-label','Conversación sobre la selección');
const selectionVoiceSlot=document.createElement('div');selectionVoiceSlot.className='selection-voice-slot';selectionVoiceSlot.append(selectionVoiceCard);document.body.append(selectionVoiceSlot);
let selectionAnchor, selectionGreetingTimer, selectionVoiceChat=null, selectionInternal=false, selectionHandingOff=false;
const selectionGreeting='Tengo el fragmento. ¿Qué te gustaría entender o cambiar?';
let cancelSelectionMorph=()=>{};

function morphSelectionEditor(before,oldButton,oldButtonRect,keyboard) {
 cancelSelectionMorph();
 if(keyboard)return;
 const editor=selectionPopover.querySelector('.selection-editor');
 const after=selectionPopover.getBoundingClientRect();
 const geometry=selectionMorphGeometry(before,after);
 const animations=[],layers=[];
 const finish=()=>{
  animations.forEach(animation=>{animation.onfinish=null;animation.cancel();});
  layers.forEach(layer=>layer.remove());selectionPopover.classList.remove('is-morphing');
  if(cancelSelectionMorph===finish)cancelSelectionMorph=()=>{};
 };
 cancelSelectionMorph=finish;
 const ease=getComputedStyle(document.documentElement).getPropertyValue('--ease-out').trim();
 if(reduced()||!geometry) {
  const fade=editor.animate([{opacity:0},{opacity:1}],{duration:150,easing:ease});
  animations.push(fade);fade.onfinish=finish;return;
 }
 // FLIP only the material; labels and editable content never inherit scale.
 const surface=document.createElement('div');surface.className='selection-morph-surface';surface.setAttribute('aria-hidden','true');
 oldButton.className='selection-morph-label';oldButton.inert=true;oldButton.setAttribute('aria-hidden','true');
 Object.assign(oldButton.style,{left:`${oldButtonRect.left-after.left-1}px`,top:`${oldButtonRect.top-after.top-1}px`,width:`${oldButtonRect.width}px`,height:`${oldButtonRect.height}px`});
 selectionPopover.classList.add('is-morphing');selectionPopover.append(surface,oldButton);layers.push(surface,oldButton);
 const material=surface.animate([
  {transform:`translate(${geometry.x}px,${geometry.y}px) scale(${geometry.scaleX},${geometry.scaleY})`},
  {transform:'translate(0px,0px) scale(1,1)'}
 ],{duration:250,easing:'cubic-bezier(0.77, 0, 0.175, 1)',fill:'both'});
 animations.push(material,
  oldButton.animate([{opacity:1},{opacity:0}],{duration:100,easing:ease,fill:'both'}),
  editor.animate([{opacity:0},{opacity:1}],{duration:150,delay:80,easing:ease,fill:'both'}));
 material.onfinish=finish;
}

function hideSelectionPopover() { cancelSelectionMorph();if(selectionPopover.matches(':popover-open'))selectionPopover.hidePopover(); }
function resetSelection() {
 clearTimeout(selectionGreetingTimer);selectionContext.cancel();selectionVoiceChat=null;
 selectionVoiceCard.classList.remove('is-visible');selectionVoiceCard.inert=true;selectionVoiceCard.setAttribute('aria-hidden','true');
 selectionControls.querySelector('[data-selection-finish]').disabled=true;
 selectionAppMenu.hidden=true;hideSelectionPopover();
}
function selectionMode(next) { selectionInternal=true;try{setMode(next);}finally{selectionInternal=false;} }
const selectionBaseMode=setMode;
setMode=function(next) {if(!selectionInternal)resetSelection();selectionBaseMode(next);};
const selectionBaseShow=showConversation;
showConversation=function(show) {
 if(show&&selectionVoiceChat!==null) {
  resetSelection();document.body.classList.remove('selection-demo');selectionMode('conversation');return;
 }
 selectionBaseShow(show);
};
const selectionBaseHint=updateHint;
updateHint=function() {
 selectionBaseHint();
 if(selectionVoiceChat!==null) {const hint=stage.querySelector('.spatial-hint');hint?.classList.remove('visible');hint?.setAttribute('aria-hidden','true');}
 if(selectionVoiceChat!==null&&activationReady)selectionVoiceCard.classList.add('is-visible');
};
const selectionBaseContent=contentMarkup;
contentMarkup=function() {
 const html=selectionBaseContent(),context=section==='chats'?inputLab.chat(selectedChat).selectionContext:null;
 if(!context)return html;
 return html.replace('<div class="thread-scroll"',`<div class="selection-context"><small>CONTEXTO · SOLO TEXTO SELECCIONADO</small><blockquote>${escapeHomeText(context.text)}</blockquote></div><div class="thread-scroll"`);
};
const selectionBaseRender=renderWorkspace;
renderWorkspace=function() {
 selectionBaseRender();
 const onlySelection=!!inputLab.chat(selectedChat).selectionContext;
 const screen=stage.querySelector('[data-screen]');
 if(screen){screen.disabled=onlySelection;screen.setAttribute('aria-pressed',String(!onlySelection&&preferences.screen));screen.title=onlySelection?'Este chat usa solo el texto seleccionado':'Compartir pantalla (simulación)';}
};
function placeSelectionPopover() {
 if(!selectionAnchor||!selectionPopover.matches(':popover-open'))return;
 const bounds=selectionPopover.getBoundingClientRect();
 const obstacles=[...document.querySelectorAll('[data-selection-obstacle]')].filter(el=>!el.hidden&&el.getClientRects().length).map(el=>el.getBoundingClientRect());
 const point=selectionPosition(selectionAnchor,bounds.width,bounds.height,{width:innerWidth,height:innerHeight},obstacles);
 if(!point){hideSelectionPopover();document.getElementById('selection-feedback').textContent='No hay espacio libre. Desplaza el documento y vuelve a seleccionar.';return;}
 selectionPopover.style.left=`${point.left}px`;selectionPopover.style.top=`${point.top}px`;
 selectionPopover.style.transformOrigin=point.below?'center top':'center bottom';
}
function placeSelectionAppMenu() {
 selectionAppMenu.hidden=!selectionMenuEnabled||!selectionAnchor;
 if(selectionAppMenu.hidden)return;
 const bounds=selectionAppMenu.getBoundingClientRect();
 const point=selectionPosition(selectionAnchor,bounds.width,bounds.height,{width:innerWidth,height:innerHeight});
 if(!point){selectionAppMenu.hidden=true;return;}
 selectionAppMenu.style.left=`${point.left}px`;selectionAppMenu.style.top=`${point.top}px`;
}
function offerSelection(keyboard=false) {
 if(!document.body.classList.contains('selection-demo')||selectionVoiceChat!==null)return;
 const selected=window.getSelection();
 if(!selected?.rangeCount||selected.isCollapsed)return;
 const range=selected.getRangeAt(0);
 if(!selectionSource.contains(range.startContainer)||!selectionSource.contains(range.endContainer))return;
 if(!selectionContext.select(selected.toString())) {
  hideSelectionPopover();document.getElementById('selection-feedback').textContent='Selecciona un fragmento de hasta 6000 caracteres.';return;
 }
 selectionAnchor=range.getBoundingClientRect();
 cancelSelectionMorph();
 placeSelectionAppMenu();
 selectionPopover.dataset.keyboard=String(keyboard);
 selectionPopover.innerHTML=`<button data-ask-selection>Preguntarle a Cursy</button>`;
 selectionPopover.showPopover({source:selectionSource});placeSelectionPopover();
 document.getElementById('selection-feedback').textContent='Texto seleccionado. Pulsa Tab para preguntarle a Cursy.';
}
function editSelection(keyboard=false) {
 if(!selectionContext.edit())return;
 const before=selectionPopover.getBoundingClientRect();
 const trigger=selectionPopover.querySelector('[data-ask-selection]');
 const oldButton=trigger.cloneNode(true),oldButtonRect=trigger.getBoundingClientRect();
 selectionPopover.innerHTML=`<div class="selection-editor"><form><label class="sr-only" for="selection-question">Pregunta sobre el texto seleccionado</label><span id="selection-scope" class="sr-only">Solo: ${escapeHomeText(selectionContext.text)}. Sin otros chats ni pantalla. Demo.</span><input id="selection-question" aria-describedby="selection-scope" maxlength="1000" placeholder="Pregunta sobre este texto…" autocomplete="off"><button type="button" data-selection-voice aria-label="Hablar con Cursy sobre la selección">${sf('mic')}</button><button class="selection-send" type="submit" aria-label="Enviar pregunta sobre la selección" disabled>${sf('chevron.up')}</button><button type="button" data-selection-close aria-label="Cerrar pregunta">${sf('xmark')}</button></form></div>`;
 placeSelectionPopover();
 if(!selectionPopover.matches(':popover-open'))return;
 morphSelectionEditor(before,oldButton,oldButtonRect,keyboard);
 document.getElementById('selection-question').focus({preventScroll:true});
}
function createSelectionChat() {
 // Always a fresh chat: no previous messages, screen or inferred surrounding text.
 const context=selectionContext.snapshot();
 chats.push({title:'Sobre el texto seleccionado',request:'',response:''});
 selectedChat=chats.length-1;section='chats';
 inputLab.chat(selectedChat).selectionContext=context;
 return selectedChat;
}
function handOffPopover() {
 selectionAppMenu.hidden=true;
 selectionHandingOff=true;hideSelectionPopover();selectionHandingOff=false;
 window.getSelection()?.removeAllRanges();
}
function sendSelectionQuestion() {
 const question=document.getElementById('selection-question')?.value.trim();if(!question)return;
 createSelectionChat();inputLab.setDraft(selectedChat,question);handOffPopover();
 document.body.classList.remove('selection-demo');selectionMode('conversation');sendExampleMessage();
}
function renderSelectionVoice() {
 const listening=selectionContext.phase==='listening';
 selectionVoiceSlot.style.top=`${current===0?44:52}px`;
 selectionVoiceCard.innerHTML=`<header><small>Solo texto seleccionado</small><button data-selection-chat aria-label="Ver chat">${sf('bubble.left.and.bubble.right')}</button><button data-selection-stop aria-label="Terminar">${sf('xmark')}</button></header><blockquote title="${escapeHomeText(selectionContext.text)}">“${escapeHomeText(selectionContext.text)}”</blockquote><p role="status">${listening?'Te escucho.':selectionGreeting}</p>`;
 selectionVoiceCard.inert=false;selectionVoiceCard.setAttribute('aria-hidden','false');selectionVoiceCard.classList.toggle('is-visible',activationReady);
 selectionControls.querySelector('[data-selection-finish]').disabled=!listening;
}
function beginSelectionVoice(existingID=null) {
 const token=selectionContext.voice();if(token===null)return;
 const draft=document.getElementById('selection-question')?.value.trim();
 const id=existingID??createSelectionChat();selectionVoiceChat=id;
 if(draft)inputLab.setDraft(id,draft); // Preserve unsent text, never send it as an utterance.
 inputLab.chat(id).messages.push({role:'assistant',text:selectionGreeting});
 handOffPopover();stopDemo();selectionMode('greeting');renderSelectionVoice();
 document.getElementById('sequence-status').textContent='Cursy inicia la conversación sobre la selección. Saludo y escucha simulados.';
 selectionGreetingTimer=setTimeout(()=>{
  if(!selectionContext.listen(token))return;
  selectionMode('listening');renderSelectionVoice();
 },3000); // Represents simulated playback completion, not an actual audio-ready signal.
}
stage.addEventListener('click',event=>{
 if(!event.target.closest('[data-composer-voice]'))return;
 const context=inputLab.chat(selectedChat).selectionContext;if(!context)return;
 event.preventDefault();event.stopImmediatePropagation();
 selectionVoiceSlot.dataset.keyboard=String(event.detail===0);
 cancelExampleReply();selectionContext.select(context.text);selectionContext.edit();beginSelectionVoice(selectedChat);
},true);
selectionEntry.addEventListener('click',()=>{
 stopDemo();resetSelection();selectionMode('idle');document.body.classList.add('selection-demo');
 document.querySelector('.context').removeAttribute('aria-hidden');
 selectionSource.tabIndex=0;selectionSource.setAttribute('aria-label','Texto de muestra para seleccionar');
 selectionSource.textContent='Un asistente debería acompañarte sin tapar aquello en lo que estás trabajando. La mejor ayuda empieza por entender el contexto: una frase, una idea o una decisión pendiente. Al seleccionar solo lo importante, la conversación puede ser más clara y precisa.';
 selectionSource.focus({preventScroll:true});
});
selectionControls.addEventListener('click',event=>{
 if(event.target.closest('[data-menu-sample]')) {
  selectionMenuEnabled=!selectionMenuEnabled;event.target.closest('button').setAttribute('aria-pressed',String(selectionMenuEnabled));
  if(selectionContext.phase==='offered'||selectionContext.phase==='editing'){placeSelectionAppMenu();placeSelectionPopover();}
 }
 if(event.target.closest('[data-selection-finish]'))finishSelectionVoice(true);
 if(event.target.closest('[data-selection-exit]')) {resetSelection();document.body.classList.remove('selection-demo');selectionMode('conversation');}
 if(event.target.closest('[data-sample-selection]')) {
  resetSelection();selectionMode('idle');const range=document.createRange();
  range.setStart(selectionSource.firstChild,0);range.setEnd(selectionSource.firstChild,selectionSource.textContent.indexOf('.')+1);
  const selected=window.getSelection();selected.removeAllRanges();selected.addRange(range);offerSelection(event.detail===0);
  if(event.detail===0)selectionPopover.querySelector('button').focus();
 }
});
selectionSource.addEventListener('pointerup',()=>offerSelection(false));
selectionSource.addEventListener('keyup',event=>{if(event.shiftKey)offerSelection(true);});
selectionPopover.addEventListener('pointerdown',event=>{if(event.target.closest('[data-ask-selection]'))event.preventDefault();});
selectionPopover.addEventListener('click',event=>{
 if(event.target.closest('[data-ask-selection]'))editSelection(event.detail===0);
 if(event.target.closest('[data-selection-close]')){resetSelection();selectionSource.focus({preventScroll:true});}
 if(event.target.closest('[data-selection-voice]')){selectionVoiceSlot.dataset.keyboard=String(event.detail===0);beginSelectionVoice();}
});
selectionPopover.addEventListener('input',()=>{selectionPopover.querySelector('[type=submit]').disabled=!document.getElementById('selection-question').value.trim();});
selectionPopover.addEventListener('submit',event=>{event.preventDefault();sendSelectionQuestion();});
selectionPopover.addEventListener('beforetoggle',event=>{
 if(event.newState==='closed')cancelSelectionMorph();
 if(event.newState==='closed'&&!selectionHandingOff&&selectionVoiceChat===null)selectionContext.cancel();
});
function finishSelectionVoice(simulate=false) {
 const id=selectionVoiceChat;if(id===null)return;
 if(simulate)inputLab.chat(id).messages.push({role:'user',text:'Resume este fragmento. (Voz simulada)'},{role:'assistant',text:'Ejemplo de resumen: un asistente ayuda mejor cuando entiende el contexto y se centra en lo importante.'});
 resetSelection();selectedChat=id;section='chats';document.body.classList.remove('selection-demo');selectionMode('conversation');
}
selectionVoiceCard.addEventListener('click',event=>{
 if(event.target.closest('[data-selection-stop]')){resetSelection();selectionMode('idle');selectionSource.focus({preventScroll:true});}
 if(event.target.closest('[data-selection-chat]'))finishSelectionVoice();
});
document.addEventListener('keydown',event=>{
 if(event.target===selectionSource&&['ArrowLeft','ArrowRight','ArrowUp','ArrowDown','Home','End'].includes(event.key))event.stopImmediatePropagation();
 if(event.key==='Tab'&&!event.shiftKey&&selectionContext.phase==='offered'&&(event.target===selectionSource||event.target.closest('[data-sample-selection]'))) {
  event.preventDefault();event.stopImmediatePropagation();selectionPopover.querySelector('button')?.focus();
 }
 if(event.key==='Escape'&&(selectionPopover.matches(':popover-open')||selectionVoiceChat!==null)) {
  event.preventDefault();event.stopImmediatePropagation();resetSelection();selectionMode('idle');selectionSource.focus({preventScroll:true});
 }
},true);
selectionSource.closest('.context').addEventListener('scroll',()=>{selectionAppMenu.hidden=true;hideSelectionPopover();},{passive:true});
window.addEventListener('resize',()=>{selectionAppMenu.hidden=true;hideSelectionPopover();});
document.addEventListener('visibilitychange',()=>{if(document.hidden){resetSelection();if(document.body.classList.contains('selection-demo'))selectionMode('idle');}});
