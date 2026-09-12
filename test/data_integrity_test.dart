import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grupo_juvenil_morados/core/validation.dart';
import 'package:grupo_juvenil_morados/data/app_services.dart';

void main() {
  test('dates reject overflow and future births; age changes on birthday', () {
    expect(parseDate('2026-02-31'), isNull);
    expect(parseDate('2026-13-01'), isNull);
    expect(parseDate('2024-02-29'), DateTime(2024, 2, 29));
    expect(
      validateBirthDate('2027-01-01', now: DateTime(2026, 9, 5)),
      isNotNull,
    );
    expect(ageOn(DateTime(2008, 9, 6), DateTime(2026, 9, 5)), 17);
    expect(ageOn(DateTime(2008, 9, 6), DateTime(2026, 9, 6)), 18);
  });
  test(
    'two saves use one document and a stale update cannot overwrite it',
    () async {
      final db = FakeFirebaseFirestore();
      final repository = AttendanceRepository(db);
      final payload = {
        'activityId': 'activity',
        'jovenId': 'young',
        'attended': true,
      };
      await repository.save(payload, expectedVersion: 0);
      await expectLater(
        repository.save({...payload, 'attended': false}, expectedVersion: 0),
        throwsStateError,
      );
      expect((await db.collection('asistencias').get()).size, 1);
      expect(
        (await db.doc('asistencias/activity:young').get()).data()!['attended'],
        true,
      );
      await repository.save({
        ...payload,
        'attended': false,
      }, expectedVersion: 1);
      final saved = (await db.doc('asistencias/activity:young').get()).data()!;
      expect(saved['attended'], false);
      expect(saved['version'], 2);
    },
  );
  test(
    'legacy duplicates keep the latest record separately for each activity',
    () async {
      final db = FakeFirebaseFirestore();
      for (final entry in [
        ('old', 'a', false, 1),
        ('new', 'a', true, 2),
        ('other', 'b', false, 3),
      ]) {
        await db.collection('asistencias').doc(entry.$1).set({
          'activityId': entry.$2,
          'jovenId': 'young',
          'attended': entry.$3,
          'updatedAt': Timestamp.fromMillisecondsSinceEpoch(entry.$4),
        });
      }
      final unique = latestAttendanceDocuments(
        (await db.collection('asistencias').get()).docs,
      );
      expect(unique.length, 2);
      expect(
        unique
            .singleWhere((doc) => doc.data()['activityId'] == 'a')
            .data()['attended'],
        true,
      );
    },
  );
}
