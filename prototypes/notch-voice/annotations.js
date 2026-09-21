// Review scenarios, not inference. DOM bounds stand in for future validated model regions.
const annotationExamples=[
 {request:'Encuentra Guardar',style:'cursor',name:'Precisión, sin ruido',target:'save',label:'Guarda aquí',reason:'Un control pequeño y aislado: basta el cursor. No añade una figura por decoración.'},
 {request:'Destaca este control',style:'circle',name:'Foco que abraza el objetivo',target:'save',label:'Este es el control',reason:'Un objetivo compacto: un círculo o una elipse lo rodea completo, dejando respirar el texto.'},
 {request:'Revisa el párrafo completo',style:'rectangle',name:'El contenido define el tamaño',target:'paragraph',label:'Este párrafo reúne la idea',reason:'Un bloque de texto necesita un recuadro con sus límites completos, no una marca fija sobre una palabra.'},
 {request:'Muéstrame dónde continuar',style:'arrow',name:'Una dirección inequívoca',target:'continue',label:'Continúa aquí',reason:'La flecha termina en el destino validado y su longitud responde a la distancia. El texto queda fuera de la trayectoria.'},
 {request:'Explícame este dato',style:'label',name:'Contexto sin cubrir contenido',target:'changes',label:'Tres cambios pendientes de revisión',reason:'La explicación aparece justo encima del objetivo, sin línea de conexión y sin tapar el dato. El bloque se adapta al texto.'},
 {request:'Guíame para mover el archivo',style:'guide',name:'Un paso, varias señales',reason:'Origen, recorrido y destino forman una misma guía. Cursy los sustituye o retira al verificar el avance, no por un temporizador.'}
];
const annotationDialog=document.createElement('dialog');
annotationDialog.className='annotation-lab';annotationDialog.setAttribute('aria-labelledby','annotation-title');
annotationDialog.innerHTML=`<header><div><small>CURSY / INDICACIONES · 02</small><h2 id="annotation-title">La misma esencia. Más precisión.</h2><p>Una superficie de color que acompaña, sin ocultar lo importante.</p></div><button data-annotation-close aria-label="Cerrar vista de indicaciones">${sf('xmark')}</button></header>
 <div class="lab-body"><div class="annotation-toolbar"><div class="annotation-palette" aria-label="Color de Cursy en el prototipo"></div><span>Comparte el color del cursor · Solo prototipo</span><button data-annotation-background aria-pressed="false">Fondo oscuro</button></div>
 <div class="annotation-cases" aria-label="Escenarios simulados"></div>
 <div class="annotation-preview"><div class="annotation-canvas"><div class="annotation-scene"></div><svg class="guidance-overlay" aria-hidden="true"></svg><div class="guidance-labels"></div></div></div>
 <div class="annotation-simulation"><span class="simulation-state" role="status"></span><div><button data-replay>Repetir marcación</button><button data-more hidden aria-pressed="false">Guía con otro paso</button><button data-layout aria-pressed="false">Probar párrafo estrecho</button><button data-step hidden></button><button data-scene aria-pressed="false">Simular pantalla cambiada</button></div></div>
 <div class="annotation-context" aria-live="polite"></div>
 <details class="guidance-contract"><summary>Criterios de Cursy y límites del prototipo</summary><div><p><strong>La herramienta la decide Cursy.</strong> Cursor para un punto; elipse para foco compacto; recuadro para una región; flecha para dirección; etiqueta para contexto. Combina hasta tres señales si un paso necesita origen, recorrido y destino.</p><p><strong>Geometría con evidencia.</strong> Área, pantalla, captura y paso deben seguir vigentes. Si cambian o no se pueden verificar, retira las señales y vuelve a localizar. No inventa tamaños a partir de un punto.</p><p><strong>Continuidad con permiso.</strong> Una guía activa podrá observar de forma acotada y avanzar con evidencia, no solo por tiempo o por un clic. No habrá un selector ni un botón para borrar figuras individualmente; cancelar la ayuda o retirar permiso siempre será posible.</p><p><strong>Esta pantalla es una simulación local.</strong> Usa límites del documento de muestra, no un modelo ni capturas. El vidrio web aproxima Liquid Glass. La app nativa aún utiliza marcas fijas y no ejecuta esta guía.</p></div></details></div>`;
