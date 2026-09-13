'use strict';
// Explicit project + ADC are required. Default mode only reports counts.
// Stop client writes for the reviewed maintenance window before --apply.
const {initializeApp} = require('firebase-admin/app');
const {getFirestore, FieldValue, Timestamp, FieldPath} = require('firebase-admin/firestore');
const {getAuth} = require('firebase-admin/auth');
const {attendanceId} = require('../domain');
async function migrate({projectId, apply = false, preserveOrphans = false, db, auth}) {
if (!projectId || !db || !auth) throw new Error('Project, Firestore and Auth are required.');
const runId = `review-${Date.now()}`;
const report = {mode: apply ? 'apply' : 'dry-run', projectId, runId, updated: 0, duplicates: 0, leaders: 0, archivedOrphans: 0, needsReview: 0, issues: []};
function review(doc,reason) {report.needsReview++;report.issues.push({path:doc.ref.path,reason});}

async function all(collection) {
  const result = [];
  let cursor;
  while (true) {
    let query = db.collection(collection).orderBy(FieldPath.documentId()).limit(250);
    if (cursor) query = query.startAfter(cursor);
    const page = await query.get(); result.push(...page.docs);
    if (page.size < 250) return result;
    cursor = page.docs.at(-1);
  }
}
function date(value) {
  if (value instanceof Timestamp) return value;
  if (typeof value !== 'string' || !/^\d{4}-\d{2}-\d{2}$/.test(value)) return null;
  const parsed = new Date(`${value}T00:00:00Z`);
  return !isNaN(parsed) && parsed.toISOString().slice(0,10) === value ? Timestamp.fromDate(parsed) : null;
}
async function saveWithBackup(doc, patch) {
  report.updated++;
  if (!apply) return;
  await db.runTransaction(async tx => {
    const current = await tx.get(doc.ref);
    const backup = db.doc(`migrationBackups/${runId}/documents/${doc.ref.parent.id}:${doc.id}`);
    const savedBackup = await tx.get(backup);
    if (!current.exists || !current.updateTime.isEqual(doc.updateTime)) {
      throw new Error('Un documento cambió durante la migración. Detén las escrituras y repite el diagnóstico.');
    }
    if (!savedBackup.exists) tx.create(backup, {path: doc.ref.path, data: current.data()});
    tx.update(doc.ref, patch);
  });
}
async function main() {
  // Resolve email-keyed profiles only when the Auth UID can be verified.
  const leaders = await all('leaders');
  for (const leader of leaders) {
    let user;
    try { user = await auth.getUserByEmail(leader.data().email); }
    catch (error) { review(leader,`Auth: ${error.code ?? 'lookup-failed'}`); continue; }
    if (user.uid === leader.id) continue;
    const target = db.doc(`leaders/${user.uid}`);
    const existing = await target.get();
    if (existing.exists && (existing.data().email !== leader.data().email ||
        existing.data().role !== leader.data().role || existing.data().status !== leader.data().status)) {
      review(leader,'Conflicting UID profile'); continue;
    }
    report.leaders++;
    if (!apply) continue;
    await db.doc(`migrationBackups/${runId}/documents/leaders:${leader.id}`).set({path:leader.ref.path,data:leader.data()});
    if (!existing.exists) await target.create({...leader.data(), updatedAt: FieldValue.serverTimestamp()});
    for (const collection of ['jovenes','registros','reportes','asistencias']) {
      const refs = await db.collection(collection).where('leaderId','==',leader.id).get();
      for (const ref of refs.docs) await saveWithBackup(ref,{leaderId:user.uid});
    }
    // Source remains recoverable in migrationBackups. Maintenance must exclude writers.
    await leader.ref.delete();
  }
  for (const collection of ['registros','reportes','jovenes','actividades']) {
    for (const doc of await all(collection)) {
      const data = doc.data();
      const patch = {};
      if (data.archived === undefined) patch.archived = false;
      if (!(data.createdAt instanceof Timestamp)) { review(doc,'Missing or invalid createdAt'); continue; }
      if (collection === 'jovenes') {
        patch.searchName = String(data.nombre ?? '').trim().toLowerCase();
        const birth = date(data.fechaNacimiento);
        if (birth && !(data.fechaNacimiento instanceof Timestamp)) patch.fechaNacimiento = birth;
        if (!birth) review(doc,'Missing or invalid fechaNacimiento');
      }
      if (collection === 'reportes' || collection === 'actividades') {
        const normalized = date(data.fecha);
        if (normalized && !(data.fecha instanceof Timestamp)) patch.fecha = normalized;
        if (!normalized && collection === 'reportes' && data.fecha == null) {
          patch.fecha = data.createdAt;
          patch.fechaInferredFromCreatedAt = true;
        } else if (!normalized) review(doc,'Invalid fecha');
      }
      if (Object.keys(patch).some(key => patch[key] !== data[key])) await saveWithBackup(doc,patch);
    }
  }
  const groups = new Map();
  for (const doc of await all('asistencias')) {
    let id;
    try { id = attendanceId(doc.data().activityId,doc.data().jovenId); }
    catch (_) { review(doc,'Invalid attendance identity'); continue; }
    if (!groups.has(id)) groups.set(id,[]);
    groups.get(id).push(doc);
  }
  for (const [id, docs] of groups) {
    docs.sort((a,b) => (b.data().updatedAt?.toMillis?.() ?? 0) - (a.data().updatedAt?.toMillis?.() ?? 0) || b.id.localeCompare(a.id));
    if (typeof docs[0].data().attended !== 'boolean' || docs.length > 150) { review(docs[0],'Invalid attendance status or excessive duplicates'); continue; }
    const latest = docs[0].data();
    const activity = await db.doc(`actividades/${latest.activityId}`).get();
    const young = await db.doc(`jovenes/${latest.jovenId}`).get();
    if (!activity.exists || !young.exists) {
      if (!preserveOrphans) { review(docs[0],'Missing activity/youth'); continue; }
      const reason=!activity.exists ? 'missing-activity' : 'missing-youth';
      for (const doc of docs) {
        report.archivedOrphans++;
        if(doc.data().archived===true && doc.data().migrationIssue===reason)continue;
        await saveWithBackup(doc,{archived:true,migrationIssue:reason,archivedAt:FieldValue.serverTimestamp(),archivedBy:'migration'});
      }
      continue;
    }
    if (!date(activity.data().fecha)) { review(docs[0],'Invalid activity date'); continue; }
    if (docs.length === 1 && docs[0].id === id && latest.activityDate && latest.version) continue;
    report.duplicates += Math.max(0,docs.length-1); report.updated++;
    if (!apply) continue;
    await db.runTransaction(async tx => {
      const current = await tx.getAll(...docs.map(doc => doc.ref));
      const backups = await tx.getAll(...docs.map(doc => db.doc(`migrationBackups/${runId}/documents/asistencias:${doc.id}`)));
      if (current.some((doc,index) => !doc.exists || !doc.updateTime.isEqual(docs[index].updateTime))) {
        throw new Error('Asistencia modificada durante la migración. Repite con las escrituras detenidas.');
      }
      for (const [index, doc] of current.entries()) {
        if (!backups[index].exists) tx.create(backups[index].ref,{path:doc.ref.path,data:doc.data()});
        if (doc.id !== id) tx.delete(doc.ref);
      }
      tx.set(db.doc(`asistencias/${id}`),{...latest, leaderId:young.data().leaderId,
        activityDate:date(activity.data().fecha).toDate().toISOString().slice(0,10),
        version:Number.isInteger(latest.version)?latest.version:1,
        createdAt:latest.createdAt ?? FieldValue.serverTimestamp()});
    });
  }
  return report;
}
return main();
}
module.exports = {migrate};
async function cli() {
  const args=process.argv.slice(2);
  const option=key=>args[args.indexOf(key)+1];
  const projectId=args.includes('--project') ? option('--project') : null;
  const apply=args.includes('--apply');
  if (!projectId || (apply && (!args.includes('--confirm-project') || option('--confirm-project')!==projectId))) {
    throw new Error('Usa --project ID para diagnóstico; para escribir añade --apply --confirm-project ID.');
  }
  initializeApp({projectId});
  const db=getFirestore('mora2');
  try {
    const report=await migrate({projectId,apply,preserveOrphans:args.includes('--preserve-orphans'),db,auth:getAuth()});
    console.log(JSON.stringify(report,null,2));
    if(report.needsReview)process.exitCode=2;
  } finally { await db.terminate(); }
}
if(require.main===module)cli().catch(error=>{console.error(error.message);process.exitCode=1;});
