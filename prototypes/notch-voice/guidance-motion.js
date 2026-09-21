// Synthetic companion only: never drives the user's pointer or sends app input.
function createGuidanceMotion(canvas,isReduced){
 const playbackRate=1.6; // Shared faster pace for artist and ink; curves stay unchanged.
 let animations=[],previousKey=null,draw=false,lightFrame=null,lastPointer=null,keyboard=false;
 let jobs=[],captions=[],actor=null,epoch=0,drawFrame=null,finishFrame=null;
 let typingFrame=null,restoreTyping=null;
 const ease=()=>getComputedStyle(document.documentElement).getPropertyValue('--ease-out').trim();
 const reducedMedia=matchMedia('(prefers-reduced-motion: reduce)');
 const finePointer=matchMedia('(hover: hover) and (pointer: fine)');
 const opticalReduction=matchMedia('(prefers-reduced-transparency: reduce), (prefers-contrast: more)');
 function cancel(){
  epoch++;animations.forEach(animation=>animation.cancel());animations=[];
  cancelAnimationFrame(lightFrame);lightFrame=null;cancelAnimationFrame(drawFrame);drawFrame=null;
  cancelAnimationFrame(typingFrame);typingFrame=null;
  if(restoreTyping){restoreTyping();restoreTyping=null}
  if(finishFrame){finishFrame(false);finishFrame=null}
  jobs.forEach(job=>job.restore());captions.forEach(element=>element.style.opacity='');
  actor?.remove();actor=null;delete canvas.dataset.drawingPhase;
 }
 function animate(element,frames,options){
  const animation=element.animate(frames,{easing:ease(),...options});
  if(!isReduced())animation.playbackRate=playbackRate;
  animations.push(animation);return animation;
 }
 function light(){
  lightFrame=null;const gradient=canvas.querySelector('#guidance-reflection');if(!gradient)return;
  const bounds=canvas.getBoundingClientRect();
  const point=lastPointer??{x:bounds.left+bounds.width*.35,y:bounds.top+bounds.height*.35};
  gradient.setAttribute('cx',point.x-bounds.left);gradient.setAttribute('cy',point.y-bounds.top);
 }
 canvas.addEventListener('pointermove',event=>{
  if(isReduced()||opticalReduction.matches||!finePointer.matches||event.pointerType==='touch')return;
  lastPointer={x:event.clientX,y:event.clientY};canvas.classList.add('reflection-active');
  if(lightFrame===null)lightFrame=requestAnimationFrame(light);
 });
 canvas.addEventListener('pointerleave',()=>canvas.classList.remove('reflection-active'));
 reducedMedia.addEventListener('change',()=>{cancel();canvas.classList.remove('reflection-active')});
 document.addEventListener('visibilitychange',()=>{if(document.hidden)cancel()});
 const transform=point=>`translate(${point.x}px,${point.y}px)`;
 async function move(from,to,run,duration=700){
  const control={x:(from.x+to.x)/2,y:Math.max(8,Math.min(from.y,to.y)-30)};
  const frames=Array.from({length:33},(_,i)=>{
   const t=i/32,u=1-t;
   return {transform:transform({x:u*u*from.x+2*u*t*control.x+t*t*to.x,y:u*u*from.y+2*u*t*control.y+t*t*to.y})};
  });
  const moving=actor;moving.style.transform=transform(to);
  await animate(moving,frames,{duration}).finished.catch(()=>{});return run===epoch;
 }
 async function press(down,run){
  const icon=actor.firstElementChild;icon.style.transform=`scale(${down ? .92 : 1})`;
  await animate(icon,[{transform:`scale(${down ? 1 : .92})`},{transform:`scale(${down ? .92 : 1})`}],{duration:180}).finished.catch(()=>{});
  return run===epoch;
 }
 function trace(job,run){
  return new Promise(resolve=>{
   finishFrame=resolve;let started;
   function tick(now){
    if(run!==epoch)return;
    started??=now;const p=Math.min(1,(now-started)/(1600/playbackRate));
    job.paint(p);actor.style.transform=transform(job.point(p));
    if(p<1)drawFrame=requestAnimationFrame(tick);
    else{drawFrame=null;finishFrame=null;resolve(true)}
   }
   drawFrame=requestAnimationFrame(tick);
  });
 }
 function reveal(element){
  element.style.opacity='';
  animate(element,[{opacity:0,transform:'translateY(4px)'},{opacity:1,transform:'translateY(0)'}],{duration:450});
 }
 async function play(){
  if(!draw||keyboard||isReduced()||!jobs.length)return;
  const run=epoch;
  actor=document.createElement('span');actor.className='annotation-pointer guidance-artist';actor.setAttribute('aria-hidden','true');
  actor.innerHTML=sf('cursorarrow');canvas.append(actor);
  let position={x:Math.max(12,jobs[0].point(0).x-58),y:Math.min(canvas.clientHeight-40,jobs[0].point(0).y+36)};
  actor.style.transform=transform(position);animate(actor,[{opacity:0},{opacity:1}],{duration:300});
  for(const job of jobs){
   canvas.dataset.drawingPhase='approach';
   if(!await move(position,job.point(0),run))return;
   canvas.dataset.drawingPhase='press';if(!await press(true,run))return;
   canvas.dataset.drawingPhase='draw';if(!await trace(job,run))return;
   job.restore();position=job.point(1);
   canvas.dataset.drawingPhase='release';if(!await press(false,run))return;
  }
  captions.forEach(reveal);canvas.dataset.drawingPhase='depart';
  const rest={x:Math.min(canvas.clientWidth-38,position.x+32),y:Math.min(canvas.clientHeight-40,position.y+32)};
  if(!await move(position,rest,run,650))return;
  await animate(actor,[{opacity:1},{opacity:0}],{duration:450}).finished.catch(()=>{});
  if(run===epoch){actor.remove();actor=null;delete canvas.dataset.drawingPhase}
 }
 return {
  input(event){keyboard=event.detail===0},
  begin(key){cancel();jobs=[];captions=[];draw=key!==previousKey;previousKey=key;light()},
  refreshLight:light,
  stroke(group){
   if(!draw||keyboard)return;
   if(isReduced()){animate(group,[{opacity:0},{opacity:1}],{duration:150});return}
   const paths=[...group.querySelectorAll('path,rect,ellipse,circle')],path=paths[0];
   const rectangle=path.tagName.toLowerCase()==='rect';
   const attr=name=>Number(path.getAttribute(name));
   const area=rectangle?{x:attr('x'),y:attr('y'),width:attr('width'),height:attr('height'),radius:attr('rx')}:null;
   const length=rectangle?0:path.getTotalLength();
   // Ink and cursor share a frame clock: optical layers cannot run ahead.
   const point=p=>rectangle?{x:area.x+area.width*p,y:area.y+area.height*p}:path.getPointAtLength(length*p);
   function paint(p){
    group.style.opacity=p===0?'0':'1';
    paths.forEach(element=>{
     if(rectangle){
      element.setAttribute('width',Math.max(.1,area.width*p));element.setAttribute('height',Math.max(.1,area.height*p));
      element.setAttribute('rx',Math.min(area.radius,area.width*p/2,area.height*p/2));
     }else{
      element.style.strokeDasharray=`${length} ${length}`;element.style.strokeDashoffset=String(length*(1-p));element.style.fill='none';
     }
     if(group.classList.contains('direction'))element.style.markerEnd='none';
    });
   }
   function restore(){
    group.style.opacity='';paths.forEach(element=>{
     if(rectangle){element.setAttribute('width',area.width);element.setAttribute('height',area.height);element.setAttribute('rx',area.radius)}
     element.style.strokeDasharray='';element.style.strokeDashoffset='';element.style.markerEnd='';element.style.fill='';
    });
   }
   jobs.push({point,paint,restore});paint(0);
  },
  caption(element){
   if(!draw||keyboard)return;
   if(isReduced()){animate(element,[{opacity:0},{opacity:1}],{duration:150});return}
   if(jobs.length){element.style.opacity='0';captions.push(element)}else reveal(element);
  },
  label(element,caption){
   if(!draw||keyboard)return;
   if(isReduced()){animate(element,[{opacity:0},{opacity:1}],{duration:150});return}
   // Same bubble entrance as guide captions, with no artist and no drawing job.
   reveal(element);
   const text=caption.textContent,run=epoch;
   const letters=[...new Intl.Segmenter('es',{granularity:'grapheme'}).segment(text)].map(part=>part.segment);
   const reserve=document.createElement('span'),ink=document.createElement('span');
   reserve.textContent=text;reserve.className='typing-reserve';reserve.setAttribute('aria-hidden','true');
   ink.className='typing-ink';ink.setAttribute('aria-hidden','true');
   caption.classList.add('typing-copy');caption.replaceChildren(reserve,ink);
   // Announce the complete explanation once, not each arriving character.
   element.setAttribute('role','note');element.setAttribute('aria-label',text);
   const restore=()=>{caption.classList.remove('typing-copy');caption.textContent=text;element.removeAttribute('role');element.removeAttribute('aria-label')};
   restoreTyping=restore;let started;
   const duration=Math.min(1000,Math.max(300,letters.length*24));
   function tick(now){
    if(run!==epoch)return;
    started??=now;const progress=Math.min(1,(now-started)/duration);
    ink.textContent=letters.slice(0,Math.floor(progress*letters.length)).join('');
    if(progress<1)typingFrame=requestAnimationFrame(tick);
    else{typingFrame=null;restore();restoreTyping=null}
   }
   typingFrame=requestAnimationFrame(tick);
  },
  play,
  reset(){cancel();jobs=[];captions=[];previousKey=null;lastPointer=null;canvas.classList.remove('reflection-active')}
 };
}
