// Widget smoke tests for Mamie-Meds.
//
// Because the app uses platform plugins (sqflite, alarm manager, etc.) that
// are unavailable in the unit-test host environment, we test only the
// pure-Dart / pure-Flutter logic: the next-occurrence calculation and the
// Medication model helpers.

import 'package:flutter_test/flutter_test.dart';
import 'package:mima/alarm_service.dart';
import 'package:mima/database_helper.dart';

void main() {
  // --------------------------------------------------------------------------
  // AlarmService.calculateNextOccurrence
  // --------------------------------------------------------------------------
  group('calculateNextOccurrence', () {
    test('returns today when the time has not yet passed', () {
      final now = DateTime.now();
      // Pick a time 2 hours in the future (wrap-safe within a day).
      final futureHour = (now.hour + 2) % 24;
      final result =
          AlarmService.calculateNextOccurrence(futureHour, now.minute);

      // The result must be strictly in the future.
      expect(result.isAfter(now), isTrue);
    });

    test('returns tomorrow when the time has already passed today', () {
      // 00:00 has always passed unless it is exactly midnight right now.
      // The implementation uses !isAfter, so a time equal to now also goes
      // to tomorrow — use a time from 10 seconds ago to be safe.
      final now = DateTime.now();
      final pastDt = now.subtract(const Duration(seconds: 10));
      final result = AlarmService.calculateNextOccurrence(
          pastDt.hour, pastDt.minute);

      expect(result.isAfter(now), isTrue);
      expect(result.day, equals((now.add(const Duration(days: 1))).day));
    });

    test('result is always strictly in the future', () {
      for (var h = 0; h < 24; h += 3) {
        for (var m = 0; m < 60; m += 15) {
          final result = AlarmService.calculateNextOccurrence(h, m);
          expect(
            result.isAfter(DateTime.now()),
            isTrue,
            reason: 'Failed for $h:$m',
          );
        }
      }
    });
  });

  // --------------------------------------------------------------------------
  // Medication model
  // --------------------------------------------------------------------------
  group('Medication', () {
    test('toMap / fromMap round-trip preserves all fields', () {
      const med = Medication(
        id: 42,
        name: 'Aspirine',
        hour: 8,
        minute: 30,
        isActive: true,
      );
      final map = med.toMap();
      final restored = Medication.fromMap(map);

      expect(restored.id, equals(med.id));
      expect(restored.name, equals(med.name));
      expect(restored.hour, equals(med.hour));
      expect(restored.minute, equals(med.minute));
      expect(restored.isActive, equals(med.isActive));
    });

    test('copyWith overrides only specified fields', () {
      const original = Medication(
        id: 1,
        name: 'Doliprane',
        hour: 12,
        minute: 0,
        isActive: true,
      );
      final copy = original.copyWith(isActive: false, hour: 20);

      expect(copy.id, equals(original.id));
      expect(copy.name, equals(original.name));
      expect(copy.hour, equals(20));
      expect(copy.minute, equals(original.minute));
      expect(copy.isActive, isFalse);
    });

    test('isActive defaults to true', () {
      const med = Medication(name: 'Test', hour: 9, minute: 0);
      expect(med.isActive, isTrue);
    });
  });
}

