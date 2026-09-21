// Synthetic layout only. Production must validate model-provided region evidence first.
const GuidanceGeometry = (() => {
 const validBox=(box,viewport)=>box && [box.x,box.y,box.width,box.height,viewport.width,viewport.height].every(Number.isFinite) &&
  box.width>0 && box.height>0 && box.x>=0 && box.y>=0 && box.x+box.width<=viewport.width+.5 && box.y+box.height<=viewport.height+.5;
 function focus(box,viewport,padding=9){
  if(!validBox(box,viewport)||!Number.isFinite(padding)||padding<0)return null;
  const x=Math.max(0,box.x-padding),y=Math.max(0,box.y-padding);
  return {x,y,width:Math.min(viewport.width,box.x+box.width+padding)-x,
   height:Math.min(viewport.height,box.y+box.height+padding)-y};
 }
 function ellipse(box,viewport){
  if(!validBox(box,viewport))return null;
  // sqrt(2) encloses the rectangular target's corners, not just its center.
  const center={x:box.x+box.width/2,y:box.y+box.height/2};
  const rx=(box.width/2+6)*Math.SQRT2,ry=(box.height/2+6)*Math.SQRT2;
  if(center.x-rx<3||center.y-ry<3||center.x+rx>viewport.width-3||center.y+ry>viewport.height-3)return null;
  return {...center,rx,ry};
 }
 function arrow(from,to){
  if(![from.x,from.y,to.x,to.y].every(Number.isFinite)||Math.hypot(to.x-from.x,to.y-from.y)<12)return null;
  const reach=(to.x-from.x)*.4;
  return `M${from.x},${from.y} C${from.x+reach},${from.y} ${to.x-reach},${to.y} ${to.x},${to.y}`;
 }
 return {validBox,focus,ellipse,arrow};
})();
if(typeof module!=='undefined')module.exports=GuidanceGeometry;
