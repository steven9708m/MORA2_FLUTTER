# Despliegue de producción — 12 de septiembre de 2026

Finalizado el 12 de septiembre de 2026 a las 22:33, hora de Panamá (13 de septiembre, 03:33 UTC).

- Aplicación: https://grupo-juvenil-morados.web.app/
- Proyecto: `grupo-juvenil-morados`.
- Firestore: `mora2`, región `northamerica-south1`.
- Functions: siete funciones de segunda generación activas en `us-central1`; sus triggers de Firestore operan en `northamerica-south1`.
- Versión de Hosting: `sites/grupo-juvenil-morados/versions/81796e19f2264a39`.
- Versión anterior de Hosting: `sites/grupo-juvenil-morados/versions/273e056664c829c6`.

## Respaldo y migración

Se bloqueó temporalmente el acceso de los clientes, se esperó la propagación de las reglas y se completó una exportación administrada de los 119 documentos existentes de la base antes de migrar. Firebase confirmó `SUCCESSFUL`.

Destino privado:

```text
gs://grupo-juvenil-morados-backups-630942576544/before-hardening-2026-09-13T03-24-17-593Z
```

El bucket tiene acceso uniforme y prevención de acceso público. No se aplicó una política automática de eliminación al respaldo.

La migración `review-1789269913205` actualizó 106 documentos, terminó con cero incidencias pendientes y conservó copias originales en `migrationBackups/{runId}/documents`. Los seis perfiles de líder ya coincidían con sus UID de Authentication, por lo que no necesitaron cambiar de ID.

Se encontraron siete marcas de asistencia cuyos jóvenes habían sido eliminados previamente. Se conservaron en `asistencias` con `archived: true` y `migrationIssue: missing-youth`, sin recrear personas ni eliminar esas marcas. La interfaz y las exportaciones excluyen las marcas archivadas de los totales activos.

## Resultado verificado

| Datos | Resultado |
|---|---|
| Jóvenes | 33 activos; fechas normalizadas y campos de búsqueda presentes |
| Actividades | 62 activas en los listados; fechas normalizadas |
| Reportes | 2; fechas normalizadas |
| Registros | 0 |
| Asistencias | 9 conservadas: 2 con ID canónico activo y 7 archivadas |
| Administrador | 1 activo; cuenta Auth habilitada |
| Índices | 12 en estado `READY` |

Las funciones `saveLeader`, `prepareLeaderAccess`, `archiveRecord`, `syncLeaderAuthentication`, `auditAttendance`, `syncYoungOwner` y `syncLeaderNames` quedaron en estado `ACTIVE`. El primer intento de crear triggers encontró propagación pendiente del rol de Eventarc; el reintento terminó correctamente sin cambios adicionales de roles por parte del asistente.

Las reglas activas de `mora2` coinciden con `firestore.rules` y reemplazan el bloqueo temporal. La descarga pública de `main.dart.js` respondió HTTP 200 y su SHA-256 coincide con la compilación local. Las tres funciones invocables respondieron HTTP 401 / `UNAUTHENTICATED` a solicitudes sin sesión.

La prueba de migración, incluyendo conservación de originales, repetición y archivo de referencias huérfanas, pasó en emuladores. Las diez pruebas Flutter pasaron y el análisis de `lib` y `test` no encontró incidencias. La compilación web JavaScript finalizó correctamente.

## Operación

La publicación no exigió compartir contraseñas ni crear archivos nuevos de claves privadas: se utilizó la sesión existente de Firebase CLI, con tokens solo en memoria. Los auxiliares y el estado detallado están en `.verification/`, excluidos de Git.

Firebase configuró limpieza de imágenes de Artifact Registry de más de un día durante el despliegue. Esta política corresponde a imágenes de compilación, no al respaldo de datos.

App Check sigue pendiente de registrar y configurar antes de exigir tokens. No se verificaron en producción la entrega de correos ni una sesión interactiva dentro del navegador del usuario. Las pruebas publicadas comprobaron contenido, estado de servicios, integridad de datos y rechazo de acceso sin autenticación.

Si hace falta recuperar datos, revisa el respaldo completo y las copias de la migración; restaurar solo una versión anterior de Hosting no revierte Firestore ni las funciones. No ejecutes una restauración completa sobre datos nuevos sin planificar su conciliación.
