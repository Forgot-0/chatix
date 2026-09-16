import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:chatix/core/router/app_routes.dart';
import 'package:chatix/core/theme/app_theme.dart';
import 'package:chatix/features/chat/domain/entities/chat_entity.dart';
import 'package:chatix/features/chat/domain/entities/chat_member_entity.dart';
import 'package:chatix/features/chat/domain/entities/chat_profile_entity.dart';
import 'package:chatix/features/chat/presentation/providers/chat_members_provider.dart';
import 'package:chatix/features/chat/presentation/screens/chat_members_screen.dart';
import 'package:chatix/gen/l10n/app_localizations.dart';
import 'package:chatix/gen/l10n/app_localizations_en.dart';

class _FakeMembersController extends ChatMembersController {
  _FakeMembersController(super.chatId, this._state);

  final ChatMembersState _state;

  @override
  Future<ChatMembersState> build() async => _state;
}

void main() {
  const chatId = 'c1';
  const myUserId = 1;

  final l10n = AppLocalizationsEn();

  ChatMemberEntity member({
    required int userId,
    required ChatRole role,
    required String name,
    String? username,
    bool isBanned = false,
    bool isMuted = false,
  }) => ChatMemberEntity(
    userId: userId,
    roleId: role.id,
    isMuted: isMuted,
    isBanned: isBanned,
    permissionsOverrides: const {},
    profile: ChatProfileEntity(
      userId: userId,
      username: username,
      displayName: name,
      avatarUrl: null,
      avatarS3Key: null,
    ),
  );

  final owner = member(userId: myUserId, role: ChatRole.owner, name: 'Ola');
  final editor = member(userId: 3, role: ChatRole.editor, name: 'Eli');
  final mia = member(
    userId: 5,
    role: ChatRole.member,
    name: 'Mia',
    username: 'mia_k',
  );
  final banned = member(
    userId: 9,
    role: ChatRole.member,
    name: 'Bad Actor',
    isBanned: true,
  );

  ChatEntity chat({
    ChatType type = ChatType.group,
    List<ChatMemberEntity>? roster,
    int memberCount = 4,
  }) => ChatEntity(
    id: chatId,
    seqCounter: 1,
    lastActivityAt: null,
    type: type,
    name: 'Team',
    description: null,
    avatarS3Key: null,
    isPublic: false,
    adminOnly: false,
    slowModeSeconds: 0,
    permissions: const {},
    createdBy: myUserId,
    memberCount: memberCount,
    members: roster,
  );

  Future<void> pumpMembers(
    WidgetTester tester,
    ChatMembersState state, {
    ThemeData? theme,
    // A list with more pages draws a spinner, which never settles.
    bool settle = true,
  }) async {
    final router = GoRouter(
      initialLocation: ChatMembersRoute.locationOf(chatId),
      routes: [
        GoRoute(
          path: ChatMembersRoute.locationOf(chatId),
          builder: (_, _) => const ChatMembersScreen(chatId: chatId),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          chatMembersProvider(
            chatId,
          ).overrideWith(() => _FakeMembersController(chatId, state)),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          theme: theme ?? AppTheme.light(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump();
      await tester.pump();
    }
  }

  /// Section headings live in the list; the app bar has its own "Members".
  Finder inList(String text) =>
      find.descendant(of: find.byType(ListView), matching: find.text(text));

  ChatMembersState stateWith({
    List<ChatMemberEntity> members = const [],
    List<ChatMemberEntity>? roster,
    Map<int, bool> presence = const {},
    ChatType type = ChatType.group,
  }) => ChatMembersState(
    chat: chat(type: type, roster: roster ?? members),
    members: members,
    myUserId: myUserId,
    presence: presence,
  );

  testWidgets('splits the roster into administration and everyone else', (
    tester,
  ) async {
    await pumpMembers(tester, stateWith(members: [owner, editor, mia]));

    expect(inList(l10n.membersSectionAdmins), findsOneWidget);
    expect(inList(l10n.membersSectionMembers), findsOneWidget);

    final admins = tester.getTopLeft(inList(l10n.membersSectionAdmins));
    final others = tester.getTopLeft(inList(l10n.membersSectionMembers));
    expect(admins.dy, lessThan(others.dy));

    // The owner and the editor are staff; Mia is not.
    expect(
      tester.getTopLeft(find.text('Ola')).dy,
      lessThan(tester.getTopLeft(find.text('Mia')).dy),
    );
  });

  testWidgets('the banned block is built from the chat detail roster', (
    tester,
  ) async {
    // Exactly the inconsistency in api-docs §5.3: the paged member list
    // never carries a banned member, the chat detail always does.
    await pumpMembers(
      tester,
      stateWith(members: [owner, mia], roster: [owner, mia, banned]),
    );

    expect(inList(l10n.membersSectionBanned), findsOneWidget);
    expect(find.text('Bad Actor'), findsOneWidget);
    expect(find.text(l10n.membersBannedHint), findsOneWidget);
  });

  testWidgets('no banned block when nobody is banned', (tester) async {
    await pumpMembers(tester, stateWith(members: [owner, mia]));

    expect(inList(l10n.membersSectionBanned), findsNothing);
  });

  testWidgets('roles other than plain member wear a badge', (tester) async {
    await pumpMembers(tester, stateWith(members: [owner, editor, mia]));

    expect(find.text(l10n.chatRoleOwner), findsOneWidget);
    expect(find.text(l10n.chatRoleEditor), findsOneWidget);
    expect(find.text(l10n.chatRoleMember), findsNothing);
  });

  testWidgets('search narrows the list to the people who match', (
    tester,
  ) async {
    await pumpMembers(tester, stateWith(members: [owner, editor, mia]));

    await tester.enterText(find.byType(TextField), 'mia');
    await tester.pumpAndSettle();

    expect(find.text('Mia'), findsOneWidget);
    expect(find.text('Ola'), findsNothing);
    expect(inList(l10n.membersSectionAdmins), findsNothing);
  });

  testWidgets('a search nobody matches says so', (tester) async {
    await pumpMembers(tester, stateWith(members: [owner, mia]));

    await tester.enterText(find.byType(TextField), 'nobody');
    await tester.pumpAndSettle();

    expect(find.text(l10n.membersSearchEmpty('nobody')), findsOneWidget);
  });

  testWidgets('a search over a partial roster can pull the rest in', (
    tester,
  ) async {
    // There is no server-side member search (api-docs §5.3), so a filtered
    // list that is too short to scroll still needs a way to the next page.
    final state = ChatMembersState(
      chat: chat(roster: [owner, mia], memberCount: 120),
      members: [owner, mia],
      hasNext: true,
      nextUserId: 5,
      myUserId: myUserId,
    );

    await pumpMembers(tester, state, settle: false);
    await tester.enterText(find.byType(TextField), 'mia');
    await tester.pumpAndSettle();

    expect(find.text(l10n.membersSearchLoadedOnly), findsOneWidget);
    expect(find.text(l10n.membersLoadMore), findsOneWidget);
  });

  testWidgets('a one-to-one chat has no search field', (tester) async {
    await pumpMembers(
      tester,
      stateWith(members: [owner, mia], type: ChatType.direct),
    );

    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('long-pressing a member offers what the owner may do', (
    tester,
  ) async {
    await pumpMembers(tester, stateWith(members: [owner, mia]));

    await tester.longPress(find.text('Mia'));
    await tester.pumpAndSettle();

    expect(find.text(l10n.memberOpenProfile), findsOneWidget);
    expect(find.text(l10n.memberMessagePrivately), findsOneWidget);
    expect(find.text(l10n.changeRole), findsOneWidget);
    expect(find.text(l10n.kickMember), findsOneWidget);
    expect(find.text(l10n.banMember), findsOneWidget);

    // No mute: the members router has no endpoint for it (api-docs §5.3).
    expect(find.text(l10n.memberMutedBadge), findsNothing);
  });

  testWidgets('an ordinary member is offered nothing but reading a profile', (
    tester,
  ) async {
    final state = ChatMembersState(
      chat: chat(roster: [owner, mia]),
      members: [owner, mia],
      // Signed in as Mia this time, who runs nothing.
      myUserId: 5,
    );

    await pumpMembers(tester, state);
    await tester.longPress(find.text('Ola'));
    await tester.pumpAndSettle();

    expect(find.text(l10n.memberOpenProfile), findsOneWidget);
    expect(find.text(l10n.kickMember), findsNothing);
    expect(find.text(l10n.banMember), findsNothing);
    expect(find.text(l10n.changeRole), findsNothing);
  });

  testWidgets('the role picker offers only roles below the owner', (
    tester,
  ) async {
    await pumpMembers(tester, stateWith(members: [owner, mia]));

    await tester.longPress(find.text('Mia'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.changeRole).last);
    await tester.pumpAndSettle();

    Finder inDialog(String text) => find.descendant(
      of: find.byType(SimpleDialog),
      matching: find.text(text),
    );

    expect(find.byType(RadioListTile<ChatRole>), findsNWidgets(4));
    expect(inDialog(l10n.chatRoleAdmin), findsOneWidget);
    expect(inDialog(l10n.chatRoleViewer), findsOneWidget);

    // Ownership cannot be handed over through a role change, and the
    // `direct` role belongs to 1:1 chats only (api-docs §5.3).
    expect(inDialog(l10n.chatRoleOwner), findsNothing);
    expect(inDialog(l10n.chatRoleDirect), findsNothing);
    expect(inDialog(l10n.roleOwnerTransferHint), findsOneWidget);
  });

  testWidgets('the ban dialog offers every shape `banned_to` can take', (
    tester,
  ) async {
    await pumpMembers(tester, stateWith(members: [owner, mia]));

    await tester.longPress(find.text('Mia'));
    await tester.pumpAndSettle();
    final ban = find.text(l10n.banMember).last;
    await tester.ensureVisible(ban);
    await tester.pumpAndSettle();
    await tester.tap(ban);
    await tester.pumpAndSettle();

    Finder inDialog(String text) => find.descendant(
      of: find.byType(AlertDialog),
      matching: find.text(text),
    );

    expect(inDialog(l10n.banForHour), findsOneWidget);
    expect(inDialog(l10n.banForDay), findsOneWidget);
    expect(inDialog(l10n.banForWeek), findsOneWidget);
    expect(inDialog(l10n.banForever), findsOneWidget);
    expect(inDialog(l10n.banUntilDate), findsOneWidget);
  });

  testWidgets('a banned member is offered the ban lifted, not another ban', (
    tester,
  ) async {
    await pumpMembers(
      tester,
      stateWith(members: [owner], roster: [owner, banned]),
    );

    await tester.longPress(find.text('Bad Actor'));
    await tester.pumpAndSettle();

    expect(find.text(l10n.banLift), findsOneWidget);
    expect(find.text(l10n.banMember), findsNothing);
  });

  testWidgets('presence comes from the separate array, absence is offline', (
    tester,
  ) async {
    // `presence` is a list beside `members`, not a field inside them
    // (api-docs §5.3): Mia has an entry, the owner has none.
    await pumpMembers(
      tester,
      stateWith(members: [owner, mia], presence: const {5: true}),
    );

    // The dot is drawn with a semantics label rather than visible text, and
    // only the member the presence array named gets one.
    final onlineDot = find.byWidgetPredicate(
      (widget) =>
          widget is Semantics && widget.properties.label == l10n.onlineNow,
    );

    expect(onlineDot, findsOneWidget);
    expect(
      find.descendant(
        of: find.ancestor(
          of: find.text('Mia'),
          matching: find.byType(ListTile),
        ),
        matching: onlineDot,
      ),
      findsOneWidget,
    );
  });

  testWidgets('renders in the dark theme as well', (tester) async {
    await pumpMembers(
      tester,
      stateWith(
        members: [owner, editor, mia],
        roster: [owner, editor, mia, banned],
      ),
      theme: AppTheme.dark(),
    );

    expect(tester.takeException(), isNull);
    expect(inList(l10n.membersSectionBanned), findsOneWidget);
  });
}
