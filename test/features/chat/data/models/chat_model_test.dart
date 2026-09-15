import 'package:flutter_test/flutter_test.dart';

import 'package:chatix/features/chat/data/models/chat_model.dart';
import 'package:chatix/features/chat/domain/entities/chat_entity.dart';

/// `GET /chats/` carries who to draw and what this reader has done with the
/// chat; `GET /chats/{id}/` carries neither (api-docs §5.2). Both come back
/// through the same model, so the difference has to survive the mapping.
void main() {
  Map<String, dynamic> chatJson({
    String type = 'direct',
    Map<String, dynamic>? peer,
    List<Map<String, dynamic>>? membersPreview,
    Map<String, dynamic> state = const <String, dynamic>{},
    Map<String, dynamic>? lastRead,
  }) => {
    'id': 'c1',
    'seq_counter': 9,
    'last_activity_at': '2026-03-10T10:00:00Z',
    'type': type,
    'name': null,
    'description': null,
    'avatar_s3_key': null,
    'is_public': false,
    'admin_only': false,
    'slow_mode_seconds': 0,
    'permissions': <String, bool>{},
    'created_by': 1,
    'member_count': 2,
    'unread_count': 3,
    'me': null,
    'last_read': lastRead,
    'last_message': null,
    'peer': peer,
    'members_preview': membersPreview ?? <Map<String, dynamic>>[],
    ...state,
  };

  Map<String, dynamic> profile(int userId, String name) => {
    'user_id': userId,
    'username': 'user$userId',
    'display_name': name,
    'avatar_url': null,
    'avatar_s3_key': null,
  };

  ChatEntity parse(Map<String, dynamic> json) =>
      ChatModel.fromJson(json).toEntity();

  group('who to draw', () {
    test('a direct chat comes with the other person', () {
      final chat = parse(chatJson(peer: profile(9, 'Ann Lee')));

      expect(chat.peer?.userId, 9);
      expect(chat.peerName(7), 'Ann Lee');
    });

    test('the peer is used even when the row has no roster to search', () {
      final chat = parse(chatJson(peer: profile(9, 'Ann Lee')));

      expect(chat.members, isNull);
      expect(chat.peerProfile(7)?.displayName, 'Ann Lee');
    });

    test('a peer whose profile has not caught up is still someone', () {
      // The projection is filled asynchronously: `user_id` is always there,
      // the rest may not be (api-docs §5.2).
      final chat = parse(
        chatJson(
          peer: {
            'user_id': 9,
            'username': null,
            'display_name': null,
            'avatar_url': null,
            'avatar_s3_key': null,
          },
        ),
      );

      expect(chat.peerProfile(7)?.userId, 9);
    });

    test('a group comes with a few faces instead', () {
      final chat = parse(
        chatJson(
          type: 'group',
          membersPreview: [profile(9, 'Ann'), profile(11, 'Bo')],
        ),
      );

      expect(chat.membersPreview.map((p) => p.userId), [9, 11]);
      expect(chat.peer, isNull);
    });

    test('a response with neither leaves both empty rather than failing', () {
      final chat = parse(chatJson(type: 'group'));

      expect(chat.peer, isNull);
      expect(chat.membersPreview, isEmpty);
    });
  });

  group('the state this reader has put the chat in', () {
    test('pinned, archived and silenced come off the row', () {
      final chat = parse(
        chatJson(
          state: {
            'is_pinned': true,
            'pinned_at': '2026-03-09T08:00:00Z',
            'is_archived': true,
            'notifications_muted_until': '2026-04-01T00:00:00Z',
            'is_muted_by_me': true,
            'draft': 'on my way',
          },
        ),
      );

      expect(chat.isPinned, isTrue);
      expect(chat.pinnedAt, DateTime.utc(2026, 3, 9, 8));
      expect(chat.isArchived, isTrue);
      expect(chat.isMutedByMe, isTrue);
      expect(chat.notificationsMutedUntil, DateTime.utc(2026, 4, 1));
      expect(chat.draft, 'on my way');
    });

    test('a chat nobody has touched reports none of it', () {
      final chat = parse(chatJson());

      expect(chat.state, isNull);
      expect(chat.isPinned, isFalse);
      expect(chat.isArchived, isFalse);
      expect(chat.isMutedByMe, isFalse);
    });

    test('a response with no state block does not claim one', () {
      // `ChatDetailDTO` has no state fields at all. Reading them as false
      // would unpin a chat every time it was fetched by id.
      final chat = parse(chatJson());

      expect(chat.state, isNull);
    });

    test('is_muted_by_me is trusted over reading the deadline here', () {
      final chat = parse(
        chatJson(
          state: {
            'notifications_muted_until': '2026-04-01T00:00:00Z',
            'is_muted_by_me': false,
          },
        ),
      );

      expect(chat.notificationsMutedUntil, isNotNull);
      expect(chat.isMutedByMe, isFalse);
    });
  });

  test('the read cursor the ticks are drawn from survives the mapping', () {
    final chat = parse(
      chatJson(
        lastRead: {
          'last_read_message_seq': 11,
          'last_read_at': '2026-03-10T09:00:00Z',
        },
      ),
    );

    expect(chat.lastRead?.lastReadMessageSeq, 11);
    expect(chat.lastRead?.lastReadAt, DateTime.utc(2026, 3, 10, 9));
  });
}
