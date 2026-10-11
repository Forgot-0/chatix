import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';

import 'package:chatix/core/ui/feedback/transfer_progress_ring.dart';
import 'package:chatix/features/chat/data/datasources/photo_compressor.dart';
import 'package:chatix/features/chat/domain/entities/attachment_entity.dart';
import 'package:chatix/features/chat/presentation/providers/local_media_provider.dart';
import 'package:chatix/features/chat/presentation/screens/media_preview_screen.dart';
import 'package:chatix/gen/l10n/app_localizations.dart';

import '../../../../helpers/chat_golden.dart';
import '../../../../helpers/fakes/fake_photo_compressor.dart';
import '../../../../helpers/pane_frame.dart';
import '../../../../helpers/test_photos.dart';

/// Opens the preview the way the composer does — pushed, and answered with
/// whatever it pops.
class _Preview {
  _Preview(this.tester, {FakePhotoCompressor? compressor})
    : compressor = compressor ?? FakePhotoCompressor();

  final WidgetTester tester;
  final FakePhotoCompressor compressor;

  MediaPreviewResult? result;
  bool isClosed = false;

  Future<void> open({
    required List<AttachmentUploadRequestEntity> uploads,
    String? caption,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          // Shapes are measured off the device; in a test there are no files
          // to measure, and the layout has to hold up without them anyway.
          localMediaRatioProvider.overrideWith((ref, key) async => 1.4),
          photoCompressorProvider.overrideWithValue(compressor),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () async {
                    result = await Navigator.of(context)
                        .push<MediaPreviewResult>(
                          MaterialPageRoute(
                            builder: (_) => MediaPreviewScreen(
                              chatId: 'a3f1c2d4-0000-4000-8000-000000000001',
                              uploads: uploads,
                              initialCaption: caption,
                            ),
                          ),
                        );
                    isClosed = true;
                  },
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  Future<MediaPreviewResult?> closed() async {
    await tester.pumpAndSettle();
    expect(isClosed, isTrue, reason: 'the preview should have closed');
    return result;
  }
}

void main() {
  late AppLocalizations l10n;

  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('en'));
  });

  AttachmentUploadRequestEntity image(String name) =>
      AttachmentUploadRequestEntity(
        filename: name,
        mimeType: 'image/jpeg',
        fileSize: 2048,
        filePath: '/tmp/$name',
      );

  AttachmentUploadRequestEntity video(String name) =>
      AttachmentUploadRequestEntity(
        filename: name,
        mimeType: 'video/mp4',
        fileSize: 4096,
        filePath: '/tmp/$name',
      );

  Finder removeButtons() => find.byTooltip(l10n.mediaPreviewRemove);

  testWidgets('every staged file is on screen with a way off it', (
    tester,
  ) async {
    final preview = _Preview(tester);
    await preview.open(
      uploads: [image('a.jpg'), image('b.jpg'), image('c.jpg')],
    );

    expect(removeButtons(), findsNWidgets(3));
  });

  testWidgets('dropping one leaves the rest staged', (tester) async {
    final preview = _Preview(tester);
    await preview.open(
      uploads: [image('a.jpg'), image('b.jpg'), image('c.jpg')],
    );

    await tester.tap(removeButtons().first);
    await tester.pumpAndSettle();

    expect(removeButtons(), findsNWidgets(2));
  });

  testWidgets('sending answers with what is left and the caption', (
    tester,
  ) async {
    final preview = _Preview(tester);
    await preview.open(uploads: [image('a.jpg'), image('b.jpg')]);

    await tester.tap(removeButtons().first);
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '  the whole trip  ');
    await tester.tap(find.byIcon(Icons.send_rounded));

    final result = await preview.closed();

    expect(result, isNotNull);
    expect(result!.uploads, hasLength(1));
    expect(result.caption, 'the whole trip');
    expect(result.asFiles, isFalse);
  });

  testWidgets('a caption typed in the composer arrives already in the box', (
    tester,
  ) async {
    final preview = _Preview(tester);
    await preview.open(uploads: [image('a.jpg')], caption: 'from the composer');

    expect(find.text('from the composer'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.send_rounded));

    expect((await preview.closed())!.caption, 'from the composer');
  });

  testWidgets('an album with no caption sends none', (tester) async {
    final preview = _Preview(tester);
    await preview.open(uploads: [image('a.jpg')]);

    await tester.tap(find.byIcon(Icons.send_rounded));
    final result = await preview.closed();

    expect(result!.caption, isNull);
    expect(result.uploads, hasLength(1));
  });

  testWidgets('dropping the last one closes the screen with nothing', (
    tester,
  ) async {
    final preview = _Preview(tester);
    await preview.open(uploads: [image('a.jpg')]);

    await tester.tap(removeButtons());

    expect(await preview.closed(), isNull);
  });

  group('compression', () {
    testWidgets('photos go out compressed by default, videos as they are', (
      tester,
    ) async {
      final preview = _Preview(tester);
      await preview.open(uploads: [image('a.jpg'), video('b.mp4')]);

      expect(find.text(l10n.mediaPreviewCompress), findsOneWidget);
      await tester.tap(find.byIcon(Icons.send_rounded));
      final sent = (await preview.closed())!.uploads;

      expect(sent.first.filePath, '/tmp/a.jpg.compressed.jpg');
      expect(sent.first.fileSize, 204);
      expect(sent.last, video('b.mp4'));
    });

    testWidgets('switched off, the photos go as taken', (tester) async {
      final preview = _Preview(tester);
      await preview.open(uploads: [image('a.jpg')]);

      await tester.tap(find.byType(Switch));
      await tester.pump();
      expect(find.text(l10n.mediaPreviewCompressOffHint), findsOneWidget);

      await tester.tap(find.byIcon(Icons.send_rounded));

      expect((await preview.closed())!.uploads, [image('a.jpg')]);
    });

    testWidgets('a ring on each photo while it is being compressed', (
      tester,
    ) async {
      final preview = _Preview(
        tester,
        compressor: FakePhotoCompressor(hold: true),
      );
      await preview.open(uploads: [image('a.jpg'), image('b.jpg')]);

      // The first is at 40 %, the second waits its turn.
      expect(find.byType(TransferProgressRing), findsNWidgets(2));
      expect(find.text('40%'), findsOneWidget);

      preview.compressor.releaseAll();
      await tester.pumpAndSettle();
      preview.compressor.releaseAll();
      await tester.pumpAndSettle();

      expect(find.byType(TransferProgressRing), findsNothing);
    });

    testWidgets('send waits for a photo still being compressed', (
      tester,
    ) async {
      final preview = _Preview(
        tester,
        compressor: FakePhotoCompressor(hold: true),
      );
      await preview.open(uploads: [image('a.jpg')]);

      await tester.tap(find.byIcon(Icons.send_rounded));
      await tester.pump();

      expect(preview.isClosed, isFalse);
      // The send button says it is waiting.
      expect(
        find.descendant(
          of: find.byType(FilledButton),
          matching: find.byType(CircularProgressIndicator),
        ),
        findsOneWidget,
      );

      preview.compressor.releaseAll();
      final sent = (await preview.closed())!.uploads;

      expect(sent.single.mimeType, 'image/jpeg');
      expect(sent.single.fileSize, 204);
    });

    testWidgets('nothing to compress, no switch', (tester) async {
      final preview = _Preview(tester);
      await preview.open(uploads: [video('a.mp4')]);

      expect(find.text(l10n.mediaPreviewCompress), findsNothing);
    });
  });

  testWidgets('"Send as file" sends every pick untouched, as files', (
    tester,
  ) async {
    final preview = _Preview(tester);
    await preview.open(
      uploads: [image('a.jpg'), video('b.mp4')],
      caption: 'originals',
    );

    await tester.tap(find.byIcon(Icons.more_vert_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.mediaPreviewSendAsFile));

    final result = (await preview.closed())!;

    expect(result.asFiles, isTrue);
    expect(result.caption, 'originals');
    expect(
      [for (final u in result.uploads) u.filePath],
      ['/tmp/a.jpg', '/tmp/b.mp4'],
    );
    expect(
      result.uploads.map((u) => u.attachmentType),
      everyElement(AttachmentType.file),
    );
  });

  group('goldens', () {
    late Directory dir;
    late List<AttachmentUploadRequestEntity> album;

    setUpAll(() {
      dir = Directory.systemTemp.createTempSync('chatix_preview_');
      album = [
        for (final (index, (w, h)) in [
          (1200, 800),
          (800, 1200),
          (1000, 1000),
        ].indexed)
          () {
            final file = TestPhotos.write(
              dir,
              name: 'p$index',
              width: w ~/ 10,
              height: h ~/ 10,
              palette: index,
            );
            return AttachmentUploadRequestEntity(
              filename: 'IMG_000$index.jpg',
              mimeType: 'image/jpeg',
              fileSize: 3400000 + index * 250000,
              filePath: file.path,
            );
          }(),
      ];
    });

    tearDownAll(() => dir.deleteSync(recursive: true));

    Future<void> loadPictures(WidgetTester tester) async {
      bool blank() => find
          .byType(RawImage, skipOffstage: false)
          .evaluate()
          .any((element) => (element.widget as RawImage).image == null);

      for (var round = 0; blank(); round++) {
        if (round == 200) fail('photos never finished decoding');
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
        await tester.pump();
      }
    }

    for (final window in [PaneWindow.phone, PaneWindow.desktop]) {
      for (final theme in chatGoldenThemes.entries) {
        testGoldens('compressing, ${window.name}, ${theme.key}', (
          tester,
        ) async {
          final ratios = {
            for (final (index, upload) in album.indexed)
              upload.filePath: [1.5, 0.66, 1.0][index],
          };

          await tester.pumpWidgetBuilder(
            ProviderScope(
              overrides: [
                localMediaRatioProvider.overrideWith(
                  (ref, key) async => ratios[key.path],
                ),
                photoCompressorProvider.overrideWithValue(
                  FakePhotoCompressor(hold: true, holdAt: 0.62),
                ),
              ],
              child: MaterialApp(
                debugShowCheckedModeBanner: false,
                theme: chatGoldenTheme(dark: theme.value),
                locale: const Locale('ru'),
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                home: PaneFrame(
                  window: window,
                  child: MediaPreviewScreen(
                    chatId: 'a3f1c2d4-0000-4000-8000-000000000001',
                    uploads: album,
                    initialCaption: 'Выходные на озере',
                  ),
                ),
              ),
            ),
            wrapper: (child) => child,
            surfaceSize: window.size,
          );
          addTearDown(() => tester.binding.setSurfaceSize(null));
          await tester.pumpAndSettle();
          await loadPictures(tester);

          await screenMatchesGolden(
            tester,
            'media_preview_compressing_${window.name}_${theme.key}',
            customPump: (tester) => tester.pump(),
          );
        });
      }
    }
  });
}
