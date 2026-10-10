import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

import 'package:chatix/core/constants/app_constants.dart';
import 'package:chatix/core/error/failures.dart';
import 'package:chatix/core/network/transfer_cancellation.dart';
import 'package:chatix/core/theme/app_theme.dart';
import 'package:chatix/core/ui/feedback/transfer_progress_ring.dart';
import 'package:chatix/core/websocket/chat_socket_service.dart';
import 'package:chatix/features/chat/domain/entities/attachment_entity.dart';
import 'package:chatix/features/chat/domain/usecases/get_attachment_file_use_case.dart';
import 'package:chatix/features/chat/presentation/providers/attachment_file_provider.dart';
import 'package:chatix/features/chat/presentation/providers/chat_providers.dart';
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
    registerFallbackValue(
      AttachmentEntity(
        id: 'fallback',
        messageId: messageId,
        chatId: chatId,
        uploaderId: 0,
        attachmentType: AttachmentType.file,
        attachmentStatus: AttachmentStatus.success,
        url: null,
        urlExpiresIn: null,
        s3Key: '',
        mimeType: '',
        originalFilename: '',
        size: 0,
        width: null,
        height: null,
        durationSeconds: null,
        createdAt: DateTime(2026),
      ),
    );
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
    Map<String, File> cached = const {},
    GetAttachmentFileUseCase? getFile,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          chatSocketServiceProvider.overrideWithValue(socket),
          // What is on this device is what the cache answers; nothing here
          // is allowed to fetch by itself.
          autoAttachmentFileProvider.overrideWith(
            (ref, key) async => cached[key.attachment.id],
          ),
          if (getFile != null)
            getAttachmentFileUseCaseProvider.overrideWithValue(getFile),
        ],
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
      await pump(tester, [
        attachment(id: 'a', status: AttachmentStatus.error),
      ], onRetry: () => retried++);

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
    Finder icon(IconData data) => find.byIcon(data);

    testWidgets('a document is a round button, its name and its size', (
      tester,
    ) async {
      await pump(tester, [
        attachment(id: 'd', type: AttachmentType.file, filename: 'report.pdf'),
      ]);

      expect(find.byType(DocumentAttachmentRow), findsOneWidget);
      expect(find.text('report.pdf'), findsOneWidget);
      // Size first, then the kind — "2.0 MB · PDF" — in the reader's units.
      expect(find.text('2 KB · PDF'), findsOneWidget);
      // Not on this device yet: the button says a tap downloads it.
      expect(icon(Icons.arrow_downward_rounded), findsOneWidget);
      // Save, share and show-in-folder moved to the message's menu.
      expect(find.text(l10n.attachmentOpen), findsNothing);
      expect(find.text(l10n.save), findsNothing);
    });

    testWidgets('a document still being validated cannot be tapped yet', (
      tester,
    ) async {
      final getFile = _MockGetAttachmentFile();
      await pump(tester, [
        attachment(
          id: 'd',
          type: AttachmentType.file,
          filename: 'report.pdf',
          status: AttachmentStatus.pending,
        ),
      ], getFile: getFile);

      expect(find.text(l10n.attachmentProcessing), findsOneWidget);
      await tester.tap(find.text('report.pdf'));
      await tester.pump();

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

    testWidgets('a failed document offers to try again', (tester) async {
      var retried = 0;
      await pump(tester, [
        attachment(
          id: 'd',
          type: AttachmentType.file,
          filename: 'report.pdf',
          status: AttachmentStatus.error,
        ),
      ], onRetry: () => retried++);

      expect(find.text(l10n.attachmentFailed), findsOneWidget);
      expect(icon(Icons.refresh_rounded), findsOneWidget);

      await tester.tap(find.text('report.pdf'));
      await tester.pump();

      expect(retried, 1);
    });

    testWidgets('a tap downloads it, the ring counts, and it ends up as its '
        'kind', (tester) async {
      final getFile = _MockGetAttachmentFile();
      final done = Completer<Either<Failure, File>>();
      late void Function(int, int) progress;
      when(
        () => getFile.execute(
          chatId: any(named: 'chatId'),
          messageId: any(named: 'messageId'),
          attachment: any(named: 'attachment'),
          onProgress: any(named: 'onProgress'),
          cancellation: any(named: 'cancellation'),
        ),
      ).thenAnswer((invocation) {
        progress =
            invocation.namedArguments[#onProgress] as void Function(int, int);
        return done.future;
      });

      await pump(tester, [
        attachment(id: 'd', type: AttachmentType.file, filename: 'report.pdf'),
      ], getFile: getFile);

      await tester.tap(find.text('report.pdf'));
      await tester.pump();
      expect(icon(Icons.close_rounded), findsOneWidget);

      progress(1024, 2048);
      await tester.pump();
      expect(find.text('1 KB / 2 KB'), findsOneWidget);
      expect(
        tester
            .widget<CircularProgressIndicator>(
              find.byType(CircularProgressIndicator),
            )
            .value,
        0.5,
      );

      done.complete(Right(File('report.pdf')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(icon(Icons.picture_as_pdf_rounded), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('2 KB · PDF'), findsOneWidget);
    });

    testWidgets('a tap while it downloads stops it', (tester) async {
      final getFile = _MockGetAttachmentFile();
      late TransferCancellation cancellation;
      when(
        () => getFile.execute(
          chatId: any(named: 'chatId'),
          messageId: any(named: 'messageId'),
          attachment: any(named: 'attachment'),
          onProgress: any(named: 'onProgress'),
          cancellation: any(named: 'cancellation'),
        ),
      ).thenAnswer((invocation) {
        cancellation =
            invocation.namedArguments[#cancellation] as TransferCancellation;
        return Completer<Either<Failure, File>>().future;
      });

      await pump(tester, [
        attachment(id: 'd', type: AttachmentType.file, filename: 'report.pdf'),
      ], getFile: getFile);

      await tester.tap(find.text('report.pdf'));
      await tester.pump();
      await tester.tap(find.text('report.pdf'));
      await tester.pump(const Duration(milliseconds: 200));

      expect(cancellation.isCancelled, isTrue);
      expect(icon(Icons.arrow_downward_rounded), findsOneWidget);
    });

    testWidgets('one already on this device shows its kind, ready to open', (
      tester,
    ) async {
      await pump(
        tester,
        [
          attachment(
            id: 'd',
            type: AttachmentType.file,
            filename: 'budget.xlsx',
          ),
        ],
        cached: {'d': File('budget.xlsx')},
      );
      // The cache answers a frame later, and the glyph cross-fades in.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(icon(Icons.table_chart_rounded), findsOneWidget);
      expect(icon(Icons.arrow_downward_rounded), findsNothing);
    });

    testWidgets('a long name is cut in the middle, keeping its extension', (
      tester,
    ) async {
      const name =
          'Маршрут_поездки_по_Кавказу_с_ночёвками_у_озёр_и_на_перевале_'
          'Бечо_март_2026.pdf';
      await pump(tester, [
        attachment(id: 'd', type: AttachmentType.file, filename: name),
      ]);

      final shown = tester
          .widget<Text>(
            find.descendant(
              of: find.byType(DocumentAttachmentRow),
              matching: find.textContaining('…'),
            ),
          )
          .data!;
      expect(shown, startsWith('Маршрут_'));
      expect(shown, endsWith('2026.pdf'));
      expect(shown.length, lessThan(name.length));
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
      await pump(tester, [
        attachment(
          id: 'v',
          type: AttachmentType.videoNote,
          filename: 'note.mp4',
          status: AttachmentStatus.error,
        ),
      ], onRetry: () => retried++);

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

class _MockGetAttachmentFile extends Mock implements GetAttachmentFileUseCase {}
