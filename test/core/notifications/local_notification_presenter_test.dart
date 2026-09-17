import 'package:flutter_test/flutter_test.dart';

import 'package:chatix/core/notifications/local_notification_presenter.dart';

/// The shade outlives the process: a reply typed into it is answered by a
/// background isolate that has to cancel a notification the app's own isolate
/// posted, and both have to arrive at the same id from the same string.
void main() {
  group('stableNotificationId', () {
    test('the same string always gives the same id', () {
      expect(stableNotificationId('msg_m-1'), stableNotificationId('msg_m-1'));
    });

    test('different strings give different ids', () {
      expect(
        stableNotificationId('msg_m-1'),
        isNot(stableNotificationId('msg_m-2')),
      );
      expect(
        stableNotificationId('chat_c-1'),
        isNot(stableNotificationId('chat_c-2')),
      );
    });

    test('ids stay inside the positive 32-bit range the platforms take', () {
      for (final value in const [
        '',
        'chat_c-1',
        'msg_00000000-0000-0000-0000-000000000000',
        'группа_чата',
        '🙂',
      ]) {
        final id = stableNotificationId(value);
        expect(id, greaterThanOrEqualTo(0));
        expect(id, lessThanOrEqualTo(0x7fffffff));
      }
    });
  });

  group('decodeNotificationPayload', () {
    test('reads back what was written', () {
      expect(decodeNotificationPayload('{"chat_id":"c-1"}'), {
        'chat_id': 'c-1',
      });
    });

    test('nothing at all reads as an empty payload', () {
      expect(decodeNotificationPayload(null), isEmpty);
      expect(decodeNotificationPayload(''), isEmpty);
    });

    test('unreadable payloads come back empty rather than throwing', () {
      // The platform calls this from a callback where a thrown exception is
      // just a notification that does nothing.
      expect(decodeNotificationPayload('not json'), isEmpty);
      expect(decodeNotificationPayload('[1,2,3]'), isEmpty);
    });
  });
}
