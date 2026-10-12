import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

import 'package:chatix/core/localization/app_date_format.dart';
import 'package:chatix/core/router/app_layout.dart';
import 'package:chatix/core/theme/app_theme.dart';
import 'package:chatix/core/storage/key_value_table.dart';
import 'package:chatix/core/theme/app_theme_extension.dart';
import 'package:chatix/core/theme/app_tokens.dart';
import 'package:chatix/features/auth/domain/entities/user_entity.dart';
import 'package:chatix/features/auth/presentation/providers/auth_provider.dart';
import 'package:chatix/features/chat/data/datasources/chat_local_prefs_store.dart';
import 'package:chatix/features/chat/domain/entities/chat_entity.dart';
import 'package:chatix/features/chat/domain/entities/chat_member_entity.dart';
import 'package:chatix/features/chat/domain/entities/chat_pages.dart';
import 'package:chatix/features/chat/domain/entities/chat_profile_entity.dart';
import 'package:chatix/features/chat/domain/entities/message_entity.dart';
import 'package:chatix/features/chat/domain/usecases/get_members_use_case.dart';
import 'package:chatix/features/chat/domain/usecases/update_chat_state_use_case.dart';
import 'package:chatix/features/chat/presentation/providers/chat_drafts_provider.dart';
import 'package:chatix/features/chat/presentation/providers/chat_local_prefs_provider.dart';
import 'package:chatix/features/chat_organizer/data/datasources/chat_organizer_local_data_source.dart';
import 'package:chatix/features/contacts/data/datasources/block_list_local_store.dart';
import 'package:chatix/features/contacts/data/datasources/contacts_local_store.dart';
import 'package:chatix/features/contacts/domain/entities/blocked_user.dart';
import 'package:chatix/features/contacts/domain/entities/contact.dart';
import 'package:chatix/features/contacts/domain/entities/contact_sync.dart';
import 'package:chatix/features/chat_organizer/presentation/providers/chat_organizer_provider.dart';
import 'package:chatix/features/chat_organizer/presentation/providers/chat_organizer_providers.dart';
import 'package:chatix/features/chat/presentation/providers/chat_providers.dart';
import 'package:chatix/features/chat/presentation/widgets/chat_avatar.dart';
import 'package:chatix/features/chat/presentation/widgets/chat_list_tile.dart';
import 'package:chatix/features/chat/presentation/widgets/chat_type_glyph.dart';
import 'package:chatix/features/chat/presentation/widgets/status_ticks.dart';
import 'package:chatix/gen/l10n/app_localizations.dart';
import 'package:chatix/gen/l10n/app_localizations_en.dart';
import 'package:chatix/gen/l10n/app_localizations_ru.dart';

import '../../../../helpers/pane_frame.dart';

class MockGetMembersUseCase extends Mock implements GetMembersUseCase {}

class MockUpdateChatStateUseCase extends Mock
    implements UpdateChatStateUseCase {}

class FakeAuthController extends AuthController {
  FakeAuthController(this._user);

  final UserEntity? _user;

  @override
  Future<UserEntity?> build() async => _user;
}

