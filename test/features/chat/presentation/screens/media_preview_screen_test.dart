import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chatix/features/chat/domain/entities/attachment_entity.dart';
import 'package:chatix/features/chat/presentation/providers/local_media_provider.dart';
import 'package:chatix/features/chat/presentation/screens/media_preview_screen.dart';
import 'package:chatix/gen/l10n/app_localizations.dart';

/// Opens the preview the way the composer does — pushed, and answered with
/// whatever it pops.
class _Preview {
  _Preview(this.tester);

  final WidgetTester tester;

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
  });

  testWidgets('a caption typed in the composer arrives already in the box', (
    tester,
  ) async {
    final preview = _Preview(tester);
    await preview.open(
      uploads: [image('a.jpg')],
      caption: 'from the composer',
    );

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
}
