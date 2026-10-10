import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

import 'package:chatix/core/error/failures.dart';
import 'package:chatix/core/network/transfer_cancellation.dart';
import 'package:chatix/features/chat/domain/entities/attachment_entity.dart';
import 'package:chatix/features/chat/domain/usecases/get_attachment_file_use_case.dart';
import 'package:chatix/features/chat/presentation/providers/attachment_download_provider.dart';
import 'package:chatix/features/chat/presentation/providers/attachment_file_provider.dart';
import 'package:chatix/features/chat/presentation/providers/chat_providers.dart';

class _MockGetAttachmentFile extends Mock implements GetAttachmentFileUseCase {}

void main() {
  final document = AttachmentEntity(
    id: 'd1',
    messageId: 'm1',
    chatId: 'c1',
    uploaderId: 7,
    attachmentType: AttachmentType.file,
    attachmentStatus: AttachmentStatus.success,
    url: null,
    urlExpiresIn: null,
    s3Key: 'chats/c1/d1/report.pdf',
    mimeType: 'application/pdf',
    originalFilename: 'report.pdf',
    size: 2048,
    width: null,
    height: null,
    durationSeconds: null,
    createdAt: DateTime(2026, 10, 10),
  );
  final key = attachmentFileKey(document, messageId: 'm1');

  setUpAll(() => registerFallbackValue(document));

  late _MockGetAttachmentFile getFile;

  setUp(() => getFile = _MockGetAttachmentFile());

  void answer(
    Future<Either<Failure, File>> Function(
      void Function(int, int) progress,
      TransferCancellation cancellation,
    )
    respond,
  ) {
    when(
      () => getFile.execute(
        chatId: any(named: 'chatId'),
        messageId: any(named: 'messageId'),
        attachment: any(named: 'attachment'),
        onProgress: any(named: 'onProgress'),
        cancellation: any(named: 'cancellation'),
      ),
    ).thenAnswer(
      (invocation) => respond(
        invocation.namedArguments[#onProgress] as void Function(int, int),
        invocation.namedArguments[#cancellation] as TransferCancellation,
      ),
    );
  }

  ProviderContainer containerWith({File? cached}) {
    final container = ProviderContainer(
      overrides: [
        autoAttachmentFileProvider.overrideWith((ref, key) async => cached),
        getAttachmentFileUseCaseProvider.overrideWithValue(getFile),
      ],
    );
    addTearDown(container.dispose);
    // Something on screen is watching, as the document row would be.
    container.listen(attachmentDownloadProvider(key), (_, _) {});
    return container;
  }

  AttachmentDownloadState stateOf(ProviderContainer container) =>
      container.read(attachmentDownloadProvider(key));

  AttachmentDownloadController controllerOf(ProviderContainer container) =>
      container.read(attachmentDownloadProvider(key).notifier);

  test('starts from what the cache says', () async {
    final missing = containerWith();
    expect(stateOf(missing).phase, AttachmentDownloadPhase.unknown);
    await pumpEventQueue();
    expect(stateOf(missing).phase, AttachmentDownloadPhase.remote);

    final here = containerWith(cached: File('report.pdf'));
    await pumpEventQueue();
    expect(stateOf(here).phase, AttachmentDownloadPhase.local);
    expect(stateOf(here).file?.path, 'report.pdf');
  });

  test('a download counts up and ends on this device', () async {
    final done = Completer<Either<Failure, File>>();
    late void Function(int, int) progress;
    answer((onProgress, _) {
      progress = onProgress;
      return done.future;
    });

    final container = containerWith();
    await pumpEventQueue();

    final result = controllerOf(container).fetch();
    expect(stateOf(container).phase, AttachmentDownloadPhase.downloading);
    expect(stateOf(container).progress, isNull);

    progress(512, 2048);
    expect(stateOf(container).progress, 0.25);
    expect(stateOf(container).received, 512);

    done.complete(Right(File('report.pdf')));
    expect((await result).isRight(), isTrue);
    expect(stateOf(container).phase, AttachmentDownloadPhase.local);
  });

  test('asking again while it runs joins the same download', () async {
    final done = Completer<Either<Failure, File>>();
    answer((_, _) => done.future);

    final container = containerWith();
    await pumpEventQueue();

    final first = controllerOf(container).fetch();
    final second = controllerOf(container).fetch();
    done.complete(Right(File('report.pdf')));
    await Future.wait([first, second]);

    verify(
      () => getFile.execute(
        chatId: any(named: 'chatId'),
        messageId: any(named: 'messageId'),
        attachment: any(named: 'attachment'),
        onProgress: any(named: 'onProgress'),
        cancellation: any(named: 'cancellation'),
      ),
    ).called(1);
  });

  test('a file already here is answered without a download', () async {
    final container = containerWith(cached: File('report.pdf'));
    await pumpEventQueue();

    final result = await controllerOf(container).fetch();
    expect(result.getRight().toNullable()?.path, 'report.pdf');
    verifyNever(
      () => getFile.execute(
        chatId: any(named: 'chatId'),
        messageId: any(named: 'messageId'),
        attachment: any(named: 'attachment'),
        onProgress: any(named: 'onProgress'),
        cancellation: any(named: 'cancellation'),
      ),
    );
  });

  test(
    'cancelling stops the transfer and a late answer changes nothing',
    () async {
      final done = Completer<Either<Failure, File>>();
      late TransferCancellation cancellation;
      answer((_, cancel) {
        cancellation = cancel;
        return done.future;
      });

      final container = containerWith();
      await pumpEventQueue();

      final result = controllerOf(container).fetch();
      controllerOf(container).cancel();

      expect(cancellation.isCancelled, isTrue);
      expect(stateOf(container).phase, AttachmentDownloadPhase.remote);

      done.complete(Right(File('report.pdf')));
      await result;
      expect(stateOf(container).phase, AttachmentDownloadPhase.remote);
    },
  );

  test('a failure leaves it a tap away and says why', () async {
    answer((_, _) async => const Left(NetworkFailure()));

    final container = containerWith();
    await pumpEventQueue();

    final result = await controllerOf(container).fetch();
    expect(result.isLeft(), isTrue);
    expect(stateOf(container).phase, AttachmentDownloadPhase.remote);
  });

  group('saved copies', () {
    test('a copy that is still there is found, a moved one is not', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final paths = container.read(savedAttachmentPathsProvider.notifier);

      final dir = Directory.systemTemp.createTempSync('saved_copies');
      addTearDown(() => dir.deleteSync(recursive: true));
      final file = File('${dir.path}/report.pdf')..writeAsStringSync('x');

      expect(paths.find(document.s3Key), isNull);

      paths.remember(document.s3Key, file.path);
      expect(paths.find(document.s3Key)?.path, file.path);

      file.deleteSync();
      expect(paths.find(document.s3Key), isNull);
    });
  });
}
