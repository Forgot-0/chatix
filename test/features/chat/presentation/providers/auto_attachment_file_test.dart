import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chatix/core/error/failures.dart';
import 'package:chatix/core/network/connectivity_providers.dart';
import 'package:chatix/core/network/offline_sync_providers.dart';
import 'package:chatix/core/providers/media_settings_providers.dart';
import 'package:chatix/core/providers/storage_providers.dart';
import 'package:chatix/core/settings/media_settings.dart';
import 'package:chatix/core/storage/cache/attachment_file_cache.dart';
import 'package:chatix/features/chat/domain/entities/attachment_entity.dart';
import 'package:chatix/features/chat/domain/usecases/get_attachment_file_use_case.dart';
import 'package:chatix/features/chat/presentation/providers/attachment_file_provider.dart';
import 'package:chatix/features/chat/presentation/providers/chat_providers.dart';

class _MockConnectivity extends Mock implements Connectivity {}

class _MockGetAttachmentFile extends Mock implements GetAttachmentFileUseCase {}

/// Auto-download is a promise about what happens *without* being asked. So
/// the gate sits in front of the fetches nobody asked for — a thumbnail
/// coming into view, a video note in the feed — and never in front of a tap.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    registerFallbackValue(
      AttachmentEntity(
        id: 'fallback',
        messageId: null,
        chatId: 'c1',
        uploaderId: 0,
        attachmentType: AttachmentType.file,
        attachmentStatus: AttachmentStatus.success,
        url: null,
        urlExpiresIn: null,
        s3Key: 'chats/c1/fallback/file',
        mimeType: 'application/octet-stream',
        originalFilename: 'file',
        size: 0,
        width: null,
        height: null,
        durationSeconds: null,
        createdAt: DateTime(2026),
      ),
    );
  });

  late Directory root;
  late _MockConnectivity connectivity;
  late _MockGetAttachmentFile download;

  AttachmentEntity attachmentOf(AttachmentType type) => AttachmentEntity(
    id: 'a1',
    messageId: 'm1',
    chatId: 'c1',
    uploaderId: 7,
    attachmentType: type,
    attachmentStatus: AttachmentStatus.success,
    url: null,
    urlExpiresIn: null,
    s3Key: 'chats/c1/a1/holiday.jpg',
    mimeType: 'image/jpeg',
    originalFilename: 'holiday.jpg',
    size: 10,
    width: 100,
    height: 100,
    durationSeconds: null,
    createdAt: DateTime(2026, 3, 1),
  );

  setUp(() {
    root = Directory.systemTemp.createTempSync('auto_attachment_test');
    connectivity = _MockConnectivity();
    download = _MockGetAttachmentFile();

    when(
      () => download.execute(
        chatId: any(named: 'chatId'),
        messageId: any(named: 'messageId'),
        attachment: any(named: 'attachment'),
        onProgress: any(named: 'onProgress'),
        cancellation: any(named: 'cancellation'),
      ),
    ).thenAnswer((_) async {
      final file = File('${root.path}/downloaded');
      await file.writeAsBytes(const [1, 2, 3]);
      return Right<Failure, File>(file);
    });
  });

  tearDown(() {
    if (root.existsSync()) root.deleteSync(recursive: true);
  });

  Future<ProviderContainer> boot({
    List<ConnectivityResult> on = const [ConnectivityResult.mobile],
  }) async {
    when(connectivity.checkConnectivity).thenAnswer((_) async => on);
    when(
      () => connectivity.onConnectivityChanged,
    ).thenAnswer((_) => const Stream<List<ConnectivityResult>>.empty());

    SharedPreferences.setMockInitialValues(const {});
    final prefs = await SharedPreferences.getInstance();

    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        connectivityProvider.overrideWithValue(connectivity),
        attachmentFileCacheProvider.overrideWithValue(
          AttachmentFileCache(rootDirectory: () async => root),
        ),
        getAttachmentFileUseCaseProvider.overrideWithValue(download),
      ],
    );
    addTearDown(container.dispose);

    container.listen(connectivityStatusProvider, (_, _) {});
    await container.read(connectivityStatusProvider.future);
    return container;
  }

  group('the bucket an attachment falls in', () {
    test('sorts every type somewhere', () {
      expect(mediaKindOf(AttachmentType.image), MediaKind.photo);
      expect(mediaKindOf(AttachmentType.video), MediaKind.video);
      // A note is video: same bytes, same cost, same budget.
      expect(mediaKindOf(AttachmentType.videoNote), MediaKind.video);
      expect(mediaKindOf(AttachmentType.voice), MediaKind.voice);
      expect(mediaKindOf(AttachmentType.file), MediaKind.file);
    });
  });

  test(
    'a photo on mobile data waits for a tap rather than downloading',
    () async {
      final container = await boot();
      final key = attachmentFileKey(
        attachmentOf(AttachmentType.image),
        messageId: 'm1',
      );

      // The default for photos is Wi-Fi only, and this is mobile data.
      expect(
        await container.read(autoAttachmentFileProvider(key).future),
        isNull,
      );
      verifyNever(
        () => download.execute(
          chatId: any(named: 'chatId'),
          messageId: any(named: 'messageId'),
          attachment: any(named: 'attachment'),
          onProgress: any(named: 'onProgress'),
          cancellation: any(named: 'cancellation'),
        ),
      );
    },
  );

  test('the same photo on Wi-Fi is fetched without being asked', () async {
    final container = await boot(on: const [ConnectivityResult.wifi]);
    final key = attachmentFileKey(
      attachmentOf(AttachmentType.image),
      messageId: 'm1',
    );

    expect(
      await container.read(autoAttachmentFileProvider(key).future),
      isNotNull,
    );
  });

  test(
    'a document is held back even on Wi-Fi, until it is turned on',
    () async {
      final container = await boot(on: const [ConnectivityResult.wifi]);
      final key = attachmentFileKey(
        attachmentOf(AttachmentType.file),
        messageId: 'm1',
      );

      expect(
        await container.read(autoAttachmentFileProvider(key).future),
        isNull,
      );

      await container
          .read(mediaSettingsProvider.notifier)
          .setAutoDownload(MediaKind.file, MediaAutoDownload.always);

      expect(
        await container.read(autoAttachmentFileProvider(key).future),
        isNotNull,
      );
    },
  );

  test('a voice message arrives ahead of the play button by default', () async {
    final container = await boot();
    final key = attachmentFileKey(
      attachmentOf(AttachmentType.voice),
      messageId: 'm1',
    );

    // Small enough that waiting for it is pure friction, so it comes down on
    // any connection.
    expect(
      await container.read(autoAttachmentFileProvider(key).future),
      isNotNull,
    );
  });

  test(
    'a file already paid for is handed over whatever the setting says',
    () async {
      final container = await boot();
      final attachment = attachmentOf(AttachmentType.image);

      await container.read(attachmentFileCacheProvider).store(
        attachment.s3Key,
        const [1, 2, 3],
      );

      final key = attachmentFileKey(attachment, messageId: 'm1');

      expect(
        await container.read(autoAttachmentFileProvider(key).future),
        isNotNull,
      );
    },
  );

  test(
    'turning the policy off never blocks a fetch that was asked for',
    () async {
      final container = await boot();
      final key = attachmentFileKey(
        attachmentOf(AttachmentType.image),
        messageId: 'm1',
      );

      // What a tap reaches: the ungated provider, which downloads regardless.
      expect(
        await container.read(attachmentFileProvider(key).future),
        isNotNull,
      );
    },
  );
}