void main() {
  final l10n = AppLocalizationsEn();

  const myUserId = 7;
  const peerId = 9;
  const chatId = 'c1';

  const me = UserEntity(id: myUserId, username: 'me', email: 'me@example.com');

  late MockGetMembersUseCase getMembers;
  late MockUpdateChatStateUseCase updateState;
  late InMemoryChatLocalPrefsStore store;

  setUp(() {
    getMembers = MockGetMembersUseCase();
    updateState = MockUpdateChatStateUseCase();
    store = InMemoryChatLocalPrefsStore();

    when(
      () => updateState.setArchived(any(), archived: any(named: 'archived')),
    ).thenAnswer((_) async => const Right(ChatStateEntity(isArchived: true)));
    when(
      () => updateState.setPinned(any(), pinned: any(named: 'pinned')),
    ).thenAnswer((_) async => const Right(ChatStateEntity(isPinned: true)));
    when(
      () => updateState.mute(any(), until: any(named: 'until')),
    ).thenAnswer((_) async => const Right(ChatStateEntity(isMutedByMe: true)));
    when(
      () => updateState.unmute(any()),
    ).thenAnswer((_) async => const Right(ChatStateEntity()));
    when(() => updateState.setDraft(any(), any())).thenAnswer(
      (invocation) async => Right(
        ChatStateEntity(
          draft: invocation.positionalArguments[1] as String?,
          draftUpdatedAt: DateTime.utc(2026, 1, 1, 12),
        ),
      ),
    );

    when(
      () => getMembers.execute(
        any(),
        limit: any(named: 'limit'),
        includePresence: any(named: 'includePresence'),
      ),
    ).thenAnswer(
      (_) async => const Right(
        MembersPage(
          members: [
            ChatMemberEntity(
              userId: peerId,
              roleId: 4,
              isMuted: false,
              isBanned: false,
              permissionsOverrides: {},
            ),
          ],
          hasNext: false,
          nextUserId: null,
          presence: [MemberPresenceEntity(userId: peerId, isOnline: true)],
        ),
      ),
    );
  });

  MessageEntity message({
    String? content,
    int authorId = peerId,
    int seq = 5,
  }) => MessageEntity(
    id: 'm1',
    chatId: chatId,
    seq: seq,
    authorId: authorId,
    type: MessageType.text,
    content: content,
    replyToId: null,
    forwardedFromChatId: null,
    forwardedFromMessageId: null,
    forwardedFromAuthorId: null,
    isEdited: false,
    createdAt: DateTime.utc(2026, 1, 1),
    profile: ChatProfileEntity(
      userId: authorId,
      username: 'ann',
      displayName: authorId == myUserId ? 'Me' : 'Ann',
      avatarUrl: null,
      avatarS3Key: null,
    ),
  );

  ChatEntity chat({
    ChatType type = ChatType.group,
    String? name = 'Design team',
    int unread = 0,
    MessageEntity? last,
    ChatMemberEntity? membership,
    bool pinned = false,
    bool muted = false,
    DateTime? at,
  }) => ChatEntity(
    id: chatId,
    seqCounter: 9,
    lastActivityAt: at ?? DateTime.now(),
    type: type,
    name: name,
    description: null,
    avatarS3Key: null,
    isPublic: false,
    adminOnly: false,
    slowModeSeconds: 0,
    permissions: const {},
    createdBy: myUserId,
    memberCount: 3,
    unreadCount: unread,
    lastMessage: last,
    me: membership,
    // Pinned and silenced ride on the row now (api-docs §5.2).
    state: pinned || muted
        ? ChatStateEntity(isPinned: pinned, isMutedByMe: muted)
        : null,
  );

  ChatMemberEntity membership(ChatRole role) => ChatMemberEntity(
    userId: myUserId,
    roleId: role.id,
    isMuted: false,
    isBanned: false,
    permissionsOverrides: const {},
  );

  Future<void> pumpTile(
    WidgetTester tester,
    ChatEntity value, {
    int? peerReadSeq,
    String? draft,
    bool dark = false,
    List<Contact> contacts = const [],
  }) async {
    final book = KeyValueContactsLocalStore(MemoryKeyValueTable());
    if (contacts.isNotEmpty) {
      await book.save(ContactsSnapshot(ownerId: myUserId, contacts: contacts));
    }

    final container = ProviderContainer(
      overrides: [
        contactsLocalStoreProvider.overrideWithValue(book),
        chatLocalPrefsStoreProvider.overrideWithValue(store),
        chatOrganizerDataSourceProvider.overrideWithValue(
          InMemoryChatOrganizerDataSource(),
        ),
        getMembersUseCaseProvider.overrideWithValue(getMembers),
        updateChatStateUseCaseProvider.overrideWithValue(updateState),
        authProvider.overrideWith(() => FakeAuthController(me)),
      ],
    );
    addTearDown(container.dispose);

    await container.read(authProvider.future);
    await container.read(chatOrganizerProvider.future);
    if (draft != null) {
      final drafts = container.read(chatDraftsProvider.notifier);
      drafts.save(value.id, draft);
      // Settles the debounced write so no timer outlives the test.
      await drafts.flush();
    }

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: dark ? AppTheme.darkTheme : AppTheme.lightTheme,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: ChatListTile(chat: value, peerReadSeq: peerReadSeq),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('a group row names the chat and credits the last speaker', (
    tester,
  ) async {
    await pumpTile(tester, chat(last: message(content: 'ship it')));

    expect(find.text('Design team'), findsOneWidget);
    expect(find.textContaining('Ann: ship it'), findsOneWidget);
  });

  testWidgets('a group carries its type glyph, a direct chat does not', (
    tester,
  ) async {
    await pumpTile(tester, chat(last: message(content: 'hi')));
    expect(find.byType(ChatTypeGlyph), findsOneWidget);

    await pumpTile(
      tester,
      chat(
        type: ChatType.direct,
        name: 'Ann',
        last: message(content: 'hi'),
      ),
    );
    expect(find.byType(ChatTypeGlyph), findsNothing);
  });

  group('the address book', () {
    Contact ann({String? firstName}) => Contact(
      ownerId: myUserId,
      userId: peerId,
      firstName: firstName,
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 1, 1),
      profile: const ContactProfile(
        id: peerId,
        username: 'ann',
        displayName: 'Ann',
      ),
    );

    testWidgets('a direct row goes by the name the reader gave the peer', (
      tester,
    ) async {
      await pumpTile(
        tester,
        chat(
          type: ChatType.direct,
          name: null,
          last: message(content: 'hi'),
        ),
        contacts: [ann(firstName: 'Аня с работы')],
      );

      expect(find.text('Аня с работы'), findsOneWidget);
      expect(find.text('Ann'), findsNothing);
      // The face is initialled to match the name beside it.
      expect(
        find.descendant(of: find.byType(ChatAvatar), matching: find.text('А')),
        findsOneWidget,
      );

      await tester.longPress(find.byType(ChatListTile));
      await tester.pumpAndSettle();
      expect(find.text('Аня с работы'), findsNWidgets(2));
    });

    testWidgets('a contact with no local name keeps their own', (tester) async {
      await pumpTile(
        tester,
        chat(
          type: ChatType.direct,
          name: null,
          last: message(content: 'hi'),
        ),
        contacts: [ann()],
      );

      expect(find.text('Ann'), findsOneWidget);
    });

    testWidgets('a group keeps its own name whoever is in the book', (
      tester,
    ) async {
      await pumpTile(
        tester,
        chat(last: message(content: 'hi')),
        contacts: [ann(firstName: 'Аня')],
      );

      expect(find.text('Design team'), findsOneWidget);
      expect(find.text('Аня'), findsNothing);
    });
  });

  testWidgets('a draft replaces the preview and says so', (tester) async {
    await pumpTile(
      tester,
      chat(last: message(content: 'ship it')),
      draft: 'on my way',
    );

    expect(find.textContaining(l10n.draftLabel), findsOneWidget);
    expect(find.textContaining('on my way'), findsOneWidget);
    expect(find.textContaining('ship it'), findsNothing);
  });

  testWidgets('a draft typed on another device shows from the row', (
    tester,
  ) async {
    await pumpTile(
      tester,
      chat(last: message(content: 'ship it')).copyWith(
        state: ChatStateEntity(
          draft: 'from the laptop',
          draftUpdatedAt: DateTime.utc(2026, 1, 1, 10),
        ),
      ),
    );

    expect(find.textContaining(l10n.draftLabel), findsOneWidget);
    expect(find.textContaining('from the laptop'), findsOneWidget);
  });

  testWidgets('a newer draft on this device beats the row copy', (
    tester,
  ) async {
    // Typed here just now; the row's copy is from the start of the year.
    await pumpTile(
      tester,
      chat(last: message(content: 'ship it')).copyWith(
        state: ChatStateEntity(
          draft: 'from the laptop',
          draftUpdatedAt: DateTime.utc(2026, 1, 1, 10),
        ),
      ),
      draft: 'from the phone',
    );

    expect(find.textContaining('from the phone'), findsOneWidget);
    expect(find.textContaining('from the laptop'), findsNothing);
  });

  testWidgets('an unread count shows as a badge', (tester) async {
    await pumpTile(tester, chat(unread: 4, last: message(content: 'hi')));

    expect(find.text('4'), findsOneWidget);
  });

  testWidgets('a silenced chat keeps the count and shows the bell', (
    tester,
  ) async {
    await pumpTile(
      tester,
      chat(unread: 4, last: message(content: 'hi'), muted: true),
    );

    expect(find.text('4'), findsOneWidget);
    expect(find.byIcon(Icons.notifications_off_outlined), findsOneWidget);
  });

  testWidgets('a pinned chat with nothing unread shows the pin', (
    tester,
  ) async {
    await pumpTile(tester, chat(last: message(content: 'hi'), pinned: true));

    expect(find.byIcon(Icons.push_pin), findsOneWidget);
  });

  group('delivery ticks', () {
    testWidgets('none on somebody else\'s message', (tester) async {
      await pumpTile(tester, chat(last: message(content: 'hi')));

      expect(find.byType(StatusTicks), findsNothing);
    });

    testWidgets('one tick on my own message with no read news', (tester) async {
      await pumpTile(
        tester,
        chat(
          type: ChatType.direct,
          name: 'Ann',
          last: message(content: 'hi', authorId: myUserId),
        ),
      );

      expect(
        tester.widget<StatusTicks>(find.byType(StatusTicks)).status,
        MessageDeliveryStatus.sent,
      );
    });

    testWidgets('two ticks once the other side has read past it', (
      tester,
    ) async {
      await pumpTile(
        tester,
        chat(
          type: ChatType.direct,
          name: 'Ann',
          last: message(content: 'hi', authorId: myUserId, seq: 5),
        ),
        peerReadSeq: 5,
      );

      expect(
        tester.widget<StatusTicks>(find.byType(StatusTicks)).status,
        MessageDeliveryStatus.read,
      );
    });

    testWidgets('a group never claims more than sent', (tester) async {
      await pumpTile(
        tester,
        chat(
          last: message(content: 'hi', authorId: myUserId, seq: 5),
        ),
        peerReadSeq: 5,
      );

      expect(
        tester.widget<StatusTicks>(find.byType(StatusTicks)).status,
        MessageDeliveryStatus.sent,
      );
    });
  });

  testWidgets('a direct row shows the other side as online once known', (
    tester,
  ) async {
    await pumpTile(
      tester,
      chat(
        type: ChatType.direct,
        name: 'Ann',
        last: message(content: 'hi'),
      ),
    );

    await tester.pump();

    expect(tester.widget<ChatAvatar>(find.byType(ChatAvatar)).isOnline, isTrue);
  });

  testWidgets('presence is not fetched for a group', (tester) async {
    await pumpTile(tester, chat(last: message(content: 'hi')));
    await tester.pump();

    verifyNever(
      () => getMembers.execute(
        any(),
        limit: any(named: 'limit'),
        includePresence: any(named: 'includePresence'),
      ),
    );
  });

  group('the long-press menu', () {
    testWidgets('offers the same actions the swipes do', (tester) async {
      await pumpTile(tester, chat(unread: 2, last: message(content: 'hi')));

      await tester.longPress(find.text('Design team'));
      await tester.pumpAndSettle();

      expect(find.text(l10n.markAsRead), findsOneWidget);
      expect(find.text(l10n.pinChat), findsOneWidget);
      expect(find.text(l10n.archiveChat), findsOneWidget);
      expect(find.text(l10n.muteChat), findsOneWidget);
    });

    testWidgets('hides "mark as read" when there is nothing unread', (
      tester,
    ) async {
      await pumpTile(tester, chat(last: message(content: 'hi')));

      await tester.longPress(find.text('Design team'));
      await tester.pumpAndSettle();

      expect(find.text(l10n.markAsRead), findsNothing);
    });

    testWidgets('offers delete only to a member who holds chat:delete', (
      tester,
    ) async {
      await pumpTile(
        tester,
        chat(
          last: message(content: 'hi'),
          membership: membership(ChatRole.member),
        ),
      );

      await tester.longPress(find.text('Design team'));
      await tester.pumpAndSettle();
      expect(find.text(l10n.deleteChat), findsNothing);

      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      await pumpTile(
        tester,
        chat(
          last: message(content: 'hi'),
          membership: membership(ChatRole.owner),
        ),
      );

      await tester.longPress(find.text('Design team'));
      await tester.pumpAndSettle();
      expect(find.text(l10n.deleteChat), findsOneWidget);
    });

    testWidgets('archiving from the menu offers a way back', (tester) async {
      await pumpTile(tester, chat(last: message(content: 'hi')));

      await tester.longPress(find.text('Design team'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.archiveChat));
      await tester.pumpAndSettle();

      expect(find.text(l10n.chatArchivedToast), findsOneWidget);
      expect(find.text(l10n.undo), findsOneWidget);
    });
  });

  group('the right-click menu', () {
    Future<void> rightClick(WidgetTester tester, Offset at) async {
      await tester.tapAt(
        at,
        buttons: kSecondaryMouseButton,
        kind: PointerDeviceKind.mouse,
      );
      await tester.pumpAndSettle();
    }

    testWidgets('offers what the long press does, at the pointer', (
      tester,
    ) async {
      await pumpTile(
        tester,
        chat(
          unread: 2,
          last: message(content: 'hi'),
          membership: membership(ChatRole.owner),
        ),
      );
      final at = tester.getCenter(find.text('Design team'));

      await rightClick(tester, at);

      final items = tester
          .widgetList<PopupMenuItem<ChatRowAction>>(
            find.byType(PopupMenuItem<ChatRowAction>),
          )
          .map((item) => item.value)
          .toList();
      expect(items, [
        ChatRowAction.markRead,
        ChatRowAction.pin,
        ChatRowAction.archive,
        ChatRowAction.mute,
        ChatRowAction.delete,
      ]);
      // A popup by the pointer, not a sheet from the bottom of the window.
      expect(find.byType(BottomSheet), findsNothing);
      final menu = tester.getRect(
        find.byType(PopupMenuItem<ChatRowAction>).first,
      );
      // Growing right of the pointer, or left of it in the window's right
      // half, as Material's menus do.
      expect(
        [menu.left, menu.right].any((edge) => (edge - at.dx).abs() < 1),
        isTrue,
      );
      expect((menu.top - at.dy).abs(), lessThan(AppSpacing.x6));
    });

    testWidgets('does what it says', (tester) async {
      await pumpTile(tester, chat(last: message(content: 'hi')));

      await rightClick(tester, tester.getCenter(find.text('Design team')));
      await tester.tap(find.text(l10n.archiveChat));
      await tester.pumpAndSettle();

      expect(find.text(l10n.chatArchivedToast), findsOneWidget);
    });

    testWidgets('is not on a row that is only a search result', (tester) async {
      final container = ProviderContainer(
        overrides: [
          chatLocalPrefsStoreProvider.overrideWithValue(store),
          chatOrganizerDataSourceProvider.overrideWithValue(
            InMemoryChatOrganizerDataSource(),
          ),
          getMembersUseCaseProvider.overrideWithValue(getMembers),
          updateChatStateUseCaseProvider.overrideWithValue(updateState),
          authProvider.overrideWith(() => FakeAuthController(me)),
        ],
      );
      addTearDown(container.dispose);
      await container.read(authProvider.future);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: ChatListTile(
                chat: chat(last: message(content: 'hi')),
                enableActions: false,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      await rightClick(tester, tester.getCenter(find.text('Design team')));

      expect(find.byType(PopupMenuItem<ChatRowAction>), findsNothing);
    });
  });

  testWidgets('the row is drawn on both grounds', (tester) async {
    await pumpTile(tester, chat(unread: 2, last: message(content: 'hi')));
    expect(tester.takeException(), isNull);

    await pumpTile(
      tester,
      chat(unread: 2, last: message(content: 'hi')),
      dark: true,
    );
    expect(tester.takeException(), isNull);
  });

  // The stamp reads the same clock as the bubbles: "09:02" today, a word for
  // yesterday, a capitalised weekday this week, a date before that.
  group('goldens', () {
    // A Saturday, so six days back is a Sunday — "Вс".
    final now = DateTime(2026, 10, 10, 12);

    List<ChatEntity> rows() => [
      chat(
        type: ChatType.direct,
        name: 'Ада',
        unread: 2,
        at: DateTime(2026, 10, 10, 9, 2),
        last: message(content: 'Кто берёт палатку?'),
      ),
      chat(
        name: 'Поход на Кавказ',
        at: DateTime(2026, 10, 9, 21, 40),
        last: message(content: 'Маршрут готов', authorId: myUserId),
      ),
      chat(
        type: ChatType.direct,
        name: 'Грейс',
        at: DateTime(2026, 10, 4, 18, 5),
        last: message(content: 'До встречи в воскресенье'),
        muted: true,
      ),
      chat(
        name: 'Архив проекта',
        at: DateTime(2025, 3, 2, 10, 15),
        last: message(content: 'Итоги года'),
        pinned: true,
      ),
    ];

    Future<void> pumpList(
      WidgetTester tester, {
      required Size window,
      required bool dark,
      List<ChatEntity>? items,
      Set<int> blocked = const {},
    }) async {
      tester.view.physicalSize = window;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final container = ProviderContainer(
        overrides: [
          chatLocalPrefsStoreProvider.overrideWithValue(store),
          chatOrganizerDataSourceProvider.overrideWithValue(
            InMemoryChatOrganizerDataSource(),
          ),
          getMembersUseCaseProvider.overrideWithValue(getMembers),
          updateChatStateUseCaseProvider.overrideWithValue(updateState),
          authProvider.overrideWith(() => FakeAuthController(me)),
          blockListLocalStoreProvider.overrideWithValue(
            MemoryBlockListLocalStore(
              BlockList(ownerId: myUserId, userIds: blocked),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
      await container.read(authProvider.future);
      await container.read(chatOrganizerProvider.future);

      final list = Column(
        children: [
          for (final row in items ?? rows())
            ChatListTile(chat: row, peerReadSeq: 9),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: dark ? AppTheme.darkTheme : AppTheme.lightTheme,
            locale: const Locale('ru'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: AppClock(
              now: now,
              child: Scaffold(
                body: window.width < AppBreakpoints.medium
                    ? list
                    // The list as the desktop shell draws it: after the
                    // rail, 360 px wide, the open chat beside it.
                    : Builder(
                        builder: (context) {
                          final scheme = Theme.of(context).colorScheme;
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              SizedBox(
                                width: PaneWindow.rail,
                                child: ColoredBox(
                                  color: scheme.surfaceContainer,
                                ),
                              ),
                              const VerticalDivider(width: 1, thickness: 1),
                              SizedBox(
                                width: AppBreakpoints.listPaneWidth,
                                child: list,
                              ),
                              const VerticalDivider(width: 1, thickness: 1),
                              Expanded(
                                child: ColoredBox(
                                  color: ChatixTheme.of(context).chatBackground,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    }

    for (final window in [PaneWindow.phone, PaneWindow.desktop]) {
      for (final dark in [false, true]) {
        final name = '${window.name}_${dark ? 'dark' : 'light'}';

        testWidgets('chat list stamps, $name', (tester) async {
          await pumpList(tester, window: window.size, dark: dark);

          expect(find.text('09:02'), findsOneWidget);
          expect(find.text('Вчера'), findsOneWidget);
          expect(find.text('Вс'), findsOneWidget);
          expect(find.text('02.03.25'), findsOneWidget);

          await expectLater(
            find.byType(MaterialApp),
            matchesGoldenFile('goldens/chat_list_stamps_$name.png'),
          );
        });

        // Right-clicked on a desktop: the row lit under the pointer, the
        // menu beside it.
        testWidgets('the right-click menu, $name', (tester) async {
          await pumpList(tester, window: window.size, dark: dark);

          await tester.tapAt(
            tester.getCenter(find.text('Поход на Кавказ')),
            buttons: kSecondaryMouseButton,
            kind: PointerDeviceKind.mouse,
          );
          await tester.pumpAndSettle();

          expect(find.byType(PopupMenuItem<ChatRowAction>), findsWidgets);
          await expectLater(
            find.byType(MaterialApp),
            matchesGoldenFile('goldens/chat_list_context_menu_$name.png'),
          );
        });

        // A blocked person's chat between two ordinary ones: its count
        // stays, quietly, with the mark that says why.
        testWidgets("a blocked peer's row, $name", (tester) async {
          ChatEntity direct(String id, int peer, String who, int unread) =>
              ChatEntity(
                id: id,
                seqCounter: 9,
                lastActivityAt: DateTime(2026, 10, 10, 9, 2),
                type: ChatType.direct,
                name: null,
                description: null,
                avatarS3Key: null,
                isPublic: false,
                adminOnly: false,
                slowModeSeconds: 0,
                permissions: const {},
                createdBy: myUserId,
                memberCount: 2,
                unreadCount: unread,
                peer: ChatProfileEntity(
                  userId: peer,
                  username: who.toLowerCase(),
                  displayName: who,
                  avatarUrl: null,
                  avatarS3Key: null,
                ),
              );

          await pumpList(
            tester,
            window: window.size,
            dark: dark,
            blocked: const {13},
            items: [
              direct('d1', 11, 'Ада', 2),
              direct('d2', 13, 'Спамер', 7),
              direct('d3', 12, 'Грейс', 1),
            ],
          );

          // Only the blocked person's row carries the mark, and its count
          // drops to the quiet fill a silenced chat uses.
          final mark = find.byIcon(Icons.block);
          expect(mark, findsOneWidget);
          expect(
            tester.widget<Icon>(mark).semanticLabel,
            AppLocalizationsRu().chatBlockedLabel,
          );
          final badges = tester
              .widgetList<UnreadBadge>(find.byType(UnreadBadge))
              .toList();
          expect([for (final b in badges) b.isMuted], [false, true, false]);
          await expectLater(
            find.byType(MaterialApp),
            matchesGoldenFile('goldens/chat_list_blocked_$name.png'),
          );
        });
      }
    }
  });
}
