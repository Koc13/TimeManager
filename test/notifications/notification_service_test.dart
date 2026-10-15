import 'package:time_manager/notifications/notification_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'task notification ids are stable, positive and clear of the fixed ids',
    () {
      expect(
        taskNotificationId('t_3fq8kz2m'),
        taskNotificationId('t_3fq8kz2m'),
      );
      expect(taskNotificationId('t_a'), isNot(taskNotificationId('t_b')));
      for (final id in ['', 't_x', 't_zzzzzzzz', 't_00000000']) {
        expect(taskNotificationId(id), greaterThanOrEqualTo(1000));
      }
    },
  );
}
