const {before,after,test}=require('node:test');
const assert=require('node:assert/strict');
const {initializeApp:adminApp}=require('firebase-admin/app');
const {getFirestore}=require('firebase-admin/firestore');
const {getAuth:adminAuth}=require('firebase-admin/auth');
const {initializeApp,deleteApp}=require('firebase/app');
const {getAuth,connectAuthEmulator,signInWithEmailAndPassword}=require('firebase/auth');
const {getFunctions,connectFunctionsEmulator,httpsCallable}=require('firebase/functions');
let db,users,client,call;const apps=[];
before(async()=>{
  if(!process.env.FIRESTORE_EMULATOR_HOST || !process.env.FIREBASE_AUTH_EMULATOR_HOST) throw new Error('Local emulators required.');
  adminApp({projectId:'demo-jv'});db=getFirestore('mora2');users=adminAuth();
  try{await users.createUser({uid:'admin',email:'admin@example.com',password:'test-password-123'});}catch(e){if(e.code!=='auth/uid-already-exists' && e.code!=='auth/email-already-exists')throw e;}
  await db.doc('leaders/admin').set({name:'Admin',email:'admin@example.com',zone:'Zona 1',role:'admin',status:'activo'});
  client=initializeApp({projectId:'demo-jv',apiKey:'demo-key',appId:'demo-app'},'integration');apps.push(client);
  const auth=getAuth(client);connectAuthEmulator(auth,`http://${process.env.FIREBASE_AUTH_EMULATOR_HOST}`,{disableWarnings:true});
  await signInWithEmailAndPassword(auth,'admin@example.com','test-password-123');
  const functions=getFunctions(client,'us-central1');connectFunctionsEmulator(functions,'127.0.0.1',5001);
  call=(name,data)=>httpsCallable(functions,name)(data);
});
after(async()=>{await Promise.all(apps.map(deleteApp));});
test('callable provisioning is retryable and preserves the Auth UID',async()=>{
  const profile={name:'Líder nuevo',email:'new@example.com',zone:'Zona 1',role:'leader',status:'activo'};
  const first=await call('saveLeader',profile);const second=await call('saveLeader',profile);
  assert.equal(first.data.uid,second.data.uid);
  assert.equal((await users.getUserByEmail(profile.email)).uid,first.data.uid);
  assert.equal((await db.doc(`leaders/${first.data.uid}`).get()).data().role,'leader');
  const access=await call('prepareLeaderAccess',{id:first.data.uid});assert.equal(access.data.email,profile.email);
});
test('callable cannot demote the only active administrator',async()=>{
  await assert.rejects(call('saveLeader',{id:'admin',name:'Admin',email:'admin@example.com',zone:'Zona 1',role:'leader',status:'activo'}),
    error=>error.code==='functions/failed-precondition');
  assert.equal((await db.doc('leaders/admin').get()).data().role,'admin');
});
test('editing a profile cannot create an account for another email',async()=>{
  await assert.rejects(call('saveLeader',{id:'admin',name:'Admin',email:'unexpected@example.com',zone:'Zona 1',role:'admin',status:'activo'}),
    error=>error.code==='functions/invalid-argument');
  await assert.rejects(users.getUserByEmail('unexpected@example.com'),error=>error.code==='auth/user-not-found');
});
test('archive preserves the record and writes an administrative audit',async()=>{
  await db.doc('actividades/event').set({nombre:'Encuentro',estado:'activa'});
  await call('archiveRecord',{collection:'actividades',id:'event'});
  const doc=await db.doc('actividades/event').get();assert.equal(doc.exists,true);assert.equal(doc.data().archived,true);
  const audit=await db.collection('auditLog').where('action','==','record.archived').get();assert.equal(audit.empty,false);
});
