import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:mocktail/mocktail.dart';

import 'package:chatix/core/constants/app_constants.dart';
import 'package:chatix/core/error/failures.dart';
import 'package:chatix/core/localization/app_date_format.dart';
import 'package:chatix/core/notifications/notification_providers.dart';
import 'package:chatix/core/notifications/notification_service.dart';
import 'package:chatix/core/theme/app_theme.dart';
import 'package:chatix/core/theme/theme_config.dart';
import 'package:chatix/core/websocket/chat_socket_service.dart';
import 'package:chatix/features/auth/domain/entities/user_entity.dart';
import 'package:chatix/features/auth/presentation/providers/auth_provider.dart';
import 'package:chatix/features/chat/data/datasources/chat_local_data_source.dart';
import 'package:chatix/features/chat/domain/entities/chat_entity.dart';
import 'package:chatix/features/chat/domain/entities/chat_member_entity.dart';
import 'package:chatix/features/chat/domain/entities/chat_pages.dart';
import 'package:chatix/features/chat/domain/entities/chat_profile_entity.dart';
import 'package:chatix/features/chat/domain/entities/message_entity.dart';
import 'package:chatix/features/chat/domain/usecases/delete_message_use_case.dart';
import 'package:chatix/features/chat/domain/usecases/get_chat_use_case.dart';
import 'package:chatix/features/chat/domain/usecases/get_messages_context_use_case.dart';
import 'package:chatix/features/chat/domain/usecases/get_messages_use_case.dart';
import 'package:chatix/features/chat/domain/usecases/mark_read_use_case.dart';
import 'package:chatix/features/chat/presentation/providers/chat_drafts_provider.dart';
import 'package:chatix/features/chat/presentation/providers/chat_providers.dart';
import 'package:chatix/features/chat/presentation/providers/chat_socket_provider.dart';
import 'package:chatix/features/chat/presentation/screens/chat_detail_screen.dart';
import 'package:chatix/features/chat/presentation/widgets/composer/chat_composer.dart';
import 'package:chatix/features/chat/presentation/widgets/message_bubble.dart';
import 'package:chatix/features/chat/presentation/widgets/message_delete_dialog.dart';
import 'package:chatix/gen/l10n/app_localizations.dart';

import '../../../../helpers/fakes/fake_secure_storage_service.dart';
import '../../../../helpers/fakes/fake_web_socket_channel.dart';
import '../../../../helpers/pane_frame.dart';

class _MockGetChatUseCase extends Mock implements GetChatUseCase {}

class _MockGetMessagesUseCase extends Mock implements GetMessagesUseCase {}

class _MockGetMessagesContextUseCase extends Mock
    implements GetMessagesContextUseCase {}

class _MockMarkReadUseCase extends Mock implements MarkReadUseCase {}

class _MockDeleteMessageUseCase extends Mock implements DeleteMessageUseCase {}

class _MockNotificationService extends Mock implements NotificationService {}

class _FakeAuthController extends AuthController {
  _FakeAuthController(this._user);

  final UserEntity? _user;

  @override
  Future<UserEntity?> build() async => _user;
}

/// The real drafts controller, counting the flushes the screen asks for.
class _RecordingDrafts extends ChatDraftsController {
  int flushes = 0;

  @override
  Future<void> flush() {
    flushes++;
    return super.flush();
  }
}

