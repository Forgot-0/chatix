import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chatix/core/constants/app_constants.dart';
import 'package:chatix/core/theme/app_theme.dart';
import 'package:chatix/core/ui/feedback/transfer_progress_ring.dart';
import 'package:chatix/core/websocket/chat_socket_service.dart';
import 'package:chatix/features/chat/domain/entities/attachment_entity.dart';
import 'package:chatix/features/chat/presentation/providers/chat_socket_provider.dart';
import 'package:chatix/features/chat/presentation/utils/album_layout.dart';
import 'package:chatix/features/chat/presentation/widgets/album_mosaic.dart';
import 'package:chatix/features/chat/presentation/widgets/document_attachment_row.dart';
import 'package:chatix/features/chat/presentation/widgets/message_album.dart';
import 'package:chatix/features/chat/presentation/widgets/message_attachments.dart';
import 'package:chatix/gen/l10n/app_localizations.dart';

import '../../../../helpers/fakes/fake_secure_storage_service.dart';
import '../../../../helpers/fakes/fake_web_socket_channel.dart';

void main() {
  const chatId = 'a3f1c2d4-0000-4000-8000-000000000001';
  const messageId = 'b3f1c2d4-0000-4000-8000-000000000002';

  late AppLocalizations l10n;
  late ChatSocketService socket;

  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('en'));
  });

  setUp(() {
    socket = ChatSocketService(
      secureStorage: FakeSecureStorageService(
        initialValues: {AppConstants.accessTokenKey: 'token'},
      ),
      channelFactory: (_) => FakeWebSocketChannel(),
    );
  });

  AttachmentEntity attachment({
    String id = 'c1',
    AttachmentType type = AttachmentType.image,
    AttachmentStatus status = AttachmentStatus.success,
    String filename = 'holiday.jpg',
    int? width = 1200,
    int? height = 800,
  }) => AttachmentEntity(
    id: id,
    messageId: messageId,
    chatId: chatId,
    uploaderId: 7,
    attachmentType: type,
    attachmentStatus: status,
    url: null,
    urlExpiresIn: null,
    s3Key: 'chats/$chatId/$id/$filename',
    mimeType: type == AttachmentType.image ? 'image/jpeg' : 'application/pdf',
    originalFilename: filename,
    size: 2048,
    width: width,
    height: height,
    durationSeconds: null,
    createdAt: DateTime(2026, 3, 1),
  );

  Future<void> pump(
    WidgetTester tester,
    List<AttachmentEntity> attachments, {
    VoidCallback? onRetry,
    bool openable = true,
    bool dark = false,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [chatSocketServiceProvider.overrideWithValue(socket)],
        child: MaterialApp(
          theme: dark ? AppTheme.darkTheme : AppTheme.lightTheme,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 280,
                child: MessageAttachments(
                  messageId: messageId,
                  attachments: attachments,
                  foreground: const Color(0xFF111111),
                  onOpen: openable ? (_) {} : null,
                  onRetry: onRetry,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  group('albums', () {
    testWidgets('several photos are one mosaic, not a column', (tester) async {
      await pump(tester, [
        attachment(id: 'a'),
        attachment(id: 'b', width: 800, height: 1200),
        attachment(id: 'c'),
      ]);

      expect(find.byType(AlbumMosaic), findsOneWidget);

      final mosaic = tester.widget<AlbumMosaic>(find.byType(AlbumMosaic));
      final layout = AlbumLayout.of(mosaic.ratios);

      expect(mosaic.ratios, [1200 / 800, 800 / 1200, 1200 / 800]);
      expect(layout.tiles, hasLength(3));
      // Three photos share rows and columns — none of them is alone on a
      // line of its own the way a stacked column would be.
      expect(layout.tiles.where((tile) => tile.width == 1), hasLength(1));
    });

    testWidgets('a lone photo still goes through the same layout', (
      tester,
    ) async {
      await pump(tester, [attachment()]);

      final mosaic = tester.widget<AlbumMosaic>(find.byType(AlbumMosaic));
      expect(mosaic.ratios, hasLength(1));
    });

    testWidgets('every photo gets a Hero, so the viewer can carry it', (
      tester,
    ) async {
      await pump(tester, [attachment(id: 'a'), attachment(id: 'b')]);

      expect(find.byType(Hero), findsNWidgets(2));
      expect(
        tester.widgetList<Hero>(find.byType(Hero)).map((hero) => hero.tag),
        [attachmentHeroTag('a'), attachmentHeroTag('b')],
      );
    });

    testWidgets('a tile that cannot be opened carries no Hero, so the '
        'context menu\'s copy of the bubble cannot fly it away', (
      tester,
    ) async {
      await pump(tester, [attachment(id: 'a')], openable: false);

      expect(find.byType(Hero), findsNothing);
    });

    testWidgets('a slot still being validated shows a ring and no Hero', (
      tester,
    ) async {
      await pump(tester, [
        attachment(id: 'a', status: AttachmentStatus.pending),
      ]);

      final ring = tester.widget<TransferProgressRing>(
        find.byType(TransferProgressRing),
      );
      expect(ring.state, TransferRingState.waiting);
      expect(find.byType(Hero), findsNothing);
    });

    testWidgets('a failed slot says so neutrally and offers to try again', (
      tester,
    ) async {
      var retried = 0;
      await pump(
        tester,
        [attachment(id: 'a', status: AttachmentStatus.error)],
        onRetry: () => retried++,
      );

      expect(find.text(l10n.attachmentFailed), findsOneWidget);

      await tester.tap(find.byType(TransferProgressRing));
      await tester.pump();

      expect(retried, 1);
    });

    testWidgets('an attachment the socket has just confirmed is ready even '
        'though the message still says pending', (tester) async {
      await pump(tester, [
        attachment(id: 'a', status: AttachmentStatus.pending),
      ]);
      expect(find.byType(TransferProgressRing), findsOneWidget);

      // `attachment_success` carries the upload tokens, which are the
      // attachment ids (api-docs §5.5).
      final container = ProviderScope.containerOf(
        tester.element(find.byType(MessageAttachments)),
      );
      container.read(confirmedAttachmentTokensProvider.notifier).state = {'a'};
      await tester.pump();

      expect(find.byType(TransferProgressRing), findsNothing);
      expect(find.byType(Hero), findsOneWidget);
    });
  });

  group('documents', () {
    testWidgets('a document is a row with its kind, name and size', (
      tester,
    ) async {
      await pump(tester, [
        attachment(id: 'd', type: AttachmentType.file, filename: 'report.pdf'),
      ]);

      expect(find.byType(DocumentAttachmentRow), findsOneWidget);
      expect(find.text('report.pdf'), findsOneWidget);
      expect(find.text('PDF · 2 KB'), findsOneWidget);
      expect(find.text(l10n.attachmentOpen), findsOneWidget);
      expect(find.text(l10n.save), findsOneWidget);
    });

    testWidgets('a document still being validated cannot be opened yet', (
      tester,
    ) async {
      await pump(tester, [
        attachment(
          id: 'd',
          type: AttachmentType.file,
          filename: 'report.pdf',
          status: AttachmentStatus.pending,
        ),
      ]);

      expect(find.text(l10n.attachmentProcessing), findsOneWidget);
      expect(find.text(l10n.attachmentOpen), findsNothing);
      expect(find.text(l10n.save), findsNothing);
    });

    testWidgets('a failed document offers to try again', (tester) async {
      var retried = 0;
      await pump(
        tester,
        [
          attachment(
            id: 'd',
            type: AttachmentType.file,
            filename: 'report.pdf',
            status: AttachmentStatus.error,
          ),
        ],
        onRetry: () => retried++,
      );

      expect(find.text(l10n.attachmentFailed), findsOneWidget);

      await tester.tap(find.byType(TransferProgressRing));
      await tester.pump();

      expect(retried, 1);
    });
  });

  group('voice and video notes', () {
    testWidgets('one still being validated says so rather than drawing an '
        'empty bubble', (tester) async {
      await pump(tester, [
        attachment(
          id: 'v',
          type: AttachmentType.voice,
          filename: 'note.m4a',
          status: AttachmentStatus.pending,
        ),
      ]);

      expect(find.text(l10n.attachmentProcessing), findsOneWidget);
    });

    testWidgets('a failed one offers to try again', (tester) async {
      var retried = 0;
      await pump(
        tester,
        [
          attachment(
            id: 'v',
            type: AttachmentType.videoNote,
            filename: 'note.mp4',
            status: AttachmentStatus.error,
          ),
        ],
        onRetry: () => retried++,
      );

      expect(find.text(l10n.attachmentFailed), findsOneWidget);
      await tester.tap(find.byType(TransferProgressRing));
      await tester.pump();

      expect(retried, 1);
    });
  });

  group('document kinds', () {
    test('the glyph follows the extension', () {
      expect(DocumentKind.of('a.pdf'), DocumentKind.pdf);
      expect(DocumentKind.of('a.ZIP'), DocumentKind.archive);
      expect(DocumentKind.of('a.docx'), DocumentKind.document);
      expect(DocumentKind.of('a.xlsx'), DocumentKind.spreadsheet);
      expect(DocumentKind.of('a.csv'), DocumentKind.spreadsheet);
      expect(DocumentKind.of('a.txt'), DocumentKind.text);
    });

    test('anything else is just a file', () {
      expect(DocumentKind.of('a.bin'), DocumentKind.other);
      expect(DocumentKind.of('noextension'), DocumentKind.other);
      expect(DocumentKind.of('.hidden'), DocumentKind.other);
      expect(DocumentKind.of('trailing.'), DocumentKind.other);
    });
  });
}
