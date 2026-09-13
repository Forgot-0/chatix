import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

import 'package:chatix/core/constants/app_constants.dart';
import 'package:chatix/core/error/failures.dart';
import 'package:chatix/core/theme/app_theme.dart';
import 'package:chatix/core/websocket/chat_socket_service.dart';
import 'package:chatix/features/auth/domain/entities/user_entity.dart';
import 'package:chatix/features/auth/presentation/providers/auth_provider.dart';
import 'package:chatix/features/chat/domain/entities/attachment_entity.dart';
import 'package:chatix/features/chat/domain/entities/chat_entity.dart';
import 'package:chatix/features/chat/domain/entities/chat_pages.dart';
import 'package:chatix/features/chat/domain/entities/chat_profile_entity.dart';
import 'package:chatix/features/chat/domain/entities/message_entity.dart';
import 'package:chatix/features/chat/domain/usecases/get_chat_use_case.dart';
import 'package:chatix/features/chat/domain/usecases/get_messages_context_use_case.dart';
import 'package:chatix/features/chat/domain/usecases/get_message_use_case.dart';
import 'package:chatix/features/chat/domain/usecases/get_messages_use_case.dart';
import 'package:chatix/features/chat/domain/usecases/mark_read_use_case.dart';
import 'package:chatix/features/chat/presentation/providers/attachment_file_provider.dart';
import 'package:chatix/features/chat/presentation/providers/chat_detail_provider.dart';
import 'package:chatix/features/chat/presentation/providers/chat_providers.dart';
import 'package:chatix/features/chat/presentation/providers/chat_socket_provider.dart';
import 'package:chatix/features/chat/presentation/screens/media_viewer_screen.dart';
import 'package:chatix/gen/l10n/app_localizations.dart';

import '../../../../helpers/chat_golden.dart';
import '../../../../helpers/fakes/fake_secure_storage_service.dart';
import '../../../../helpers/fakes/fake_web_socket_channel.dart';

class MockGetChatUseCase extends Mock implements GetChatUseCase {}

class MockGetMessagesUseCase extends Mock implements GetMessagesUseCase {}

class MockGetMessagesContextUseCase extends Mock
    implements GetMessagesContextUseCase {}

class MockMarkReadUseCase extends Mock implements MarkReadUseCase {}

class MockGetMessageUseCase extends Mock implements GetMessageUseCase {}

class FakeAuthController extends AuthController {
  FakeAuthController(this._user);

  final UserEntity? _user;

  @override
  Future<UserEntity?> build() async => _user;
}

/// The viewer as the reader meets it: whose photo it is, where it sits in
/// the chat's media, and the two ways back out.
void main() {
  const chatId = '550e8400-e29b-41d4-a716-446655440000';
  const me = UserEntity(id: 7, username: 'me', email: 'me@example.com');

  late MockGetChatUseCase getChat;
  late MockGetMessagesUseCase getMessages;
  late MockGetMessagesContextUseCase getContext;
  late MockMarkReadUseCase markRead;
  late MockGetMessageUseCase getMessage;
  late ChatSocketService socket;
  late Directory temporary;
  late File stubImage;
  late AppLocalizations l10n;

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
  });

  tearDown(() {
    if (temporary.existsSync()) temporary.deleteSync(recursive: true);
  });

  AttachmentEntity photo(String id) => AttachmentEntity(
    id: id,
    messageId: null,
    chatId: chatId,
    uploaderId: 42,
    attachmentType: AttachmentType.image,
    attachmentStatus: AttachmentStatus.success,
    url: null,
    urlExpiresIn: null,
    s3Key: 'chats/$chatId/$id/photo.png',
    mimeType: 'image/png',
    originalFilename: '$id.png',
    size: 2048,
    width: 1200,
    height: 800,
    durationSeconds: null,
    createdAt: DateTime.utc(2026, 3, 1, 9),
  );

  MessageEntity message(
    String id,
    int seq,
    List<AttachmentEntity> attachments,
  ) => MessageEntity(
    id: id,
    chatId: chatId,
    seq: seq,
    authorId: 42,
    type: MessageType.image,
    content: null,
    replyToId: null,
    forwardedFromChatId: null,
    forwardedFromMessageId: null,
    forwardedFromAuthorId: null,
    isEdited: false,
    createdAt: DateTime.utc(2026, 3, 1, 9),
    attachments: attachments,
    profile: const ChatProfileEntity(
      userId: 42,
      username: 'ada',
      displayName: 'Ada Lovelace',
      avatarUrl: null,
      avatarS3Key: null,
    ),
  );

  ChatEntity chat() => ChatEntity(
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
  );

  /// Opens the viewer over a feed holding [messages], the way the bubble
  /// does.
  Future<ProviderContainer> pump(
    WidgetTester tester, {
    required List<MessageEntity> messages,
    required String attachmentId,
    required String messageId,
    bool dark = false,
  }) async {
    when(() => getChat.execute(chatId)).thenAnswer((_) async => Right(chat()));
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
        chatSocketServiceProvider.overrideWithValue(socket),
        authProvider.overrideWith(() => FakeAuthController(me)),
        // The bytes are beside the point here; that they come from the cache
        // rather than from a link is the point, and that is the seam.
        attachmentFileProvider.overrideWith((ref, key) async => stubImage),
      ],
    );
    addTearDown(container.dispose);

    await container.read(authProvider.future);
    container.listen(chatDetailProvider(chatId), (_, _) {});
    await container.read(chatDetailProvider(chatId).future);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: dark ? AppTheme.darkTheme : AppTheme.lightTheme,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: MediaViewerScreen(
            chatId: chatId,
            messageId: messageId,
            attachmentId: attachmentId,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    return container;
  }

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

    expect(
      find.textContaining(l10n.mediaViewerCounter(2, 3)),
      findsOneWidget,
    );
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

    expect(
      find.textContaining(l10n.mediaViewerCounter(1, 3)),
      findsOneWidget,
    );

    await tester.fling(find.byType(PageView), const Offset(-400, 0), 1000);
    await tester.pumpAndSettle();

    expect(
      find.textContaining(l10n.mediaViewerCounter(2, 3)),
      findsOneWidget,
    );
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

    await pump(
      tester,
      messages: const [],
      messageId: 'm9',
      attachmentId: 'z',
    );

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

    await pump(
      tester,
      messages: const [],
      messageId: 'm9',
      attachmentId: 'z',
    );

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
}
