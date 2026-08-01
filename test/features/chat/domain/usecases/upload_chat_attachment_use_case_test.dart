import 'package:chatix/features/chat/data/repositories/chat_attachment_uploader.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';
import 'package:chatix/core/error/failures.dart';
import 'package:chatix/features/chat/domain/entities/attachment_entity.dart';
import 'package:chatix/features/chat/domain/entities/chat_attachment_limits.dart';
import 'package:chatix/features/chat/domain/repositories/chat_repository.dart';
import 'package:chatix/features/chat/domain/usecases/upload_chat_attachment_use_case.dart';

class MockChatRepository extends Mock implements ChatRepository {}

class MockChatAttachmentUploader extends Mock implements ChatAttachmentUploader {}

void main() {
  late UploadChatAttachmentUseCase useCase;
  late MockChatRepository mockRepository;
  late MockChatAttachmentUploader mockUploader;

  setUpAll(() {
    registerFallbackValue(<AttachmentUploadRequestEntity>[]);
  });

  setUp(() {
    mockRepository = MockChatRepository();
    mockUploader = MockChatAttachmentUploader();
    useCase = UploadChatAttachmentUseCase(mockRepository, mockUploader);
  });

  const tChatId = 'a3f1c2d4-0000-4000-8000-000000000001';

  AttachmentUploadRequestEntity image({
    String filename = 'photo.jpg',
    int size = 1024,
  }) => AttachmentUploadRequestEntity(
    filename: filename,
    mimeType: 'image/jpeg',
    fileSize: size,
    filePath: '/tmp/$filename',
  );

  AttachmentUploadRequestEntity document({
    String filename = 'report.pdf',
    int size = 2048,
  }) => AttachmentUploadRequestEntity(
    filename: filename,
    mimeType: 'application/pdf',
    fileSize: size,
    filePath: '/tmp/$filename',
  );

  AttachmentUploadTicketEntity ticket(String token) =>
      AttachmentUploadTicketEntity(
        uploadToken: token,
        uploadUrl: 'https://minio.example.com/upload/$token?sig=abc',
        attachmentType: AttachmentType.image,
        expiresIn: 3600,
      );

  void stubUploaderSuccess() {
    when(
      () => mockUploader.upload(
        uploadUrl: any(named: 'uploadUrl'),
        mimeType: any(named: 'mimeType'),
        contentLength: any(named: 'contentLength'),
        filePath: any(named: 'filePath'),
        bytes: any(named: 'bytes'),
      ),
    ).thenAnswer((_) async => const Right(null));
  }

  group('three-step flow (api-docs §6.5)', () {
    test(
      'requests tickets, PUTs each file, confirms, then yields the tokens',
      () async {
        final uploads = [image(filename: 'a.jpg'), image(filename: 'b.jpg')];
        when(
          () => mockRepository.requestAttachmentUpload(tChatId, uploads),
        ).thenAnswer(
          (_) async => Right([ticket('token-a'), ticket('token-b')]),
        );
        stubUploaderSuccess();
        when(
          () => mockRepository.confirmAttachmentUpload(tChatId, [
            'token-a',
            'token-b',
          ]),
        ).thenAnswer((_) async => const Right(null));

        final events = await useCase.execute(tChatId, uploads).toList();
        final stages = events
            .map((e) => e.getRight().toNullable()?.stage)
            .toList();

        expect(stages, [
          ChatAttachmentUploadStage.requesting,
          ChatAttachmentUploadStage.uploading,
          ChatAttachmentUploadStage.uploading,
          ChatAttachmentUploadStage.confirming,
          ChatAttachmentUploadStage.done,
        ]);

        // The tokens on the terminal event are exactly what goes into
        // `sendMessage(uploadTokens: ...)` — step 4.
        expect(events.last.getRight().toNullable()!.uploadTokens, [
          'token-a',
          'token-b',
        ]);

        verifyInOrder([
          () => mockRepository.requestAttachmentUpload(tChatId, uploads),
          // ⚠️ Raw PUT with the file's own MIME type — not a multipart POST
          // (that's the avatar flow, api-docs §4.5).
          () => mockUploader.upload(
            uploadUrl: 'https://minio.example.com/upload/token-a?sig=abc',
            mimeType: 'image/jpeg',
            contentLength: 1024,
            filePath: '/tmp/a.jpg',
            bytes: null,
          ),
          () => mockUploader.upload(
            uploadUrl: 'https://minio.example.com/upload/token-b?sig=abc',
            mimeType: 'image/jpeg',
            contentLength: 1024,
            filePath: '/tmp/b.jpg',
            bytes: null,
          ),
          () => mockRepository.confirmAttachmentUpload(tChatId, [
            'token-a',
            'token-b',
          ]),
        ]);
      },
    );

    test('stops at step 1 and never uploads if tickets fail', () async {
      final uploads = [image()];
      when(
        () => mockRepository.requestAttachmentUpload(tChatId, uploads),
      ).thenAnswer((_) async => const Left(NetworkFailure()));

      final events = await useCase.execute(tChatId, uploads).toList();

      expect(events.last.getLeft().toNullable(), isA<NetworkFailure>());
      verifyNever(
        () => mockUploader.upload(
          uploadUrl: any(named: 'uploadUrl'),
          mimeType: any(named: 'mimeType'),
          contentLength: any(named: 'contentLength'),
          filePath: any(named: 'filePath'),
          bytes: any(named: 'bytes'),
        ),
      );
      verifyNever(() => mockRepository.confirmAttachmentUpload(any(), any()));
    });

    test('does not confirm when a PUT fails', () async {
      final uploads = [image()];
      when(
        () => mockRepository.requestAttachmentUpload(tChatId, uploads),
      ).thenAnswer((_) async => Right([ticket('token-a')]));
      when(
        () => mockUploader.upload(
          uploadUrl: any(named: 'uploadUrl'),
          mimeType: any(named: 'mimeType'),
          contentLength: any(named: 'contentLength'),
          filePath: any(named: 'filePath'),
          bytes: any(named: 'bytes'),
        ),
      ).thenAnswer(
        (_) async =>
            const Left(ServerFailure(message: 'expired', statusCode: 403)),
      );

      final events = await useCase.execute(tChatId, uploads).toList();

      expect(events.last.getLeft().toNullable()!.statusCode, 403);
      // Confirming bytes that never landed would leave the message pointing at
      // an attachment the backend will mark `error`.
      verifyNever(() => mockRepository.confirmAttachmentUpload(any(), any()));
    });

    test('aborts when the server returns a ticket/file count mismatch', () async {
      // Tickets are paired with files **by index**; a short list would upload
      // file B to file A's URL, so the flow must refuse rather than guess.
      final uploads = [image(filename: 'a.jpg'), image(filename: 'b.jpg')];
      when(
        () => mockRepository.requestAttachmentUpload(tChatId, uploads),
      ).thenAnswer((_) async => Right([ticket('token-a')]));

      final events = await useCase.execute(tChatId, uploads).toList();

      expect(events.last.getLeft().toNullable(), isA<ServerFailure>());
      verifyNever(
        () => mockUploader.upload(
          uploadUrl: any(named: 'uploadUrl'),
          mimeType: any(named: 'mimeType'),
          contentLength: any(named: 'contentLength'),
          filePath: any(named: 'filePath'),
          bytes: any(named: 'bytes'),
        ),
      );
    });

    test('surfaces a confirm failure', () async {
      final uploads = [image()];
      when(
        () => mockRepository.requestAttachmentUpload(tChatId, uploads),
      ).thenAnswer((_) async => Right([ticket('token-a')]));
      stubUploaderSuccess();
      when(
        () => mockRepository.confirmAttachmentUpload(tChatId, ['token-a']),
      ).thenAnswer(
        (_) async => const Left(
          ServerFailure(message: 'INVALID_UPLOAD_TOKEN', statusCode: 400),
        ),
      );

      final events = await useCase.execute(tChatId, uploads).toList();

      expect(events.last.getLeft().toNullable()!.statusCode, 400);
      expect(
        events.map((e) => e.getRight().toNullable()?.stage),
        isNot(contains(ChatAttachmentUploadStage.done)),
      );
    });
  });

  group('client-side limits enforced before any byte moves', () {
    test('rejects an empty selection', () async {
      final events = await useCase.execute(tChatId, const []).toList();

      expect(events.single.getLeft().toNullable(), isA<InputFailure>());
      verifyNever(() => mockRepository.requestAttachmentUpload(any(), any()));
    });

    test('rejects a disallowed MIME type', () async {
      final events = await useCase
          .execute(tChatId, [
            const AttachmentUploadRequestEntity(
              filename: 'malware.exe',
              mimeType: 'application/x-msdownload',
              fileSize: 100,
              filePath: '/tmp/malware.exe',
            ),
          ])
          .toList();

      final failure = events.single.getLeft().toNullable();
      expect(failure, isA<InputFailure>());
      // The message names the offending file — "unsupported type" alone
      // doesn't tell the user which of 10 files to remove.
      expect(failure!.message, contains('malware.exe'));
      verifyNever(() => mockRepository.requestAttachmentUpload(any(), any()));
    });

    test('rejects an image above the 50 MB media cap', () async {
      final events = await useCase
          .execute(tChatId, [
            image(size: ChatAttachmentLimits.maxMediaSizeBytes + 1),
          ])
          .toList();

      final failure = events.single.getLeft().toNullable();
      expect(failure, isA<InputFailure>());
      expect(failure!.message, contains('50.0 MB'));
    });

    test('accepts an image of exactly 50 MB', () async {
      final uploads = [image(size: ChatAttachmentLimits.maxMediaSizeBytes)];
      expect(useCase.validate(uploads), isNull);
    });

    test('rejects a document above the 100 MB file cap', () async {
      final events = await useCase
          .execute(tChatId, [
            document(size: ChatAttachmentLimits.maxFileSizeBytes + 1),
          ])
          .toList();

      expect(events.single.getLeft().toNullable(), isA<InputFailure>());
    });

    test('accepts a document of exactly 100 MB', () {
      // ⚠️ Documents get a *higher* size cap than media (100 vs 50 MB) but a
      // far lower count cap (1 vs 10) — the two buckets share nothing.
      expect(
        useCase.validate([
          document(size: ChatAttachmentLimits.maxFileSizeBytes),
        ]),
        isNull,
      );
    });

    test('rejects more than 10 images', () async {
      final uploads = List.generate(
        ChatAttachmentLimits.maxMediaCount + 1,
        (i) => image(filename: 'photo$i.jpg'),
      );

      final events = await useCase.execute(tChatId, uploads).toList();

      final failure = events.single.getLeft().toNullable();
      expect(failure, isA<InputFailure>());
      expect(failure!.message, contains('10'));
      verifyNever(() => mockRepository.requestAttachmentUpload(any(), any()));
    });

    test('accepts exactly 10 images', () {
      final uploads = List.generate(
        ChatAttachmentLimits.maxMediaCount,
        (i) => image(filename: 'photo$i.jpg'),
      );
      expect(useCase.validate(uploads), isNull);
    });

    test('rejects more than one document', () async {
      // The document bucket allows exactly 1 per message, which also means a
      // message can never mix a document with photos.
      final events = await useCase
          .execute(tChatId, [
            document(filename: 'a.pdf'),
            document(filename: 'b.pdf'),
          ])
          .toList();

      expect(events.single.getLeft().toNullable(), isA<InputFailure>());
    });

    test('rejects an empty file', () async {
      final events = await useCase
          .execute(tChatId, [image(size: 0)])
          .toList();

      expect(events.single.getLeft().toNullable(), isA<InputFailure>());
    });

    test('rejects a file with neither a path nor bytes', () {
      expect(
        useCase.validate([
          const AttachmentUploadRequestEntity(
            filename: 'ghost.jpg',
            mimeType: 'image/jpeg',
            fileSize: 100,
          ),
        ]),
        isA<InputFailure>(),
      );
    });

    test('images and videos share the same 10-item bucket', () {
      // 6 images + 5 videos = 11 media items → over the media cap even though
      // neither type alone exceeds it.
      final uploads = [
        ...List.generate(6, (i) => image(filename: 'p$i.jpg')),
        ...List.generate(
          5,
          (i) => AttachmentUploadRequestEntity(
            filename: 'v$i.mp4',
            mimeType: 'video/mp4',
            fileSize: 1024,
            filePath: '/tmp/v$i.mp4',
          ),
        ),
      ];

      expect(useCase.validate(uploads), isA<InputFailure>());
    });
  });
}
