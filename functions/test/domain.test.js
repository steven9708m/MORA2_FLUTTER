const {test} = require('node:test');
const assert = require('node:assert/strict');
const {validateProfile,assertAdminTransition,attendanceId} = require('../domain');
test('rejects privilege values and malformed addresses',()=>{
  const profile={name:'Ana',email:'ana@example.com',zone:'Zona 1',role:'leader',status:'activo'};
  assert.equal(validateProfile({...profile,email:' ANA@example.com '}).email,'ana@example.com');
  assert.throws(()=>validateProfile({...profile,role:'superadmin'}));
  assert.throws(()=>validateProfile({...profile,email:'a@'}));
});
test('last active admin cannot be disabled or demoted',()=>{
  const admin={role:'admin',status:'activo'};
  assert.throws(()=>assertAdminTransition(admin,{...admin,status:'inactivo'},1));
  assert.throws(()=>assertAdminTransition(admin,{...admin,role:'leader'},1));
  assert.doesNotThrow(()=>assertAdminTransition(admin,{...admin,role:'leader'},2));
});
test('attendance identity is unique for valid component identifiers',()=>{
  assert.equal(attendanceId('activity-1','young_1'),'activity-1:young_1');
  assert.notEqual(attendanceId('ab','c'),attendanceId('a','bc'));
  assert.throws(()=>attendanceId('a:b','c')); assert.throws(()=>attendanceId('a','../b'));
});
