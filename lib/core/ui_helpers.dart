part of '../app.dart';

String safeString(
  Map<String, dynamic> data,
  String key, [
  String fallback = '',
]) {
  final value = data[key];
  if (value == null) return fallback;
  return value.toString();
}

String _phoneDisplay(Map<String, dynamic> data) {
  final phone = safeString(data, 'telefono').trim();
  return phone.isEmpty ? 'Sin teléfono' : phone;
}

bool safeBool(Map<String, dynamic> data, String key, [bool fallback = false]) {
  final value = data[key];
  if (value is bool) return value;
  return fallback;
}

bool isAdmin(String role) => role == 'admin';

String _ageDisplay(Map<String, dynamic> data) {
  final birth = parseDate(data['fechaNacimiento']);
  return birth == null
      ? safeString(data, 'edad')
      : '${ageOn(birth, DateTime.now())}';
}

String _formatAnyDate(dynamic value) {
  if (value == null) return '';
  if (value is Timestamp) {
    return DateFormat('yyyy-MM-dd').format(value.toDate().toUtc());
  }
  final raw = value.toString().trim();
  if (raw.isEmpty) return '';
  try {
    final dt = DateTime.parse(raw);
    return DateFormat('yyyy-MM-dd').format(dt);
  } catch (_) {
    return raw;
  }
}

DateTime? _extractDate(dynamic value) {
  if (value == null) return null;
  if (value is Timestamp) return value.toDate().toUtc();
  return _tryParseDateInput(value.toString());
}

DateTime? _tryParseDateInput(String value) => parseDate(value);

List<QueryDocumentSnapshot<Map<String, dynamic>>> _sortActivitiesByProximity(
  Iterable<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
) {
  final now = DateTime.now();
  final normalizedToday = DateTime(now.year, now.month, now.day);
  final sorted = docs.toList();

  sorted.sort((a, b) {
    final aDate = _extractDate(a.data()['fecha']);
    final bDate = _extractDate(b.data()['fecha']);

    if (aDate == null && bDate == null) return 0;
    if (aDate == null) return 1;
    if (bDate == null) return -1;

    final aDay = DateTime(aDate.year, aDate.month, aDate.day);
    final bDay = DateTime(bDate.year, bDate.month, bDate.day);
    final aPast = aDay.isBefore(normalizedToday);
    final bPast = bDay.isBefore(normalizedToday);

    if (aPast != bPast) return aPast ? 1 : -1;
    return aDay.compareTo(bDay);
  });

  return sorted;
}

String _formatRelativeActivityDate(dynamic value) {
  final date = _extractDate(value);
  if (date == null) return 'Fecha sin validar';
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final target = DateTime(date.year, date.month, date.day);
  final difference = target.difference(today).inDays;

  if (difference == 0) return 'Hoy';
  if (difference == 1) return 'Mañana';
  if (difference > 1) return 'En $difference días';
  if (difference == -1) return 'Ayer';
  return 'Hace ${difference.abs()} días';
}

Future<void> _pickDateIntoController(
  BuildContext context,
  TextEditingController controller, {
  bool birthDate = false,
}) async {
  final picked = await showDatePicker(
    context: context,
    initialDate: (() {
      final value = _tryParseDateInput(controller.text) ?? DateTime.now();
      return birthDate && value.isAfter(DateTime.now())
          ? DateTime.now()
          : value;
    })(),
    firstDate: DateTime(1900),
    lastDate: birthDate ? DateTime.now() : DateTime(2100),
  );
  if (picked == null) return;
  controller.text = DateFormat('yyyy-MM-dd').format(picked);
}

String _activityStatusLabel(String status) {
  switch (status.trim().toLowerCase()) {
    case 'activa':
      return 'Activa';
    case 'cerrada':
      return 'Cerrada';
    case 'programada':
    default:
      return 'Programada';
  }
}

Color _activityStatusColor(String status) {
  switch (status.trim().toLowerCase()) {
    case 'activa':
      return const Color(0xFF0F9D58);
    case 'cerrada':
      return const Color(0xFF6B7280);
    case 'programada':
    default:
      return const Color(0xFF6A3EC5);
  }
}

String _truncateText(String value, {int maxLength = 110}) {
  final clean = value.trim();
  if (clean.length <= maxLength) return clean;
  return '${clean.substring(0, maxLength).trimRight()}...';
}

List<List<T>> _chunkList<T>(List<T> items, int size) {
  final chunks = <List<T>>[];
  for (var i = 0; i < items.length; i += size) {
    final end = (i + size < items.length) ? i + size : items.length;
    chunks.add(items.sublist(i, end));
  }
  return chunks;
}

String _boolToSiNo(dynamic value) => value == true ? 'SI' : 'NO';

String _leaderDisplayName(
  Map<String, dynamic> data,
  Map<String, String> leaderNames,
) {
  final leaderId = safeString(data, 'leaderId').trim();
  final leaderName = leaderId.isEmpty ? '' : leaderNames[leaderId]?.trim();
  if (leaderName != null && leaderName.isNotEmpty) return leaderName;

  final storedName = safeString(data, 'leaderName').trim();
  if (storedName.isNotEmpty) return storedName;

  return leaderId.isEmpty ? 'Sin líder' : 'Líder no encontrado';
}

void _downloadBytes(Uint8List bytes, String filename) {
  if (!kIsWeb) {
    throw UnsupportedError('La descarga está disponible en la versión web.');
  }
  final blob = html.Blob([bytes]);
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.AnchorElement(href: url)
    ..setAttribute('download', filename)
    ..click();
  html.Url.revokeObjectUrl(url);
  anchor.remove();
}