/// The chat screen itself, not a composition of its parts: what happens
/// when it closes, and how a message leaves it.
void main() {
  const chatId = '8d3f1c2a-5b6e-4f70-9a81-b2c3d4e5f607';
  const me = UserEntity(id: 7, username: 'me', email: 'me@example.com');
  const ada = 42;

  setUpAll(() {
    dotenv.testLoad(fileInput: 'BASE_URL=https://api.example.com');
    registerFallbackValue(
      const MessagesPage(messages: [], nextCursor: null, hasNext: false),
    );
  });

  ChatProfileEntity profile(int userId) => ChatProfileEntity(
    userId: userId,
    username: userId == ada ? 'ada' : 'me',
    displayName: userId == ada ? 'Ada Lovelace' : 'Me',
    avatarUrl: null,
    avatarS3Key: null,
  );

  ChatMemberEntity member(int userId) => ChatMemberEntity(
    userId: userId,
    roleId: ChatRole.member.id,
    isMuted: false,
    isBanned: false,
    permissionsOverrides: const {},
    profile: profile(userId),
  );

  MessageEntity message(int seq, int author, String content) => MessageEntity(
    id: 'm$seq',
    chatId: chatId,
    seq: seq,
    authorId: author,
    type: MessageType.text,
    content: content,
    replyToId: null,
    forwardedFromChatId: null,
    forwardedFromMessageId: null,
    forwardedFromAuthorId: null,
    isEdited: false,
    createdAt: DateTime(2026, 10, 10, 9).add(Duration(minutes: seq)),
    attachments: const [],
    profile: profile(author),
  );

  final conversations = <String, List<MessageEntity>>{
    'en': [
      message(3, me.id, 'Sending it before lunch'),
      message(2, me.id, 'Almost — two sections left'),
      message(1, ada, 'Are the release notes ready?'),
    ],
    'ru': [
      message(3, me.id, 'Отправлю до обеда'),
      message(2, me.id, 'Почти — осталось два раздела'),
      message(1, ada, 'Заметки к релизу готовы?'),
    ],
  };

  ChatEntity chat() => ChatEntity(
    id: chatId,
    seqCounter: 3,
    lastActivityAt: DateTime(2026, 10, 10, 9, 3),
    type: ChatType.group,
    name: 'Release crew',
    description: null,
    avatarS3Key: null,
    isPublic: false,
    adminOnly: false,
    slowModeSeconds: 0,
    permissions: const {},
    createdBy: ada,
    memberCount: 2,
    unreadCount: 0,
    lastRead: ReadDetailEntity(
      lastReadMessageSeq: 3,
      lastReadAt: DateTime(2026, 10, 10, 9, 3),
    ),
    members: [member(me.id), member(ada)],
  );

  late _MockGetChatUseCase getChat;
  late _MockGetMessagesUseCase getMessages;
  late _MockGetMessagesContextUseCase getContext;
  late _MockMarkReadUseCase markRead;
  late _MockDeleteMessageUseCase deleteMessage;
  late _MockNotificationService notifications;
  late FakeWebSocketChannel channel;
  late ChatSocketService socket;

  setUp(() {
    getChat = _MockGetChatUseCase();
    getMessages = _MockGetMessagesUseCase();
    getContext = _MockGetMessagesContextUseCase();
    markRead = _MockMarkReadUseCase();
    deleteMessage = _MockDeleteMessageUseCase();
    notifications = _MockNotificationService();
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
    when(() => notifications.cancelGroup(any())).thenAnswer((_) async {});
    when(
      () => deleteMessage.execute(any(), any()),
    ).thenAnswer((_) async => const Right(null));
  });

  tearDown(() async {
    await socket.dispose();
    await channel.dispose();
  });

  Future<ProviderContainer> pumpChat(
    WidgetTester tester, {
    Locale locale = const Locale('en'),
    PaneWindow window = PaneWindow.phone,
    bool dark = false,
  }) async {
    final messages = conversations[locale.languageCode]!;
    when(() => getChat.execute(chatId)).thenAnswer((_) async => Right(chat()));
    when(
      () => getMessages.execute(chatId, limit: any(named: 'limit')),
    ).thenAnswer(
      (_) async => Right(
        MessagesPage(messages: messages, nextCursor: null, hasNext: false),
      ),
    );

    final container = ProviderContainer(
      // Whatever has no backend here fails once and stays failed, rather
      // than leaving a retry timer behind the test.
      retry: (_, _) => null,
      overrides: [
        getChatUseCaseProvider.overrideWithValue(getChat),
        getMessagesUseCaseProvider.overrideWithValue(getMessages),
        getMessagesContextUseCaseProvider.overrideWithValue(getContext),
        markReadUseCaseProvider.overrideWithValue(markRead),
        deleteMessageUseCaseProvider.overrideWithValue(deleteMessage),
        chatSocketServiceProvider.overrideWithValue(socket),
        notificationServiceProvider.overrideWithValue(notifications),
        authProvider.overrideWith(() => _FakeAuthController(me)),
        chatDraftsProvider.overrideWith(_RecordingDrafts.new),
      ],
    );
    addTearDown(container.dispose);
    await container.read(authProvider.future);

    final appearance = const AppearanceSettings().copyWith(
      wallpaperId: AppWallpaper.plain.id,
    );

    await tester.pumpWidgetBuilder(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: dark ? AppTheme.dark(appearance) : AppTheme.light(appearance),
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) =>
              AppClock(now: DateTime(2026, 10, 10, 12), child: child!),
          home: PaneFrame(
            window: window,
            child: const ChatDetailScreen(chatId: chatId),
          ),
        ),
      ),
      wrapper: (child) => child,
      surfaceSize: window.size,
    );
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    return container;
  }

  /// Long-presses the bubble that says [text] and picks [action] from its
  /// menu.
  Future<void> pickFromMenu(
    WidgetTester tester,
    String text,
    String action,
  ) async {
    await tester.longPress(
      find.descendant(
        of: find.byType(MessageBubble),
        matching: find.text(text),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text(action).last);
    await tester.pumpAndSettle();
  }

  Finder dialogButton(String label) => find.descendant(
    of: find.byType(MessageDeleteDialog),
    matching: find.text(label),
  );

  group('closing the chat', () {
    testWidgets('throws nothing and puts the draft on disk', (tester) async {
      final container = await pumpChat(tester);
      final drafts =
          container.read(chatDraftsProvider.notifier) as _RecordingDrafts;

      await tester.enterText(
        find.descendant(
          of: find.byType(ChatComposer),
          matching: find.byType(EditableText),
        ),
        'half a thought',
      );
      await tester.pump();

      // What leaving the chat does to the screen: it is taken out of the
      // tree. In Riverpod 3 any `ref` in dispose() is a StateError, which
      // used to abort the flush and leak the controllers after it.
      await tester.pumpWidget(const SizedBox());
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(drafts.flushes, 1);
      expect(container.read(chatLocalDataSourceProvider).readDrafts(), {
        chatId: 'half a thought',
      });
    });
  });

  group('deleting a message', () {
    testWidgets('asks first, and says it is gone for everybody', (
      tester,
    ) async {
      await pumpChat(tester);

      await pickFromMenu(tester, 'Sending it before lunch', 'Delete');

      expect(find.byType(MessageDeleteDialog), findsOneWidget);
      expect(find.text('Delete message?'), findsOneWidget);
      expect(
        find.text('It will disappear for all participants.'),
        findsOneWidget,
      );
      verifyNever(() => deleteMessage.execute(any(), any()));
    });

    testWidgets('cancelling deletes nothing', (tester) async {
      await pumpChat(tester);

      await pickFromMenu(tester, 'Sending it before lunch', 'Delete');
      await tester.tap(dialogButton('Cancel'));
      await tester.pumpAndSettle();

      verifyNever(() => deleteMessage.execute(any(), any()));
      expect(find.text('Sending it before lunch'), findsOneWidget);
    });

    testWidgets('confirming deletes it, and says nothing more', (tester) async {
      await pumpChat(tester);

      await pickFromMenu(tester, 'Sending it before lunch', 'Delete');
      await tester.tap(dialogButton('Delete'));
      await tester.pumpAndSettle();

      verify(() => deleteMessage.execute(chatId, 'm3')).called(1);
      expect(find.text('Sending it before lunch'), findsNothing);
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('a refusal is reported in the reader\'s words', (tester) async {
      when(() => deleteMessage.execute(chatId, 'm3')).thenAnswer(
        (_) async => const Left(
          ApiFailure(
            code: 'CHAT_ACCESS_DENIED',
            message: 'Access denied for chat',
            detail: {'chat_id': chatId, 'requester_id': 7},
            status: 403,
          ),
        ),
      );
      await pumpChat(tester, locale: const Locale('ru'));

      await pickFromMenu(tester, 'Отправлю до обеда', 'Удалить');
      await tester.tap(dialogButton('Удалить'));
      await tester.pumpAndSettle();

      final snackBar = find.byType(SnackBar);
      expect(snackBar, findsOneWidget);
      expect(
        find.descendant(
          of: snackBar,
          matching: find.text('У вас нет прав на это действие.'),
        ),
        findsOneWidget,
      );
      // Not the server's English, and the message is still there.
      expect(find.textContaining('Access denied'), findsNothing);
      expect(find.text('Отправлю до обеда'), findsOneWidget);
    });

    testWidgets('a selection goes the same way: one question, one report', (
      tester,
    ) async {
      when(() => deleteMessage.execute(chatId, 'm2')).thenAnswer(
        (_) async => const Left(
          ApiFailure(
            code: 'NOT_FOUND_MESSAGE',
            message: 'Message not found',
            detail: {'message_id': 'm2'},
            status: 404,
          ),
        ),
      );
      await pumpChat(tester);

      await pickFromMenu(tester, 'Sending it before lunch', 'Select');
      await tester.tap(find.text('Almost — two sections left'));
      await tester.pumpAndSettle();
      expect(find.text('2 selected'), findsOneWidget);

      await tester.tap(find.byTooltip('Delete'));
      await tester.pumpAndSettle();

      expect(find.text('Delete 2 messages?'), findsOneWidget);
      expect(
        find.text('They will disappear for all participants.'),
        findsOneWidget,
      );

      await tester.tap(dialogButton('Delete'));
      await tester.pumpAndSettle();

      verify(() => deleteMessage.execute(chatId, 'm3')).called(1);
      verify(() => deleteMessage.execute(chatId, 'm2')).called(1);
      expect(find.text('Sending it before lunch'), findsNothing);
      expect(find.text('Almost — two sections left'), findsOneWidget);
      expect(
        find.text(
          '1 of 2 succeeded — 1 failed: '
          "We couldn't find that — it may have been deleted.",
        ),
        findsOneWidget,
      );
      // The bar is back to the chat's own.
      expect(find.text('2 selected'), findsNothing);
    });
  });

  group('goldens', () {
    for (final window in [PaneWindow.phone, PaneWindow.desktop]) {
      for (final theme in {'light': false, 'dark': true}.entries) {
        testGoldens('delete dialog, ${window.name}, ${theme.key}', (
          tester,
        ) async {
          await pumpChat(
            tester,
            locale: const Locale('ru'),
            window: window,
            dark: theme.value,
          );

          await pickFromMenu(tester, 'Отправлю до обеда', 'Удалить');

          await screenMatchesGolden(
            tester,
            'chat_delete_message_${window.name}_${theme.key}',
          );
        });
      }
    }
  });
}
