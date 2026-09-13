# Actualización y operación de JV Líderes

## Cambios

Las escrituras de líderes pasan por Cloud Functions, que validan al administrador activo y conservan al menos uno. El cliente no puede asignarse roles, reclamar perfiles por correo ni borrar administradores. Un líder con jóvenes activos debe reasignarlos antes de desactivarse.

Las nuevas cuentas reciben una contraseña aleatoria en servidor. Reintentar reutiliza el UID; el usuario establece su contraseña mediante el correo estándar de Firebase solicitado desde la interfaz. Authentication y Firestore no comparten transacción: `authSyncPending` y un trigger con reintentos sincronizan nombre y estado. Una cuenta sin perfil autorizado no puede leer datos de la aplicación.

Las reglas validan campos, tipos, propietarios, referencias y fechas. La asistencia utiliza ID `actividadId:jovenId`, transacciones y versiones para detectar ediciones simultáneas. La interfaz confirma el resultado del servidor y distingue guardados parciales. Las actividades cerradas o archivadas bloquean nuevas marcas; un administrador debe reabrirlas para corregirlas.

Retirar documentos los archiva y conserva su historial. `auditLog` registra operaciones administrativas y cambios de asistencia; solo administradores pueden leerlo y solo el servidor lo escribe. Los triggers sincronizan referencias al reasignar un joven.

El frontend incorpora rutas directas, localización española, diseño adaptable, estados de carga/error, formularios que conservan datos al fallar, búsqueda por prefijo y páginas de 25 registros. El panel usa conteos agregados con actualización manual y asistencia en tiempo real dentro del período elegido. La edad se calcula desde la fecha de nacimiento al mostrarse.

## Interpretación de cifras y límites

- **Pendiente** significa que un joven activo de la lista consultada no tiene marca guardada; no equivale a ausente.
- **Presente / ausente** es una marca explícita confirmada por Firestore.
- **Registros** en el resumen por actividad cuenta documentos únicos guardados. El denominador no representa una convocatoria histórica completa.
- La lista de asistencia usa los jóvenes activos actuales; no hay una lista de convocados congelada por actividad. Archivar o reasignar jóvenes puede cambiar listados activos y atribución al líder, conservando las marcas históricas.
- Las exportaciones `.xlsx` descargables están orientadas a web. Las pruebas locales no acreditan funcionamiento en dispositivos nativos.
- La compilación web utiliza JavaScript. El paquete existente `universal_html` impide compilar a WebAssembly; esa migración queda pendiente.
- Restaurar registros archivados requiere actualmente una operación administrativa mediante Admin SDK; no hay papelera en la interfaz.

## Migración obligatoria

Esta revisión ya se migró y publicó en producción el 12 de septiembre de 2026, hora de Panamá; consulta el [registro del despliegue](DESPLIEGUE_2026-09-12.md). Los pasos siguientes quedan como procedimiento de referencia. Verifica el proyecto `grupo-juvenil-morados` y la base `mora2` antes de cualquier ejecución adicional.

1. Ensaya en un entorno de pruebas. Conserva una exportación administrada completa de Firestore y la versión desplegada. Las copias por documento del script no reemplazan el respaldo completo.
2. Prepara credenciales ADC administrativas para el mantenimiento. No incluyas cuentas de servicio en Git ni en el frontend.
3. Ejecuta el diagnóstico sin escrituras:

   ```powershell
   node functions/scripts/migrate.js --project grupo-juvenil-morados
   ```

   Revisa `needsReview`; la salida 2 indica casos pendientes. Perfiles sin cuenta Auth verificable, conflictos entre perfiles, fechas inválidas, referencias huérfanas y documentos sin `createdAt` requieren intervención. El script no inventa fechas de nacimiento ni crea cuentas para perfiles antiguos.