document.body.append(annotationDialog);
let annotationIndex=2,annotationNarrow=false,annotationStale=false,annotationStep=0,annotationMore=false,annotationReplay=0;
let annotationLayoutFrame,annotationRenderKey=null;
let annotationDrag=null;
const annotationMotion=createGuidanceMotion(annotationDialog.querySelector('.annotation-canvas'),()=>reduced());
const annotationEntry=document.createElement('button');annotationEntry.id='open-annotations';annotationEntry.textContent='Ver figuras de Cursy';
document.querySelector('.lab .controls').append(annotationEntry);
annotationEntry.addEventListener('click',event=>{annotationMotion.input(event);stopDemo();setMode('idle');annotationDialog.showModal();renderAnnotationExample()});
function annotationPalette(){
 annotationDialog.querySelector('.annotation-palette').innerHTML=palette.map(([key,title,color])=>`<button data-guidance-tint="${key}" style="--swatch:${color}" aria-label="Color ${title}" aria-pressed="${key===tint}">${sf(key===tint?'checkmark':'cursorarrow')}</button>`).join('');
}
function renderAnnotationExample(){
 const item=annotationExamples[annotationIndex];annotationPalette();
 annotationDialog.querySelector('.annotation-cases').innerHTML=annotationExamples.map((example,index)=>`<button data-example="${index}" aria-pressed="${index===annotationIndex}">${example.request}</button>`).join('');
 const scene=annotationDialog.querySelector('.annotation-scene');scene.classList.toggle('narrow',annotationNarrow);
 scene.innerHTML=item.style==='guide'?`<div class="sample-title"><span>ESPACIO DE TRABAJO / MUESTRA</span><span>Entrega de diseño</span></div><div class="transfer-board"><div class="transfer-source"><small>ARCHIVOS</small><div class="sample-file" data-target="source" draggable="${annotationStep!==2}" tabindex="0" role="button" aria-label="Propuesta.pdf, pulsa Enter para simular recoger">${sf('rectangle')}<div>Propuesta.pdf<small>Documento · 2 páginas</small></div></div></div><div class="sample-drop" data-target="destination"><span>${sf(annotationStep===2?'checkmark.circle.fill':'plus')}</span><strong>${annotationStep===2?'Propuesta.pdf recibido':'Entrega final'}</strong><small>${annotationStep===2?'Resultado simulado':'Suelta el documento aquí'}</small></div></div><p class="sample-footnote">Arrastra el archivo de muestra o usa el botón «Simular recoger».</p>`:
 `<div class="sample-title"><span>NOTAS / PROPUESTA</span><button data-target="save" tabindex="-1">Guardar</button></div><article class="sample-document"><small>OBJETIVO</small><h3>Una idea, sin perder el hilo.</h3><p data-target="paragraph">Organiza los cambios alrededor de una sola idea. Reúne el contexto, explica qué necesita mejorar y termina con una decisión clara para que el equipo sepa por dónde continuar.</p><div class="sample-actions"><span data-target="changes">3 cambios</span><button data-target="continue" tabindex="-1">Continuar</button></div></article>`;
 if(item.style==='guide'&&annotationStep>=2){
  const empty=document.createElement('div');empty.className='sample-file';empty.textContent='Archivo trasladado';
  scene.querySelector('[data-target="source"]').replaceWith(empty);
  scene.querySelector('.sample-drop').innerHTML=`<span>${sf('checkmark.circle.fill')}</span><strong>Propuesta.pdf recibido</strong><small>Resultado simulado</small>${annotationMore&&annotationStep===2?'<button data-target="review" data-review>Revisar entrega</button>':''}`;
  scene.querySelector('.sample-footnote').textContent=annotationMore&&annotationStep===2?'Siguiente paso de muestra: abre «Revisar entrega».':'Entrega completada en esta demostración.';
 }
 const draggable=scene.querySelector('[data-target="source"]');if(draggable)draggable.draggable=false;
 annotationDialog.querySelector('.annotation-context').innerHTML=`<div><small>DECISIÓN SIMULADA DE CURSY</small><h3>${item.name}</h3><p>${item.reason}</p></div><div class="annotation-principle">${sf('cursorarrow.motionlines')}<p>Mismo color. Misma identidad.<br><span>La forma cambia con lo que necesitas ver.</span></p></div>`;
 syncAnnotationState();queueAnnotationLayout();
}
function syncAnnotationState(){
 const guide=annotationExamples[annotationIndex].style==='guide';
 const layout=annotationDialog.querySelector('[data-layout]');layout.hidden=guide;layout.textContent=annotationNarrow?'Probar párrafo ancho':'Probar párrafo estrecho';layout.setAttribute('aria-pressed',String(annotationNarrow));
 const more=annotationDialog.querySelector('[data-more]');more.hidden=!guide;more.setAttribute('aria-pressed',String(annotationMore));
 const step=annotationDialog.querySelector('[data-step]');step.hidden=!guide;step.disabled=annotationStale;step.textContent=annotationStep===0?'Simular recoger':annotationStep===1?'Simular soltar':annotationStep===2&&annotationMore?'Simular revisión':'Repetir guía de muestra';
 const review=annotationDialog.querySelector('[data-review]');if(review)review.disabled=annotationStale;
 const guideStatus=annotationStep===0?'Recoge el documento':annotationStep===1?'Llévalo al destino':annotationStep===2&&annotationMore?'¡Muy bien! Ahora revisa la entrega.':'¡Muy bien! Has completado la entrega.';
 annotationDialog.querySelector('.simulation-state').textContent=annotationStale?'Escena cambiada · indicaciones retiradas hasta verificar':guide?guideStatus:'Diseño adaptativo · límites del contenido de muestra';
 const scene=annotationDialog.querySelector('[data-scene]');scene.textContent=annotationStale?'Simular nueva verificación':'Simular pantalla cambiada';scene.setAttribute('aria-pressed',String(annotationStale));
}
function queueAnnotationLayout(){cancelAnimationFrame(annotationLayoutFrame);annotationLayoutFrame=requestAnimationFrame(drawAnnotations)}
function drawAnnotations(){
 if(!annotationDialog.open)return;
 const canvas=annotationDialog.querySelector('.annotation-canvas'),overlay=canvas.querySelector('svg'),labels=canvas.querySelector('.guidance-labels');
 const root=canvas.getBoundingClientRect(),viewport={width:canvas.clientWidth,height:canvas.clientHeight};
 const renderKey=[annotationIndex,annotationNarrow,annotationStale,annotationStep,annotationMore,annotationReplay,tint,viewport.width,viewport.height].join('/');
 // Initial ResizeObserver delivery must not cancel the very first drawing.
 if(renderKey===annotationRenderKey)return;
 annotationRenderKey=renderKey;
 annotationMotion.begin(`${annotationIndex}/${annotationNarrow}/${annotationStale}/${annotationStep===2?2:annotationStep===3?3:0}/${annotationMore}/${annotationReplay}`);
 overlay.setAttribute('viewBox',`0 0 ${viewport.width} ${viewport.height}`);labels.replaceChildren();
 const color=palette.find(choice=>choice[0]===tint)[2];
 overlay.innerHTML=`<defs><linearGradient id="guidance-glass" x1="0" y1="0" x2=".4" y2="1"><stop stop-color="white" stop-opacity=".96"/><stop offset=".3" stop-color="${color}"/><stop offset="1" stop-color="${color}" stop-opacity=".65"/></linearGradient><marker id="guidance-tip" viewBox="0 0 12 12" refX="10" refY="6" markerWidth="5" markerHeight="5" orient="auto-start-reverse"><path d="M2 2 L10 6 L2 10" fill="none" stroke="${color}" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/></marker></defs>`;
 overlay.querySelector('defs').insertAdjacentHTML('beforeend','<radialGradient id="guidance-reflection" gradientUnits="userSpaceOnUse" r="200"><stop stop-color="white" stop-opacity=".95"/><stop offset=".35" stop-color="white" stop-opacity=".5"/><stop offset="1" stop-color="white" stop-opacity="0"/></radialGradient>');
 // The base edge is tinted; illumination lives in an independent pointer-lit layer.
 overlay.querySelector('#guidance-glass stop').setAttribute('stop-color',color);
 annotationMotion.refreshLight();
 if(annotationStale)return;
 const box=key=>{const target=canvas.querySelector(`[data-target="${key}"]`);if(!target)return null;const rect=annotationDrag?.source===target?annotationDrag.rect:target.getBoundingClientRect();return {x:rect.left-root.left,y:rect.top-root.top,width:rect.width,height:rect.height}};
 const center=rect=>({x:rect.x+rect.width/2,y:rect.y+rect.height/2});
 const shape=(markup,extra='')=>{
  overlay.insertAdjacentHTML('beforeend',`<g class="guidance-mark ${extra}">${markup.replaceAll('STYLE','class="guidance-underlay"')}${markup.replaceAll('STYLE','class="guidance-edge"')}${markup.replaceAll('STYLE','class="guidance-specular"')}</g>`);
  annotationMotion.stroke(overlay.lastElementChild,overlay.querySelectorAll('.guidance-mark').length-1);
 };
 const rectangle=rect=>{const area=GuidanceGeometry.focus(rect,viewport);if(area)shape(`<rect x="${area.x}" y="${area.y}" width="${area.width}" height="${area.height}" rx="14" STYLE/>`)};
 const ellipse=rect=>{
  const area=GuidanceGeometry.ellipse(rect,viewport);
  if(area){const {x,y,rx,ry}=area;shape(`<path d="M${x-rx},${y} A${rx},${ry} 0 1 1 ${x+rx},${y} A${rx},${ry} 0 1 1 ${x-rx},${y}" STYLE/>`)}else rectangle(rect);
 };
 const arrow=(from,to)=>{
  const path=GuidanceGeometry.arrow(from,to);if(!path)return;
  const angle=Math.abs(to.x-from.x)>.01?(to.x>=from.x?0:Math.PI):Math.atan2(to.y-from.y,to.x-from.x);
  const arm=sign=>({x:to.x-12*Math.cos(angle+sign*.55),y:to.y-12*Math.sin(angle+sign*.55)});
  const a=arm(1),b=arm(-1);
  shape(`<path d="${path} L${a.x},${a.y} L${to.x},${to.y} L${b.x},${b.y}" STYLE/>`,'direction');
 };
 function tag(rect,text,number,placement='auto'){
  const element=document.createElement('div');element.className='annotation-tag';
  if(number){const badge=document.createElement('b');badge.textContent=number;element.append(badge)}
  const caption=document.createElement('span');caption.textContent=text;element.append(caption);labels.append(element);
  const width=element.offsetWidth,height=element.offsetHeight;
  const x=Math.max(10,Math.min(viewport.width-width-10,rect.x+rect.width/2-width/2));
  const gap=annotationExamples[annotationIndex].style==='label'?12:24;
  const above=rect.y-height-gap;const y=placement!=='below'&&above>=8?above:Math.min(viewport.height-height-8,rect.y+rect.height+gap);
  element.style.left=`${x}px`;element.style.top=`${y}px`;
  if(annotationExamples[annotationIndex].style==='label'){
   annotationMotion.label(element,caption);
  }else annotationMotion.caption(element);
 }
 const item=annotationExamples[annotationIndex];
 if(item.style==='guide'){
  const source=box('source'),destination=box('destination');if(!GuidanceGeometry.validBox(destination,viewport))return;
  if(annotationStep>=2){
   if(annotationMore&&annotationStep===2){
    const review=box('review');if(GuidanceGeometry.validBox(review,viewport))rectangle(review);
    tag(destination,'¡Muy bien! Ahora revisa la entrega.',null);
   }else tag(destination,'¡Muy bien! Has completado la entrega.',null);
   annotationMotion.play();return;
  }
  if(!GuidanceGeometry.validBox(source,viewport))return;
  rectangle(source);rectangle(destination);
  arrow({x:source.x+source.width+22,y:source.y+source.height/2},{x:destination.x-17,y:destination.y+destination.height/2});
  tag(source,annotationStep===0?'Recoge este archivo':'Archivo recogido','1');tag(destination,annotationStep===0?'Llévalo aquí':'Suelta aquí','2');
 }else{
  const target=box(item.target);if(!GuidanceGeometry.validBox(target,viewport))return;
  if(item.style==='rectangle')rectangle(target);
  if(item.style==='circle')ellipse(target);
  if(item.style==='arrow')arrow({x:Math.max(25,target.x-155),y:target.y-56},{x:target.x-8,y:target.y+target.height/2});
  if(item.style==='cursor'){
   const cursor=document.createElement('span');cursor.className='annotation-pointer';cursor.innerHTML=sf('cursorarrow');cursor.style.left=`${target.x+target.width-10}px`;cursor.style.top=`${target.y+target.height-12}px`;labels.append(cursor);
   annotationMotion.caption(cursor);
  }
  tag(target,item.label,null,item.style==='rectangle'?'below':'auto');
 }
 annotationMotion.play();
}
annotationDialog.addEventListener('click',event=>{
 annotationMotion.input(event);
 if(event.target.closest('[data-annotation-close]'))annotationDialog.close();
 const choice=event.target.closest('[data-example]');if(choice){annotationIndex=Number(choice.dataset.example);annotationStep=0;annotationStale=false;renderAnnotationExample();annotationDialog.querySelector(`[data-example="${annotationIndex}"]`).focus()}
 const color=event.target.closest('[data-guidance-tint]');if(color){setCursorTint(color.dataset.guidanceTint);annotationDialog.querySelector(`[data-guidance-tint="${tint}"]`).focus()}
 if(event.target.closest('[data-layout]')){annotationNarrow=!annotationNarrow;renderAnnotationExample()}
 if(event.target.closest('[data-step]')){annotationStep=annotationStep===0?1:annotationStep===1?2:annotationStep===2&&annotationMore?3:0;renderAnnotationExample()}
 if(event.target.closest('[data-review]')&&!annotationStale){annotationStep=3;renderAnnotationExample();annotationDialog.querySelector('[data-step]').focus()}
 if(event.target.closest('[data-more]')){annotationMore=!annotationMore;annotationStep=0;renderAnnotationExample()}
 if(event.target.closest('[data-replay]')){annotationReplay++;queueAnnotationLayout()}
 if(event.target.closest('[data-scene]')){annotationStale=!annotationStale;syncAnnotationState();queueAnnotationLayout()}
 const background=event.target.closest('[data-annotation-background]');if(background){const dark=annotationDialog.querySelector('.annotation-preview').classList.toggle('dark');background.setAttribute('aria-pressed',String(dark));background.textContent=dark?'Fondo claro':'Fondo oscuro'}
});
annotationDialog.addEventListener('pointerdown',event=>{
 const source=event.target.closest('[data-target="source"]');
 if(!source||annotationStale||annotationStep>=2||annotationDrag||event.button!==0)return;
 annotationMotion.input({detail:1});
 annotationDrag={source,id:event.pointerId,x:event.clientX,y:event.clientY,moved:false,rect:source.getBoundingClientRect()};source.setPointerCapture(event.pointerId);
});
annotationDialog.addEventListener('pointermove',event=>{
 const drag=annotationDrag;if(!drag||drag.id!==event.pointerId)return;
 const x=event.clientX-drag.x,y=event.clientY-drag.y;
 if(!drag.moved&&Math.hypot(x,y)>6){drag.moved=true;annotationStep=1;syncAnnotationState();queueAnnotationLayout()}
 if(drag.moved){drag.source.style.transform=`translate(${x}px,${y}px)`;drag.source.style.opacity='.55'}
});
function finishAnnotationDrag(event,cancelled=false){
 const drag=annotationDrag;if(!drag||drag.id!==event.pointerId)return;
 annotationDrag=null;drag.source.style.transform='';drag.source.style.opacity='';
 if(drag.source.hasPointerCapture(event.pointerId))drag.source.releasePointerCapture(event.pointerId);
 const target=annotationDialog.querySelector('[data-target="destination"]').getBoundingClientRect();
 const inside=event.clientX>=target.left&&event.clientX<=target.right&&event.clientY>=target.top&&event.clientY<=target.bottom;
 annotationStep=!cancelled&&!annotationStale&&drag.moved&&inside?2:0;
 renderAnnotationExample();annotationDialog.querySelector('[data-step]').focus();
}
annotationDialog.addEventListener('pointerup',event=>finishAnnotationDrag(event));
annotationDialog.addEventListener('pointercancel',event=>finishAnnotationDrag(event,true));
annotationDialog.addEventListener('lostpointercapture',event=>finishAnnotationDrag(event,true));
annotationDialog.addEventListener('keydown',event=>{
 event.stopPropagation();
 if(['Enter',' '].includes(event.key)&&event.target.matches('[data-target="source"]')){event.preventDefault();annotationMotion.input({detail:0});if(!annotationStale&&annotationStep<2){annotationStep=1;syncAnnotationState();queueAnnotationLayout();annotationDialog.querySelector('[data-step]').focus()}}
});
annotationDialog.addEventListener('close',()=>{annotationMotion.reset();annotationRenderKey=null;annotationDrag=null;cancelAnimationFrame(annotationLayoutFrame);annotationEntry.focus()});
document.addEventListener('cursy-tint-change',()=>{if(annotationDialog.open){annotationPalette();queueAnnotationLayout()}});
new ResizeObserver(queueAnnotationLayout).observe(annotationDialog.querySelector('.annotation-scene'));
