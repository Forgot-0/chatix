import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:mocktail/mocktail.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

import 'package:chatix/core/constants/app_constants.dart';
import 'package:chatix/core/error/failures.dart';
import 'package:chatix/core/theme/app_theme.dart';
import 'package:chatix/core/theme/app_tokens.dart';
import 'package:chatix/core/websocket/chat_socket_service.dart';
import 'package:chatix/features/auth/domain/entities/user_entity.dart';
import 'package:chatix/features/auth/presentation/providers/auth_provider.dart';
import 'package:chatix/features/chat/domain/entities/attachment_entity.dart';
import 'package:chatix/features/chat/domain/entities/chat_entity.dart';
import 'package:chatix/features/chat/domain/entities/chat_member_entity.dart';
import 'package:chatix/features/chat/domain/entities/chat_pages.dart';
import 'package:chatix/features/chat/domain/entities/chat_profile_entity.dart';
import 'package:chatix/features/chat/domain/entities/message_entity.dart';
import 'package:chatix/features/chat/domain/usecases/delete_message_use_case.dart';
import 'package:chatix/features/chat/domain/usecases/get_chat_use_case.dart';
import 'package:chatix/features/chat/domain/usecases/get_messages_context_use_case.dart';
import 'package:chatix/features/chat/domain/usecases/get_message_use_case.dart';
import 'package:chatix/features/chat/domain/usecases/get_messages_use_case.dart';
import 'package:chatix/features/chat/domain/usecases/mark_read_use_case.dart';
import 'package:chatix/features/chat/presentation/providers/attachment_file_provider.dart';
import 'package:chatix/features/chat/presentation/providers/chat_detail_provider.dart';
import 'package:chatix/features/chat/presentation/providers/chat_providers.dart';
import 'package:chatix/features/chat/presentation/providers/chat_socket_provider.dart';
import 'package:chatix/features/chat/presentation/providers/video_poster_provider.dart';
import 'package:chatix/features/chat/presentation/screens/media_viewer_screen.dart';
import 'package:chatix/features/chat/presentation/widgets/media_viewer/viewer_chrome.dart';
import 'package:chatix/gen/l10n/app_localizations.dart';

import '../../../../helpers/chat_golden.dart';
import '../../../../helpers/fakes/fake_secure_storage_service.dart';
import '../../../../helpers/fakes/fake_video_player_platform.dart';
import '../../../../helpers/fakes/fake_web_socket_channel.dart';
import '../../../../helpers/pane_frame.dart';
import '../../../../helpers/test_photos.dart';

class MockGetChatUseCase extends Mock implements GetChatUseCase {}

class MockGetMessagesUseCase extends Mock implements GetMessagesUseCase {}

class MockGetMessagesContextUseCase extends Mock
    implements GetMessagesContextUseCase {}

class MockMarkReadUseCase extends Mock implements MarkReadUseCase {}

class MockGetMessageUseCase extends Mock implements GetMessageUseCase {}

class MockDeleteMessageUseCase extends Mock implements DeleteMessageUseCase {}

class FakeAuthController extends AuthController {
  FakeAuthController(this._user);

  final UserEntity? _user;

  @override
  Future<UserEntity?> build() async => _user;
}

