import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:mocktail/mocktail.dart';

import 'package:chatix/core/constants/app_constants.dart';
import 'package:chatix/core/localization/app_date_format.dart';
import 'package:chatix/core/theme/app_theme.dart';
import 'package:chatix/core/theme/app_tokens.dart';
import 'package:chatix/core/theme/theme_config.dart';
import 'package:chatix/core/websocket/chat_socket_service.dart';
import 'package:chatix/features/auth/domain/entities/user_entity.dart';
import 'package:chatix/features/auth/presentation/providers/auth_provider.dart';
import 'package:chatix/features/chat/domain/entities/attachment_entity.dart';
import 'package:chatix/features/chat/domain/entities/chat_entity.dart';
import 'package:chatix/features/chat/domain/entities/chat_pages.dart';
import 'package:chatix/features/chat/domain/entities/chat_profile_entity.dart';
import 'package:chatix/features/chat/domain/entities/message_entity.dart';
import 'package:chatix/features/chat/domain/entities/reaction_entity.dart';
import 'package:chatix/features/chat/domain/entities/slow_mode.dart';
import 'package:chatix/features/chat/domain/usecases/get_chat_use_case.dart';
import 'package:chatix/features/chat/domain/usecases/get_messages_context_use_case.dart';
import 'package:chatix/features/chat/domain/usecases/get_messages_use_case.dart';
import 'package:chatix/features/chat/domain/usecases/mark_read_use_case.dart';
import 'package:chatix/features/chat/presentation/providers/attachment_file_provider.dart';
import 'package:chatix/features/chat/presentation/providers/chat_detail_provider.dart';
import 'package:chatix/features/chat/presentation/providers/chat_providers.dart';
import 'package:chatix/features/chat/presentation/providers/chat_socket_provider.dart';
import 'package:chatix/features/chat/presentation/widgets/chat_feed.dart';
import 'package:chatix/features/chat/presentation/widgets/chat_feed_metrics.dart';
import 'package:chatix/features/chat/presentation/widgets/chat_pending_bubble.dart';
import 'package:chatix/features/chat/presentation/widgets/composer/chat_composer.dart';
import 'package:chatix/features/chat/presentation/widgets/message_album.dart';
import 'package:chatix/features/chat/presentation/widgets/message_bubble.dart';
import 'package:chatix/features/chat/presentation/widgets/reaction_chip.dart';
import 'package:chatix/features/chat/presentation/widgets/status_ticks.dart';
import 'package:chatix/gen/l10n/app_localizations.dart';

import '../../../../helpers/fakes/fake_secure_storage_service.dart';
import '../../../../helpers/fakes/fake_web_socket_channel.dart';
import '../../../../helpers/test_photos.dart';

class MockGetChatUseCase extends Mock implements GetChatUseCase {}

class MockGetMessagesUseCase extends Mock implements GetMessagesUseCase {}

class MockGetMessagesContextUseCase extends Mock
    implements GetMessagesContextUseCase {}

class MockMarkReadUseCase extends Mock implements MarkReadUseCase {}

class FakeAuthController extends AuthController {
  FakeAuthController(this._user);

  final UserEntity? _user;

  @override
  Future<UserEntity?> build() async => _user;
}

/// The windows the feed is checked in.
///
/// A two-pane window is the chat list beside the chat: an 80 px rail, a
/// 360 px list, and the conversation in whatever is left — which at 1440 is
/// a 1000 px pane, and at 1920 a pane wide enough for the centred column.
enum _Device {
  phone(Size(390, 844), twoPane: false),
  desktop(Size(1440, 900), twoPane: true),
  wide(Size(1920, 1080), twoPane: true);

  const _Device(this.size, {required this.twoPane});

  final Size size;
  final bool twoPane;

  static const double rail = 80;
  static const double list = 360;
}

