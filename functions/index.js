'use strict';
const {randomBytes, createHash} = require('node:crypto');
const {initializeApp} = require('firebase-admin/app');
const {getAuth} = require('firebase-admin/auth');
const {getFirestore, FieldValue} = require('firebase-admin/firestore');
const {onCall, HttpsError} = require('firebase-functions/v2/https');
const {onDocumentWritten} = require('firebase-functions/v2/firestore');
const {validateProfile, assertAdminTransition} = require('./domain');
initializeApp();
const db = getFirestore('mora2');
const auth = getAuth();
// Enable only after registering App Check providers and observing valid traffic.
const enforceAppCheck = process.env.ENFORCE_APP_CHECK === 'true';
const options = {region: 'us-central1', enforceAppCheck, maxInstances: 5};

async function requireAdmin(request, transaction) {
  if (!request.auth) throw new HttpsError('unauthenticated', 'Inicia sesión.');
  const ref = db.doc(`leaders/${request.auth.uid}`);
  const snap = transaction ? await transaction.get(ref) : await ref.get();
  if (snap.data()?.role !== 'admin' || snap.data()?.status !== 'activo') {
    throw new HttpsError('permission-denied', 'Esta operación requiere un administrador activo.');
  }
}

function documentId(value) {
  if (typeof value !== 'string' || !value || value.length > 254 || value.includes('/')) {
    throw new HttpsError('invalid-argument', 'Identificador inválido.');
  }
  return value;
}

async function userForEmail(email) {
  try { return await auth.getUserByEmail(email); }
  catch (error) {
    if (error.code !== 'auth/user-not-found') throw error;
    try {
      return await auth.createUser({email, password: randomBytes(32).toString('base64url')});
    } catch (creationError) {
      if (creationError.code !== 'auth/email-already-exists') throw creationError;
      return auth.getUserByEmail(email);
    }
  }
}

exports.saveLeader = onCall(options, async request => {
  await requireAdmin(request);
  let profile;
  try { profile = validateProfile(request.data ?? {}); }
  catch (error) { throw new HttpsError('invalid-argument', error.message); }
  let user;
  if (request.data.id) {
    const id = documentId(request.data.id);
    try { user = await auth.getUser(id); }
    catch (error) {
      if (error.code !== 'auth/user-not-found') throw error;
      throw new HttpsError('failed-precondition', 'El perfil antiguo requiere migración al UID de la cuenta.');
    }
    if (user.email?.toLowerCase() !== profile.email) {
      throw new HttpsError('invalid-argument', 'El correo de un perfil existente no se puede cambiar desde este formulario.');
    }
  } else {
    user = await userForEmail(profile.email);
  }
  const ref = db.doc(`leaders/${user.uid}`);
  // Auth and Firestore cannot share a transaction. Retrying finds the same UID.
  await db.runTransaction(async tx => {
    await requireAdmin(request, tx);
    const lock = db.doc('_system/adminChanges');
    await tx.get(lock);
    const previous = await tx.get(ref);
    const admins = await tx.get(db.collection('leaders').where('role', '==', 'admin').where('status', '==', 'activo'));
    try { assertAdminTransition(previous.data(), profile, admins.size); }
    catch (error) { throw new HttpsError('failed-precondition', error.message); }
    if (profile.status === 'inactivo') {
      const assigned = await tx.get(db.collection('jovenes').where('leaderId', '==', user.uid));
      if (assigned.docs.some(doc => doc.data().archived !== true)) {
        throw new HttpsError('failed-precondition', 'Reasigna los jóvenes activos antes de desactivar este líder.');
      }
    }
    tx.set(ref, {...profile, createdAt: previous.data()?.createdAt ?? FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(), authSyncPending: true}, {merge: true});
    tx.set(lock, {updatedAt: FieldValue.serverTimestamp()});
    tx.create(db.collection('auditLog').doc(), {action: 'leader.saved', targetId: user.uid,
      actorId: request.auth.uid, role: profile.role, status: profile.status, at: FieldValue.serverTimestamp()});
  });
  // A retryable trigger synchronizes Authentication from the latest profile.
  return {uid: user.uid, email: profile.email};
});

exports.syncLeaderAuthentication = onDocumentWritten({document: 'leaders/{uid}',
  database: 'mora2', region: 'us-central1', retry: true, maxInstances: 5}, async event => {
  if (!event.data?.after.exists || event.data.after.data().authSyncPending !== true) return;
  const ref = event.data.after.ref;
  // An older delivery may finish after a newer one. Always reconcile again if
  // the profile changed while the Auth operation was in flight.
  for (let attempt=0; attempt<5; attempt++) {
    const current = await ref.get();
    if (!current.exists) return;
    const desired = current.data();
    await auth.updateUser(event.params.uid, {disabled: desired.status !== 'activo', displayName: desired.name});
    if (desired.status !== 'activo') await auth.revokeRefreshTokens(event.params.uid);
    const settled = await db.runTransaction(async tx => {
      const latest = await tx.get(ref);
      if (!latest.exists) return true;
      if (!latest.updateTime.isEqual(current.updateTime)) return false;
      tx.update(ref, {authSyncPending: false});
      return true;
    });
    if (settled) return;
  }
  throw new Error('Profile changed repeatedly; retry Auth reconciliation.');
});

