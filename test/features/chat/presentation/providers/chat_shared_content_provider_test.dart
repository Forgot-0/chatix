import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:chatix/features/chat/domain/entities/attachment_entity.dart';
import 'package:chatix/features/chat/domain/entities/message_entity.dart';
import 'package:chatix/features/chat/domain/usecases/get_local_messages_use_case.dart';
import 'package:chatix/features/chat/presentation/providers/chat_detail_provider.dart';
import 'package:chatix/features/chat/presentation/providers/chat_profile_provider.dart';
import 'package:chatix/features/chat/presentation/providers/chat_providers.dart';

class MockGetLocalMessagesUseCase extends Mock
    implements GetLocalMessagesUseCase {}

/// The shared-content panel reads the cache on this device and, when the
/// chat screen behind it is alive, the window it has loaded. What matters is
/// that it never starts that screen itself: opening a chat profile by link
/// would otherwise fetch a chat and a page of messages nobody asked for.
void main() {
  const chatId = 'c1';

  MessageEntity message(int seq, {List<AttachmentEntity> attachments = const []}) =>
      MessageEntity(
        id: 'm$seq',
        chatId: chatId,
        seq: seq,
        authorId: 7,
        type: MessageType.text,
        content: null,
        replyToId: null,
        forwardedFromChatId: null,
        forwardedFromMessageId: null,
        forwardedFromAuthorId: null,
        isEdited: false,
        createdAt: DateTime.utc(2026, 5, 1).add(Duration(minutes: seq)),
        attachments: attachments,
      );

  AttachmentEntity photo(String id) => AttachmentEntity(
    id: id,
    messageId: null,
    chatId: chatId,
    uploaderId: 7,
    attachmentType: AttachmentType.image,
    attachmentStatus: AttachmentStatus.success,
    url: null,
    urlExpiresIn: null,
    s3Key: 'key/$id',
    mimeType: 'image/jpeg',
    originalFilename: '$id.jpg',
    size: 1,
    width: null,
    height: null,
    durationSeconds: null,
    createdAt: DateTime.utc(2026, 5, 1),
  );

  late MockGetLocalMessagesUseCase localMessages;

  setUp(() {
    localMessages = MockGetLocalMessagesUseCase();
    when(
      () => localMessages.execute(any(), limit: any(named: 'limit')),
    ).thenReturn([
      message(1, attachments: [photo('a')]),
      message(2, attachments: [photo('b')]),
    ]);
  });

  ProviderContainer container() {
    final container = ProviderContainer(
      overrides: [
        getLocalMessagesUseCaseProvider.overrideWithValue(localMessages),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('sorts what the cache holds without touching the chat screen', () {
    final ref = container();

    final content = ref.read(chatSharedContentProvider(chatId));

    expect(content.media.map((item) => item.attachmentId), ['b', 'a']);
    expect(ref.exists(chatDetailProvider(chatId)), isFalse);
  });

  test('a chat this device has never opened has nothing to show', () {
    when(
      () => localMessages.execute(any(), limit: any(named: 'limit')),
    ).thenReturn(const []);

    expect(container().read(chatSharedContentProvider(chatId)).isEmpty, isTrue);
  });

  test('asks the cache for its whole depth, not one screenful', () {
    container().read(chatSharedContentProvider(chatId));

    final limit =
        verify(
              () => localMessages.execute(chatId, limit: captureAny(named: 'limit')),
            ).captured.single
            as int;

    expect(limit, greaterThanOrEqualTo(200));
  });
}
