const {test,after}=require('node:test');
const assert=require('node:assert/strict');
const {execFile}=require('node:child_process');
const {promisify}=require('node:util');
const {initializeApp,deleteApp}=require('firebase-admin/app');
const {getFirestore,Timestamp}=require('firebase-admin/firestore');
const {getAuth}=require('firebase-admin/auth');
const run=promisify(execFile);
let app,db;
after(async()=>{if(db)await db.terminate();if(app)await deleteApp(app);});
test('migration diagnoses without writes, preserves originals and can be repeated',async()=>{
  if(!process.env.FIRESTORE_EMULATOR_HOST || !process.env.FIREBASE_AUTH_EMULATOR_HOST) throw new Error('Local emulators required.');
  // Separate demo project prevents deployed test triggers from racing maintenance.
  const projectId='demo-jv-migration';
  app=initializeApp({projectId},'migration');db=getFirestore(app,'mora2');
  const user=await getAuth(app).createUser({uid:'migrated-leader',email:'legacy@example.com'});
  const stamp=Timestamp.fromDate(new Date('2026-01-01T00:00:00Z'));
  await db.doc('leaders/legacy@example.com').set({name:'Legacy',email:user.email,role:'admin',status:'activo',zone:'Zona 1'});
  await db.doc('jovenes/young').set({nombre:'Ana',leaderId:user.email,fechaNacimiento:'2008-01-02',createdAt:stamp});
  await db.doc('actividades/event').set({nombre:'Evento',fecha:'2026-01-01',createdAt:stamp});
  await db.doc('reportes/report').set({leaderId:user.email,createdAt:stamp});
  for(const [id,attended,time] of [['old',false,1],['latest',true,2]]) {
    await db.doc(`asistencias/${id}`).set({activityId:'event',jovenId:'young',leaderId:user.email,attended,updatedAt:Timestamp.fromMillis(time)});
  }
  const migrate=async (apply,preserve=false)=>{
    const args=['scripts/migrate.js','--project',projectId,...(apply?['--apply','--confirm-project',projectId]:[]),...(preserve?['--preserve-orphans']:[])];
    const {stdout}=await run(process.execPath,args,{timeout:45000});return JSON.parse(stdout);
  };
  const diagnostic=await migrate(false);assert.equal(diagnostic.mode,'dry-run');
  assert.equal((await db.doc('jovenes/young').get()).data().archived,undefined);
  assert.equal((await db.doc('leaders/legacy@example.com').get()).exists,true);
  const applied=await migrate(true);assert.equal(applied.needsReview,0);
  assert.equal((await db.doc('leaders/legacy@example.com').get()).exists,false);
  assert.equal((await db.doc('leaders/migrated-leader').get()).exists,true);
  const youth=(await db.doc('jovenes/young').get()).data();
  assert.equal(youth.leaderId,user.uid);assert.equal(youth.searchName,'ana');assert.equal(youth.archived,false);
  const records=await db.collection('asistencias').get();assert.equal(records.size,1);assert.equal(records.docs[0].id,'event:young');
  assert.equal(records.docs[0].data().attended,true);
  assert.equal((await db.doc(`migrationBackups/${applied.runId}/documents/jovenes:young`).get()).data().data.leaderId,user.email);
  assert.equal((await db.doc(`migrationBackups/${applied.runId}/documents/asistencias:latest`).get()).data().data.leaderId,user.email);
  assert.equal((await db.doc('reportes/report').get()).data().fechaInferredFromCreatedAt,true);
  const repeated=await migrate(true);assert.equal(repeated.updated,0);assert.equal(repeated.leaders,0);
  await db.doc('asistencias/orphan').set({activityId:'event',jovenId:'deleted-young',leaderId:user.uid,attended:true});
  const preserved=await migrate(true,true);assert.equal(preserved.needsReview,0);assert.equal(preserved.archivedOrphans,1);
  const orphan=await db.doc('asistencias/orphan').get();assert.equal(orphan.exists,true);assert.equal(orphan.data().archived,true);
  assert.equal(orphan.data().attended,true);assert.equal(orphan.data().migrationIssue,'missing-youth');
  assert.equal((await db.doc(`migrationBackups/${preserved.runId}/documents/asistencias:orphan`).get()).exists,true);
  assert.equal((await migrate(true,true)).updated,0);
});
