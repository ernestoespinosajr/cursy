const {test}=require('node:test');
const assert=require('node:assert/strict');
const vm=require('node:vm');
const fs=require('node:fs');
const source=fs.readFileSync(`${__dirname}/guidance-motion.js`,'utf8');
const drawDuration=1600/1.6;

function harness(reduced=false){
 let next=0;const frames=new Map(),actors=[];
 const textElement=()=>({style:{},textContent:'',attrs:{},children:[],classList:{add(){},remove(){}},
  setAttribute(key,value){this.attrs[key]=value},removeAttribute(key){delete this.attrs[key]},
  replaceChildren(...children){this.children=children},animate(){return {finished:Promise.resolve(),cancel(){}}}});
 const canvas={dataset:{},clientWidth:800,clientHeight:400,
  querySelector:()=>null,addEventListener(){},classList:{add(){},remove(){}},
  append(actor){actors.push(actor)}};
 const document={documentElement:{},addEventListener(){},createElement(){return {...textElement(),
  style:{},firstElementChild:{style:{},animate(){return {finished:Promise.resolve(),cancel(){}}}},
  setAttribute(){},remove(){this.removed=true},animate(){return {finished:Promise.resolve(),cancel(){}}}
 }}};
 const create=vm.runInNewContext(source+';createGuidanceMotion',{
  document,sf:()=>'<span></span>',getComputedStyle:()=>({getPropertyValue:()=> 'cubic-bezier(0.23,1,0.32,1)'}),
  matchMedia:()=>({matches:false,addEventListener(){}}),
  requestAnimationFrame:fn=>{frames.set(++next,fn);return next},cancelAnimationFrame:id=>frames.delete(id)
 });
 const motion=create(canvas,()=>reduced);
 const flush=async()=>{for(let i=0;i<12;i++)await Promise.resolve()};
 const frame=async time=>{const pending=[...frames.values()];frames.clear();pending.forEach(fn=>fn(time));await flush()};
 function group(kind='rect'){
  const values={x:30,y:40,width:400,height:100,rx:14};
  const paths=Array.from({length:3},()=>({tagName:kind,style:{},attrs:{...values},
   getAttribute(key){return this.attrs[key]},setAttribute(key,value){this.attrs[key]=Number(value)},
   getTotalLength:()=>200,getPointAtLength:length=>({x:30+length,y:40})}));
  return {style:{},classList:{contains:()=>false},querySelectorAll:()=>paths,paths};
 }
 return {motion,canvas,actors,frames,group,frame,flush,textElement};
}
test('rectangle grows from fixed corner and its live corner matches the artist',async()=>{
 const h=harness(),g=h.group();h.motion.begin('a');h.motion.stroke(g);
 const done=h.motion.play();await h.flush();await h.frame(0);await h.frame(drawDuration/2);
 assert.equal(g.paths[0].attrs.width,200);assert.equal(g.paths[0].attrs.height,50);
 assert.equal(h.actors[0].style.transform,'translate(230px,90px)');
 assert.equal(g.paths[0].attrs.x,30);assert.equal(g.paths[0].attrs.y,40);
 await h.frame(drawDuration);await done;
 assert.equal(g.paths[0].attrs.width,400);assert.ok(h.actors[0].removed);
});
test('stroke head and artist use the same progress, then cancellation settles safely',async()=>{
 const h=harness(),g=h.group('path');h.motion.begin('a');h.motion.stroke(g);
 const done=h.motion.play();await h.flush();await h.frame(0);await h.frame(drawDuration/2);
 assert.equal(g.paths[0].style.strokeDashoffset,'100');
 assert.equal(h.actors[0].style.transform,'translate(130px,40px)');
 h.motion.reset();await done;assert.equal(h.frames.size,0);assert.ok(h.actors[0].removed);
 assert.equal(g.paths[0].style.strokeDashoffset,'');assert.equal(h.canvas.dataset.drawingPhase,undefined);
});
test('three marks use one artist sequentially, never three simultaneous cursors',async()=>{
 const h=harness(),groups=[h.group(),h.group(),h.group()];h.motion.begin('a');groups.forEach(g=>h.motion.stroke(g));
 const done=h.motion.play();await h.flush();
 assert.equal(groups[1].style.opacity,'0');
 for(let i=0;i<3;i++){await h.frame(i*2000);await h.frame(i*2000+1600)}
 await done;assert.equal(h.actors.length,1);assert.ok(h.actors[0].removed);
 groups.forEach(g=>assert.equal(g.paths[0].attrs.width,400));
});
test('reduced motion never creates travelling actor or partial geometry',async()=>{
 const h=harness(true),g=h.group();g.animate=()=>({finished:Promise.resolve(),cancel(){}});
 h.motion.begin('a');h.motion.stroke(g);await h.motion.play();
 assert.equal(h.actors.length,0);assert.equal(g.paths[0].attrs.width,400);assert.equal(h.frames.size,0);
});
test('replay cancels old sequence without leaving a detached actor or callback',async()=>{
 const h=harness(),g=h.group();h.motion.begin('a');h.motion.stroke(g);
 const done=h.motion.play();await h.flush();await h.frame(0);
 h.motion.begin('b');await done;assert.ok(h.actors[0].removed);assert.equal(h.frames.size,0);
 assert.equal(g.paths[0].attrs.width,400);
});
test('explanation types progressively without an artist or clipping its bubble',async()=>{
 const h=harness(),label=h.textElement(),caption=h.textElement();caption.textContent='Tres cambios';h.motion.begin('label');
 h.motion.label(label,caption);await h.motion.play();await h.frame(0);await h.frame(150);
 assert.equal(h.actors.length,0);assert.equal(label.style.clipPath,undefined);
 assert.equal(caption.children[0].textContent,'Tres cambios');assert.equal(caption.children[1].textContent,'Tres c');
 assert.equal(label.attrs['aria-label'],'Tres cambios');
 await h.frame(300);assert.equal(caption.textContent,'Tres cambios');assert.equal(h.frames.size,0);
});
test('changing scene stops typing and restores complete accessible text',async()=>{
 const h=harness(),label=h.textElement(),caption=h.textElement();caption.textContent='Explicación';h.motion.begin('label');
 h.motion.label(label,caption);await h.frame(0);h.motion.reset();
 assert.equal(h.frames.size,0);assert.equal(caption.textContent,'Explicación');assert.equal(label.attrs['aria-label'],undefined);
});
test('reduced motion shows the entire explanation without typing',async()=>{
 const h=harness(true),label=h.textElement(),caption=h.textElement();caption.textContent='Explicación';h.motion.begin('label');
 h.motion.label(label,caption);await h.motion.play();assert.equal(h.frames.size,0);assert.equal(h.actors.length,0);
 assert.equal(caption.textContent,'Explicación');
});
