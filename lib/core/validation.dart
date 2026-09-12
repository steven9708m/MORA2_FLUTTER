import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

DateTime? parseDate(Object? value) {
  if (value is Timestamp) return value.toDate().toUtc();
  if (value is DateTime) return value;
  if (value is! String || value.trim().isEmpty) return null;
  try {
    return DateFormat('yyyy-MM-dd').parseStrict(value.trim());
  } catch (_) {
    return null;
  }
}

int ageOn(DateTime birth, DateTime today) {
  var age = today.year - birth.year;
  if (today.month < birth.month ||
      (today.month == birth.month && today.day < birth.day)) {
    age--;
  }
  return age;
}

String? validateBirthDate(String? value, {DateTime? now}) {
  final date = parseDate(value);
  final today = now ?? DateTime.now();
  if (date == null) return 'Selecciona una fecha válida.';
  if (date.isAfter(DateTime(today.year, today.month, today.day))) {
    return 'El nacimiento no puede estar en el futuro.';
  }
  if (ageOn(date, today) > 120) return 'Revisa la fecha de nacimiento.';
  return null;
}

String? validateEmail(String? value) =>
    RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch((value ?? '').trim())
    ? null
    : 'Escribe un correo válido.';

Timestamp dateTimestamp(String value) {
  final date = parseDate(value);
  if (date == null) throw ArgumentError('Fecha inválida');
  return Timestamp.fromDate(DateTime.utc(date.year, date.month, date.day));
}

String attendanceId(String activityId, String jovenId) {
  final valid = RegExp(r'^[A-Za-z0-9_-]+$');
  if (!valid.hasMatch(activityId) || !valid.hasMatch(jovenId)) {
    throw ArgumentError(
      'El identificador necesita migración. Contacta al administrador.',
    );
  }
  return '$activityId:$jovenId';
}