4. Programa mantenimiento y detén todas las escrituras de clientes, integraciones y tareas administrativas. Usa reglas temporales que denieguen escrituras: una página de mantenimiento no bloquea aplicaciones antiguas. No actives los nuevos triggers durante la migración.
5. Con respaldo comprobado y diagnóstico revisado, aplica:

   ```powershell
   node functions/scripts/migrate.js --project grupo-juvenil-morados --apply --confirm-project grupo-juvenil-morados
   ```

   El script añade `archived: false` y `searchName`, convierte fechas ISO válidas, migra perfiles antiguos al UID comprobado y actualiza referencias. Completa la fecha faltante de reportes desde `createdAt`, marcada con `fechaInferredFromCreatedAt`. Deduplica asistencia conservando la última actualización. Los originales se guardan en `migrationBackups/{runId}/documents` antes de modificarse. Una escritura concurrente detectada aborta la operación; investiga y repite con los escritores detenidos.

   Si el diagnóstico identifica asistencias cuyos jóvenes o actividades ya fueron eliminados, la opción explícita `--preserve-orphans` conserva esos documentos en `asistencias`, con `archived: true` y `migrationIssue`, y guarda sus originales. No recrea personas ni actividades. Las marcas archivadas quedan fuera de los totales activos. Sin esa opción, el diagnóstico sigue señalándolas como pendientes de revisión. El informe incluye las rutas y motivos de cada incidencia.
6. Repite el diagnóstico, resuelve todos los casos pendientes y compara conteos y muestras con el respaldo. Confirma que quede un administrador activo con ID coincidente con Authentication antes de reabrir.

## Publicación coordinada

Los siguientes comandos documentan el despliegue coordinado. Para actualizaciones posteriores, no repitas la migración ni el mantenimiento si el cambio no lo requiere.

Despliega índices y espera que estén listos:

```powershell
firebase deploy --only firestore:indexes --project grupo-juvenil-morados
```

Después de migrar, despliega funciones, reglas y frontend dentro de la misma ventana de mantenimiento:

```powershell
firebase deploy --only functions --project grupo-juvenil-morados
flutter build web --release
firebase deploy --only 'firestore:rules,hosting' --project grupo-juvenil-morados
```

Revisa permisos IAM, facturación y disponibilidad de Functions de segunda generación en el proyecto. Las funciones usan `us-central1`; la base existente está en `northamerica-south1`. Mide la latencia antes de decidir un traslado, que también requiere actualizar el cliente.

Comprueba sesión de administrador y líder, aislamiento entre líderes, nuevo reporte, asistencia individual/masiva, archivo, búsqueda, exportación y rutas directas. Fuerza la recarga del cliente antiguo y revisa errores de índices/permisos antes de terminar el mantenimiento.

## App Check, supervisión y recuperación

Registra el proveedor web y compila con `--dart-define=APP_CHECK_WEB_SITE_KEY=CLAVE_PUBLICA_DEL_SITIO`. Android usa Play Integrity y Apple App Attest; registra cada aplicación. Observa primero tráfico válido y compatibilidad. Después configura `ENFORCE_APP_CHECK=true` en el entorno de funciones, vuelve a desplegarlas y activa la exigencia de Firestore en la consola. `functions/.env.example` es solo una plantilla. No actives exigencia mientras clientes legítimos carezcan de tokens.

Supervisa errores de funciones, perfiles con `authSyncPending: true` persistente, reintentos, crecimiento de auditoría y lecturas. Define retención y restauración de archivos y respaldos según las necesidades de la organización.

Si falla la publicación, conserva el mantenimiento y recupera datos y versión compatibles desde el respaldo verificado. Volver solamente al HTML anterior no revierte reglas, funciones ni datos. La recuperación individual debe revisar los originales de `migrationBackups` y las referencias creadas; no existe reversión automática del script.

## Pruebas

`flutter test` cubre acceso, bloqueo de envíos, reintento de formularios, fechas, versiones de asistencia, deduplicación, Excel y navegación/paginación a 360, 768 y 1440 píxeles. Las pruebas del backend usan exclusivamente proyectos ficticios `demo-*`; incluyen reglas, funciones y migración. Los emuladores no verifican índices de producción, IAM, entrega real de correo ni proveedores App Check.

Capturas opcionales: `flutter test --dart-define=SAVE_REVIEW_SCREENSHOTS=true --dart-define=REVIEW_FONT_PATH=RUTA_A_ROBOTO_TTF`. Se guardan en `.verification/screens/` y no se versionan.

Las fechas civiles se interpretan en UTC tanto en el cliente como en las [reglas Timestamp de Firebase](https://firebase.google.com/docs/reference/rules/rules.Timestamp).
