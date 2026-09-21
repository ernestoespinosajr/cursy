const {test} = require('node:test');
const assert = require('node:assert/strict');
const {HomeInputLab} = require('./home-input-model.js');
test('blank input is ignored, text is bounded and multiline is retained',()=>{
 const lab=new HomeInputLab();lab.setDraft(0,'   ');assert.equal(lab.send(0),null);
 lab.setDraft(0,'hola\nsegunda línea');const token=lab.send(0);
 assert.ok(token);assert.equal(lab.chat(0).messages[0].text,'hola\nsegunda línea');
 assert.equal(lab.chat(0).draft,'');lab.setDraft(1,'a'.repeat(4100));assert.equal(lab.chat(1).draft.length,4000);
});
test('drafts are isolated and a late reply cannot cross a cancelled chat',()=>{
 const lab=new HomeInputLab();lab.setDraft(0,'primero');lab.setDraft(1,'segundo');
 const token=lab.send(0);lab.cancel();assert.equal(lab.answer(0,token,'tarde'),false);
 assert.equal(lab.chat(1).draft,'segundo');assert.equal(lab.chat(0).messages.length,1);
});
test('one response per request, and no double-send',()=>{
 const lab=new HomeInputLab();lab.setDraft(0,'hola');const token=lab.send(0);
 lab.setDraft(0,'otra');assert.equal(lab.send(0),null);
 assert.equal(lab.answer(0,token,'ejemplo'),true);assert.equal(lab.answer(0,token,'duplicada'),false);
 assert.equal(lab.chat(0).messages.length,2);
});
test('microphone test permission, disconnected device, stop and selection reset',()=>{
 const lab=new HomeInputLab();assert.equal(lab.startTest('denied'),'denied');
 lab.selectMicrophone('missing');assert.equal(lab.startTest(),'missing');
 lab.selectMicrophone('builtin');assert.equal(lab.startTest(),'testing');
 lab.selectMicrophone('system');assert.equal(lab.testState,'idle');
 lab.startTest();lab.stopTest();assert.equal(lab.testState,'idle');
});
