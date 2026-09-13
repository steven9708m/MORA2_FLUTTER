import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../core/validation.dart';

List<QueryDocumentSnapshot<Map<String, dynamic>>> latestAttendanceDocuments(
  Iterable<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
) {
  final result = <String, QueryDocumentSnapshot<Map<String, dynamic>>>{};
  int updated(Map<String, dynamic> data) => data['updatedAt'] is Timestamp
      ? (data['updatedAt'] as Timestamp).millisecondsSinceEpoch
      : 0;
  for (final doc in docs) {
    if (doc.data()['archived'] == true) continue;
    final data = doc.data(),
        key = '${doc.data()['activityId']}:${doc.data()['jovenId']}';
    final previous = result[key];
    if (previous == null ||
        updated(data) > updated(previous.data()) ||
        (updated(data) == updated(previous.data()) &&
            doc.id.compareTo(previous.id) > 0)) {
      result[key] = doc;
    }
  }
  return result.values.toList();
}

/// Firebase dependencies are supplied at bootstrap; repositories can be tested
/// independently with a Firestore emulator or an in-memory implementation.
class AppServices {
  final FirebaseAuth auth;
  final FirebaseFirestore firestore;
  final FirebaseFunctions functions;
  late final AttendanceRepository attendance = AttendanceRepository(firestore);
  late final LeaderRepository leaders = LeaderRepository(functions, auth);
  final Map<String, _SharedQuery> _queries = {};
  AppServices({
    required this.auth,
    required this.firestore,
    required this.functions,
  });

  Stream<QuerySnapshot<Map<String, dynamic>>> watch(
    String key,
    Query<Map<String, dynamic>> query,
  ) => _queries.putIfAbsent(key, () => _SharedQuery(query)).stream;

  Future<void> archive(String collection, String id) async {
    await functions.httpsCallable('archiveRecord').call({
      'collection': collection,
      'id': id,
    });
  }
}

class _SharedQuery {
  final Query<Map<String, dynamic>> query;
  final _listeners =
      <MultiStreamController<QuerySnapshot<Map<String, dynamic>>>>{};
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _subscription;
  QuerySnapshot<Map<String, dynamic>>? _latest;
  _SharedQuery(this.query);
  late final stream = Stream<QuerySnapshot<Map<String, dynamic>>>.multi((
    listener,
  ) {
    _listeners.add(listener);
    if (_latest != null) listener.add(_latest!);
    _subscription ??= query.snapshots().listen(
      (value) {
        _latest = value;
        for (final target in _listeners.toList()) {
          target.add(value);
        }
      },
      onError: (Object error, StackTrace stack) {
        for (final target in _listeners.toList()) {
          target.addError(error, stack);
        }
      },
    );
    listener.onCancel = () {
      _listeners.remove(listener);
      if (_listeners.isEmpty) {
        _subscription?.cancel();
        _subscription = null;
        _latest = null;
      }
    };
  });
}

class LeaderRepository {
  final FirebaseFunctions functions;
  final FirebaseAuth auth;
  LeaderRepository(this.functions, this.auth);

  Future<String> save(Map<String, dynamic> profile, {String? id}) async {
    final result = await functions.httpsCallable('saveLeader').call({
      ...profile,
      if (id != null) 'id': id,
    });
    return (result.data as Map)['uid'] as String;
  }

  Future<void> sendAccess(String id) async {
    final result = await functions.httpsCallable('prepareLeaderAccess').call({
      'id': id,
    });
    await auth.sendPasswordResetEmail(
      email: (result.data as Map)['email'] as String,
    );
  }
}

class AttendanceRecord {
  final String id;
  final String jovenId;
  final bool attended;
  final int version;
  final DateTime updatedAt;
  const AttendanceRecord({
    required this.id,
    required this.jovenId,
    required this.attended,
    required this.version,
    required this.updatedAt,
  });
  factory AttendanceRecord.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return AttendanceRecord(
      id: doc.id,
      jovenId: data['jovenId'] as String,
      attended: data['attended'] == true,
      version: (data['version'] as num?)?.toInt() ?? 0,
      updatedAt: data['updatedAt'] is Timestamp
          ? (data['updatedAt'] as Timestamp).toDate()
          : DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}

class AttendanceRepository {
  final FirebaseFirestore firestore;
  AttendanceRepository(this.firestore);

  Query<Map<String, dynamic>> query(String activityId, {String? leaderId}) {
    Query<Map<String, dynamic>> query = firestore
        .collection('asistencias')
        .where('activityId', isEqualTo: activityId);
    if (leaderId != null) query = query.where('leaderId', isEqualTo: leaderId);
    return query;
  }

  /// Legacy duplicates are displayed once until the administrative migration.
  static Map<String, AttendanceRecord> latest(
    Iterable<DocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final result = <String, AttendanceRecord>{};
    for (final doc in docs) {
      if (doc.data()?['jovenId'] is! String ||
          doc.data()?['archived'] == true) {
        continue;
      }
      final record = AttendanceRecord.fromDoc(doc);
      final previous = result[record.jovenId];
      if (previous == null ||
          record.updatedAt.isAfter(previous.updatedAt) ||
          (record.updatedAt == previous.updatedAt &&
              record.id.compareTo(previous.id) > 0)) {
        result[record.jovenId] = record;
      }
    }
    return result;
  }

  Future<void> save(
    Map<String, dynamic> payload, {
    required int expectedVersion,
  }) async {
    final id = attendanceId(
      payload['activityId'] as String,
      payload['jovenId'] as String,
    );
    final reference = firestore.collection('asistencias').doc(id);
    await firestore.runTransaction((transaction) async {
      final existing = await transaction.get(reference);
      final version = (existing.data()?['version'] as num?)?.toInt() ?? 0;
      if (version != expectedVersion) {
        throw StateError(
          'Otra persona actualizó esta asistencia. Revisa el valor actual e intenta de nuevo.',
        );
      }
      transaction.set(reference, {
        ...payload,
        'version': version + 1,
        'createdAt':
            existing.data()?['createdAt'] ?? FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });
  }
}
