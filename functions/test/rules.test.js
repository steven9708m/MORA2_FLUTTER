const {before,after,beforeEach,test}=require('node:test');
const fs=require('node:fs');
const {initializeTestEnvironment,assertSucceeds,assertFails}=require('@firebase/rules-unit-testing');
const {doc,setDoc,updateDoc,getDoc,getDocs,collection,query,where,deleteDoc,serverTimestamp,Timestamp,runTransaction}=require('firebase/firestore');
let env;
before(async()=>{env=await initializeTestEnvironment({projectId:'demo-jv',firestore:{rules:fs.readFileSync('../firestore.rules','utf8')}});});
after(async()=>{await env?.cleanup();});
const client=uid=>env.authenticatedContext(uid,{email:`${uid}@example.com`,email_verified:false}).firestore();
const stamp=Timestamp.fromDate(new Date('2026-01-01T00:00:00Z'));
const young=(leaderId='leader')=>({nombre:'Ana',searchName:'ana',edad:18,fechaNacimiento:Timestamp.fromDate(new Date('2008-01-01T00:00:00Z')),
  telefono:'',leaderName:'Líder',leaderId,claseNuevo:false,claseDoctrina:false,claseMaestro:false,claseLiderazgo:false,bautismo:false,createdAt:stamp,updatedAt:stamp});
const attendance=()=>({activityId:'activity',activityName:'Reunión',activityDate:'2026-01-01',jovenId:'young',jovenNombre:'Ana',
  leaderId:'leader',leaderName:'Líder',leaderZone:'Zona 1',attended:true,version:1,updatedBy:'leader',createdAt:serverTimestamp(),updatedAt:serverTimestamp()});
