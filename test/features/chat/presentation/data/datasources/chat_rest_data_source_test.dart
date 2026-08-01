import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

import 'package:chatix/core/error/failures.dart';
import 'package:chatix/core/network/api_client.dart';
import 'package:chatix/features/chat/data/datasources/chat_rest_data_source.dart';
import 'package:chatix/features/chat/domain/entities/attachment_entity.dart';
import 'package:chatix/features/chat/domain/entities/chat_entity.dart';
import 'package:chatix/features/chat/domain/entities/message_entity.dart';

class MockApiClient extends Mock implements ApiClient {}

/// Pins the **wire contract** of api-docs §6 — the exact verb, path and body
/// keys of each call.
///
/// These are the details that no other layer can catch: a repository test
/// mocks this class away, and a use-case test is two layers removed. A typo
/// in a body key (`bannet_to` for `banned_to`) or a `PUT` where §6.2 demands
/// `PATCH` still type-checks perfectly, still returns `Right`, and only shows
/// up against a live backend as a silently ignored field.
void main() {
  late ChatRestDataSourceImpl dataSource;
  late MockApiClient mockApiClient;

  const tChatId = 'a3f1c2d4-0000-4000-8000-000000000001';
  const tMessageId = 'b4e2d3c5-0000-4000-8000-000000000002';

  /// Minimal `MessageDTO` (§6.4) — enough for `MessageModel.fromJson`.
  final tMessageJson = <String, dynamic>{
    'id': tMessageId,
    'chat_id': tChatId,
    'seq': 7,
    'author_id': 42,
    'type': 'text',
    'content': 'hello',
    'reply_to_id': null,
    'forwarded_from_chat_id': null,
    'forwarded_from_message_id': null,
    'forwarded_from_author_id': null,
    'is_edited': false,
    'created_at': '2026-01-01T00:00:00Z',
    'attachments': <dynamic>[],
    'reply_to': null,
    'forwarded_from': null,
  };

  final tChatJson = <String, dynamic>{
    'id': tChatId,
    'seq_counter': 7,
    'last_activity_at': null,
    'type': 'group',
    'name': 'Team',
    'description': null,
    'avatar_s3_key': null,
    'is_public': false,
    'admin_only': false,
    'slow_mode_seconds': 0,
    'permissions': <String, dynamic>{},
    'created_by': 1,
    'member_count': 2,
    'unread_count': 0,
    'me': null,
    'last_read': null,
  };

  setUpAll(() {
    registerFallbackValue(Options());
  });

  setUp(() {
    mockApiClient = MockApiClient();
    dataSource = ChatRestDataSourceImpl(mockApiClient);
  });

  void stubPost(Object? responseData) {
    when(
      () => mockApiClient.post(
        any(),
        data: any(named: 'data'),
        options: any(named: 'options'),
      ),
    ).thenAnswer((_) async => Right(responseData));
  }

  void stubPatch(Object? responseData) {
    when(
      () => mockApiClient.patch(
        any(),
        data: any(named: 'data'),
        options: any(named: 'options'),
      ),
    ).thenAnswer((_) async => Right(responseData));
  }

  /// The `data` map handed to the most recent `patch` call.
  Map<String, dynamic> capturedPatchBody() {
    final captured = verify(
      () => mockApiClient.patch(
        captureAny(),
        data: captureAny(named: 'data'),
        options: any(named: 'options'),
      ),
    ).captured;
    return captured[1] as Map<String, dynamic>;
  }

  group('members — ban (api-docs §6.3)', () {
    test('sends the expiry as `banned_to`, PATCHed to .../ban/', () async {
      stubPatch(null);
      final bannedTo = DateTime.utc(2026, 5, 17, 12, 30);

      final result = await dataSource.banMember(
        tChatId,
        99,
        reason: 'spam',
        bannedTo: bannedTo,
      );

      expect(result.isRight(), isTrue);

      final captured = verify(
        () => mockApiClient.patch(
          captureAny(),
          data: captureAny(named: 'data'),
          options: any(named: 'options'),
        ),
      ).captured;

      expect(captured[0], '/chats/$tChatId/members/99/ban/');

      final body = captured[1] as Map<String, dynamic>;
      expect(body['reason'], 'spam');
      // The documented key. A misspelling here is accepted by the server and
      // silently dropped, turning a timed ban into a permanent one.
      expect(body['banned_to'], bannedTo.toIso8601String());
      expect(body.containsKey('bannet_to'), isFalse);
    });

    test('omits `banned_to` entirely for a permanent ban', () async {
      stubPatch(null);

      await dataSource.banMember(tChatId, 99);

      final body = capturedPatchBody();
      // Absent, not null: the backend's datetime validator rejects an explicit
      // null rather than reading it as "no expiry".
      expect(body.containsKey('banned_to'), isFalse);
      expect(body.containsKey('reason'), isFalse);
    });
  });

  group('chats — update (api-docs §6.2)', () {
    test('uses PATCH, never PUT, and omits untouched fields', () async {
      stubPatch(tChatJson);

      final result = await dataSource.updateChat(tChatId, name: 'Renamed');

      expect(result.isRight(), isTrue);

      final captured = verify(
        () => mockApiClient.patch(
          captureAny(),
          data: captureAny(named: 'data'),
          options: any(named: 'options'),
        ),
      ).captured;

      expect(captured[0], '/chats/$tChatId/');
      final body = captured[1] as Map<String, dynamic>;
      expect(body, {'name': 'Renamed'});

      // A PUT would either 405 or wipe the omitted settings.
      verifyNever(
        () => mockApiClient.put(
          any(),
          data: any(named: 'data'),
          options: any(named: 'options'),
        ),
      );
    });
  });

  group('chats — create (api-docs §6.2)', () {
    test('rejects a direct chat with no member id before any request', () async {
      final result = await dataSource.createChat(
        chatType: ChatType.direct,
        memberIds: const [],
      );

      expect(result.getLeft().toNullable(), isA<InputFailure>());
      verifyNever(
        () => mockApiClient.post(
          any(),
          data: any(named: 'data'),
          options: any(named: 'options'),
        ),
      );
    });

    test('rejects a direct chat with two member ids before any request', () async {
      final result = await dataSource.createChat(
        chatType: ChatType.direct,
        memberIds: const [2, 3],
      );

      expect(result.getLeft().toNullable(), isA<InputFailure>());
      verifyNever(
        () => mockApiClient.post(
          any(),
          data: any(named: 'data'),
          options: any(named: 'options'),
        ),
      );
    });

    test('allows a direct chat with exactly one member id', () async {
      stubPost(tChatJson);

      final result = await dataSource.createChat(
        chatType: ChatType.direct,
        memberIds: const [2],
      );

      expect(result.isRight(), isTrue);
      final captured = verify(
        () => mockApiClient.post(
          captureAny(),
          data: captureAny(named: 'data'),
          options: any(named: 'options'),
        ),
      ).captured;
      expect(captured[0], '/chats/');
      expect((captured[1] as Map<String, dynamic>)['chat_type'], 'direct');
      expect((captured[1] as Map<String, dynamic>)['member_ids'], [2]);
    });

    test('does not apply the one-member rule to group chats', () async {
      stubPost(tChatJson);

      final result = await dataSource.createChat(
        name: 'Team',
        chatType: ChatType.group,
        memberIds: const [2, 3, 4],
      );

      expect(result.isRight(), isTrue);
    });
  });

  group('messages — send (api-docs §6.4)', () {
    test('always sends an Idempotency-Key header', () async {
      stubPost(tMessageJson);

      await dataSource.sendMessage(tChatId, content: 'hello');

      final captured = verify(
        () => mockApiClient.post(
          captureAny(),
          data: captureAny(named: 'data'),
          options: captureAny(named: 'options'),
        ),
      ).captured;

      expect(captured[0], '/chats/$tChatId/messages/');

      final options = captured[2] as Options;
      final key = options.headers?['Idempotency-Key'] as String?;
      expect(key, isNotNull);
      // A v4 UUID — the format the backend caches on for 24 h.
      expect(
        RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
        ).hasMatch(key!),
        isTrue,
        reason: 'expected a v4 UUID, got "$key"',
      );
    });

    test('reuses a caller-supplied key verbatim so a retry cannot duplicate', () async {
      stubPost(tMessageJson);
      const tKey = 'c5f3e4d6-0000-4000-8000-000000000003';

      await dataSource.sendMessage(tChatId, content: 'hi', idempotencyKey: tKey);
      await dataSource.sendMessage(tChatId, content: 'hi', idempotencyKey: tKey);

      final captured = verify(
        () => mockApiClient.post(
          any(),
          data: any(named: 'data'),
          options: captureAny(named: 'options'),
        ),
      ).captured;

      expect(
        captured.map((o) => (o as Options).headers?['Idempotency-Key']),
        [tKey, tKey],
      );
    });

    test('generates a DIFFERENT key per call when none is supplied', () async {
      stubPost(tMessageJson);

      await dataSource.sendMessage(tChatId, content: 'one');
      await dataSource.sendMessage(tChatId, content: 'two');

      final captured = verify(
        () => mockApiClient.post(
          any(),
          data: any(named: 'data'),
          options: captureAny(named: 'options'),
        ),
      ).captured;

      final keys = captured
          .map((o) => (o as Options).headers?['Idempotency-Key'])
          .toSet();
      // Two distinct messages must not collapse into one via a shared key.
      expect(keys, hasLength(2));
    });

    test('omits upload_tokens when empty rather than sending []', () async {
      stubPost(tMessageJson);

      await dataSource.sendMessage(
        tChatId,
        content: 'hello',
        uploadTokens: const [],
      );

      final captured = verify(
        () => mockApiClient.post(
          any(),
          data: captureAny(named: 'data'),
          options: any(named: 'options'),
        ),
      ).captured;

      expect(
        (captured.single as Map<String, dynamic>).containsKey('upload_tokens'),
        isFalse,
      );
    });

    test('passes message_type and reply_to_id through in snake_case', () async {
      stubPost(tMessageJson);

      await dataSource.sendMessage(
        tChatId,
        content: 'quoted',
        replyToId: tMessageId,
        messageType: MessageType.reply,
      );

      final captured = verify(
        () => mockApiClient.post(
          any(),
          data: captureAny(named: 'data'),
          options: any(named: 'options'),
        ),
      ).captured;

      final body = captured.single as Map<String, dynamic>;
      expect(body['reply_to_id'], tMessageId);
      expect(body['message_type'], 'reply');
    });
  });

  group('messages — forward (api-docs §6.4)', () {
    test('puts the TARGET chat in the path and the source pair in the body', () async {
      stubPost(tMessageJson);
      const tTargetChatId = 'd6a4b5c7-0000-4000-8000-000000000004';

      await dataSource.forwardMessage(
        sourceChatId: tChatId,
        sourceMessageId: tMessageId,
        targetChatId: tTargetChatId,
        comment: 'look',
      );

      final captured = verify(
        () => mockApiClient.post(
          captureAny(),
          data: captureAny(named: 'data'),
          options: any(named: 'options'),
        ),
      ).captured;

      // Swapping these two is the easy mistake, and it "works" — it forwards
      // the wrong way round into the wrong chat.
      expect(captured[0], '/chats/$tTargetChatId/messages/forward/');
      expect(captured[1], {
        'source_chat_id': tChatId,
        'source_message_id': tMessageId,
        'comment': 'look',
      });
    });
  });

  group('attachments (api-docs §6.5)', () {
    test('parses the BARE ARRAY of upload tickets', () async {
      stubPost([
        {
          'upload_token': 'e7b5c6d8-0000-4000-8000-000000000005',
          'upload_url': 'https://s3.example.com/put?sig=abc',
          'attachment_type': 'image',
          'expires_in': 3600,
        },
      ]);

      final result = await dataSource.requestAttachmentUpload(tChatId, const [
        AttachmentUploadRequestEntity(
          filename: 'a.png',
          mimeType: 'image/png',
          fileSize: 1024,
          bytes: [1, 2, 3],
        ),
      ]);

      final tickets = result.getRight().toNullable();
      expect(tickets, hasLength(1));
      expect(tickets!.single.uploadToken,
          'e7b5c6d8-0000-4000-8000-000000000005');

      final captured = verify(
        () => mockApiClient.post(
          captureAny(),
          data: captureAny(named: 'data'),
          options: any(named: 'options'),
        ),
      ).captured;

      expect(captured[0], '/chats/$tChatId/attachments/upload-requests/');
      expect((captured[1] as Map<String, dynamic>)['uploads'], [
        {'filename': 'a.png', 'mime_type': 'image/png', 'file_size': 1024},
      ]);
    });

    test('confirm posts the tokens to the confirm sub-path', () async {
      stubPost(null);

      final result = await dataSource.confirmAttachmentUpload(tChatId, const [
        'e7b5c6d8-0000-4000-8000-000000000005',
      ]);

      expect(result.isRight(), isTrue);

      final captured = verify(
        () => mockApiClient.post(
          captureAny(),
          data: captureAny(named: 'data'),
          options: any(named: 'options'),
        ),
      ).captured;

      expect(
        captured[0],
        '/chats/$tChatId/attachments/upload-requests/confirm/',
      );
      expect(captured[1], {
        'upload_tokens': ['e7b5c6d8-0000-4000-8000-000000000005'],
      });
    });
  });

  group('calls (api-docs §6.6)', () {
    test('mute posts {muted} to the participant sub-path', () async {
      stubPost(null);

      await dataSource.muteCallParticipant(tChatId, 99, true);

      final captured = verify(
        () => mockApiClient.post(
          captureAny(),
          data: captureAny(named: 'data'),
          options: any(named: 'options'),
        ),
      ).captured;

      expect(captured[0], '/chats/$tChatId/calls/participants/99/mute/');
      expect(captured[1], {'muted': true});
    });
  });
}
