import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';

import 'package:chatix/features/chat/data/datasources/recent_media_source.dart';
import 'package:chatix/features/chat/domain/entities/attachment_entity.dart';
import 'package:chatix/features/chat/domain/entities/chat_attachment_limits.dart';
import 'package:chatix/features/chat/presentation/widgets/composer/composer_attachment_sheet.dart';
import 'package:chatix/gen/l10n/app_localizations.dart';

import '../../../../../helpers/chat_golden.dart';

/// A gallery that answers from a list instead of a device.
class FakeRecentMediaSource implements RecentMediaSource {
  FakeRecentMediaSource({
    this.state = RecentMediaAccess.granted,
    this.count = 30,
    this.readable = true,
  });

  RecentMediaAccess state;
  final int count;

  /// False stands for a photo deleted between the strip being drawn and it
  /// being tapped.
  final bool readable;

  int accessCalls = 0;

  @override
  Future<RecentMediaAccess> access() async {
    accessCalls++;
    return state;
  }

  @override
  Future<List<RecentMediaItem>> recent({int limit = 24}) async => [
    for (var i = 0; i < (count < limit ? count : limit); i++)
      RecentMediaItem(
        id: 'photo-$i',
        isVideo: i.isEven,
        duration: Duration(seconds: i),
      ),
  ];

  @override
  Future<Uint8List?> thumbnail(String id, {int size = 256}) async => null;

  @override
  Future<AttachmentUploadRequestEntity?> upload(String id) async => readable
      ? AttachmentUploadRequestEntity(
          filename: '$id.jpg',
          mimeType: 'image/jpeg',
          fileSize: 1024,
          filePath: '/tmp/$id.jpg',
        )
      : null;
}