beforeEach(async()=>{
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async ctx=>{
    const db=ctx.firestore();
    for(const [id,role,status] of [['admin','admin','activo'],['leader','leader','activo'],['other','leader','activo'],['disabled','leader','inactivo']])
      await setDoc(doc(db,'leaders',id),{name:id,email:`${id}@example.com`,role,status,zone:'Zona 1'});
    await setDoc(doc(db,'jovenes','young'),young());
    await setDoc(doc(db,'actividades','activity'),{nombre:'Reunión',fecha:stamp,estado:'activa',descripcion:'Encuentro',createdAt:stamp,updatedAt:stamp});
    await setDoc(doc(db,'registros','record'),{titulo:'Título',descripcion:'Texto',leaderId:'leader',createdAt:stamp,updatedAt:stamp});
  });
});
test('unauthenticated and inactive users cannot read youth',async()=>{
  await assertFails(getDoc(doc(env.unauthenticatedContext().firestore(),'jovenes','young')));
  await assertFails(getDoc(doc(client('disabled'),'jovenes','young')));
  await assertFails(getDoc(doc(client('other'),'jovenes','young')));
  await assertSucceeds(getDoc(doc(client('leader'),'jovenes','young')));
});
test('owner cannot transfer records or forge timestamps',async()=>{
  const ref=doc(client('leader'),'registros','record');
  await assertFails(updateDoc(ref,{leaderId:'other',updatedAt:serverTimestamp()}));
  await assertFails(updateDoc(ref,{createdAt:Timestamp.now(),updatedAt:serverTimestamp()}));
  await assertSucceeds(updateDoc(ref,{titulo:'Actualizado',updatedAt:serverTimestamp()}));
});
test('client cannot claim invitations, edit roles or delete the last admin',async()=>{
  await env.withSecurityRulesDisabled(ctx=>setDoc(doc(ctx.firestore(),'leaders','leader@example.com'),{name:'Leader',role:'admin',status:'activo',zone:'Zona 1',email:'leader@example.com'}));
  await assertFails(setDoc(doc(client('other'),'leaders','other'),{role:'admin'}));
  await assertFails(deleteDoc(doc(client('admin'),'leaders','admin')));
  await assertFails(setDoc(doc(client('admin'),'leaders','new'),{role:'leader'}));
});
test('reports require typed dates and nonnegative attendance',async()=>{
  const db=client('leader'); const base={semana:'Semana 1',fecha:stamp,asistencia:5,observaciones:'Bien',leaderId:'leader',createdAt:serverTimestamp(),updatedAt:serverTimestamp()};
  const {fecha,...missing}=base;
  await assertFails(setDoc(doc(db,'reportes','bad'),missing));
  await assertFails(setDoc(doc(db,'reportes','bad'),{...base,asistencia:-2}));
  await assertSucceeds(setDoc(doc(db,'reportes','good'),base));
});
test('attendance creation requires canonical identity, ownership and existing activity',async()=>{
  const db=client('leader');
  await assertFails(setDoc(doc(db,'asistencias','random'),attendance()));
  await assertFails(setDoc(doc(client('other'),'asistencias','activity:young'),{...attendance(),updatedBy:'other'}));
  await assertFails(setDoc(doc(db,'asistencias','missing:young'),{...attendance(),activityId:'missing'}));
  await assertFails(setDoc(doc(db,'asistencias','activity:young'),{...attendance(),activityDate:'2026-12-31'}));
  await assertSucceeds(setDoc(doc(db,'asistencias','activity:young'),attendance()));
  await assertSucceeds(getDocs(query(collection(db,'asistencias'),where('activityId','==','activity'),where('leaderId','==','leader'))));
  await assertSucceeds(getDocs(query(collection(db,'asistencias'),where('jovenId','==','young'))));
});
test('transaction may read missing canonical doc; versions and references are protected',async()=>{
  const db=client('leader'),ref=doc(db,'asistencias','activity:young');
  await assertSucceeds(runTransaction(db,async tx=>{await tx.get(ref);tx.set(ref,attendance());}));
  await assertFails(updateDoc(ref,{attended:false,updatedAt:serverTimestamp()}));
  await assertFails(updateDoc(ref,{jovenId:'another',version:2,updatedAt:serverTimestamp()}));
  await assertSucceeds(updateDoc(ref,{attended:false,version:2,updatedAt:serverTimestamp()}));
});
test('closed and archived activity deny attendance writes',async()=>{
  await env.withSecurityRulesDisabled(ctx=>updateDoc(doc(ctx.firestore(),'actividades','activity'),{estado:'cerrada'}));
  await assertFails(setDoc(doc(client('leader'),'asistencias','activity:young'),attendance()));
  await env.withSecurityRulesDisabled(ctx=>updateDoc(doc(ctx.firestore(),'actividades','activity'),{estado:'activa',archived:true}));
  await assertFails(setDoc(doc(client('leader'),'asistencias','activity:young'),attendance()));
});
test('youth types and owner assignment are validated; archived records stay read-only',async()=>{
  const data={...young(),archived:false,createdAt:serverTimestamp(),updatedAt:serverTimestamp()};
  await assertSucceeds(setDoc(doc(client('leader'),'jovenes','new'),data));
  await assertFails(setDoc(doc(client('leader'),'jovenes','bad'),{...data,claseNuevo:'true'}));
  await assertFails(updateDoc(doc(client('leader'),'jovenes','new'),{leaderId:'other',updatedAt:serverTimestamp()}));
  await assertFails(updateDoc(doc(client('admin'),'jovenes','new'),{leaderId:'disabled',updatedAt:serverTimestamp()}));
  await assertSucceeds(updateDoc(doc(client('admin'),'jovenes','new'),{leaderId:'other',updatedAt:serverTimestamp()}));
  await env.withSecurityRulesDisabled(ctx=>updateDoc(doc(ctx.firestore(),'jovenes','new'),{archived:true}));
  await assertFails(updateDoc(doc(client('other'),'jovenes','new'),{nombre:'Cambio',updatedAt:serverTimestamp()}));
  await assertFails(deleteDoc(doc(client('admin'),'jovenes','new')));
});
