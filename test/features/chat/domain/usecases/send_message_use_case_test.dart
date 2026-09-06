import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';
import 'package:chatix/core/error/failures.dart';
import 'package:chatix/features/chat/domain/entities/message_entity.dart';
import 'package:chatix/features/chat/domain/repositories/chat_repository.dart';
import 'package:chatix/features/chat/domain/usecases/send_message_use_case.dart';

class MockChatRepository extends Mock implements ChatRepository {}

void main() {
  late SendMessageUseCase useCase;
  late MockChatRepository mockRepository;

  setUp(() {
    mockRepository = MockChatRepository();
    useCase = SendMessageUseCase(mockRepository);
  });

  const tChatId = 'a3f1c2d4-0000-4000-8000-000000000001';

  final tMessage = MessageEntity(
    id: 'm-1',
    chatId: tChatId,
    seq: 42,
    authorId: 7,
    type: MessageType.text,
    content: 'Hello',
    replyToId: null,
    forwardedFromChatId: null,
    forwardedFromMessageId: null,
    forwardedFromAuthorId: null,
    isEdited: false,
    createdAt: DateTime.utc(2026, 1, 1),
    attachments: const [],
  );

  void stubSendMessage() {
    when(
      () => mockRepository.sendMessage(
        any(),
        content: any(named: 'content'),
        replyToId: any(named: 'replyToId'),
        messageType: any(named: 'messageType'),
        uploadTokens: any(named: 'uploadTokens'),
        idempotencyKey: any(named: 'idempotencyKey'),
      ),
    ).thenAnswer((_) async => Right(tMessage));
  }

  group('happy path', () {
    test('forwards a plain text message to the repository', () async {
      stubSendMessage();

      final result = await useCase.execute(tChatId, content: 'Hello');

      expect(result.getRight().toNullable(), tMessage);
      verify(
        () => mockRepository.sendMessage(
          tChatId,
          content: 'Hello',
          replyToId: null,
          messageType: null,
          uploadTokens: null,
          idempotencyKey: null,
        ),
      ).called(1);
    });

    test('trims content and drops whitespace-only text to null', () async {
      stubSendMessage();

      await useCase.execute(
        tChatId,
        content: '   ',
        uploadTokens: const ['token-1'],
      );

      verify(
        () => mockRepository.sendMessage(
          tChatId,
          content: null,
          replyToId: null,
          messageType: null,
          uploadTokens: const ['token-1'],
          idempotencyKey: null,
        ),
      ).called(1);
    });

    test('infers MessageType.reply when replyToId is given', () async {
      stubSendMessage();

      await useCase.execute(tChatId, content: 'Sure', replyToId: 'm-0');

      verify(
        () => mockRepository.sendMessage(
          tChatId,
          content: 'Sure',
          replyToId: 'm-0',
          messageType: MessageType.reply,
          uploadTokens: null,
          idempotencyKey: null,
        ),
      ).called(1);
    });

    test('keeps an explicit messageType instead of inferring one', () async {
      stubSendMessage();

      await useCase.execute(
        tChatId,
        content: 'See photo',
        replyToId: 'm-0',
        messageType: MessageType.image,
      );

      verify(
        () => mockRepository.sendMessage(
          tChatId,
          content: 'See photo',
          replyToId: 'm-0',
          messageType: MessageType.image,
          uploadTokens: null,
          idempotencyKey: null,
        ),
      ).called(1);
    });
  });

  group('idempotency key (api-docs §6.4)', () {
    test('passes the caller-supplied key through verbatim', () async {
      stubSendMessage();
      const key = 'b7e2c1a0-1111-4000-8000-000000000002';

      await useCase.execute(tChatId, content: 'Hi', idempotencyKey: key);

      verify(
        () => mockRepository.sendMessage(
          tChatId,
          content: 'Hi',
          replyToId: null,
          messageType: null,
          uploadTokens: null,
          idempotencyKey: key,
        ),
      ).called(1);
    });

    test(
      'reuses the same key across retries so the send is not duplicated',
      () async {
        const key = 'c1d2e3f4-2222-4000-8000-000000000003';
        var attempts = 0;

        when(
          () => mockRepository.sendMessage(
            any(),
            content: any(named: 'content'),
            replyToId: any(named: 'replyToId'),
            messageType: any(named: 'messageType'),
            uploadTokens: any(named: 'uploadTokens'),
            idempotencyKey: any(named: 'idempotencyKey'),
          ),
        ).thenAnswer((_) async {
          attempts++;
          if (attempts == 1) return const Left(NetworkFailure());
          return Right(tMessage);
        });

        final first = await useCase.execute(
          tChatId,
          content: 'Hi',
          idempotencyKey: key,
        );
        final second = await useCase.execute(
          tChatId,
          content: 'Hi',
          idempotencyKey: key,
        );

        expect(first.isLeft(), isTrue);
        expect(second.getRight().toNullable(), tMessage);

        verify(
          () => mockRepository.sendMessage(
            tChatId,
            content: 'Hi',
            replyToId: null,
            messageType: null,
            uploadTokens: null,
            idempotencyKey: key,
          ),
        ).called(2);
      },
    );
  });

  group('client-side validation', () {
    test('rejects a message with neither text nor attachments', () async {
      final result = await useCase.execute(tChatId);

      expect(result.getLeft().toNullable(), isA<InputFailure>());
      verifyNever(
        () => mockRepository.sendMessage(
          any(),
          content: any(named: 'content'),
          replyToId: any(named: 'replyToId'),
          messageType: any(named: 'messageType'),
          uploadTokens: any(named: 'uploadTokens'),
          idempotencyKey: any(named: 'idempotencyKey'),
        ),
      );
    });

    test('allows an attachment-only message with no content', () async {
      stubSendMessage();

      final result = await useCase.execute(
        tChatId,
        uploadTokens: const ['token-1'],
      );

      expect(result.isRight(), isTrue);
    });

    test('rejects content longer than 4096 characters', () async {
      final result = await useCase.execute(
        tChatId,
        content: 'x' * (SendMessageUseCase.maxContentLength + 1),
      );

      final failure = result.getLeft().toNullable();
      expect(failure, isA<InputFailure>());
      expect(failure!.message, contains('4096'));
      verifyNever(
        () => mockRepository.sendMessage(
          any(),
          content: any(named: 'content'),
          replyToId: any(named: 'replyToId'),
          messageType: any(named: 'messageType'),
          uploadTokens: any(named: 'uploadTokens'),
          idempotencyKey: any(named: 'idempotencyKey'),
        ),
      );
    });

    test('accepts content of exactly 4096 characters', () async {
      stubSendMessage();

      final result = await useCase.execute(
        tChatId,
        content: 'x' * SendMessageUseCase.maxContentLength,
      );

      expect(result.isRight(), isTrue);
    });

    test('rejects an empty chat id', () async {
      final result = await useCase.execute('  ', content: 'Hello');

      expect(result.getLeft().toNullable(), isA<InputFailure>());
    });
  });

  test('propagates a repository failure unchanged', () async {
    when(
      () => mockRepository.sendMessage(
        any(),
        content: any(named: 'content'),
        replyToId: any(named: 'replyToId'),
        messageType: any(named: 'messageType'),
        uploadTokens: any(named: 'uploadTokens'),
        idempotencyKey: any(named: 'idempotencyKey'),
      ),
    ).thenAnswer(
      (_) async => const Left(ServerFailure(message: 'Slow mode', statusCode: 429)),
    );

    final result = await useCase.execute(tChatId, content: 'Hello');

    final failure = result.getLeft().toNullable();
    expect(failure, isA<ServerFailure>());
    expect(failure!.statusCode, 429);
  });
}
