import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chatix/core/constants/app_constants.dart';
import 'package:chatix/core/localization/app_date_format.dart';
import 'package:chatix/core/theme/app_tokens.dart';
import 'package:chatix/core/theme/theme_config.dart';
import 'package:chatix/core/websocket/chat_socket_service.dart';
import 'package:chatix/features/chat/domain/entities/attachment_entity.dart';
import 'package:chatix/features/chat/domain/entities/chat_profile_entity.dart';
import 'package:chatix/features/chat/domain/entities/message_entity.dart';
import 'package:chatix/features/chat/presentation/providers/attachment_download_provider.dart';
import 'package:chatix/features/chat/presentation/providers/attachment_file_provider.dart';
import 'package:chatix/features/chat/presentation/providers/chat_socket_provider.dart';
import 'package:chatix/features/chat/presentation/widgets/chat_date_separator.dart';
import 'package:chatix/features/chat/presentation/widgets/chat_feed_metrics.dart';
import 'package:chatix/features/chat/presentation/widgets/chat_wallpaper.dart';
import 'package:chatix/features/chat/presentation/widgets/message_bubble.dart';
import 'package:chatix/features/chat/presentation/widgets/status_ticks.dart';
import 'package:chatix/gen/l10n/app_localizations.dart';

import '../../../../helpers/chat_golden.dart';
import '../../../../helpers/fakes/fake_secure_storage_service.dart';
import '../../../../helpers/fakes/fake_web_socket_channel.dart';
import '../../../../helpers/pane_frame.dart';
import '../../../../helpers/test_photos.dart';