exports.prepareLeaderAccess = onCall(options, async request => {
  await requireAdmin(request);
  const id = documentId(request.data?.id);
  const profile = await db.doc(`leaders/${id}`).get();
  if (!profile.exists || profile.data().status !== 'activo') {
    throw new HttpsError('failed-precondition', 'El líder debe estar activo para recibir acceso.');
  }
  const user = await userForEmail(profile.data().email);
  if (user.uid !== id) throw new HttpsError('failed-precondition', 'Migra el perfil antiguo al UID real.');
  await db.collection('auditLog').add({action: 'leader.access_prepared', actorId: request.auth.uid,
    targetId: id, at: FieldValue.serverTimestamp()});
  // The client sends Firebase's standard recovery email after this validation.
  return {uid: id, email: user.email};
});

exports.archiveRecord = onCall(options, async request => {
  if (!request.auth) throw new HttpsError('unauthenticated', 'Inicia sesión.');
  const collection = request.data?.collection;
  if (!['registros', 'reportes', 'jovenes', 'actividades'].includes(collection)) {
    throw new HttpsError('invalid-argument', 'Desactiva líderes desde Editar líder.');
  }
  const ref = db.collection(collection).doc(documentId(request.data?.id));
  await db.runTransaction(async tx => {
    const actor = await tx.get(db.doc(`leaders/${request.auth.uid}`));
    const record = await tx.get(ref);
    const admin = actor.data()?.role === 'admin';
    if (actor.data()?.status !== 'activo' || !['admin','leader'].includes(actor.data()?.role) || !record.exists ||
        (!admin && (collection === 'actividades' || record.data().leaderId !== request.auth.uid))) {
      throw new HttpsError('permission-denied', 'No tienes permiso para archivar este registro.');
    }
    tx.update(ref, {archived: true, archivedAt: FieldValue.serverTimestamp(),
      archivedBy: request.auth.uid, updatedAt: FieldValue.serverTimestamp()});
    tx.create(db.collection('auditLog').doc(), {action: 'record.archived', collection,
      targetId: ref.id, actorId: request.auth.uid, at: FieldValue.serverTimestamp()});
  });
});

exports.auditAttendance = onDocumentWritten({document:'asistencias/{id}', database:'mora2',
  region:'us-central1', retry:true, maxInstances:5}, async event => {
  const before=event.data?.before.data(), after=event.data?.after.data();
  if (before?.attended===after?.attended && !!before===!!after) return;
  const id=createHash('sha256').update(event.id).digest('hex');
  await db.doc(`auditLog/${id}`).set({action:'attendance.changed',targetId:event.params.id,
    activityId:after?.activityId ?? before?.activityId ?? '',jovenId:after?.jovenId ?? before?.jovenId ?? '',
    previous:before?.attended ?? null,current:after?.attended ?? null,
    actorId:after?.updatedBy ?? 'migration',at:event.time});
});

exports.syncYoungOwner = onDocumentWritten({document:'jovenes/{id}',database:'mora2',region:'us-central1',retry:true,maxInstances:5},async event=>{
  const before=event.data?.before.data(),after=event.data?.after.data();
  if (!before || !after || before.leaderId===after.leaderId) return;
  const records=await db.collection('asistencias').where('jovenId','==',event.params.id).get();
  for (let offset=0;offset<records.size;offset+=20) {
    await Promise.all(records.docs.slice(offset,offset+20).map(doc=>db.runTransaction(async tx=>{
      const young=await tx.get(event.data.after.ref);
      const attendance=await tx.get(doc.ref);
      if (!young.exists || !attendance.exists) return;
      const leader=await tx.get(db.doc(`leaders/${young.data().leaderId}`));
      tx.update(doc.ref,{leaderId:young.data().leaderId,leaderName:leader.data()?.name ?? '',
        leaderZone:leader.data()?.zone ?? '',version:(attendance.data().version ?? 0)+1});
    })));
  }
});

exports.syncLeaderNames = onDocumentWritten({document:'leaders/{id}',database:'mora2',region:'us-central1',retry:true,maxInstances:5},async event=>{
  if (!event.data?.after.exists || event.data.before.data()?.name===event.data.after.data().name) return;
  const young=await db.collection('jovenes').where('leaderId','==',event.params.id).get();
  for(let offset=0;offset<young.size;offset+=20) {
    await Promise.all(young.docs.slice(offset,offset+20).map(doc=>db.runTransaction(async tx=>{
      const leader=await tx.get(event.data.after.ref);
      const current=await tx.get(doc.ref);
      if(leader.exists && current.exists && current.data().leaderId===leader.id && current.data().leaderName!==leader.data().name)
        tx.update(doc.ref,{leaderName:leader.data().name});
    })));
  }
});
