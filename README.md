# JV Líderes

Aplicación Flutter para administrar líderes, jóvenes, actividades, reportes y asistencia. Usa Firebase Authentication, Firestore **mora2** y Cloud Functions en **us-central1**.

## Desarrollo y pruebas

Requisitos: Flutter 3.35 o superior (validado con 3.38.9), Dart 3.8 o superior, Node.js 22, Firebase CLI y Java 21 para los emuladores.

```powershell
flutter pub get
npm --prefix functions ci
flutter analyze
flutter test
npm --prefix functions test
npm --prefix functions run check
firebase emulators:exec --only 'auth,firestore,functions' --project demo-jv 'npm --prefix functions run test:emulators'
```

Para desarrollo aislado, inicia los emuladores y, en otra terminal, abre la aplicación:

```powershell
firebase emulators:start --only 'auth,firestore,functions' --project demo-jv
# Otra terminal:
flutter run -d chrome --dart-define=USE_FIREBASE_EMULATORS=true
```

La base local comienza vacía. Usa Admin SDK conectado al emulador para crear una cuenta de prueba y `leaders/{uid}` con `name`, `email`, `zone`, `role: admin` y `status: activo`. Las pruebas automatizadas crean sus propios datos en proyectos ficticios `demo-*`.

## Organización

- `lib/main.dart`: inicialización de Firebase, App Check y servicios.
- `lib/app.dart`: aplicación, rutas y composición de la interfaz.
- `lib/features/`: pantallas agrupadas por función.
- `lib/data/`: repositorios, dependencias inyectables y consultas compartidas.
- `lib/core/`, `lib/ui/`: validación, fechas, errores, formularios y paginación reutilizables.
- `functions/`: operaciones administrativas, sincronización, auditoría y migración.
- `firestore.rules`, `firestore.indexes.json`: autorización, validación e índices.

Los módulos de interfaz todavía comparten una biblioteca Dart mediante `part`; la separación facilita mantener las pantallas y conserva compatibilidad. Los repositorios y validaciones son bibliotecas independientes.

## Publicación

**Esta versión requiere migrar los datos existentes antes de publicar el frontend.** Las listas filtran por `archived: false` y la búsqueda necesita `searchName`. Publicar solamente la web puede ocultar documentos antiguos y dejar operaciones administrativas sin servidor.

Consulta [la guía de actualización](docs/ACTUALIZACION.md). No se ha migrado ni desplegado esta revisión en producción.
