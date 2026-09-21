// Only explicit selected text belongs to this context. No surrounding DOM/history.
(function(root) {
 class SelectionContext {
  constructor() { this.revision=0; this.text=''; this.phase='idle'; }
  select(text) {
   this.cancel();
   if (!text.trim() || text.length>6000) return false;
   this.text=text; this.phase='offered'; return true;
  }
  edit() { if(this.phase!=='offered')return false; this.phase='editing'; return true; }
  voice() { if(this.phase!=='editing')return null; this.phase='greeting'; return ++this.revision; }
  listen(token) { if(token!==this.revision||this.phase!=='greeting')return false; this.phase='listening';return true; }
  cancel() { this.revision++;this.text='';this.phase='idle'; }
  snapshot() { return Object.freeze({kind:'selection-only',text:this.text}); }
 }
 function selectionPosition(rect,width,height,viewport,obstacles=[]) {
  const margin=12,gap=12;
  if(![rect.left,rect.top,rect.bottom,rect.width,width,height,viewport.width,viewport.height].every(Number.isFinite)||width<=0||height<=0||width>viewport.width-2*margin||height>viewport.height-2*margin)return null;
  const left=Math.max(margin,Math.min(rect.left+rect.width/2-width/2,viewport.width-width-margin));
  const blockers=obstacles.filter(box=>[box.left,box.right,box.top,box.bottom].every(Number.isFinite)&&box.right>left&&box.left<left+width&&box.bottom>box.top);
  // Nearby app toolbar is an occupied anchor, not a rule for any particular app.
  const nearby=blockers.filter(box=>box.bottom>=rect.top-96&&box.top<=rect.bottom+gap);
  let top=Math.min(rect.top,...nearby.map(box=>box.top))-height-gap;
  for(let i=0;i<=blockers.length;i++) {
   const hit=blockers.filter(box=>top+height+gap>box.top&&top-gap<box.bottom);
   if(!hit.length)break;top=Math.min(...hit.map(box=>box.top))-height-gap;
  }
  if(top>=margin)return {left,top,below:false};
  top=Math.max(rect.bottom,...nearby.map(box=>box.bottom))+gap;
  for(let i=0;i<=blockers.length;i++) {
   const hit=blockers.filter(box=>top+height+gap>box.top&&top-gap<box.bottom);
   if(!hit.length)break;top=Math.max(...hit.map(box=>box.bottom))+gap;
  }
  return top+height<=viewport.height-margin?{left,top,below:true}:null;
 }
 function selectionMorphGeometry(from,to) {
  if(![from.left,from.top,from.width,from.height,to.left,to.top,to.width,to.height].every(Number.isFinite)||Math.min(from.width,from.height,to.width,to.height)<=0)return null;
  // Don't sweep through an app menu if collision handling flips the anchor side.
  if(Math.abs(from.top-to.top)>Math.max(from.height,to.height))return null;
  return {x:from.left-to.left,y:from.top-to.top,scaleX:from.width/to.width,scaleY:from.height/to.height};
 }
 if(typeof module!=='undefined')module.exports={SelectionContext,selectionPosition,selectionMorphGeometry};
 else Object.assign(root,{SelectionContext,selectionPosition,selectionMorphGeometry});
})(globalThis);
