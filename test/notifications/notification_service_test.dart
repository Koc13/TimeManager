import 'package:first_app/notifications/notification_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('habitNotificationId', () {
    test('is deterministic - the same habit id always maps to the same '
        'notification id', () {
      const habitId = 'a1b2c3d4-1111-2222-3333-444455556666';

      expect(habitNotificationId(habitId), habitNotificationId(habitId));
    });

    test('is always positive, regardless of the string hashCode\'s sign', () {
      final ids = [
        'a1b2c3d4-1111-2222-3333-444455556666',
        'zzzzzzzz-9999-8888-7777-666655554444',
        '',
        'x',
      ];

      for (final id in ids) {
        expect(habitNotificationId(id), greaterThanOrEqualTo(0));
      }
    });

    test('different habit ids very likely map to different notification '
        'ids', () {
      expect(
        habitNotificationId('habit-a'),
        isNot(habitNotificationId('habit-b')),
      );
    });
  });
}