/// The viewer as the reader meets it: whose photo it is, where it sits in
/// the chat's media, the ways through it and back out, what can be done
/// with it — and a video's controls.
void main() {
  const chatId = '550e8400-e29b-41d4-a716-446655440000';
  const me = UserEntity(id: 7, username: 'me', email: 'me@example.com');
  const ada = 42;

  late MockGetChatUseCase getChat;
  late MockGetMessagesUseCase getMessages;
  late MockGetMessagesContextUseCase getContext;
  late MockMarkReadUseCase markRead;
  late MockGetMessageUseCase getMessage;
  late MockDeleteMessageUseCase deleteMessage;
  late ChatSocketService socket;
  late Directory temporary;
  late File stubImage;
  late AppLocalizations l10n;
  late VideoPlayerPlatform originalVideoPlatform;

  setUpAll(() async {
    dotenv.testLoad(fileInput: 'BASE_URL=https://api.example.com');
    registerFallbackValue(
      const MessagesPage(messages: [], nextCursor: null, hasNext: false),
    );
    l10n = await AppLocalizations.delegate.load(const Locale('en'));
  });

  setUp(() {
    getChat = MockGetChatUseCase();
    getMessages = MockGetMessagesUseCase();
    getContext = MockGetMessagesContextUseCase();
    markRead = MockMarkReadUseCase();
    getMessage = MockGetMessageUseCase();
    deleteMessage = MockDeleteMessageUseCase();
    socket = ChatSocketService(
      secureStorage: FakeSecureStorageService(
        initialValues: {AppConstants.accessTokenKey: 'token'},
      ),
      channelFactory: (_) => FakeWebSocketChannel(),
    );

    temporary = Directory.systemTemp.createTempSync('media_viewer_test');
    stubImage = File('${temporary.path}/photo.png')
      ..writeAsBytesSync(kStubImageBytes);

    when(
      () => markRead.execute(any(), any()),
    ).thenAnswer((_) async => const Right(null));

    originalVideoPlatform = VideoPlayerPlatform.instance;
  });

  tearDown(() {
    VideoPlayerPlatform.instance = originalVideoPlatform;
    try {
      if (temporary.existsSync()) temporary.deleteSync(recursive: true);
    } on FileSystemException {
      // Windows: a picture decoding on the real event loop (see
      // `runAsync`) may still hold its file open. It is a temp directory.
    }
  });

  AttachmentEntity photo(String id, {int width = 1200, int height = 800}) =>
      AttachmentEntity(
        id: id,
        messageId: null,
        chatId: chatId,
        uploaderId: ada,
        attachmentType: AttachmentType.image,
        attachmentStatus: AttachmentStatus.success,
        url: null,
        urlExpiresIn: null,
        s3Key: 'chats/$chatId/$id/photo.png',
        mimeType: 'image/png',
        originalFilename: '$id.png',
        size: 2048,
        width: width,
        height: height,
        durationSeconds: null,
        createdAt: DateTime.utc(2026, 3, 1, 9),
      );

  AttachmentEntity video(String id, {int seconds = 12}) => AttachmentEntity(
    id: id,
    messageId: null,
    chatId: chatId,
    uploaderId: ada,
    attachmentType: AttachmentType.video,
    attachmentStatus: AttachmentStatus.success,
    url: null,
    urlExpiresIn: null,
    s3Key: 'chats/$chatId/$id/clip.mp4',
    mimeType: 'video/mp4',
    originalFilename: '$id.mp4',
    size: 4096,
    width: 1280,
    height: 720,
    durationSeconds: seconds,
    createdAt: DateTime.utc(2026, 3, 1, 9),
  );

  MessageEntity message(
    String id,
    int seq,
    List<AttachmentEntity> attachments, {
    String? caption,
    int authorId = ada,
    // Local, not UTC: the header prints local time, and a golden must not
    // depend on the zone of the machine drawing it.
    DateTime? at,
  }) => MessageEntity(
    id: id,
    chatId: chatId,
    seq: seq,
    authorId: authorId,
    type: MessageType.image,
    content: caption,
    replyToId: null,
    forwardedFromChatId: null,
    forwardedFromMessageId: null,
    forwardedFromAuthorId: null,
    isEdited: false,
    createdAt: at ?? DateTime(2026, 3, 1, 14, 30),
    attachments: attachments,
    profile: authorId == ada
        ? const ChatProfileEntity(
            userId: ada,
            username: 'ada',
            displayName: 'Ada Lovelace',
            avatarUrl: null,
            avatarS3Key: null,
          )
        : null,
  );

  ChatEntity chat({ChatRole role = ChatRole.member}) => ChatEntity(
    id: chatId,
    seqCounter: 10,
    lastActivityAt: DateTime.utc(2026, 3, 1),
    type: ChatType.group,
    name: 'Team',
    description: null,
    avatarS3Key: null,
    isPublic: false,
    adminOnly: false,
    slowModeSeconds: 0,
    permissions: const {},
    createdBy: 1,
    memberCount: 3,
    unreadCount: 0,
    lastRead: null,
    me: ChatMemberEntity(
      userId: me.id,
      roleId: role.id,
      isMuted: false,
      isBanned: false,
      permissionsOverrides: const {},
    ),
  );

  /// Opens the viewer over a feed holding [messages], the way the bubble
  /// does.
  ///
  /// [window] draws it at that window's size; on a tablet or a desktop the
  /// shell's rail and list are underneath, as they are under the real
  /// full-window route. [files] and [posters] say which picture stands for
  /// which attachment; anything not named is the stub.
  Future<ProviderContainer> pump(
    WidgetTester tester, {
    required List<MessageEntity> messages,
    required String attachmentId,
    required String messageId,
    bool dark = false,
    PaneWindow? window,
    ChatRole role = ChatRole.member,
    Map<String, File> files = const {},
    Map<String, File> posters = const {},
    List<Override> overrides = const [],
    bool settle = true,
  }) async {
    when(
      () => getChat.execute(chatId),
    ).thenAnswer((_) async => Right(chat(role: role)));
    when(
      () => getMessages.execute(chatId, limit: any(named: 'limit')),
    ).thenAnswer(
      (_) async => Right(
        MessagesPage(messages: messages, nextCursor: null, hasNext: false),
      ),
    );

    final container = ProviderContainer(
      overrides: [
        getChatUseCaseProvider.overrideWithValue(getChat),
        getMessagesUseCaseProvider.overrideWithValue(getMessages),
        getMessagesContextUseCaseProvider.overrideWithValue(getContext),
        markReadUseCaseProvider.overrideWithValue(markRead),
        getMessageUseCaseProvider.overrideWithValue(getMessage),
        deleteMessageUseCaseProvider.overrideWithValue(deleteMessage),
        chatSocketServiceProvider.overrideWithValue(socket),
        authProvider.overrideWith(() => FakeAuthController(me)),
        // The bytes are beside the point here; that they come from the cache
        // rather than from a link is the point, and that is the seam.
        attachmentFileProvider.overrideWith(
          (ref, key) async => files[key.attachment.id] ?? stubImage,
        ),
        autoAttachmentFileProvider.overrideWith(
          (ref, key) async => files[key.attachment.id] ?? stubImage,
        ),
        videoPosterProvider.overrideWith(
          (ref, key) => posters[key.attachment.id],
        ),
        ...overrides,
      ],
    );
    addTearDown(container.dispose);

    await container.read(authProvider.future);
    container.listen(chatDetailProvider(chatId), (_, _) {});
    await container.read(chatDetailProvider(chatId).future);

    if (window != null) {
      await tester.binding.setSurfaceSize(window.size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
    }

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: dark ? AppTheme.darkTheme : AppTheme.lightTheme,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) {
              final screen = MediaViewerScreen(
                chatId: chatId,
                messageId: messageId,
                attachmentId: attachmentId,
              );
              if (window == null || !window.hasRail) return screen;

              // The viewer is a route over the whole window; the shell is
              // what it covers.
              return Stack(
                children: [
                  PaneFrame(
                    window: window,
                    child: ColoredBox(
                      color: Theme.of(context).colorScheme.surface,
                    ),
                  ),
                  screen,
                ],
              );
            },
          ),
        ),
      ),
    );
    if (settle) await tester.pumpAndSettle();

    return container;
  }

  /// Waits for every picture on screen to be decoded (see
  /// chat_feed_media_test.dart).
  Future<void> loadPictures(WidgetTester tester) async {
    bool blank() => find
        .byType(RawImage, skipOffstage: false)
        .evaluate()
        .any((element) => (element.widget as RawImage).image == null);

    for (var round = 0; blank(); round++) {
      if (round == 200) fail('pictures never finished decoding');
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump();
    }
  }

  /// Lets a video open, play for a moment and reach [FakeVideoPlayerPlatform]'s
  /// position.
  Future<void> openVideo(WidgetTester tester) async {
    for (var i = 0; i < 5; i++) {
      await tester.pump();
    }
    await tester.pump(const Duration(milliseconds: 150));
  }

  /// A playing controller polls on a periodic timer of its own: unmounting
  /// disposes it before the test is checked for pending timers.
  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  }

  String counter(int index, int count) => l10n.mediaViewerCounter(index, count);

  Finder pageOf(String attachmentId) => find.byKey(ValueKey(attachmentId));

  testWidgets('opens on what was tapped, not on the first photo', (
    tester,
  ) async {
    await pump(
      tester,
      messages: [
        message('m2', 2, [photo('c')]),
        message('m1', 1, [photo('a'), photo('b')]),
      ],
      messageId: 'm1',
      attachmentId: 'b',
    );

    expect(find.textContaining(counter(2, 3)), findsOneWidget);
  });

  testWidgets('the header names the author and when they sent it', (
    tester,
  ) async {
    await pump(
      tester,
      messages: [
        message('m1', 1, [photo('a')]),
      ],
      messageId: 'm1',
      attachmentId: 'a',
    );

    expect(find.text('Ada Lovelace'), findsOneWidget);
    expect(find.textContaining('2026'), findsOneWidget);
  });

  testWidgets('the chat\'s other media is a swipe away, oldest first', (
    tester,
  ) async {
    await pump(
      tester,
      messages: [
        message('m2', 2, [photo('c')]),
        message('m1', 1, [photo('a'), photo('b')]),
      ],
      messageId: 'm1',
      attachmentId: 'a',
    );

    expect(find.textContaining(counter(1, 3)), findsOneWidget);

    await tester.fling(find.byType(PageView), const Offset(-400, 0), 1000);
    await tester.pumpAndSettle();

    expect(find.textContaining(counter(2, 3)), findsOneWidget);
  });

  testWidgets('a photo can be pinched: it sits in an InteractiveViewer', (
    tester,
  ) async {
    await pump(
      tester,
      messages: [
        message('m1', 1, [photo('a')]),
      ],
      messageId: 'm1',
      attachmentId: 'a',
    );

    expect(find.byType(InteractiveViewer), findsWidgets);
    expect(find.byType(Hero), findsWidgets);
  });

  testWidgets('dragging it down puts it back', (tester) async {
    await pump(
      tester,
      messages: [
        message('m1', 1, [photo('a')]),
      ],
      messageId: 'm1',
      attachmentId: 'a',
    );

    expect(find.byType(MediaViewerScreen), findsOneWidget);

    await tester.drag(find.byType(PageView), const Offset(0, 300));
    await tester.pumpAndSettle();

    expect(find.byType(MediaViewerScreen), findsNothing);
  });

  testWidgets('a short drag is not a dismissal', (tester) async {
    await pump(
      tester,
      messages: [
        message('m1', 1, [photo('a')]),
      ],
      messageId: 'm1',
      attachmentId: 'a',
    );

    await tester.drag(find.byType(PageView), const Offset(0, 40));
    await tester.pumpAndSettle();

    expect(find.byType(MediaViewerScreen), findsOneWidget);
  });

  testWidgets('media outside the loaded window is fetched on its own', (
    tester,
  ) async {
    when(
      () => getMessage.execute(chatId, 'm9'),
    ).thenAnswer((_) async => Right(message('m9', 9, [photo('z')])));

    await pump(tester, messages: const [], messageId: 'm9', attachmentId: 'z');

    // Nothing in the loaded feed to walk, so the message itself is read and
    // shown alone rather than the screen coming up empty.
    verify(() => getMessage.execute(chatId, 'm9')).called(1);
    expect(find.text('Ada Lovelace'), findsOneWidget);
    expect(find.text(l10n.mediaViewerUnavailable), findsNothing);
  });

  testWidgets('media that is genuinely gone says so', (tester) async {
    when(() => getMessage.execute(chatId, 'm9')).thenAnswer(
      (_) async => const Left(
        ApiFailure(
          code: 'NOT_FOUND_MESSAGE',
          message: 'gone',
          detail: null,
          status: 404,
        ),
      ),
    );

    await pump(tester, messages: const [], messageId: 'm9', attachmentId: 'z');

    expect(find.text(l10n.mediaViewerUnavailable), findsOneWidget);
  });

  testWidgets('the same screen in the dark theme', (tester) async {
    await pump(
      tester,
      messages: [
        message('m1', 1, [photo('a')]),
      ],
      messageId: 'm1',
      attachmentId: 'a',
      dark: true,
    );

    expect(find.text('Ada Lovelace'), findsOneWidget);
  });

  group('zoom', () {
    double scaleOf(WidgetTester tester, String attachmentId) => tester
        .widget<InteractiveViewer>(
          find.descendant(
            of: pageOf(attachmentId),
            matching: find.byType(InteractiveViewer),
          ),
        )
        .transformationController!
        .value
        .getMaxScaleOnAxis();

    Future<void> doubleTap(WidgetTester tester, Offset at) async {
      await tester.tapAt(at);
      await tester.pump(const Duration(milliseconds: 60));
      await tester.tapAt(at);
      await tester.pumpAndSettle();
    }

    testWidgets('a double tap zooms in 2.5 times about the tap, and a second '
        'one goes back', (tester) async {
      await pump(
        tester,
        messages: [
          message('m1', 1, [photo('a')]),
        ],
        messageId: 'm1',
        attachmentId: 'a',
      );

      const at = Offset(300, 250);
      await doubleTap(tester, at);

      expect(scaleOf(tester, 'a'), closeTo(2.5, 0.001));
      // The point under the finger is still under the finger.
      final transform = tester
          .widget<InteractiveViewer>(
            find.descendant(
              of: pageOf('a'),
              matching: find.byType(InteractiveViewer),
            ),
          )
          .transformationController!
          .value;
      final viewerOrigin = tester.getTopLeft(
        find.descendant(
          of: pageOf('a'),
          matching: find.byType(InteractiveViewer),
        ),
      );
      final local = at - viewerOrigin;
      expect(
        MatrixUtils.transformPoint(transform, local),
        offsetMoreOrLessEquals(local, epsilon: 0.5),
      );

      await doubleTap(tester, at);

      expect(scaleOf(tester, 'a'), closeTo(1, 0.001));
    });

    testWidgets('it gets there gradually, not in one jump', (tester) async {
      await pump(
        tester,
        messages: [
          message('m1', 1, [photo('a')]),
        ],
        messageId: 'm1',
        attachmentId: 'a',
      );

      await tester.tapAt(const Offset(300, 250));
      await tester.pump(const Duration(milliseconds: 60));
      await tester.tapAt(const Offset(300, 250));
      await tester.pump();
      await tester.pump(AppMotion.base ~/ 2);

      final midway = scaleOf(tester, 'a');
      expect(midway, greaterThan(1));
      expect(midway, lessThan(2.5));
      await tester.pumpAndSettle();
    });

    testWidgets('a zoomed photo is panned, not paged', (tester) async {
      await pump(
        tester,
        messages: [
          message('m2', 2, [photo('b')]),
          message('m1', 1, [photo('a')]),
        ],
        messageId: 'm1',
        attachmentId: 'a',
      );

      await doubleTap(tester, const Offset(300, 250));
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();

      expect(find.textContaining(counter(1, 2)), findsOneWidget);
    });
  });

  group('the bars', () {
    double opacityOf(WidgetTester tester, Type bar) => tester
        .widget<AnimatedOpacity>(
          find.ancestor(
            of: find.byType(bar),
            matching: find.byType(AnimatedOpacity),
          ),
        )
        .opacity;

    testWidgets('a tap on the picture clears them away, another brings them '
        'back', (tester) async {
      await pump(
        tester,
        messages: [
          message('m1', 1, [photo('a')], caption: 'Pier'),
        ],
        messageId: 'm1',
        attachmentId: 'a',
      );

      expect(opacityOf(tester, ViewerTopBar), 1);

      // A single tap is only a single tap once a second one has not come.
      Future<void> tap() async {
        await tester.tapAt(const Offset(400, 300));
        await tester.pump(kDoubleTapTimeout + const Duration(milliseconds: 1));
        await tester.pumpAndSettle();
      }

      await tap();

      expect(opacityOf(tester, ViewerTopBar), 0);
      expect(opacityOf(tester, ViewerBottomBar), 0);

      await tap();

      expect(opacityOf(tester, ViewerTopBar), 1);
    });

    testWidgets('the caption is the message\'s text', (tester) async {
      await pump(
        tester,
        messages: [
          message('m1', 1, [photo('a')], caption: 'From the pier at dusk'),
        ],
        messageId: 'm1',
        attachmentId: 'a',
      );

      expect(find.text('From the pier at dusk'), findsOneWidget);
      expect(find.text(l10n.mediaViewerCaptionMore), findsNothing);
    });

    testWidgets('a long caption is folded, and opens', (tester) async {
      final long = List.filled(40, 'the tide came in over the rocks').join(' ');

      await pump(
        tester,
        messages: [
          message('m1', 1, [photo('a')], caption: long),
        ],
        messageId: 'm1',
        attachmentId: 'a',
      );

      expect(find.text(l10n.mediaViewerCaptionMore), findsOneWidget);
      expect(
        tester.widget<Text>(find.text(long)).maxLines,
        MediaViewerLayout.captionFoldedLines,
      );

      await tester.tap(find.text(l10n.mediaViewerCaptionMore));
      await tester.pumpAndSettle();

      expect(find.text(l10n.mediaViewerCaptionLess), findsOneWidget);
      expect(tester.widget<Text>(find.text(long)).maxLines, isNull);
    });

    testWidgets('a reader without the right to delete is not offered it', (
      tester,
    ) async {
      await pump(
        tester,
        messages: [
          message('m1', 1, [photo('a')]),
        ],
        messageId: 'm1',
        attachmentId: 'a',
      );

      expect(find.byTooltip(l10n.messageForward), findsOneWidget);
      expect(find.byTooltip(l10n.mediaViewerShowInChat), findsOneWidget);
      expect(find.byTooltip(l10n.save), findsOneWidget);
      expect(find.byTooltip(l10n.messageDelete), findsNothing);
    });

    testWidgets('the author is', (tester) async {
      await pump(
        tester,
        messages: [
          message('m1', 1, [photo('a')], authorId: me.id),
        ],
        messageId: 'm1',
        attachmentId: 'a',
      );

      expect(find.byTooltip(l10n.messageDelete), findsOneWidget);
    });
  });

  group('actions', () {
    testWidgets('"show in chat" closes onto the message, lit up', (
      tester,
    ) async {
      final container = await pump(
        tester,
        messages: [
          message('m2', 2, [photo('b')]),
          message('m1', 1, [photo('a')]),
        ],
        messageId: 'm1',
        attachmentId: 'a',
      );

      await tester.tap(find.byTooltip(l10n.mediaViewerShowInChat));
      await tester.pumpAndSettle();

      expect(find.byType(MediaViewerScreen), findsNothing);
      expect(
        container.read(chatDetailProvider(chatId)).value!.highlightMessageId,
        'm1',
      );
    });

    testWidgets('deleting asks first, says the whole album goes, and closes '
        'the strip up', (tester) async {
      when(
        () => deleteMessage.execute(chatId, 'm2'),
      ).thenAnswer((_) async => const Right(null));

      await pump(
        tester,
        messages: [
          message('m3', 3, [photo('d')]),
          message('m2', 2, [photo('b'), photo('c')], authorId: me.id),
          message('m1', 1, [photo('a')]),
        ],
        messageId: 'm2',
        attachmentId: 'c',
      );
      expect(find.textContaining(counter(3, 4)), findsOneWidget);

      await tester.tap(find.byTooltip(l10n.messageDelete));
      await tester.pumpAndSettle();

      expect(find.text(l10n.mediaViewerDeleteAlbum(2)), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, l10n.messageDelete));
      await tester.pumpAndSettle();

      verify(() => deleteMessage.execute(chatId, 'm2')).called(1);
      // Both of the album's photos are gone; the viewer stays open on what
      // came after them.
      expect(find.byType(MediaViewerScreen), findsOneWidget);
      expect(find.textContaining(counter(2, 2)), findsOneWidget);
      expect(pageOf('d'), findsOneWidget);
    });

    testWidgets('saying no deletes nothing', (tester) async {
      await pump(
        tester,
        messages: [
          message('m1', 1, [photo('a')], authorId: me.id),
        ],
        messageId: 'm1',
        attachmentId: 'a',
      );

      await tester.tap(find.byTooltip(l10n.messageDelete));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.cancel));
      await tester.pumpAndSettle();

      verifyNever(() => deleteMessage.execute(any(), any()));
      expect(find.byType(MediaViewerScreen), findsOneWidget);
    });
  });

  group('keyboard and mouse', () {
    final three = [
      message('m3', 3, [photo('c')]),
      message('m2', 2, [photo('b')]),
      message('m1', 1, [photo('a')]),
    ];

    testWidgets('Esc closes it', (tester) async {
      await pump(tester, messages: three, messageId: 'm1', attachmentId: 'a');

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      expect(find.byType(MediaViewerScreen), findsNothing);
    });

    testWidgets('the arrow keys page, and stop at the ends', (tester) async {
      await pump(tester, messages: three, messageId: 'm1', attachmentId: 'a');

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(find.textContaining(counter(2, 3)), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(find.textContaining(counter(3, 3)), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pumpAndSettle();
      expect(find.textContaining(counter(2, 3)), findsOneWidget);
    });

    testWidgets('the mouse wheel pages, one notch at a time', (tester) async {
      await pump(tester, messages: three, messageId: 'm1', attachmentId: 'a');

      final mouse = TestPointer(1, PointerDeviceKind.mouse);
      final centre = tester.getCenter(find.byType(PageView));
      await tester.sendEventToBinding(mouse.hover(centre));

      // Event time, which is what the wheel's one-page-per-gesture rule
      // reads: the test's pointer stamps everything zero otherwise.
      await tester.sendEventToBinding(
        mouse.scroll(
          const Offset(0, 100),
          timeStamp: const Duration(seconds: 1),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining(counter(2, 3)), findsOneWidget);

      // The tail of the same flick, while the page is still turning.
      await tester.sendEventToBinding(
        mouse.scroll(
          const Offset(0, 100),
          timeStamp: const Duration(seconds: 1, milliseconds: 50),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining(counter(2, 3)), findsOneWidget);

      await tester.sendEventToBinding(
        mouse.scroll(
          const Offset(0, -100),
          timeStamp: const Duration(seconds: 2),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining(counter(1, 3)), findsOneWidget);
    });

    testWidgets('the wheel does not zoom', (tester) async {
      await pump(tester, messages: three, messageId: 'm1', attachmentId: 'a');

      final mouse = TestPointer(1, PointerDeviceKind.mouse);
      await tester.sendEventToBinding(
        mouse.hover(tester.getCenter(find.byType(PageView))),
      );
      await tester.sendEventToBinding(mouse.scroll(const Offset(0, -100)));
      await tester.pumpAndSettle();

      final scale = tester
          .widget<InteractiveViewer>(
            find.descendant(
              of: pageOf('a'),
              matching: find.byType(InteractiveViewer),
            ),
          )
          .transformationController!
          .value
          .getMaxScaleOnAxis();
      expect(scale, 1);
    });
  });

  group('on a wide screen', () {
    final three = [
      message('m3', 3, [photo('c')]),
      message('m2', 2, [photo('b')]),
      message('m1', 1, [photo('a')]),
    ];

    testWidgets('a strip of thumbnails walks the media', (tester) async {
      await pump(
        tester,
        messages: three,
        messageId: 'm1',
        attachmentId: 'a',
        window: PaneWindow.desktop,
      );

      expect(find.byType(ViewerThumbnailStrip), findsOneWidget);

      await tester.tap(find.bySemanticsLabel(counter(3, 3)));
      await tester.pumpAndSettle();

      expect(find.textContaining(counter(3, 3)), findsOneWidget);
    });

    testWidgets(
      'and arrows at the sides, only where there is somewhere to go',
      (tester) async {
        await pump(
          tester,
          messages: three,
          messageId: 'm1',
          attachmentId: 'a',
          window: PaneWindow.desktop,
        );

        final previous = find.byTooltip(l10n.mediaViewerPrevious);
        final next = find.byTooltip(l10n.mediaViewerNext);
        expect(
          tester
              .widget<IgnorePointer>(
                find
                    .ancestor(
                      of: previous,
                      matching: find.byType(IgnorePointer),
                    )
                    .first,
              )
              .ignoring,
          isTrue,
        );

        await tester.tap(next);
        await tester.pumpAndSettle();

        expect(find.textContaining(counter(2, 3)), findsOneWidget);
      },
    );

    testWidgets('a phone has neither', (tester) async {
      await pump(
        tester,
        messages: three,
        messageId: 'm1',
        attachmentId: 'a',
        window: PaneWindow.phone,
      );

      expect(find.byType(ViewerThumbnailStrip), findsNothing);
      expect(find.byType(ViewerSideArrow), findsNothing);
    });
  });

  group('video', () {
    testWidgets('plays in the viewer, with its controls', (tester) async {
      final platform = FakeVideoPlayerPlatform();
      VideoPlayerPlatform.instance = platform;

      await pump(
        tester,
        messages: [
          message('m1', 1, [video('v')]),
        ],
        messageId: 'm1',
        attachmentId: 'v',
        settle: false,
      );
      await openVideo(tester);

      expect(platform.playing, isNotEmpty);
      expect(find.byTooltip(l10n.videoPause), findsOneWidget);
      expect(find.text('0:12'), findsOneWidget);

      await tester.tap(find.byTooltip(l10n.videoPause));
      await tester.pump();

      expect(platform.playing, isEmpty);
      expect(find.byTooltip(l10n.videoPlay), findsNWidgets(2));
      await unmount(tester);
    });

    testWidgets('a short one goes round, a long one does not', (tester) async {
      final short = FakeVideoPlayerPlatform(
        duration: const Duration(seconds: 6),
      );
      VideoPlayerPlatform.instance = short;

      await pump(
        tester,
        messages: [
          message('m1', 1, [video('v', seconds: 6)]),
        ],
        messageId: 'm1',
        attachmentId: 'v',
        settle: false,
      );
      await openVideo(tester);
      expect(short.looping.values, [true]);
      await unmount(tester);

      final long = FakeVideoPlayerPlatform(
        duration: const Duration(minutes: 2),
      );
      VideoPlayerPlatform.instance = long;

      await pump(
        tester,
        messages: [
          message('m1', 1, [video('v', seconds: 120)]),
        ],
        messageId: 'm1',
        attachmentId: 'v',
        settle: false,
      );
      await openVideo(tester);
      expect(long.looping.values, [false]);
      await unmount(tester);
    });

    testWidgets('the speed button cycles the speed', (tester) async {
      final platform = FakeVideoPlayerPlatform();
      VideoPlayerPlatform.instance = platform;

      await pump(
        tester,
        messages: [
          message('m1', 1, [video('v')]),
        ],
        messageId: 'm1',
        attachmentId: 'v',
        settle: false,
      );
      await openVideo(tester);

      await tester.tap(find.text('1x'));
      await tester.pump();

      expect(find.text('1.5x'), findsOneWidget);
      expect(platform.speeds.values.last, 1.5);
      await unmount(tester);
    });

    testWidgets('swiping away stops it', (tester) async {
      final platform = FakeVideoPlayerPlatform();
      VideoPlayerPlatform.instance = platform;

      await pump(
        tester,
        messages: [
          message('m2', 2, [photo('p')]),
          message('m1', 1, [video('v')]),
        ],
        messageId: 'm1',
        attachmentId: 'v',
        settle: false,
      );
      await openVideo(tester);
      expect(platform.playing, isNotEmpty);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      // The controller lets go of the platform behind a stream cancel that
      // completes on the real event loop, not the test's fake one.
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump();

      expect(platform.playing, isEmpty);
      expect(platform.disposed, isNotEmpty);
      expect(find.byTooltip(l10n.videoPause), findsNothing);
    });

    testWidgets('a device with no player says so and offers another app', (
      tester,
    ) async {
      VideoPlayerPlatform.instance = FakeVideoPlayerPlatform(failToOpen: true);

      await pump(
        tester,
        messages: [
          message('m1', 1, [video('v')]),
        ],
        messageId: 'm1',
        attachmentId: 'v',
      );

      expect(find.text(l10n.mediaViewerVideoUnplayable), findsOneWidget);
      expect(find.text(l10n.mediaViewerOpenExternally), findsOneWidget);
    });

    testWidgets('Space plays and pauses', (tester) async {
      final platform = FakeVideoPlayerPlatform();
      VideoPlayerPlatform.instance = platform;

      await pump(
        tester,
        messages: [
          message('m1', 1, [video('v')]),
        ],
        messageId: 'm1',
        attachmentId: 'v',
        settle: false,
      );
      await openVideo(tester);

      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pump();

      expect(platform.playing, isEmpty);
    });
  });

  group('goldens', () {
    /// Five pieces of media in four messages: a photo, an album of two with
    /// a long caption, a captioned video, and another photo.
    Future<
      ({
        List<MessageEntity> messages,
        Map<String, File> files,
        Map<String, File> posters,
      })
    >
    gallery() async {
      File picture(String name, int w, int h, int palette) => TestPhotos.write(
        temporary,
        name: name,
        width: w,
        height: h,
        palette: palette,
      );

      final files = {
        'p1': picture('p1', 240, 160, 0),
        'p2': picture('p2', 180, 240, 1),
        'p3': picture('p3', 240, 180, 3),
        'p4': picture('p4', 240, 160, 4),
        'v1': stubImage,
      };
      final posters = {'v1': picture('v1-poster', 256, 144, 2)};

      final messages = [
        message('m4', 4, [photo('p4')], at: DateTime(2026, 3, 2, 8, 5)),
        message(
          'm3',
          3,
          [video('v1')],
          caption: 'Waves, slowed down',
          at: DateTime(2026, 3, 1, 19, 12),
        ),
        message(
          'm2',
          2,
          [
            photo('p2', width: 900, height: 1200),
            photo('p3', width: 1200, height: 900),
          ],
          caption:
              'The pier at the end of the day: the tide was coming in over '
              'the rocks, the gulls had gone quiet, and the last ferry was '
              'still out past the lighthouse. Worth the walk — next time we '
              'should bring the big lens and stay for the stars.',
          at: DateTime(2026, 3, 1, 18, 47),
        ),
        message('m1', 1, [photo('p1')], at: DateTime(2026, 3, 1, 14, 30)),
      ];

      return (messages: messages, files: files, posters: posters);
    }

    for (final window in [PaneWindow.phone, PaneWindow.desktop]) {
      for (final theme in chatGoldenThemes.entries) {
        testGoldens('a photo with its caption, ${window.name}, ${theme.key}', (
          tester,
        ) async {
          final fixture = await tester.runAsync(gallery);
          if (window != PaneWindow.phone) {
            debugDefaultTargetPlatformOverride = TargetPlatform.windows;
          }

          try {
            await pump(
              tester,
              messages: fixture!.messages,
              messageId: 'm2',
              attachmentId: 'p2',
              window: window,
              dark: theme.value,
              role: ChatRole.admin,
              files: fixture.files,
              posters: fixture.posters,
            );
            await loadPictures(tester);

            await screenMatchesGolden(
              tester,
              'media_viewer_photo_${window.name}_${theme.key}',
            );
          } finally {
            debugDefaultTargetPlatformOverride = null;
          }
        });

        testGoldens('a paused video, ${window.name}, ${theme.key}', (
          tester,
        ) async {
          final fixture = await tester.runAsync(gallery);
          VideoPlayerPlatform.instance = FakeVideoPlayerPlatform(
            position: const Duration(seconds: 4),
            buffered: const Duration(seconds: 8),
          );
          if (window != PaneWindow.phone) {
            debugDefaultTargetPlatformOverride = TargetPlatform.windows;
          }

          try {
            await pump(
              tester,
              messages: fixture!.messages,
              messageId: 'm3',
              attachmentId: 'v1',
              window: window,
              dark: theme.value,
              role: ChatRole.admin,
              files: fixture.files,
              posters: fixture.posters,
              settle: false,
            );
            await openVideo(tester);
            await tester.tap(find.byTooltip(l10n.videoPause));
            await tester.pumpAndSettle();
            await loadPictures(tester);

            await screenMatchesGolden(
              tester,
              'media_viewer_video_${window.name}_${theme.key}',
            );
          } finally {
            debugDefaultTargetPlatformOverride = null;
          }
        });
      }
    }
  });
}