/// The composer's own panel: the last few photos inline, and the routes to
/// everything else. The limits from api-docs §5.5 are enforced here rather
/// than left to come back as `ATTACHMENT_LIMIT_EXCEEDED`.
void main() {
  late FakeRecentMediaSource source;
  ComposerAttachmentResult? result;

  setUp(() {
    source = FakeRecentMediaSource();
    result = null;
  });

  /// Wide and tall enough that the whole sheet is built at once: the strip
  /// and the list are both lazy, and a row nobody scrolled to is not a row
  /// that is missing.
  void roomy(WidgetTester tester) {
    tester.view.physicalSize = const Size(2400, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  Future<void> open(WidgetTester tester) async {
    roomy(tester);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [recentMediaSourceProvider.overrideWithValue(source)],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async =>
                    result = await ComposerAttachmentSheet.show(context),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  group('what it offers', () {
    testWidgets('the documented routes, and no more', (tester) async {
      await open(tester);

      expect(find.text('Photos & videos'), findsOneWidget);
      expect(find.text('Camera'), findsOneWidget);
      expect(find.text('Document'), findsOneWidget);
      expect(find.text('Voice message'), findsOneWidget);
      expect(find.text('Video note'), findsOneWidget);
    });

    testWidgets('nothing about location — the API carries no place', (
      tester,
    ) async {
      await open(tester);

      expect(find.byIcon(Icons.location_on_outlined), findsNothing);
      expect(find.byIcon(Icons.place_outlined), findsNothing);
      expect(find.textContaining('ocation'), findsNothing);
    });

    testWidgets('the exclusive types say they travel alone', (tester) async {
      await open(tester);

      expect(find.text('Sent on its own, up to 600 s'), findsOneWidget);
      expect(
        find.text('Sent on its own, up to 60 s and 640 px'),
        findsOneWidget,
      );
    });
  });

  group('the recent strip', () {
    testWidgets('shows what the gallery has', (tester) async {
      await open(tester);

      expect(find.text('Recent'), findsOneWidget);
      expect(find.byType(RecentMediaTile), findsWidgets);
    });

    testWidgets('a refused grant explains itself and offers to ask again', (
      tester,
    ) async {
      source.state = RecentMediaAccess.denied;
      await open(tester);

      expect(find.text('Allow photo access to pick from here'), findsOneWidget);
      expect(find.byType(RecentMediaTile), findsNothing);

      source.state = RecentMediaAccess.granted;
      await tester.tap(find.text('Allow'));
      await tester.pumpAndSettle();

      expect(find.byType(RecentMediaTile), findsWidgets);
    });

    testWidgets('a refusal is not re-asked every time the sheet opens', (
      tester,
    ) async {
      source.state = RecentMediaAccess.denied;
      await open(tester);
      expect(source.accessCalls, 1);

      // Closing and reopening asks nothing: the system prompt only comes
      // back when the reader taps the line that offers it.
      await tester.tapAt(const Offset(20, 20));
      await tester.pumpAndSettle();
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(source.accessCalls, 1);
    });

    testWidgets('a platform with no gallery gets no strip and no excuse', (
      tester,
    ) async {
      source.state = RecentMediaAccess.unsupported;
      await open(tester);

      expect(find.text('Recent'), findsNothing);
      expect(find.text('Allow photo access to pick from here'), findsNothing);
      // The rows are still the whole point of the sheet.
      expect(find.text('Camera'), findsOneWidget);
    });
  });

  group('picking', () {
    /// The strip is lazy and only a handful of tiles fit, so anything past
    /// the fold has to be brought into view first — a tap aimed at a tile
    /// that is off screen lands on the sheet's barrier and closes it.
    Future<void> tapTile(WidgetTester tester, int index) async {
      final tile = find.byKey(ValueKey('photo-$index'));

      if (tile.evaluate().isEmpty) {
        await tester.scrollUntilVisible(
          tile,
          120,
          scrollable: find
              .descendant(
                of: find.byType(RecentMediaStrip),
                matching: find.byType(Scrollable),
              )
              .first,
        );
      }

      await tester.ensureVisible(tile);
      await tester.pumpAndSettle();

      await tester.tap(tile);
      await tester.pumpAndSettle();
    }

    testWidgets('a tap stages it and the button counts', (tester) async {
      await open(tester);

      await tapTile(tester, 0);
      expect(find.text('Attach 1'), findsOneWidget);

      await tapTile(tester, 1);
      expect(find.text('Attach 2'), findsOneWidget);
    });

    testWidgets('tapping again takes it back off', (tester) async {
      await open(tester);

      await tapTile(tester, 0);
      await tapTile(tester, 0);

      // The sheet's own title is "Attach"; what should be gone is the
      // confirm button that counts what is picked.
      expect(find.byType(FilledButton), findsNothing);
    });

    testWidgets('the tenth is the last — MAX_MEDIA_PER_MESSAGE', (
      tester,
    ) async {
      await open(tester);

      for (var i = 0; i < ChatAttachmentLimits.maxMediaCount; i++) {
        await tapTile(tester, i);
      }
      expect(find.text('Attach 10'), findsOneWidget);

      await tapTile(tester, ChatAttachmentLimits.maxMediaCount);

      expect(find.text('Attach 10'), findsOneWidget);
      expect(
        find.text('Up to 10 photos or videos per message'),
        findsOneWidget,
      );
    });

    testWidgets('confirming hands the files back', (tester) async {
      await open(tester);

      await tapTile(tester, 0);
      await tester.tap(find.text('Attach 1'));
      await tester.pumpAndSettle();

      expect(result?.kind, ComposerAttachmentKind.uploads);
      expect(result?.uploads, hasLength(1));
      expect(result?.uploads.single.mimeType, 'image/jpeg');
    });

    testWidgets('a photo that has gone says so rather than sending nothing', (
      tester,
    ) async {
      source = FakeRecentMediaSource(readable: false);
      await open(tester);

      await tapTile(tester, 0);
      await tester.tap(find.text('Attach 1'));
      await tester.pumpAndSettle();

      expect(find.text('That file could not be read'), findsOneWidget);
      expect(result, isNull);
    });
  });

  group('the rows that record', () {
    testWidgets('voice asks the composer to start recording', (tester) async {
      await open(tester);

      await tester.tap(find.text('Voice message'));
      await tester.pumpAndSettle();

      expect(result?.kind, ComposerAttachmentKind.recordVoice);
      expect(result?.uploads, isEmpty);
    });

    testWidgets('video note asks for a capture', (tester) async {
      await open(tester);

      await tester.tap(find.text('Video note'));
      await tester.pumpAndSettle();

      expect(result?.kind, ComposerAttachmentKind.recordVideoNote);
    });
  });

  group('goldens', () {
    for (final entry in chatGoldenThemes.entries) {
      testGoldens('the attachment sheet on the ${entry.key} theme', (
        tester,
      ) async {
        await tester.pumpWidgetBuilder(
          ProviderScope(
            overrides: [recentMediaSourceProvider.overrideWithValue(source)],
            child: const Align(
              alignment: Alignment.bottomCenter,
              // Stands in for the modal sheet's own surface, which the
              // widget deliberately does not draw itself.
              child: Material(
                clipBehavior: Clip.antiAlias,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: ComposerAttachmentSheet(),
              ),
            ),
          ),
          wrapper: materialAppWrapper(
            theme: chatGoldenTheme(dark: entry.value),
            localizations: AppLocalizations.localizationsDelegates,
          ),
          surfaceSize: const Size(380, 620),
        );
        await tester.pumpAndSettle();

        await screenMatchesGolden(tester, 'attachment_sheet_${entry.key}');
      });
    }
  });
}
