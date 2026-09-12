'use strict';

function validateProfile(data) {
  const text = (field, max) => {
    const value = data[field];
    if (typeof value !== 'string' || !value.trim() || value.trim().length > max) {
      throw new Error(`El campo ${field} no es válido.`);
    }
    return value.trim();
  };
  const name = text('name', 150);
  const email = text('email', 254).toLowerCase();
  const zone = text('zone', 80);
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) throw new Error('Correo inválido.');
  if (!['admin', 'leader'].includes(data.role)) throw new Error('Rol inválido.');
  if (!['activo', 'inactivo'].includes(data.status)) throw new Error('Estado inválido.');
  return {name, email, zone, role: data.role, status: data.status};
}

function assertAdminTransition(previous, next, activeAdminCount) {
  if (previous?.role === 'admin' && previous.status === 'activo' &&
      (next.role !== 'admin' || next.status !== 'activo') && activeAdminCount <= 1) {
    throw new Error('Debe quedar al menos un administrador activo.');
  }
}

function attendanceId(activityId, jovenId) {
  if (![activityId, jovenId].every(id => typeof id === 'string' && /^[A-Za-z0-9_-]+$/.test(id))) {
    throw new Error('Identificador incompatible; requiere revisión manual.');
  }
  return `${activityId}:${jovenId}`;
}

module.exports = {validateProfile, assertAdminTransition, attendanceId};
