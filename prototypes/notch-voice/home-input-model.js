// Synthetic F3 state only: no microphone, network, storage or native preferences.
(function(root) {
 class HomeInputLab {
  constructor() { this.records = new Map(); this.revision = 0; this.pending = null; this.microphone = 'system'; this.testState = 'idle'; }
  chat(id, seed) {
   if (!this.records.has(id)) this.records.set(id, {draft:'', messages:seed?.request ? [
    {role:'user', text:seed.request}, {role:'assistant', text:seed.response}] : []});
   return this.records.get(id);
  }
  setDraft(id, text) { this.chat(id).draft = text.slice(0, 4000); }
  send(id) {
   const chat = this.chat(id), text = chat.draft.trim();
   if (!text || this.pending) return null;
   chat.messages.push({role:'user', text}); chat.draft = '';
   const token = ++this.revision; this.pending = {id, token}; return token;
  }
  answer(id, token, text) {
   if (this.pending?.id !== id || this.pending.token !== token) return false;
   this.chat(id).messages.push({role:'assistant', text}); this.pending = null; return true;
  }
  cancel() { this.pending = null; this.revision++; }
  selectMicrophone(device) { this.stopTest(); this.microphone = device; }
  startTest(permission = 'allowed') {
   this.testState = permission === 'denied' ? 'denied' : this.microphone === 'missing' ? 'missing' : 'testing';
   return this.testState;
  }
  stopTest() { this.testState = 'idle'; }
 }
 if (typeof module !== 'undefined') module.exports = {HomeInputLab};
 else root.HomeInputLab = HomeInputLab;
})(globalThis);
