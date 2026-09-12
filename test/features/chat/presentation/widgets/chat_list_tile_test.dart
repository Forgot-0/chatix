import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

import 'package:chatix/core/theme/app_theme.dart';
import 'package:chatix/features/auth/domain/entities/user_entity.dart';
import 'package:chatix/features/auth/presentation/providers/auth_provider.dart';
import 'package:chatix/features/chat/data/datasources/chat_local_prefs_store.dart';
import 'package:chatix/features/chat/domain/entities/chat_entity.dart';
import 'package:chatix/features/chat/domain/entities/chat_member_entity.dart';
import 'package:chatix/features/chat/domain/entities/chat_pages.dart';
import 'package:chatix/features/chat/domain/entities/chat_profile_entity.dart';
import 'package:chatix/features/chat/domain/entities/message_entity.dart';
import 'package:chatix/features/chat/domain/usecases/get_members_use_case.dart';
import 'package:chatix/features/chat/presentation/providers/chat_drafts_provider.dart';
import 'package:chatix/features/chat/presentation/providers/chat_local_prefs_provider.dart';
import 'package:chatix/features/chat_organizer/data/datasources/chat_organizer_local_data_source.dart';
import 'package:chatix/features/chat_organizer/presentation/providers/chat_organizer_provider.dart';
import 'package:chatix/features/chat_organizer/presentation/providers/chat_organizer_providers.dart';
import 'package:chatix/features/chat/presentation/providers/chat_providers.dart';
import 'package:chatix/features/chat/presentation/widgets/chat_avatar.dart';
import 'package:chatix/features/chat/presentation/widgets/chat_list_tile.dart';
import 'package:chatix/features/chat/presentation/widgets/chat_type_glyph.dart';
import 'package:chatix/features/chat/presentation/widgets/status_ticks.dart';
import 'package:chatix/gen/l10n/app_localizations.dart';
import 'package:chatix/gen/l10n/app_localizations_en.dart';

class MockGetMembersUseCase extends Mock implements GetMembersUseCase {}

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
  late InMemoryChatLocalPrefsStore store;

  setUp(() {
    getMembers = MockGetMembersUseCase();
    store = InMemoryChatLocalPrefsStore();

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
  }) => ChatEntity(
    id: chatId,
    seqCounter: 9,
    lastActivityAt: DateTime.now(),
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
    ChatLocalPrefs prefs = const ChatLocalPrefs(),
    Set<String> pinned = const <String>{},
    String? draft,
    bool dark = false,
  }) async {
    for (final flag in ChatLocalFlag.values) {
      await store.writeFlag(flag, prefs.of(flag));
    }

    final container = ProviderContainer(
      overrides: [
        chatLocalPrefsStoreProvider.overrideWithValue(store),
        chatOrganizerDataSourceProvider.overrideWithValue(
          InMemoryChatOrganizerDataSource(pinned: pinned),
        ),
        getMembersUseCaseProvider.overrideWithValue(getMembers),
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
      chat(type: ChatType.direct, name: 'Ann', last: message(content: 'hi')),
    );
    expect(find.byType(ChatTypeGlyph), findsNothing);
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

  testWidgets('an unread count shows as a badge', (tester) async {
    await pumpTile(tester, chat(unread: 4, last: message(content: 'hi')));

    expect(find.text('4'), findsOneWidget);
  });

  testWidgets('a silenced chat keeps the count and shows the bell', (
    tester,
  ) async {
    await pumpTile(
      tester,
      chat(unread: 4, last: message(content: 'hi')),
      prefs: const ChatLocalPrefs(muted: {chatId}),
    );

    expect(find.text('4'), findsOneWidget);
    expect(find.byIcon(Icons.notifications_off_outlined), findsOneWidget);
  });

  testWidgets('a pinned chat with nothing unread shows the pin', (
    tester,
  ) async {
    await pumpTile(
      tester,
      chat(last: message(content: 'hi')),
      pinned: const {chatId},
    );

    expect(find.byIcon(Icons.push_pin), findsOneWidget);
  });

  group('delivery ticks', () {
    testWidgets('none on somebody else\'s message', (tester) async {
      await pumpTile(tester, chat(last: message(content: 'hi')));

      expect(find.byType(StatusTicks), findsNothing);
    });

    testWidgets('one tick on my own message with no read news', (
      tester,
    ) async {
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
        chat(last: message(content: 'hi', authorId: myUserId, seq: 5)),
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
      chat(type: ChatType.direct, name: 'Ann', last: message(content: 'hi')),
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
        chat(last: message(content: 'hi'), membership: membership(ChatRole.member)),
      );

      await tester.longPress(find.text('Design team'));
      await tester.pumpAndSettle();
      expect(find.text(l10n.deleteChat), findsNothing);

      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      await pumpTile(
        tester,
        chat(last: message(content: 'hi'), membership: membership(ChatRole.owner)),
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
}
