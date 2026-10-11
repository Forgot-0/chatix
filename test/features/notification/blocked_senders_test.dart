import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chatix/core/notifications/notification_service.dart';
import 'package:chatix/features/notification/data/datasources/blocked_senders_store.dart';
import 'package:chatix/features/notification/data/datasources/notification_avatar_cache.dart';
import 'package:chatix/features/notification/data/push_notification_presenter.dart';
import 'package:chatix/features/notification/domain/entities/blocked_senders.dart';
import 'package:chatix/features/notification/domain/entities/notification_preferences.dart';
import 'package:chatix/features/notification/domain/entities/push_message.dart';
import 'package:chatix/features/notification/domain/usecases/resolve_notification_display_use_case.dart';

class _RecordingSink implements NotificationSink {
  final List<LocalNotificationRequest> posted = [];

  @override
  Future<void> show(LocalNotificationRequest request) async {
    posted.add(request);
  }
}

class _NoAvatars implements NotificationAvatarCache {
  @override
  Future<String?> fileFor(String? url) async => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const _copy = PushNotificationCopy(
  appName: 'ChatiX',
  newMessage: 'New message',
  replyLabel: 'Reply',
  replyPlaceholder: 'Message',
  markReadLabel: 'Mark as read',
);

/// Who blocked whom, applied on this device: until the backend's "этап 2"
/// (api-docs §4.13) a blocked person's push is still sent, and this is where
/// it stops.
void main() {
  const blocked = BlockedSenders(
    userIds: {42},
    directChatIds: {'direct-with-42'},
  );

  group('BlockedSenders', () {
    test('recognises the sender, or the direct chat with them', () {
      expect(blocked.covers(senderId: 42), isTrue);
      expect(blocked.covers(chatId: 'direct-with-42'), isTrue);
      expect(blocked.covers(senderId: 43, chatId: 'group'), isFalse);
      expect(blocked.covers(), isFalse);
      expect(BlockedSenders.none.covers(senderId: 42), isFalse);
    });

    test('goes through JSON and back unchanged', () {
      expect(BlockedSenders.fromJson(blocked.toJson()), blocked);
    });

    test('junk in the JSON is dropped, not trusted', () {
      expect(
        BlockedSenders.fromJson(const {
          'user_ids': [42, '43', null],
          'direct_chat_ids': ['c', '', 5],
        }),
        const BlockedSenders(userIds: {42}, directChatIds: {'c'}),
      );
    });
  });

  group('the copy the background isolate reads', () {
    test('saved by the app, loaded by a fresh instance', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      await PrefsBlockedSendersStore(prefs).save(blocked);

      expect(PrefsBlockedSendersStore(prefs).load(), blocked);
      expect(await PrefsBlockedSendersStore.loadStandalone(), blocked);
    });

    test('nobody blocked removes the entry', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final store = PrefsBlockedSendersStore(prefs);
      await store.save(blocked);

      await store.save(BlockedSenders.none);

      expect(prefs.getString(PrefsBlockedSendersStore.storageKey), isNull);
      expect(store.load(), BlockedSenders.none);
    });

    test('a corrupt entry blocks nobody', () async {
      SharedPreferences.setMockInitialValues({
        PrefsBlockedSendersStore.storageKey: '[1, 2',
      });
      final prefs = await SharedPreferences.getInstance();

      expect(PrefsBlockedSendersStore(prefs).load(), BlockedSenders.none);
    });
  });

  group('the display decision', () {
    const decide = ResolveNotificationDisplayUseCase();

    test('a blocked sender is suppressed — a mention included', () {
      final decision = decide.execute(
        preferences: const NotificationPreferences(),
        chatId: 'group',
        isMention: true,
        fromBlockedSender: true,
      );

      expect(decision, const NotificationDisplayDecision.suppressed());
    });

    test('a system notice is never from a person, blocked or not', () {
      final decision = decide.execute(
        preferences: const NotificationPreferences(),
        isSystem: true,
        fromBlockedSender: true,
      );

      expect(decision.show, isTrue);
    });
  });

  group('PushMessage.senderId', () {
    test('read under the spellings senders use', () {
      for (final key in [
        'sender_id',
        'senderId',
        'author_id',
        'from_user_id',
      ]) {
        expect(
          PushMessage.fromPayload({'chat_id': 'c', key: '42'}).senderId,
          42,
          reason: key,
        );
      }
    });

    test('nested, as FCM flattens it', () {
      expect(
        PushMessage.fromPayload(const {
          'data': '{"message": {"chat_id": "c", "sender_id": 42}}',
        }).senderId,
        42,
      );
    });

    test('never user_id — in a NotificationDTO that is the recipient', () {
      expect(
        PushMessage.fromPayload(const {'chat_id': 'c', 'user_id': 7}).senderId,
        isNull,
      );
    });
  });

  group('the presenter', () {
    late _RecordingSink sink;
    late PushNotificationPresenter presenter;

    setUp(() {
      sink = _RecordingSink();
      presenter = PushNotificationPresenter(
        notifications: sink,
        avatars: _NoAvatars(),
      );
    });

    Future<bool> present(Map<String, dynamic> payload) => presenter.present(
      PushMessage.fromPayload(payload),
      preferences: const NotificationPreferences(),
      copy: _copy,
      blocked: blocked,
      now: DateTime(2026, 10, 11, 12),
    );

    test('a group message from the blocked person is not drawn', () async {
      expect(
        await present(const {
          'chat_id': 'group',
          'message_id': 'm1',
          'sender_id': '42',
          'body': 'hi',
        }),
        isFalse,
      );
      expect(sink.posted, isEmpty);
    });

    test('their direct chat is not drawn, even without a sender', () async {
      expect(
        await present(const {
          'chat_id': 'direct-with-42',
          'message_id': 'm2',
          'body': 'hi',
        }),
        isFalse,
      );
      expect(sink.posted, isEmpty);
    });

    test('everybody else still is', () async {
      expect(
        await present(const {
          'chat_id': 'group',
          'message_id': 'm3',
          'sender_id': '43',
          'sender_name': 'Grace',
          'body': 'hi',
        }),
        isTrue,
      );
      expect(sink.posted.single.title, 'Grace');
    });
  });
}