/// Every shape a bubble takes since the time moved onto the last line — in
/// Russian, on the wallpaper, in a phone window and in the two-pane desktop
/// window, on both themes and at both densities that stress the layout.
///
/// Four pages per frame, because one phone screen does not hold them all:
/// text (short and long, theirs and mine), replies (a run, quotes with and
/// without their picture, a forward, edits), photos with captions, and
/// documents in each of their states.
void main() {
  const chatId = '7d1c0b9a-2c4e-4f0a-9b1e-3f5a6c7d8e9f';
  const me = 7;
  const ada = 42;

  late Directory filesDir;
  final files = <String, File>{};
  late ChatSocketService socket;

  // Pinned, so that "Вчера" and the year on the oldest chip read the same
  // whatever day the goldens are rendered on.
  final now = DateTime(2026, 10, 10, 12);
  final today = DateTime(now.year, now.month, now.day);
  DateTime todayAt(int hour, int minute) =>
      today.add(Duration(hours: hour, minutes: minute));
  final yesterday = today.subtract(const Duration(days: 1));
  // Another year, so the chip carries one: "2 марта 2025".
  final longAgo = DateTime(now.year - 1, 3, 2, 18, 5);

  setUpAll(() {
    filesDir = Directory.systemTemp.createTempSync('bubble_layout_matrix');
    files['photo-ada'] = TestPhotos.write(
      filesDir,
      name: 'photo-ada',
      width: 160,
      height: 110,
      palette: 2,
    );
    files['photo-me'] = TestPhotos.write(
      filesDir,
      name: 'photo-me',
      width: 120,
      height: 150,
      palette: 1,
    );
    files['quoted-photo'] = TestPhotos.write(
      filesDir,
      name: 'quoted-photo',
      width: 120,
      height: 120,
      palette: 4,
    );
    // A spreadsheet already on this device: its button shows its kind.
    files['doc-local'] = File('${filesDir.path}/smeta.xlsx')
      ..writeAsBytesSync(const [0]);
  });

  tearDownAll(() {
    if (filesDir.existsSync()) filesDir.deleteSync(recursive: true);
  });

  setUp(() {
    socket = ChatSocketService(
      secureStorage: FakeSecureStorageService(
        initialValues: {AppConstants.accessTokenKey: 'token'},
      ),
      channelFactory: (_) => FakeWebSocketChannel(),
    );
  });

  ChatProfileEntity profile(int userId) => ChatProfileEntity(
    userId: userId,
    username: userId == ada ? 'ada' : 'me',
    displayName: userId == ada ? 'Ада' : 'Я',
    avatarUrl: null,
    avatarS3Key: null,
  );

  AttachmentEntity attachment(
    String id, {
    required AttachmentType type,
    required String filename,
    int size = 2 * 1024 * 1024,
    int? width,
    int? height,
  }) => AttachmentEntity(
    id: id,
    messageId: 'm-$id',
    chatId: chatId,
    uploaderId: ada,
    attachmentType: type,
    attachmentStatus: AttachmentStatus.success,
    url: null,
    urlExpiresIn: null,
    s3Key: 'chats/$chatId/$id/$filename',
    mimeType: type == AttachmentType.image
        ? 'image/png'
        : 'application/octet-stream',
    originalFilename: filename,
    size: size,
    width: width,
    height: height,
    durationSeconds: null,
    createdAt: today,
  );

  var seq = 0;
  MessageEntity message({
    String? id,
    required int author,
    required DateTime at,
    String? content,
    bool isEdited = false,
    MessageEntity? replyTo,
    MessageEntity? forwardedFrom,
    List<AttachmentEntity> attachments = const [],
  }) {
    seq++;
    return MessageEntity(
      id: id ?? 'm$seq',
      chatId: chatId,
      seq: seq,
      authorId: author,
      type: MessageType.text,
      content: content,
      replyToId: replyTo?.id,
      forwardedFromChatId: forwardedFrom == null ? null : 'other',
      forwardedFromMessageId: forwardedFrom?.id,
      forwardedFromAuthorId: forwardedFrom?.authorId,
      isEdited: isEdited,
      createdAt: at,
      attachments: attachments,
      replyTo: replyTo,
      forwardedFrom: forwardedFrom,
      profile: profile(author),
    );
  }

  Widget bubble(
    MessageEntity message, {
    bool first = true,
    bool last = true,
    MessageDeliveryStatus status = MessageDeliveryStatus.read,
  }) {
    final mine = message.authorId == me;
    return MessageBubble(
      message: message,
      isMine: mine,
      isFirstInGroup: first,
      isLastInGroup: last,
      deliveryStatus: mine ? status : null,
      onShowDetails: () {},
      onOpenAttachment: (_) {},
    );
  }

  List<Widget> textPage() {
    return [
      ChatDateSeparator(date: longAgo),
      bubble(message(author: ada, at: longAgo, content: 'ок')),
      bubble(message(author: me, at: longAgo, content: 'Да')),
      ChatDateSeparator(date: yesterday.add(const Duration(hours: 21))),
      bubble(
        message(
          author: ada,
          at: yesterday.add(const Duration(hours: 21, minutes: 40)),
          content:
              'Посмотрела прогноз на выходные: в субботу ясно, в воскресенье '
              'к обеду дождь. Предлагаю выйти рано',
        ),
      ),
      bubble(
        message(
          author: me,
          at: yesterday.add(const Duration(hours: 21, minutes: 44)),
          content:
              'Согласен, тогда встречаемся у станции в 6:30 и берём '
              'с собой горелку и запасные батарейки для фонарей',
        ),
      ),
    ];
  }

  // One document caught mid-download, so the ring and its "1,2 / 2,0 МБ"
  // are in the matrix; every other one is whatever the cache says.
  const progressMessageId = 'm-doc-progress';
  AttachmentEntity progressDoc() => attachment(
    'doc-progress',
    type: AttachmentType.file,
    filename: 'Снаряжение.docx',
  );

  List<Widget> repliesPage() {
    final quotedPhoto = message(
      author: me,
      at: todayAt(9, 0),
      attachments: [
        attachment(
          'quoted-photo',
          type: AttachmentType.image,
          filename: 'pereval.png',
          width: 120,
          height: 120,
        ),
      ],
    );
    // A picture the reader's settings have not fetched: the quote shows
    // what it was rather than an empty square.
    final quotedMissing = message(
      author: ada,
      at: todayAt(9, 1),
      content: 'Вот маршрут',
      attachments: [
        attachment(
          'quoted-missing',
          type: AttachmentType.image,
          filename: 'map.png',
          width: 120,
          height: 120,
        ),
      ],
    );

    return [
      ChatDateSeparator(date: todayAt(9, 2)),
      bubble(
        message(author: ada, at: todayAt(9, 2), content: 'Кто берёт палатку?'),
        last: false,
      ),
      bubble(
        message(author: ada, at: todayAt(9, 3), content: 'И котелок'),
        first: false,
      ),
      bubble(
        message(
          author: ada,
          at: todayAt(9, 5),
          content: 'Шикарный вид!',
          replyTo: quotedPhoto,
        ),
      ),
      bubble(
        message(
          author: me,
          at: todayAt(9, 7),
          content: 'ок',
          replyTo: quotedMissing,
        ),
      ),
      bubble(
        message(
          author: me,
          at: todayAt(9, 8),
          content: 'Это тебе пригодится',
          forwardedFrom: message(author: ada, at: todayAt(8, 0)),
        ),
        status: MessageDeliveryStatus.sent,
      ),
      bubble(
        message(
          author: ada,
          at: todayAt(9, 12),
          content: 'Поправила время встречи',
          isEdited: true,
        ),
      ),
      bubble(
        message(
          author: me,
          at: todayAt(9, 14),
          content: 'Отлично',
          isEdited: true,
        ),
      ),
    ];
  }

  List<Widget> photosPage() => [
    ChatDateSeparator(date: todayAt(10, 0)),
    bubble(
      message(
        author: ada,
        at: todayAt(10, 0),
        content: 'Вид с перевала, утро',
        attachments: [
          attachment(
            'photo-ada',
            type: AttachmentType.image,
            filename: 'view.png',
            width: 160,
            height: 110,
          ),
        ],
      ),
    ),
    bubble(
      message(
        author: me,
        at: todayAt(10, 4),
        content: 'Красота',
        attachments: [
          attachment(
            'photo-me',
            type: AttachmentType.image,
            filename: 'me.png',
            width: 120,
            height: 150,
          ),
        ],
      ),
    ),
  ];

  List<Widget> documentsPage() => [
    ChatDateSeparator(date: todayAt(10, 6)),
    bubble(
      message(
        author: ada,
        at: todayAt(10, 6),
        attachments: [
          attachment(
            'doc-remote',
            type: AttachmentType.file,
            filename:
                'Маршрут_поездки_по_Кавказу_с_ночёвками_у_озёр_и_на_перевале_'
                'Бечо_март_2026.pdf',
          ),
        ],
      ),
    ),
    bubble(
      message(
        id: progressMessageId,
        author: ada,
        at: todayAt(10, 7),
        attachments: [progressDoc()],
      ),
    ),
    bubble(
      message(
        author: me,
        at: todayAt(10, 9),
        attachments: [
          attachment(
            'doc-local',
            type: AttachmentType.file,
            filename: 'smeta.xlsx',
            size: 48 * 1024,
          ),
        ],
      ),
    ),
    bubble(
      message(
        author: me,
        at: todayAt(10, 11),
        content: 'Билеты, распечатай',
        attachments: [
          attachment(
            'doc-tickets',
            type: AttachmentType.file,
            filename: 'tickets.zip',
            size: 730 * 1024,
          ),
        ],
      ),
      status: MessageDeliveryStatus.sent,
    ),
  ];

  /// The pane the conversation is drawn in, measured as the feed measures
  /// itself: the pane, never the window.
  Widget pane(List<Widget> page) => LayoutBuilder(
    builder: (context, constraints) => ChatFeedMetrics(
      width: ChatLayout.columnWidthFor(constraints.maxWidth),
      height: constraints.maxHeight,
      child: ChatWallpaper(
        seed: chatId.hashCode,
        child: Align(
          alignment: Alignment.topCenter,
          child: SizedBox(
            width: ChatLayout.columnWidthFor(constraints.maxWidth),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: page,
            ),
          ),
        ),
      ),
    ),
  );

  Future<void> loadPictures(WidgetTester tester) async {
    bool blank() => find
        .byType(RawImage)
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

  Future<void> pumpFrame(
    WidgetTester tester, {
    required PaneWindow window,
    required bool dark,
    required AppDensity density,
    required List<Widget> page,
  }) async {
    tester.view.physicalSize = window.size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          chatSocketServiceProvider.overrideWithValue(socket),
          // The file cache is the seam: what is on disk is what is drawn,
          // and what is not stays a tap away.
          autoAttachmentFileProvider.overrideWith(
            (ref, key) async => files[key.attachment.id],
          ),
          attachmentFileProvider.overrideWith(
            (ref, key) async => files[key.attachment.id]!,
          ),
          attachmentDownloadProvider(
            attachmentFileKey(progressDoc(), messageId: progressMessageId),
          ).overrideWith(_HalfwayDownload.new),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: chatGoldenTheme(dark: dark, density: density),
          locale: const Locale('ru'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: AppClock(
              now: now,
              child: PaneFrame(window: window, child: pane(page)),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await loadPictures(tester);
    await tester.pumpAndSettle();
  }

  for (final window in [PaneWindow.phone, PaneWindow.desktop]) {
    for (final theme in chatGoldenThemes.entries) {
      for (final density in chatGoldenDensities.entries) {
        for (final (name, page) in [
          ('text', textPage),
          ('replies', repliesPage),
          ('photos', photosPage),
          ('documents', documentsPage),
        ]) {
          final id = '${window.name}_${theme.key}_${density.key}_$name';

          testWidgets('bubble matrix: $id', (tester) async {
            await pumpFrame(
              tester,
              window: window,
              dark: theme.value,
              density: density.value,
              page: page(),
            );

            expect(tester.takeException(), isNull);
            await expectLater(
              find.byType(MaterialApp),
              matchesGoldenFile('goldens/bubble_layout_$id.png'),
            );
          });
        }
      }
    }
  }
}

/// A download a little past halfway, held there.
class _HalfwayDownload extends AttachmentDownloadController {
  _HalfwayDownload() : super((chatId: '', messageId: '', attachment: _unused));

  @override
  AttachmentDownloadState build() => const AttachmentDownloadState.downloading(
    received: 1258291,
    total: 2 * 1024 * 1024,
  );
}

final AttachmentEntity _unused = AttachmentEntity(
  id: '',
  messageId: '',
  chatId: '',
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
);
