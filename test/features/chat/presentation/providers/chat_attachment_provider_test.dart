import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

import 'package:chatix/core/error/failures.dart';
import 'package:chatix/core/network/transfer_cancellation.dart';
import 'package:chatix/features/chat/data/repositories/chat_attachment_uploader.dart';
import 'package:chatix/features/chat/domain/entities/attachment_entity.dart';
import 'package:chatix/features/chat/domain/repositories/chat_repository.dart';
import 'package:chatix/features/chat/domain/usecases/upload_chat_attachment_use_case.dart';
import 'package:chatix/features/chat/presentation/providers/chat_attachment_provider.dart';
import 'package:chatix/features/chat/presentation/providers/chat_providers.dart';

class MockChatRepository extends Mock implements ChatRepository {}

class MockChatAttachmentUploader extends Mock
    implements ChatAttachmentUploader {}

void main() {
  const chatId = 'a3f1c2d4-0000-4000-8000-000000000001';

  late MockChatRepository repository;
  late MockChatAttachmentUploader uploader;

  setUpAll(() {
    registerFallbackValue(<AttachmentUploadRequestEntity>[]);
  });

  setUp(() {
    repository = MockChatRepository();
    uploader = MockChatAttachmentUploader();
  });

  AttachmentUploadRequestEntity image(String name) =>
      AttachmentUploadRequestEntity(
        filename: name,
        mimeType: 'image/jpeg',
        fileSize: 1024,
        filePath: '/tmp/$name',
      );

  AttachmentUploadTicketEntity ticket(String token) =>
      AttachmentUploadTicketEntity(
        uploadToken: token,
        uploadUrl: 'https://s3.example/$token',
        attachmentType: AttachmentType.image,
        expiresIn: 3600,
      );

  ProviderContainer boot() {
    final container = ProviderContainer(
      overrides: [
        uploadChatAttachmentUseCaseProvider.overrideWithValue(
          UploadChatAttachmentUseCase(repository, uploader),
        ),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  Future<ChatAttachmentState> read(ProviderContainer container) async =>
      await container.read(chatAttachmentProvider(chatId).future);

  test('a selection that breaks the limits is refused, not staged', () async {
    final container = boot();
    await read(container);

    container
        .read(chatAttachmentProvider(chatId).notifier)
        .select([
          for (var i = 0; i < 11; i++) image('photo$i.jpg'),
        ]);

    final state = container.read(chatAttachmentProvider(chatId)).value!;
    expect(state.hasSelection, isFalse);
    expect(state.failure, isA<InputFailure>());
  });

  test('one file can be dropped without losing the rest', () async {
    final container = boot();
    await read(container);

    final notifier = container.read(chatAttachmentProvider(chatId).notifier);
    notifier.select([image('a.jpg'), image('b.jpg'), image('c.jpg')]);
    notifier.removeAt(1);

    final state = container.read(chatAttachmentProvider(chatId)).value!;
    expect(
      state.selected.map((upload) => upload.filename),
      ['a.jpg', 'c.jpg'],
    );
  });

  test('dropping a file nobody selected changes nothing', () async {
    final container = boot();
    await read(container);

    final notifier = container.read(chatAttachmentProvider(chatId).notifier);
    notifier.select([image('a.jpg')]);
    notifier.removeAt(4);

    expect(
      container.read(chatAttachmentProvider(chatId)).value!.selected,
      hasLength(1),
    );
  });

  test('cancelling mid-upload empties the tray and says nothing', () async {
    final container = boot();
    await read(container);

    final started = Completer<void>();
    final release = Completer<void>();

    when(
      () => repository.requestAttachmentUpload(chatId, any()),
    ).thenAnswer((_) async => Right([ticket('token-a')]));
    when(
      () => uploader.upload(
        uploadUrl: any(named: 'uploadUrl'),
        mimeType: any(named: 'mimeType'),
        contentLength: any(named: 'contentLength'),
        filePath: any(named: 'filePath'),
        bytes: any(named: 'bytes'),
        onProgress: any(named: 'onProgress'),
        cancellation: any(named: 'cancellation'),
      ),
    ).thenAnswer((invocation) async {
      if (!started.isCompleted) started.complete();
      await release.future;

      final cancellation =
          invocation.namedArguments[#cancellation] as TransferCancellation?;
      return cancellation?.isCancelled ?? false
          ? const Left(CancelledFailure(message: 'Upload cancelled'))
          : const Right(null);
    });

    final notifier = container.read(chatAttachmentProvider(chatId).notifier);
    notifier.select([image('a.jpg')]);

    final upload = notifier.upload();
    await started.future;

    notifier.cancel();
    release.complete();
    await upload;

    final state = container.read(chatAttachmentProvider(chatId)).value!;
    expect(state.hasSelection, isFalse);
    expect(state.uploadTokens, isEmpty);
    expect(
      state.failure,
      isNull,
      reason: 'a cancel is an answer, not an error worth showing',
    );
    verifyNever(() => repository.confirmAttachmentUpload(any(), any()));
  });

  test('a failed upload keeps the selection, so it can be retried', () async {
    final container = boot();
    await read(container);

    when(
      () => repository.requestAttachmentUpload(chatId, any()),
    ).thenAnswer((_) async => Right([ticket('token-a')]));
    when(
      () => uploader.upload(
        uploadUrl: any(named: 'uploadUrl'),
        mimeType: any(named: 'mimeType'),
        contentLength: any(named: 'contentLength'),
        filePath: any(named: 'filePath'),
        bytes: any(named: 'bytes'),
        onProgress: any(named: 'onProgress'),
        cancellation: any(named: 'cancellation'),
      ),
    ).thenAnswer((_) async => const Left(NetworkFailure()));

    final notifier = container.read(chatAttachmentProvider(chatId).notifier);
    notifier.select([image('a.jpg')]);
    await notifier.upload();

    final failed = container.read(chatAttachmentProvider(chatId)).value!;
    expect(failed.failure, isA<NetworkFailure>());
    expect(failed.hasSelection, isTrue);

    // The second attempt goes through.
    when(
      () => uploader.upload(
        uploadUrl: any(named: 'uploadUrl'),
        mimeType: any(named: 'mimeType'),
        contentLength: any(named: 'contentLength'),
        filePath: any(named: 'filePath'),
        bytes: any(named: 'bytes'),
        onProgress: any(named: 'onProgress'),
        cancellation: any(named: 'cancellation'),
      ),
    ).thenAnswer((_) async => const Right(null));
    when(
      () => repository.confirmAttachmentUpload(chatId, any()),
    ).thenAnswer((_) async => const Right(null));

    await notifier.retry();

    final done = container.read(chatAttachmentProvider(chatId)).value!;
    expect(done.failure, isNull);
    expect(done.uploadTokens, ['token-a']);
    expect(done.isReady, isTrue);
  });
}
