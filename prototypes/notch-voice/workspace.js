// Isolated design lab. All choices stay in memory; no app preferences or audio.
const sf = (name, extra='') => `<i class="sf ${extra}" data-symbol="${name}" style="--symbol:url('symbols/${name}.png')" aria-hidden="true"></i>`;
const iconButton = (name, label, action) => `<button class="icon-button" aria-label="${label}" title="${label}" ${action}>${sf(name)}</button>`;
const palette = [['mint','Menta','#38d6a1'],['blue','Azul','#3887ff'],['coral','Coral','#ff4d57'],['gold','Dorado','#ffb829'],['violet','Violeta','#b370ff']];
const escapeChatTitle = value => String(value).replace(/[&<>"']/g, character => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[character]));
let section='chats', tint='mint', sidebarShown=true, selectedChat=0;
const chats=[{title:'Una propuesta más clara',request:'¿Cómo puedo hacer esta propuesta más clara?',response:'Empieza por el objetivo, agrupa los cambios y deja una sola decisión al final. Así es más fácil revisar lo importante.'},
 {title:'Entender un diagrama',request:'¿Qué significa esta parte del diagrama?',response:'Representa la entrada de datos. La flecha indica hacia dónde pasan al siguiente componente.'}];
const preferences={language:'Español',model:'GPT-4.1',screen:true,spatial:true,cursor:true};
const originalRender=renderVariant;
renderVariant=function(index){
 const template=document.createElement('template');template.innerHTML=originalRender(index);
 const header=template.content.querySelector('.head');
 header.innerHTML=`${iconButton('xmark','Cerrar panel','data-dismiss')}${iconButton('sidebar.left','Mostrar u ocultar barra lateral','data-sidebar')}${sf('cursorarrow.motionlines')}<div><div class="identity">Cursy<small>Temporal</small></div><div class="status">Listo para ayudarte</div></div><div class="meta"><span class="shortcut" title="Control + Opción">${sf('mic')}${sf('control')}${sf('option')}</span>${iconButton('rectangle','Compartir pantalla (simulación)','data-screen')}${iconButton('gearshape','Ajustes','data-section="general"')}${iconButton('chevron.up','Recoger conversación','data-close')}</div>`;
 template.content.querySelector('.messages').outerHTML='<div class="workspace"></div>';
 const hint=document.createElement('div');hint.className='spatial-hint';hint.innerHTML=sf('cursorarrow.motionlines')+'<span>Señala mientras hablas · Esc cancela</span>';
 const hintSlot=document.createElement('div');hintSlot.className='hint-slot';hintSlot.append(hint);
 template.content.querySelector('.assembly').append(hintSlot);
 const chevron=template.content.querySelector('.chevron');if(chevron)chevron.innerHTML=sf('chevron.down');
 template.content.querySelector('.workspace').innerHTML=workspaceMarkup();
 return template.innerHTML;
};
function workspaceMarkup(){
 let nav=section==='chats'?`<div class="side-heading">Chats${iconButton('plus','Nueva conversación de ejemplo','data-new')}</div><div class="chat-list">${chats.map((chat,index)=>`<button data-chat="${index}" aria-current="${index===selectedChat}">${escapeChatTitle(chat.title)}<small>Temporal</small></button>`).join('')}</div><div class="side-bottom"><p>Solo durante esta sesión</p><button data-section="general">${sf('gearshape')}Ajustes</button></div>`:
 `<button data-section="chats">${sf('chevron.left')}Volver a chats</button><div class="side-heading">Ajustes</div>${[['general','General','gearshape'],['voice','Voz','waveform'],['microphone','Micrófono','mic'],['shortcuts','Atajos','control'],['cursor','Cursor','cursorarrow.motionlines'],['privacy','Privacidad','hand.raised'],['help','Ayuda','bubble.left.and.bubble.right']].map(([key,title,symbol])=>`<button data-section="${key}" aria-current="${section===key}">${sf(symbol)}${title}</button>`).join('')}<div class="side-bottom"><p>Vista previa · Sin cambios en la app</p></div>`;
 return `<aside class="sidebar" aria-label="${section==='chats'?'Chats':'Ajustes'}">${nav}</aside><div class="workspace-content">${contentMarkup()}</div>`;
}
function selectRow(key,title,options){return `<div class="setting-row"><label for="setting-${key}">${title}</label><select id="setting-${key}" data-pref="${key}">${options.map(value=>`<option ${preferences[key]===value?'selected':''}>${value}</option>`).join('')}</select></div>`}
function toggleRow(key,title){return `<div class="setting-row"><label for="setting-${key}">${title}</label><input id="setting-${key}" aria-label="${title}" type="checkbox" data-pref="${key}" ${preferences[key]?'checked':''}></div>`}
function contentMarkup(){
 if(section==='chats'){
  const chat=chats[selectedChat];
  return chat.request?`<div class="messages"><div class="message user"><small>Tú</small><p>${chat.request}</p></div><div class="message"><small>Cursy</small><p>${chat.response}</p></div></div>`:`<h2>Tu conversación,<br>sin salir de lo que haces.</h2><p>Habla con Cursy usando Control + Opción.</p><p>${sf('cursorarrow')} El cursor sigue guiándote en pantalla.</p><p class="explanation">Este es un chat vacío de muestra. El prototipo no usa el micrófono.</p>`;
 }
 if(section==='general')return `<h2>General</h2><p>Tu experiencia, a tu manera.</p><div class="settings-list">${selectRow('language','Idioma',['Español','English'])}${selectRow('model','Modelo de respaldo',['GPT-4.1','GPT-4.1 mini'])}<div class="setting-row"><span>${sf('mic')} Mantén Control + Opción para hablar</span></div></div><p class="explanation">Cursy elige cómo señalar según lo que necesitas. No tienes que configurar las figuras.</p><p class="explanation">Controles de muestra. No cambian el modelo de voz ni el de localización.</p>`;
 if(section==='cursor')return `<h2>Cursor</h2><p>Un color para Cursy. Una sombra a juego.</p><div class="colors">${palette.map(([key,title,color])=>`<button class="color" style="--tint:${color}" data-tint="${key}" aria-label="${title}" aria-pressed="${key===tint}">${sf('cursorarrow','cursor-swatch')}${key===tint?sf('checkmark','selected-mark'):''}<span>${title}</span></button>`).join('')}</div>${toggleRow('cursor','Mostrar cursor en la demo')}<p class="explanation">El navegador aproxima el material; Liquid Glass real se verifica en macOS. Todos los pictogramas de esta vista son SF Symbols.</p>`;
 return `<h2>Privacidad</h2><p>Siempre sabes qué compartes.</p><div class="settings-list">${toggleRow('screen','Compartir pantalla')}${toggleRow('spatial','Señalar mientras hablas')}</div><p class="explanation">En esta demo no se captura ni se envía la pantalla. El mensaje de contexto espacial aparece debajo del notch, nunca sobre la cámara.</p><p class="explanation">Chats temporales: solo durante esta sesión. Las preferencias de esta página no modifican Cursy.</p>`;
}
function renderWorkspace(){
 const workspace=stage.querySelector('.workspace');if(!workspace)return;
 const active=document.activeElement;
 const focusKey=['data-section','data-chat','data-tint','data-new'].find(key=>workspace.contains(active)&&active.hasAttribute(key));
 const focusValue=focusKey?active.getAttribute(focusKey):null;
 workspace.innerHTML=workspaceMarkup();workspace.classList.toggle('hide-sidebar',!sidebarShown);
 stage.querySelector('[data-sidebar]').setAttribute('aria-expanded',String(sidebarShown));
 stage.querySelector('[data-screen]').setAttribute('aria-pressed',String(preferences.screen));
 if(focusKey){
  const target=[...workspace.querySelectorAll(`[${focusKey}]`)].find(item=>item.getAttribute(focusKey)===focusValue);
  (target??workspace.querySelector('button'))?.focus({preventScroll:true});
 }
}
const originalShowConversation=showConversation;
showConversation=function(show){originalShowConversation(show);updateHint()};
function updateHint(){
 const hint=stage.querySelector('.spatial-hint');if(!hint)return;
 stage.querySelector('.assembly').dataset.activity=mode;
 const visible=mode==='listening'&&preferences.screen&&preferences.spatial&&(activationReady||expanded);
 hint.classList.toggle('visible',visible);hint.setAttribute('aria-hidden',String(!visible));
 // Expanded mode still reserves the camera and places guidance in the black neck.
 const slot=hint.parentElement;slot.classList.toggle('expanded',expanded);
 slot.style.top=expanded?'31px':`${current===0?44:52}px`;
}
stage.addEventListener('click',event=>{
 const destination=event.target.closest('[data-section]');
 if(destination){section=destination.dataset.section;sidebarShown=true;renderWorkspace()}
 if(event.target.closest('[data-sidebar]')){sidebarShown=!sidebarShown;renderWorkspace()}
 if(event.target.closest('[data-new]')){chats.push({title:'Nueva conversación',request:'',response:''});selectedChat=chats.length-1;renderWorkspace()}
 const chat=event.target.closest('[data-chat]');if(chat){selectedChat=Number(chat.dataset.chat);renderWorkspace()}
 const color=event.target.closest('[data-tint]');if(color)setCursorTint(color.dataset.tint);
 if(event.target.closest('[data-screen]')){preferences.screen=!preferences.screen;renderWorkspace();updateHint()}
 if(event.target.closest('[data-dismiss]')){stopDemo();setMode('idle');showConversation(false)}
});
function setCursorTint(key){
 const choice=palette.find(item=>item[0]===key);if(!choice)return;
 tint=key;document.documentElement.style.setProperty('--cursor-tint',choice[2]);renderWorkspace();
 document.dispatchEvent(new Event('cursy-tint-change'));
}
stage.addEventListener('change',event=>{
 const key=event.target.dataset.pref;if(!key)return;
 preferences[key]=event.target.type==='checkbox'?event.target.checked:event.target.value;
 companion.style.visibility=preferences.cursor?'visible':'hidden';updateHint();
});

// Reflect the already-requested flight/click sequence in the design lab too.
// Retarget from the current painted position, cancel every stale continuation.
let flightFrame, activationReady=false;
const originalClearTimers=clearCursorTimers;
clearCursorTimers=function(){originalClearTimers();cancelAnimationFrame(flightFrame);companion.querySelector('.sf').style.transform=''};
companion.innerHTML=sf('cursorarrow')+'<span class="cursor-caption">Cursy</span>';
document.querySelector('.proto-picker-replay').innerHTML=sf('arrow.clockwise');
function flight(destination,duration,done){
 const rect=companion.getBoundingClientRect();const start={x:rect.left,y:rect.top};
 const bend=Math.min(140,Math.max(30,Math.hypot(destination.x-start.x,destination.y-start.y)*.2));
 const direction=start.x<=destination.x?-1:1;
 const first={x:start.x+direction*bend,y:start.y+(destination.y-start.y)*.35};
 const second={x:destination.x-direction*bend,y:destination.y+(start.y-destination.y)*.2};
 companion.style.transition='none';let began;
 function frame(now){
  began??=now;const raw=Math.min(1,(now-began)/duration),amount=raw*raw*(3-2*raw),remaining=1-amount;
  const x=remaining**3*start.x+3*remaining**2*amount*first.x+3*remaining*amount**2*second.x+amount**3*destination.x;
  const y=remaining**3*start.y+3*remaining**2*amount*first.y+3*remaining*amount**2*second.y+amount**3*destination.y;
  companion.style.transform=`translate(${x}px,${y}px)`;
  if(raw<1)flightFrame=requestAnimationFrame(frame);else{companion.style.transition='';done()}
 }
 flightFrame=requestAnimationFrame(frame);
}
updateCursor=function(){
 clearCursorTimers();document.querySelector('.rows span').classList.remove('pointed');
 if(['connecting','listening','processing','greeting'].includes(mode)){
  const reveal=()=>{activationReady=true;setSurface(stage.querySelector('.voice'),!expanded);updateHint()};
  if(reduced()||companion.dataset.position==='dock'){moveCursor('dock');companion.style.opacity='0';reveal();return}
  activationReady=false;setSurface(stage.querySelector('.voice'),false);
  companion.style.opacity='1';companion.classList.add('docking');
  flight({x:innerWidth/2-13,y:32},800,()=>{
   companion.querySelector('.sf').style.transform='scale(.82)';
   later(()=>{companion.querySelector('.sf').style.transform='';reveal();moveCursor('dock');later(()=>companion.style.opacity='0',180)},140);
  });
 }else{
  activationReady=false;companion.style.opacity='1';companion.style.transition='';
  moveCursor(mode==='responding'?'target':'rest');
  if(mode==='responding'){
   later(()=>document.querySelector('.rows span').classList.add('pointed'),reduced()?0:250);
   later(()=>{document.querySelector('.rows span').classList.remove('pointed');moveCursor('rest')},1500);
  }
 }
 updateHint();
};
const originalSetMode=setMode;
setMode=function(next){originalSetMode(next);updateHint()};
document.querySelector('.tag').textContent='Cursy / Superficie continua · 03';
document.querySelector('.caption').textContent='Prototipo local sin micrófono ni red. Prueba Conectando → Escuchando: el aviso solo aparece cuando la entrada está lista (simulación).';
// Reuse the existing route and variant picker; this is refinement, not a new design branch.
requestAnimationFrame(()=>{renderWorkspace();setMode('conversation')});
