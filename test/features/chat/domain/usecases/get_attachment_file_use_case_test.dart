import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

import 'package:chatix/core/error/failures.dart';
import 'package:chatix/core/network/transfer_cancellation.dart';
import 'package:chatix/core/storage/cache/attachment_file_cache.dart';
import 'package:chatix/features/chat/data/repositories/chat_attachment_downloader.dart';
import 'package:chatix/features/chat/domain/entities/attachment_entity.dart';
import 'package:chatix/features/chat/domain/repositories/chat_repository.dart';
import 'package:chatix/features/chat/domain/usecases/get_attachment_file_use_case.dart';

class MockChatRepository extends Mock implements ChatRepository {}

class MockDownloader extends Mock implements ChatAttachmentDownloader {}

void main() {
  late MockChatRepository repository;
  late MockDownloader downloader;
  late AttachmentFileCache cache;
  late GetAttachmentFileUseCase useCase;
  late Directory root;

  const chatId = 'a3f1c2d4-0000-4000-8000-000000000001';
  const messageId = 'b3f1c2d4-0000-4000-8000-000000000002';
  const s3Key = 'chats/a3f1/9c2e/holiday.jpg';

  AttachmentEntity attachment({String? url}) => AttachmentEntity(
    id: 'c3f1c2d4-0000-4000-8000-000000000003',
    messageId: messageId,
    chatId: chatId,
    uploaderId: 7,
    attachmentType: AttachmentType.image,
    attachmentStatus: AttachmentStatus.success,
    url: url,
    urlExpiresIn: url == null ? null : 300,
    s3Key: s3Key,
    mimeType: 'image/jpeg',
    originalFilename: 'holiday.jpg',
    size: 4,
    width: 1200,
    height: 800,
    durationSeconds: null,
    createdAt: DateTime(2026, 3, 1),
  );

  setUp(() {
    root = Directory.systemTemp.createTempSync('attachment_file_use_case');
    repository = MockChatRepository();
    downloader = MockDownloader();
    cache = AttachmentFileCache(rootDirectory: () async => root);
    useCase = GetAttachmentFileUseCase(repository, downloader, cache);
  });

  tearDown(() {
    if (root.existsSync()) root.deleteSync(recursive: true);
  });

  void stubDownload(Either<Failure, List<int>> answer, {String? url}) {
    when(
      () => downloader.download(
        url: url ?? any(named: 'url'),
        onProgress: any(named: 'onProgress'),
        cancellation: any(named: 'cancellation'),
      ),
    ).thenAnswer((_) async => answer);
  }

  void stubFreshUrl(String url) {
    when(
      () => repository.getAttachmentDownloadUrl(chatId, messageId, any()),
    ).thenAnswer(
      (_) async => Right(
        AttachmentDownloadUrlEntity(
          attachmentId: 'c3f1c2d4-0000-4000-8000-000000000003',
          url: url,
          expiresIn: 300,
        ),
      ),
    );
  }

  Future<Either<Failure, File>> run({
    String? url,
    TransferCancellation? cancellation,
  }) => useCase.execute(
    chatId: chatId,
    messageId: messageId,
    attachment: attachment(url: url),
    cancellation: cancellation,
  );

  test('a file already in the cache is not downloaded again', () async {
    await cache.store(s3Key, [1, 2, 3]);

    final result = await run(url: 'https://s3.example/fresh');

    expect(result.isRight(), isTrue);
    expect(await result.getRight().toNullable()!.readAsBytes(), [1, 2, 3]);
    verifyZeroInteractions(downloader);
    verifyZeroInteractions(repository);
  });

  test('the link the message came with is tried first, and what comes '
      'down is cached under the s3 key', () async {
    stubDownload(const Right([4, 5, 6]), url: 'https://s3.example/inline');

    final result = await run(url: 'https://s3.example/inline');

    expect(result.isRight(), isTrue);
    expect(await cache.find(s3Key), isNotNull);
    verifyNever(
      () => repository.getAttachmentDownloadUrl(any(), any(), any()),
    );
  });

  test('an expired link is replaced by a fresh one without a word to the '
      'reader', () async {
    when(
      () => downloader.download(
        url: 'https://s3.example/stale',
        onProgress: any(named: 'onProgress'),
        cancellation: any(named: 'cancellation'),
      ),
    ).thenAnswer(
      (_) async => const Left(ServerFailure(message: 'no', statusCode: 403)),
    );
    when(
      () => downloader.download(
        url: 'https://s3.example/fresh',
        onProgress: any(named: 'onProgress'),
        cancellation: any(named: 'cancellation'),
      ),
    ).thenAnswer((_) async => const Right([9, 9]));
    stubFreshUrl('https://s3.example/fresh');

    final result = await run(url: 'https://s3.example/stale');

    expect(result.isRight(), isTrue);
    expect(await result.getRight().toNullable()!.readAsBytes(), [9, 9]);
    verify(
      () => repository.getAttachmentDownloadUrl(chatId, messageId, any()),
    ).called(1);
  });

  test('an attachment with no link at all goes straight for a fresh one',
      () async {
    stubFreshUrl('https://s3.example/fresh');
    stubDownload(const Right([1]), url: 'https://s3.example/fresh');

    final result = await run();

    expect(result.isRight(), isTrue);
    verify(
      () => repository.getAttachmentDownloadUrl(chatId, messageId, any()),
    ).called(1);
  });

  test('a dead connection is not retried with a new link — it would fail '
      'the same way twice', () async {
    stubDownload(const Left(NetworkFailure()));

    final result = await run(url: 'https://s3.example/inline');

    expect(result.getLeft().toNullable(), isA<NetworkFailure>());
    verifyNever(
      () => repository.getAttachmentDownloadUrl(any(), any(), any()),
    );
  });

  test('a cancelled download is not retried either', () async {
    final cancellation = TransferCancellation()..cancel();
    stubDownload(const Left(CancelledFailure()));

    final result = await run(
      url: 'https://s3.example/inline',
      cancellation: cancellation,
    );

    expect(result.getLeft().toNullable(), isA<CancelledFailure>());
    verifyNever(
      () => repository.getAttachmentDownloadUrl(any(), any(), any()),
    );
    expect(await cache.find(s3Key), isNull);
  });

  test('a refused download-url request is the failure the caller sees',
      () async {
    when(
      () => repository.getAttachmentDownloadUrl(chatId, messageId, any()),
    ).thenAnswer(
      (_) async => const Left(
        ApiFailure(
          code: 'ATTACHMENT_NOT_FOUND',
          message: 'gone',
          detail: null,
          status: 404,
        ),
      ),
    );

    final result = await run();

    expect(result.getLeft().toNullable(), isA<ApiFailure>());
    expect(await cache.find(s3Key), isNull);
  });
}