/// Photos in the feed: how big they get, what they sit in, and that every
/// copy of a bubble — the one in the list, the one still going out, the one
/// the context menu lifts — comes out the same size.
void main() {
  const chatId = '7d1c0b9a-2c4e-4f0a-9b1e-3f5a6c7d8e9f';
  const me = UserEntity(id: 7, username: 'me', email: 'me@example.com');
  const ada = 42;

  late Directory photosDir;
  final photos = <String, File>{};

  setUpAll(() {
    dotenv.testLoad(fileInput: 'BASE_URL=https://api.example.com');
    registerFallbackValue(
      const MessagesPage(messages: [], nextCursor: null, hasNext: false),
    );

    photosDir = Directory.systemTemp.createTempSync('chat_feed_media_test');
    // Small files: the tile crops them to fill, so only the shape and the
    // colours matter, and those the attachment's own width/height decide.
    final specs = <String, (int, int, int)>{
      'portrait': (90, 160, 0),
      'landscape': (160, 90, 1),
      'a3-1': (150, 100, 2),
      'a3-2': (90, 120, 3),
      'a3-3': (120, 120, 4),
      'a5-1': (120, 90, 0),
      'a5-2': (90, 120, 1),
      'a5-4': (120, 120, 3),
      'a5-5': (120, 80, 4),
      'caption': (160, 120, 2),
    };
    for (final MapEntry(key: id, value: (w, h, palette)) in specs.entries) {
      photos[id] = TestPhotos.write(
        photosDir,
        name: id,
        width: w,
        height: h,
        palette: palette,
      );
    }
  });

  tearDownAll(() {
    if (photosDir.existsSync()) photosDir.deleteSync(recursive: true);
  });

  ChatProfileEntity profile(int userId) => ChatProfileEntity(
    userId: userId,
    username: userId == ada ? 'ada' : 'me',
    displayName: userId == ada ? 'Ada Lovelace' : 'Me',
    avatarUrl: null,
    avatarS3Key: null,
  );

  AttachmentEntity media(
    String id, {
    required int width,
    required int height,
    AttachmentType type = AttachmentType.image,
    int? duration,
  }) => AttachmentEntity(
    id: id,
    messageId: null,
    chatId: chatId,
    uploaderId: ada,
    attachmentType: type,
    attachmentStatus: AttachmentStatus.success,
    url: null,
    urlExpiresIn: null,
    s3Key: 'chats/$chatId/$id',
    mimeType: type == AttachmentType.video ? 'video/mp4' : 'image/png',
    originalFilename: '$id.png',
    size: 2048,
    width: width,
    height: height,
    durationSeconds: duration,
    createdAt: DateTime(2026, 3, 1, 18),
  );

  MessageEntity message(
    int seq, {
    required int author,
    String? content,
    List<AttachmentEntity> attachments = const [],
  }) => MessageEntity(
    id: 'm$seq',
    chatId: chatId,
    seq: seq,
    authorId: author,
    type: attachments.isEmpty ? MessageType.text : MessageType.image,
    content: content,
    replyToId: null,
    forwardedFromChatId: null,
    forwardedFromMessageId: null,
    forwardedFromAuthorId: null,
    isEdited: false,
    createdAt: DateTime(2026, 3, 1, 18).add(Duration(minutes: seq)),
    attachments: attachments,
    profile: profile(author),
  );

  /// The cases the layout has to get right, oldest first: text, a lone
  /// portrait, a lone landscape, albums of three and five, a photo with a
  /// caption, and a long text.
  List<MessageEntity> conversation() => [
    message(1, author: ada, content: 'Here are the shots from Saturday'),
    message(
      2,
      author: ada,
      attachments: [media('portrait', width: 1080, height: 1920)],
    ),
    message(
      3,
      author: me.id,
      attachments: [media('landscape', width: 1920, height: 1080)],
    ),
    message(
      4,
      author: ada,
      attachments: [
        media('a3-1', width: 1600, height: 1067),
        media('a3-2', width: 900, height: 1200),
        media('a3-3', width: 1200, height: 1200),
      ],
    ),
    message(
      5,
      author: me.id,
      attachments: [
        media('a5-1', width: 1200, height: 900),
        media('a5-2', width: 900, height: 1200),
        media(
          'a5-3',
          width: 1920,
          height: 1080,
          type: AttachmentType.video,
          duration: 42,
        ),
        media('a5-4', width: 1080, height: 1080),
        media('a5-5', width: 1200, height: 800),
      ],
    ),
    message(
      6,
      author: ada,
      content:
          'The view from the ridge. Worth every step of the climb, '
          'honestly — we should go back in May.',
      attachments: [media('caption', width: 1600, height: 1200)],
    ),
    message(
      7,
      author: me.id,
      content:
          'Sorting them into an album tonight. The light on the third one '
          'is unreal — I will send the full-size files once I am back on '
          'Wi-Fi, these are the compressed previews. Also: the panorama did '
          'not survive the trip, the stitching broke halfway through.',
    ),
  ].reversed.toList();

  /// Two messages the queue is still carrying: one on its way, one that
  /// stopped and is waiting to be told what to do.
  const pending = [
    PendingMessage(idempotencyKey: 'p1', content: 'On my way, see you there'),
    PendingMessage(
      idempotencyKey: 'p2',
      content: 'Sending the rest tonight',
      attempts: 3,
      needsAttention: true,
    ),
  ];

  ChatEntity chat() => ChatEntity(
    id: chatId,
    seqCounter: 7,
    lastActivityAt: DateTime(2026, 3, 1, 18, 7),
    type: ChatType.direct,
    name: null,
    description: null,
    avatarS3Key: null,
    isPublic: false,
    adminOnly: false,
    slowModeSeconds: 0,
    permissions: const {},
    createdBy: me.id,
    memberCount: 2,
    unreadCount: 0,
    lastRead: ReadDetailEntity(
      lastReadMessageSeq: 7,
      lastReadAt: DateTime(2026, 3, 1, 18, 7),
    ),
  );

  late MockGetChatUseCase getChat;
  late MockGetMessagesUseCase getMessages;
  late MockGetMessagesContextUseCase getContext;
  late MockMarkReadUseCase markRead;
  late FakeWebSocketChannel channel;
  late ChatSocketService socket;

  setUp(() {
    // A photo the last test started loading is still pending in the shared
    // cache, tied to that test's fake clock — and would never finish here.
    PaintingBinding.instance.imageCache
      ..clear()
      ..clearLiveImages();

    getChat = MockGetChatUseCase();
    getMessages = MockGetMessagesUseCase();
    getContext = MockGetMessagesContextUseCase();
    markRead = MockMarkReadUseCase();
    channel = FakeWebSocketChannel();
    socket = ChatSocketService(
      secureStorage: FakeSecureStorageService(
        initialValues: {AppConstants.accessTokenKey: 'token'},
      ),
      channelFactory: (_) => channel,
    );

    when(
      () => markRead.execute(any(), any()),
    ).thenAnswer((_) async => const Right(null));
  });

  tearDown(() async {
    await socket.dispose();
    await channel.dispose();
  });

  /// The chat screen in [device]'s window: a header, the feed, the
  /// composer — beside a rail and a chat list when the window has two panes.
  Future<ProviderContainer> pumpScreen(
    WidgetTester tester, {
    required _Device device,
    bool dark = false,
  }) async {
    when(() => getChat.execute(chatId)).thenAnswer((_) async => Right(chat()));
    when(
      () => getMessages.execute(chatId, limit: any(named: 'limit')),
    ).thenAnswer(
      (_) async => Right(
        MessagesPage(
          messages: conversation(),
          nextCursor: null,
          hasNext: false,
        ),
      ),
    );

    final container = ProviderContainer(
      overrides: [
        getChatUseCaseProvider.overrideWithValue(getChat),
        getMessagesUseCaseProvider.overrideWithValue(getMessages),
        getMessagesContextUseCaseProvider.overrideWithValue(getContext),
        markReadUseCaseProvider.overrideWithValue(markRead),
        chatSocketServiceProvider.overrideWithValue(socket),
        authProvider.overrideWith(() => FakeAuthController(me)),
        // The file cache is the seam: what is on disk is what is drawn.
        autoAttachmentFileProvider.overrideWith(
          (ref, key) async => photos[key.attachment.id],
        ),
        attachmentFileProvider.overrideWith(
          (ref, key) async => photos[key.attachment.id]!,
        ),
      ],
    );
    addTearDown(container.dispose);

    await container.read(authProvider.future);
    container.listen(chatDetailProvider(chatId), (_, _) {});
    await container.read(chatDetailProvider(chatId).future);

    final controller = TextEditingController();
    final focusNode = FocusNode();
    addTearDown(controller.dispose);
    addTearDown(focusNode.dispose);

    // The mesh is seeded from the chat id; a hash that moves between SDKs
    // would make every one of these a liability. The pattern has its own
    // goldens.
    final appearance = const AppearanceSettings().copyWith(
      wallpaperId: AppWallpaper.plain.id,
    );

    final screen = Scaffold(
      appBar: AppBar(title: const Text('Ada Lovelace')),
      body: Column(
        children: [
          Expanded(
            child: Consumer(
              builder: (context, ref, _) => ChatFeed(
                chatId: chatId,
                state: ref
                    .watch(chatDetailProvider(chatId))
                    .value!
                    .copyWith(pending: pending),
                myUserId: me.id,
                selectionMode: false,
                selectedIds: const {},
                onStartSelection: (_) {},
                onToggleSelected: (_) {},
                onEdit: (_) {},
                onRefresh: () async {},
              ),
            ),
          ),
          ChatComposer(
            controller: controller,
            focusNode: focusNode,
            length: 0,
            hasAttachments: false,
            isRecording: false,
            isSending: false,
            slowMode: SlowMode.off,
            replyTo: null,
            editing: null,
            onAttach: () {},
            onSend: () {},
            onVoiceRecorded: (_) {},
          ),
        ],
      ),
    );

    await tester.pumpWidgetBuilder(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: dark ? AppTheme.dark(appearance) : AppTheme.light(appearance),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          // Date chips name the year when it is not this one: pinned, so a
          // golden reads the same in any year it is rendered in.
          builder: (context, child) =>
              AppClock(now: DateTime(2026, 10, 10, 12), child: child!),
          home: device.twoPane ? _TwoPanes(chat: screen) : screen,
        ),
      ),
      wrapper: (child) => child,
      surfaceSize: device.size,
    );
    addTearDown(() => tester.binding.setSurfaceSize(null));
    addTearDown(tester.view.reset);

    await tester.pumpAndSettle();
    return container;
  }

  ScrollPosition feedPosition(WidgetTester tester) => tester
      .state<ScrollableState>(
        find.descendant(
          of: find.byType(ChatFeed),
          matching: find.byType(Scrollable),
        ),
      )
      .position;

  /// Waits for every photo on screen to be decoded.
  ///
  /// A file image starts loading inside the test's fake clock, and the
  /// engine's answer only lands once real time has passed *and* the fake
  /// zone is pumped — so neither alone gets there, and priming the golden on
  /// a load that is still pending waits forever. This alternates the two
  /// until nothing is left blank, and fails loudly rather than hanging.
  Future<void> loadPictures(WidgetTester tester) async {
    bool blank() => find
        .byType(RawImage, skipOffstage: false)
        .evaluate()
        .any((element) => (element.widget as RawImage).image == null);

    for (var round = 0; blank(); round++) {
      if (round == 200) fail('photos in the feed never finished decoding');
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump();
    }
  }

  /// Lets the scroll settle and the sticky date fade, so a golden shows the
  /// feed at rest rather than mid-gesture, with its photos in.
  Future<void> settle(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    await loadPictures(tester);
  }

  Finder bubbleOf(String messageId) => find.byWidgetPredicate(
    (widget) => widget is MessageBubble && widget.message.id == messageId,
  );

  Finder albumOf(String messageId) => find.descendant(
    of: bubbleOf(messageId),
    matching: find.byType(MessageAlbum),
  );

  /// The bubble's painted ground, where it has one.
  Finder groundOf(String messageId) => find.descendant(
    of: bubbleOf(messageId),
    matching: find.byWidgetPredicate(
      (widget) =>
          widget is DecoratedBox && widget.decoration is ShapeDecoration,
    ),
  );

  /// Walks the feed from the newest message to the oldest, calling [visit]
  /// at each stop.
  Future<void> pageThrough(
    WidgetTester tester,
    Future<void> Function(int page) visit,
  ) async {
    final position = feedPosition(tester);
    final step = position.viewportDimension * 0.85;

    var page = 1;
    var offset = 0.0;
    while (true) {
      position.jumpTo(offset.clamp(0, position.maxScrollExtent));
      await settle(tester);
      await visit(page);

      if (offset >= position.maxScrollExtent) break;
      offset += step;
      page++;
    }
  }

  group('sizes', () {
    testWidgets('the feed publishes its own pane, not the window', (
      tester,
    ) async {
      await pumpScreen(tester, device: _Device.desktop);

      final metrics = tester.widget<ChatFeedMetrics>(
        find.byType(ChatFeedMetrics),
      );
      final feed = tester.getSize(find.byType(ChatFeed));

      expect(metrics.width, 1440 - _Device.rail - _Device.list);
      expect(metrics.width, feed.width);
      expect(metrics.height, feed.height);
    });

    testWidgets('on a desktop pane no picture is wider than 420', (
      tester,
    ) async {
      await pumpScreen(tester, device: _Device.desktop);

      final seen = <String>{};
      await pageThrough(tester, (_) async {
        for (final element in find.byType(MessageAlbum).evaluate()) {
          final album = element.widget as MessageAlbum;
          final size = tester.getSize(find.byWidget(album));
          seen.add(album.attachments.first.id);

          expect(size.width, lessThanOrEqualTo(ChatLayout.mediaMaxWidthWide));
          expect(size.height, lessThanOrEqualTo(ChatLayout.mediaMaxHeight));
        }
      });

      // Every picture in the conversation was measured, not just the
      // newest screenful.
      expect(seen, containsAll(['portrait', 'landscape', 'a3-1', 'a5-1']));
      expect(seen, contains('caption'));
    });

    testWidgets('on a phone a portrait stays under half the screen', (
      tester,
    ) async {
      await pumpScreen(tester, device: _Device.phone);
      await tester.scrollUntilVisible(
        albumOf('m2'),
        200,
        scrollable: find.descendant(
          of: find.byType(ChatFeed),
          matching: find.byType(Scrollable),
        ),
      );

      final portrait = tester.getSize(albumOf('m2'));

      expect(portrait.height, lessThanOrEqualTo(_Device.phone.size.height / 2));
      // Still a portrait: the height cap took the width down with it.
      expect(portrait.width / portrait.height, closeTo(9 / 16, 0.01));
    });

    testWidgets('a pane past 1000 px holds the conversation to a column', (
      tester,
    ) async {
      await pumpScreen(tester, device: _Device.wide);

      final pane = tester.getRect(find.byType(ChatFeed));
      final column = Rect.fromCenter(
        center: pane.center,
        width: ChatLayout.columnMaxWidth,
        height: pane.height,
      );

      for (final element in find.byType(MessageBubble).evaluate()) {
        final rect = tester.getRect(find.byWidget(element.widget));
        expect(rect.left, greaterThanOrEqualTo(column.left - 0.5));
        expect(rect.right, lessThanOrEqualTo(column.right + 0.5));
      }

      final composerField = tester.getRect(find.byType(TextField));
      expect(composerField.left, greaterThanOrEqualTo(column.left));
      expect(composerField.right, lessThanOrEqualTo(column.right));
    });
  });

  group('the bubble around a picture', () {
    testWidgets('a picture with nothing to say is the bubble itself', (
      tester,
    ) async {
      await pumpScreen(tester, device: _Device.desktop);
      await tester.scrollUntilVisible(
        albumOf('m3'),
        200,
        scrollable: find.descendant(
          of: find.byType(ChatFeed),
          matching: find.byType(Scrollable),
        ),
      );

      // No ground drawn behind it, and the ticks ride on the photo, inset
      // from its bottom-right corner.
      expect(groundOf('m3'), findsNothing);

      final photo = tester.getRect(albumOf('m3'));
      final ticks = tester.getRect(
        find.descendant(of: bubbleOf('m3'), matching: find.byType(StatusTicks)),
      );
      expect(photo.contains(ticks.topLeft), isTrue);
      expect(photo.contains(ticks.bottomRight), isTrue);
      expect(
        photo.right - ticks.right,
        greaterThanOrEqualTo(ChatLayout.mediaMetaInset),
      );
    });

    testWidgets('a caption hangs under the photo, which runs to the edges', (
      tester,
    ) async {
      await pumpScreen(tester, device: _Device.desktop);

      final ground = tester.getRect(groundOf('m6'));
      final photo = tester.getRect(albumOf('m6'));

      // No frame: the photo starts where the bubble starts and is exactly
      // as wide — the caption wraps to it rather than widening the bubble.
      expect(photo.topLeft, ground.topLeft);
      expect(photo.width, ground.width);
      expect(ground.height, greaterThan(photo.height));
    });

    testWidgets('reactions on a bare photo go under it, not into a frame', (
      tester,
    ) async {
      final photo = message(
        2,
        author: ada,
        attachments: [media('portrait', width: 1080, height: 1920)],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            chatSocketServiceProvider.overrideWithValue(socket),
            autoAttachmentFileProvider.overrideWith(
              (ref, key) async => photos[key.attachment.id],
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            home: Scaffold(
              body: ChatFeedMetrics(
                width: 390,
                height: 640,
                child: MessageBubble(
                  message: photo,
                  isMine: false,
                  reactions: const MessageReactionsEntity(
                    messageId: 'm2',
                    groups: [ReactionGroupEntity(emoji: '+1', count: 2)],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      // Past the chip's entrance, so it is measured where it comes to rest.
      await tester.pump(const Duration(seconds: 1));

      final picture = tester.getRect(find.byType(MessageAlbum));
      final chip = tester.getRect(find.byType(ReactionChip));

      // Still no ground: a reaction is not a caption.
      expect(groundOf('m2'), findsNothing);
      expect(chip.top, greaterThanOrEqualTo(picture.bottom));
      expect(chip.left, greaterThanOrEqualTo(picture.left));
      expect(chip.right, lessThanOrEqualTo(picture.right));
    });
  });

  group('copies of a bubble', () {
    testWidgets('the context menu lifts a copy of exactly the same size', (
      tester,
    ) async {
      await pumpScreen(tester, device: _Device.desktop);
      await tester.scrollUntilVisible(
        albumOf('m4'),
        200,
        scrollable: find.descendant(
          of: find.byType(ChatFeed),
          matching: find.byType(Scrollable),
        ),
      );
      await settle(tester);

      final inFeed = tester.getSize(albumOf('m4'));

      await tester.longPress(albumOf('m4'));
      await tester.pumpAndSettle();

      final copies = find.byWidgetPredicate(
        (widget) =>
            widget is MessageAlbum && widget.attachments.first.id == 'a3-1',
      );
      expect(copies, findsNWidgets(2));
      for (final element in copies.evaluate()) {
        expect(tester.getSize(find.byWidget(element.widget)), inFeed);
      }
    });

    testWidgets('a message going out is as wide as the one it becomes', (
      tester,
    ) async {
      const text =
          'A message long enough to wrap, so that both bubbles are held to '
          'the same width limit rather than to the length of their text.';

      final sent = MessageEntity(
        id: 'sent',
        chatId: chatId,
        seq: 1,
        authorId: me.id,
        type: MessageType.text,
        content: text,
        replyToId: null,
        forwardedFromChatId: null,
        forwardedFromMessageId: null,
        forwardedFromAuthorId: null,
        isEdited: false,
        createdAt: DateTime(2026, 3, 1, 18),
        attachments: const [],
      );

      for (final width in [390.0, 1000.0]) {
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              theme: AppTheme.lightTheme,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              home: Scaffold(
                body: ChatFeedMetrics(
                  width: width,
                  height: 700,
                  child: Column(
                    children: [
                      MessageBubble(message: sent, isMine: true),
                      const ChatPendingBubble(
                        pending: PendingMessage(
                          idempotencyKey: 'p',
                          content: text,
                        ),
                        chatId: chatId,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );

        Rect groundIn(Finder host) => tester.getRect(
          find.descendant(
            of: host,
            matching: find.byWidgetPredicate(
              (widget) =>
                  widget is Container && widget.decoration is ShapeDecoration,
            ),
          ),
        );

        final real = groundIn(find.byType(MessageBubble));
        final going = groundIn(find.byType(ChatPendingBubble));

        expect(going.width, real.width, reason: 'feed $width');
        expect(going.right, real.right, reason: 'feed $width');
        expect(real.width, ChatLayout.bubbleMaxWidthFor(width));
      }
    });
  });

  group('goldens', () {
    for (final device in [_Device.phone, _Device.desktop]) {
      for (final theme in {'light': false, 'dark': true}.entries) {
        testGoldens('the media feed, ${device.name}, ${theme.key}', (
          tester,
        ) async {
          await pumpScreen(tester, device: device, dark: theme.value);

          await pageThrough(tester, (page) async {
            await screenMatchesGolden(
              tester,
              'feed_media_${device.name}_${theme.key}_p$page',
            );
          });
        });
      }
    }

    for (final theme in {'light': false, 'dark': true}.entries) {
      testGoldens('the centred column on a wide pane, ${theme.key}', (
        tester,
      ) async {
        await pumpScreen(tester, device: _Device.wide, dark: theme.value);
        await settle(tester);

        await screenMatchesGolden(tester, 'feed_media_wide_${theme.key}');
      });
    }

    for (final device in [_Device.phone, _Device.desktop]) {
      for (final theme in {'light': false, 'dark': true}.entries) {
        testGoldens('the menu over an album, ${device.name}, ${theme.key}', (
          tester,
        ) async {
          await pumpScreen(tester, device: device, dark: theme.value);
          await tester.scrollUntilVisible(
            albumOf('m4'),
            200,
            scrollable: find.descendant(
              of: find.byType(ChatFeed),
              matching: find.byType(Scrollable),
            ),
          );
          await settle(tester);

          await tester.longPress(albumOf('m4'));
          await tester.pumpAndSettle();
          await loadPictures(tester);

          await screenMatchesGolden(
            tester,
            'feed_media_menu_${device.name}_${theme.key}',
          );
        });
      }
    }
  });
}

/// The shell around the chat in a two-pane window: a rail and a chat list,
/// drawn as plain shapes — only their widths matter here.
class _TwoPanes extends StatelessWidget {
  const _TwoPanes({required this.chat});

  final Widget chat;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final divider = BorderSide(color: scheme.outlineVariant);

    return Row(
      children: [
        Container(
          width: _Device.rail,
          decoration: BoxDecoration(
            color: scheme.surfaceContainer,
            border: Border(right: divider),
          ),
          child: Column(
            children: [
              const SizedBox(height: AppSpacing.x4),
              for (var i = 0; i < 4; i++)
                Container(
                  width: 40,
                  height: 40,
                  margin: const EdgeInsets.symmetric(vertical: AppSpacing.x2),
                  decoration: BoxDecoration(
                    color: i == 0
                        ? scheme.secondaryContainer
                        : scheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(AppRadii.md),
                  ),
                ),
            ],
          ),
        ),
        Container(
          width: _Device.list,
          decoration: BoxDecoration(
            color: scheme.surface,
            border: Border(right: divider),
          ),
          child: Column(
            children: [
              for (var i = 0; i < 9; i++)
                Container(
                  height: 72,
                  color: i == 0 ? scheme.secondaryContainer : null,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.x4,
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: scheme.surfaceContainerHighest,
                      ),
                      const SizedBox(width: AppSpacing.x3),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _Bar(width: 140, color: scheme.onSurfaceVariant),
                          const SizedBox(height: AppSpacing.x2),
                          _Bar(width: 200, color: scheme.outlineVariant),
                        ],
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        Expanded(child: chat),
      ],
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.width, required this.color});

  final double width;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: width,
    height: 8,
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.5),
      borderRadius: BorderRadius.circular(AppRadii.full),
    ),
  );
}
