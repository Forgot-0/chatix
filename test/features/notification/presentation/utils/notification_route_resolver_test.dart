import 'package:flutter_test/flutter_test.dart';

import 'package:chatix/features/notification/domain/entities/notification_entity.dart';
import 'package:chatix/features/notification/presentation/utils/notification_route_resolver.dart';

NotificationEntity _notification(Map<String, dynamic> payload) {
  return NotificationEntity(
    id: 1,
    userId: 2,
    type: NotificationType.chat,
    title: 'Ada',
    message: 'Hello',
    payload: payload,
    isRead: false,
    createdAt: DateTime(2026, 9, 17),
    updatedAt: DateTime(2026, 9, 17),
  );
}

/// The payload is untyped (api-docs §7.2), so every step down from "open this
/// message" has to land somewhere sensible rather than nowhere.
void main() {
  test('a seq opens the chat at that message', () {
    final route = resolveNotificationRoute(
      _notification(const {'chat_id': 'c-1', 'message_seq': 42}),
    );

    expect(route, '/chats/c-1?message=42');
  });

  test('a message id is used when there is no seq', () {
    final route = resolveNotificationRoute(
      _notification(const {'chat_id': 'c-1', 'message_id': 'm-1'}),
    );

    expect(route, '/chats/c-1?message_id=m-1');
  });

  test('a chat on its own opens the chat', () {
    final route = resolveNotificationRoute(
      _notification(const {'chat_id': 'c-1'}),
    );

    expect(route, '/chats/c-1');
  });

  test('a nested payload is dug through', () {
    final route = resolveNotificationRoute(
      _notification(const {
        'data': {
          'message': {'chat_id': 'c-9', 'seq': '3'},
        },
      }),
    );

    expect(route, '/chats/c-9?message=3');
  });

  test('a payload with no chat has nowhere to go', () {
    final notification = _notification(const {'kind': 'account_verified'});

    expect(resolveNotificationRoute(notification), isNull);
    expect(hasNotificationDestination(notification), isFalse);
  });

  test('resolving straight from a payload agrees with the entity', () {
    const payload = {'chat_id': 'c-1', 'message_seq': 7};

    expect(
      resolveNotificationRouteFromPayload(payload),
      resolveNotificationRoute(_notification(payload)),
    );
  });
}
