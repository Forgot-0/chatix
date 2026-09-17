import 'package:flutter_test/flutter_test.dart';

import 'package:chatix/core/notifications/notification_service.dart';
import 'package:chatix/features/notification/data/datasources/notification_avatar_cache.dart';
import 'package:chatix/features/notification/data/push_notification_presenter.dart';
import 'package:chatix/features/notification/domain/entities/notification_preferences.dart';
import 'package:chatix/features/notification/domain/entities/push_message.dart';

/// Records what would have gone to the shade.
class _RecordingSink implements NotificationSink {
  final List<LocalNotificationRequest> posted = [];

  @override
  Future<void> show(LocalNotificationRequest request) async {
    posted.add(request);
  }
}

/// Never touches the network: a notification must not wait on an avatar.
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

void main() {
  late _RecordingSink sink;
  late PushNotificationPresenter presenter;

  final noon = DateTime(2026, 9, 17, 12);

  setUp(() {
    sink = _RecordingSink();
    presenter = PushNotificationPresenter(
      notifications: sink,
      avatars: _NoAvatars(),
    );
  });

  Future<bool> present(
    Map<String, dynamic> payload, {
    NotificationPreferences preferences = const NotificationPreferences(),
    DateTime? now,
  }) {
    return presenter.present(
      PushMessage.fromPayload(payload),
      preferences: preferences,
      copy: _copy,
      now: now ?? noon,
    );
  }

  test('a chat message is drawn, bundled by chat, with both buttons', () async {
    final shown = await present(const {
      'chat_id': 'c-1',
      'message_id': 'm-1',
      'sender_name': 'Ada',
      'chat_name': 'Analytical Engines',
      'body': 'It works',
    });

    expect(shown, isTrue);
    expect(sink.posted, hasLength(1));

    final request = sink.posted.single;
    expect(request.title, 'Ada');
    expect(request.body, 'It works');
    expect(request.subText, 'Analytical Engines');
    expect(request.groupKey, 'chat_c-1');
    expect(request.actions, {
      NotificationActionType.reply,
      NotificationActionType.markRead,
    });
  });

  test('previews off hide both the sender and the text', () async {
    await present(
      const {'chat_id': 'c-1', 'sender_name': 'Ada', 'body': 'Secret'},
      preferences: const NotificationPreferences(showPreview: false),
    );

    final request = sink.posted.single;
    expect(request.title, isNot('Ada'));
    expect(request.body, 'New message');
  });

  test('a chat set to "nothing" posts nothing', () async {
    final shown = await present(
      const {'chat_id': 'c-1', 'body': 'Hello'},
      preferences: const NotificationPreferences(
        chatProfiles: {'c-1': ChatNotificationProfile.off},
      ),
    );

    expect(shown, isFalse);
    expect(sink.posted, isEmpty);
  });

  test('quiet hours post the same notification without a sound', () async {
    await present(
      const {'chat_id': 'c-1', 'body': 'Hello'},
      preferences: const NotificationPreferences(
        quietHours: QuietHours(
          enabled: true,
          startMinute: 23 * 60,
          endMinute: 7 * 60,
        ),
      ),
      now: DateTime(2026, 9, 17, 3),
    );

    final request = sink.posted.single;
    expect(request.playSound, isFalse);
    expect(request.enableVibration, isFalse);
  });

  test('the same event arriving twice is drawn once', () async {
    const payload = {
      'chat_id': 'c-1',
      'message_id': 'm-1',
      'event_id': 'e-1',
      'body': 'Hello',
    };

    expect(await present(payload), isTrue);
    expect(await present(payload), isFalse);
    expect(sink.posted, hasLength(1));
  });

  test('two messages in a chat share a group and keep separate ids', () async {
    await present(const {
      'chat_id': 'c-1',
      'message_id': 'm-1',
      'body': 'One',
    });
    await present(const {
      'chat_id': 'c-1',
      'message_id': 'm-2',
      'body': 'Two',
    });

    expect(sink.posted.map((r) => r.groupKey).toSet(), {'chat_c-1'});
    expect(sink.posted.map((r) => r.id).toSet(), hasLength(2));
  });

  test('a system notice has no group and no buttons', () async {
    await present(const {'title': 'Your email is verified'});

    final request = sink.posted.single;
    expect(request.groupKey, isNull);
    expect(request.actions, isEmpty);
    expect(request.channel, 'system');
  });

  test('a push this build cannot read is not drawn', () async {
    expect(await present(const {'unrelated': 'value'}), isFalse);
    expect(sink.posted, isEmpty);
  });

  test('a message with no text says so rather than showing nothing', () async {
    await present(const {'chat_id': 'c-1', 'sender_name': 'Ada'});

    expect(sink.posted.single.body, 'New message');
  });
}
