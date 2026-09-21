const {test}=require('node:test');
const assert=require('node:assert/strict');
const {SelectionContext,selectionPosition}=require('./selection-model.js');
const {selectionMorphGeometry}=require('./selection-model.js');
test('morph maps material from button to editor without scaling content',()=>{
 const from={left:180,top:208,width:180,height:38},to={left:85,top:200,width:370,height:46};
 const geometry=selectionMorphGeometry(from,to);
 assert.equal(to.left+geometry.x,from.left);assert.equal(to.top+geometry.y,from.top);
 assert.equal(to.width*geometry.scaleX,from.width);assert.equal(to.height*geometry.scaleY,from.height);
});
test('morph fades instead of crossing obstacles when placement flips sides',()=>{
 assert.equal(selectionMorphGeometry({left:0,top:10,width:180,height:38},{left:0,top:200,width:370,height:46}),null);
 assert.equal(selectionMorphGeometry({left:0,top:0,width:0,height:38},{left:0,top:0,width:370,height:46}),null);
});
test('selection snapshot contains only exact selected text and is immutable',()=>{
 const state=new SelectionContext();state.select('  texto\nseleccionado  ');
 const context=state.snapshot();assert.deepEqual(context,{kind:'selection-only',text:'  texto\nseleccionado  '});
 assert.ok(Object.isFrozen(context));state.select('otro');assert.equal(context.text,'  texto\nseleccionado  ');
});
test('voice must follow explicit edit, greeting precedes listening',()=>{
 const state=new SelectionContext();state.select('texto');assert.equal(state.voice(),null);
 state.edit();const token=state.voice();assert.equal(state.phase,'greeting');assert.ok(state.listen(token));assert.equal(state.phase,'listening');assert.equal(state.listen(token),false);
});
test('cancellation and new selection invalidate greeting callbacks',()=>{
 const state=new SelectionContext();state.select('uno');state.edit();const token=state.voice();state.cancel();assert.equal(state.listen(token),false);
 state.select('dos');assert.equal(state.listen(token),false);assert.equal(state.text,'dos');
});
test('empty and oversized selections are rejected without retaining old context',()=>{
 const state=new SelectionContext();state.select('antes');assert.equal(state.select('  '),false);assert.equal(state.text,'');
 assert.equal(state.select('x'.repeat(6001)),false);
});
test('anchor stays in viewport with above preference and below fallback',()=>{
 assert.deepEqual(selectionPosition({left:100,top:200,bottom:240,width:200},240,50,{width:700,height:500}),{left:80,top:138,below:false});
 const edge=selectionPosition({left:0,top:10,bottom:40,width:20},296,90,{width:320,height:500});
 assert.deepEqual(edge,{left:12,top:52,below:true});
});
test('places toolbar above another app menu, not over its actions',()=>{
 const rect={left:100,top:250,bottom:290,width:300};
 const menu={left:80,right:440,top:200,bottom:238};
 const point=selectionPosition(rect,368,46,{width:700,height:600},[menu]);
 assert.equal(point.top,142);assert.ok(point.top+46+12<=menu.top);assert.equal(point.below,false);
});
test('falls below selection when a menu occupies the top edge',()=>{
 const point=selectionPosition({left:100,top:80,bottom:120,width:200},250,46,{width:500,height:500},[{left:90,right:360,top:20,bottom:68}]);
 assert.equal(point.top,132);assert.equal(point.below,true);
});
test('rejects crowded or oversized placement rather than clamping over content',()=>{
 const rect={left:50,top:60,bottom:180,width:200};
 assert.equal(selectionPosition(rect,250,70,{width:320,height:220}),null);
 assert.equal(selectionPosition(rect,500,40,{width:320,height:600}),null);
});
test('ignores horizontally unrelated menus and avoids multiple stacked obstacles',()=>{
 const rect={left:100,top:300,bottom:340,width:200};
 const point=selectionPosition(rect,240,40,{width:700,height:600},[
  {left:100,right:350,top:240,bottom:288},{left:100,right:350,top:180,bottom:228},
  {left:500,right:600,top:20,bottom:500}]);
 assert.deepEqual(point,{left:80,top:128,below:false});
});
