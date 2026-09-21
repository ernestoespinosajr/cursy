const {test}=require('node:test');
const assert=require('node:assert/strict');
const geometry=require('./guidance-geometry.js');
const viewport={width:1000,height:600};
test('focus encloses whole wide and wrapped paragraphs',()=>{
 for(const box of [{x:60,y:150,width:760,height:54},{x:60,y:150,width:400,height:110}]){
  const frame=geometry.focus(box,viewport);
  assert.equal(frame.width,box.width+18);assert.equal(frame.height,box.height+18);
  assert.ok(frame.x<=box.x&&frame.y<=box.y);
 }
});
test('invalid, missing or offscreen regions never generate a mark',()=>{
 for(const box of [null,{x:NaN,y:1,width:4,height:4},{x:-2,y:1,width:4,height:4},{x:995,y:0,width:20,height:20},{x:2,y:2,width:0,height:4}]){
  assert.equal(geometry.focus(box,viewport),null);assert.equal(geometry.ellipse(box,viewport),null);
 }
});
test('padding at the edge preserves the complete target and remains positive',()=>{
 for(const box of [{x:0,y:0,width:1,height:1},{x:990,y:590,width:10,height:10}]){
  const frame=geometry.focus(box,viewport);assert.ok(frame.width>0&&frame.height>0);
  assert.ok(frame.x<=box.x&&frame.y<=box.y);
  assert.ok(frame.x+frame.width>=box.x+box.width&&frame.y+frame.height>=box.y+box.height);
  assert.ok(geometry.validBox(frame,viewport));
 }
});
test('ellipse contains target corners and rejects a clipped oval',()=>{
 const box={x:300,y:180,width:100,height:40},oval=geometry.ellipse(box,viewport);
 assert.ok((box.width/2/oval.rx)**2+(box.height/2/oval.ry)**2<1);
 assert.equal(geometry.ellipse({...box,x:0},viewport),null);
});
test('arrow follows independent endpoints; short or invalid direction is rejected',()=>{
 assert.match(geometry.arrow({x:100,y:150},{x:550,y:250}),/^M100,150 C.*550,250$/);
 assert.equal(geometry.arrow({x:0,y:0},{x:0,y:2}),null);
 assert.equal(geometry.arrow({x:Infinity,y:0},{x:20,y:20}),null);
});
