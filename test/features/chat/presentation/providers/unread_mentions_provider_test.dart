import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chatix/core/websocket/chat_socket_service.dart';
import 'package:chatix/core/websocket/ws_event.dart';
import 'package:chatix/features/auth/domain/entities/user_entity.dart';
import 'package:chatix/features/auth/presentation/providers/auth_provider.dart';
import 'package:chatix/features/chat/data/datasources/chat_local_data_source.dart';
import 'package:chatix/features/chat/data/datasources/chat_local_store.dart';
import 'package:chatix/features/chat/presentation/providers/chat_socket_provider.dart';
import 'package:chatix/features/chat/presentation/providers/unread_mentions_provider.dart';

class _FakeAuthController extends AuthController {
  _FakeAuthController(this._user);

  final UserEntity? _user;

  @override
  Future<UserEntity?> build() async => _user;
}

/// A socket whose event stream is driven by hand.
class _FakeSocket implements ChatSocketService {
  final StreamController<WSEvent> _events =
      StreamController<WSEvent>.broadcast();

  @override
  Stream<WSEvent> get events => _events.stream;

  void emit(WSEvent event) => _events.add(event);

  Future<void> close() => _events.close();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// The mentions a chat row can know about without a server counter: the
/// ones that came over the socket, and the ones in the message cache.
void main() {
  const me = UserEntity(id: 7, username: 'mira', email: 'm@example.com');

  Map<String, dynamic> json(
    String chatId,
    String content, {
    required int seq,
    int authorId = 9,
  }) => {
    'id': '$chatId-m$seq',
    'chat_id': chatId,
    'seq': seq,
    'author_id': authorId,
    'type': 'text',
    'content': content,
    'reply_to_id': null,
    'forwarded_from_chat_id': null,
    'forwarded_from_message_id': null,
    'forwarded_from_author_id': null,
    'is_edited': false,
    'created_at': '2026-01-01T00:00:00Z',
    'attachments': <Object?>[],
    'reactions': <Object?>[],
  };

  NewMessage arrived(
    String chatId,
    String content, {
    int seq = 5,
    int author = 9,
  }) => NewMessage(
    chatId: chatId,
    messageId: '$chatId-m$seq',
    seq: seq,
    message: json(chatId, content, seq: seq, authorId: author),
  );

  late _FakeSocket socket;
  late ChatLocalStore store;

  setUp(() {
    socket = _FakeSocket();
    store = inMemoryChatLocalStore();
  });

  Future<ProviderContainer> boot({UserEntity? user = me}) async {
    final container = ProviderContainer(
      overrides: [
        chatSocketServiceProvider.overrideWithValue(socket),
        chatLocalDataSourceProvider.overrideWithValue(store),
        authProvider.overrideWith(() => _FakeAuthController(user)),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(socket.close);

    await container.read(authProvider.future);
    container.listen(liveMentionsProvider, (_, _) {});
    return container;
  }

  group('over the socket', () {
    test('a new message naming the reader is recorded', () async {
      final container = await boot();

      socket.emit(arrived('c1', '@mira, look', seq: 4));
      await pumpEventQueue();

      expect(container.read(liveMentionsProvider), {'c1': 4});
    });

    test('a later one moves it on, an older one does not', () async {
      final container = await boot();

      socket
        ..emit(arrived('c1', '@mira one', seq: 4))
        ..emit(arrived('c1', '@mira two', seq: 9))
        ..emit(arrived('c1', '@mira late replay', seq: 6));
      await pumpEventQueue();

      expect(container.read(liveMentionsProvider)['c1'], 9);
    });

    test('an edit that adds the mention counts as one', () async {
      final container = await boot();

      socket.emit(
        MessageEdited(
          chatId: 'c2',
          messageId: 'c2-m3',
          seq: 3,
          message: json('c2', 'now with @mira', seq: 3),
        ),
      );
      await pumpEventQueue();

      expect(container.read(liveMentionsProvider), {'c2': 3});
    });

    test('other people, own messages and other events are not', () async {
      final container = await boot();

      socket
        ..emit(arrived('c1', '@mirabel hi'))
        ..emit(arrived('c1', 'as @mira said', author: 7))
        ..emit(const MessagesRead(chatId: 'c1', seq: 5, readerId: 9));
      await pumpEventQueue();

      expect(container.read(liveMentionsProvider), isEmpty);
    });

    test('nobody signed in, nothing listened for', () async {
      final container = await boot(user: null);

      socket.emit(arrived('c1', '@mira'));
      await pumpEventQueue();

      expect(container.read(mentionReaderProvider), isNull);
      expect(container.read(liveMentionsProvider), isEmpty);
    });
  });

  group('in the message cache', () {
    test('the newest cached mention of the reader is found', () async {
      await store.writeMessages('c1', [
        json('c1', '@mira first', seq: 2),
        json('c1', 'unrelated', seq: 3),
        json('c1', 'again, @Mira', seq: 4),
      ]);
      final container = await boot();

      expect(container.read(cachedMentionSeqProvider('c1')), 4);
      expect(container.read(cachedMentionSeqProvider('c2')), isNull);
    });
  });
}
