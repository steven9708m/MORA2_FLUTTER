part of '../app.dart';

Future<void> _deleteDoc(
  String collection,
  String docId,
  BuildContext context,
) async {
  if (collection == 'leaders') {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Para retirar un líder, reasigna sus jóvenes y cambia su estado desde Editar.',
        ),
      ),
    );
    return;
  }
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Archivar registro'),
      content: const Text(
        'Se ocultará de las listas activas y se conservará su historial.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Archivar'),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return;
  try {
    await appServices.archive(collection, docId);
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Registro archivado.')));
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_errorMessage(e))));
    }
  }
}

String? _required(String? value) =>
    (value ?? '').trim().isEmpty ? 'Este campo es obligatorio.' : null;

String _errorMessage(Object error) {
  if (error is StateError) return error.message.toString();
  if (error is FirebaseFunctionsException) {
    if (error.code == 'not-found' || error.code == 'unimplemented') {
      return 'La operación de servidor aún no está disponible. Contacta al administrador.';
    }
    return error.message ??
        'No se pudo completar la operación. Intenta de nuevo.';
  }
  if (error is FirebaseException) {
    switch (error.code) {
      case 'invalid-credential':
      case 'wrong-password':
      case 'user-not-found':
        return 'No se pudo iniciar sesión con esos datos.';
      case 'user-disabled':
        return 'La cuenta está desactivada. Contacta al administrador.';
      case 'permission-denied':
        return 'Tu cuenta no tiene permiso para esta operación. Revisa tu sesión.';
      case 'unavailable':
      case 'network-request-failed':
        return 'No hay conexión con el servicio. Revisa tu conexión e intenta de nuevo.';
      case 'too-many-requests':
        return 'Hubo demasiados intentos. Espera un momento e intenta de nuevo.';
    }
  }
  return 'No se pudo completar la operación. Tus datos permanecen en el formulario para reintentar.';
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;
  const _ErrorState(this.message, {this.onRetry});
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off_outlined, size: 36),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
          if (onRetry != null)
            TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
            ),
        ],
      ),
    ),
  );
}

Future<void> _showEditor(
  BuildContext context, {
  required String title,
  required GlobalKey<FormState> formKey,
  required Widget content,
  required Future<String> Function() onSave,
}) async {
  final message = await showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (_) => AsyncEditor(
      title: title,
      formKey: formKey,
      content: content,
      onSave: onSave,
      errorMessage: _errorMessage,
    ),
  );
  if (message != null && context.mounted) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

List<QueryDocumentSnapshot<Map<String, dynamic>>> _uniqueAttendance(
  List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
) {
  final byPair = <String, QueryDocumentSnapshot<Map<String, dynamic>>>{};
  for (final doc in docs) {
    final data = doc.data();
    if (data['archived'] == true) continue;
    final key = '${data['activityId']}:${data['jovenId']}';
    final previous = byPair[key];
    final date = data['updatedAt'] is Timestamp
        ? (data['updatedAt'] as Timestamp).millisecondsSinceEpoch
        : 0;
    final previousDate = previous?.data()['updatedAt'] is Timestamp
        ? (previous!.data()['updatedAt'] as Timestamp).millisecondsSinceEpoch
        : 0;
    if (previous == null ||
        date > previousDate ||
        (date == previousDate && doc.id.compareTo(previous.id) > 0)) {
      byPair[key] = doc;
    }
  }
  return byPair.values.toList();
}
