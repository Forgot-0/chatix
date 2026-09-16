import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chatix/core/theme/app_theme.dart';
import 'package:chatix/features/chat/domain/entities/chat_entity.dart';
import 'package:chatix/features/chat/domain/entities/chat_member_entity.dart';
import 'package:chatix/features/chat/presentation/providers/chat_members_provider.dart';
import 'package:chatix/features/chat/presentation/screens/chat_invite_members_screen.dart';
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

  ChatMemberEntity member(int userId, ChatRole role) => ChatMemberEntity(
    userId: userId,
    roleId: role.id,
    isMuted: false,
    isBanned: false,
    permissionsOverrides: const {},
  );

  ChatEntity chat({
    ChatType type = ChatType.group,
    int memberCount = 3,
    List<ChatMemberEntity>? roster,
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

  Future<void> pumpInvite(
    WidgetTester tester,
    ChatMembersState state, {
    ThemeData? theme,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          chatMembersProvider(
            chatId,
          ).overrideWith(() => _FakeMembersController(chatId, state)),
        ],
        child: MaterialApp(
          theme: theme ?? AppTheme.light(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const ChatInviteMembersScreen(chatId: chatId),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  ChatMembersState stateWith({
    required ChatRole myRole,
    ChatType type = ChatType.group,
    int memberCount = 3,
  }) {
    final me = member(myUserId, myRole);
    return ChatMembersState(
      chat: chat(type: type, memberCount: memberCount, roster: [me]),
      members: [me],
      myUserId: myUserId,
    );
  }

  testWidgets('says how many more people the chat can hold', (tester) async {
    await pumpInvite(tester, stateWith(myRole: ChatRole.owner));

    // A group holds 500 (api-docs §5.1) and three are already in.
    expect(find.text(l10n.inviteRoomLeft(497)), findsOneWidget);
  });

  testWidgets('a full chat offers nothing rather than a doomed request', (
    tester,
  ) async {
    await pumpInvite(
      tester,
      stateWith(myRole: ChatRole.owner, memberCount: 500),
    );

    expect(find.text(l10n.inviteChatFull(500)), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('a one-to-one chat has no invite to offer at all', (
    tester,
  ) async {
    // The `direct` role holds no `member:invite` (api-docs §8.1), which is
    // also why the member list draws no invite button for this chat.
    await pumpInvite(
      tester,
      stateWith(myRole: ChatRole.direct, type: ChatType.direct, memberCount: 2),
    );

    expect(find.text(l10n.membersEmptyNoInvite), findsOneWidget);
  });

  testWidgets('without member:invite there is nothing to do here', (
    tester,
  ) async {
    await pumpInvite(tester, stateWith(myRole: ChatRole.member));

    expect(find.text(l10n.membersEmptyNoInvite), findsOneWidget);
  });

  testWidgets('the owner may invite as anything below owner', (tester) async {
    await pumpInvite(tester, stateWith(myRole: ChatRole.owner));

    expect(find.widgetWithText(ChoiceChip, l10n.chatRoleAdmin), findsOneWidget);
    expect(
      find.widgetWithText(ChoiceChip, l10n.chatRoleViewer),
      findsOneWidget,
    );

    // Ownership is not handed over by inviting (api-docs §5.3), and `direct`
    // belongs to 1:1 chats the server sets up itself.
    expect(find.widgetWithText(ChoiceChip, l10n.chatRoleOwner), findsNothing);
    expect(find.widgetWithText(ChoiceChip, l10n.chatRoleDirect), findsNothing);
  });

  testWidgets('an admin cannot invite another admin', (tester) async {
    await pumpInvite(tester, stateWith(myRole: ChatRole.admin));

    expect(
      find.widgetWithText(ChoiceChip, l10n.chatRoleEditor),
      findsOneWidget,
    );
    expect(find.widgetWithText(ChoiceChip, l10n.chatRoleAdmin), findsNothing);
  });

  bool isSelected(WidgetTester tester, String label) => tester
      .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, label))
      .selected;

  testWidgets('a group invites as an ordinary member by default', (
    tester,
  ) async {
    await pumpInvite(tester, stateWith(myRole: ChatRole.owner));

    expect(isSelected(tester, l10n.chatRoleMember), isTrue);
  });

  testWidgets('a channel invites as a viewer by default', (tester) async {
    // What the server itself would default to for a channel (api-docs §8.1).
    await pumpInvite(
      tester,
      stateWith(myRole: ChatRole.owner, type: ChatType.channel),
    );

    expect(isSelected(tester, l10n.chatRoleViewer), isTrue);
    expect(isSelected(tester, l10n.chatRoleMember), isFalse);
  });

  testWidgets('nothing can be added until someone is picked', (tester) async {
    await pumpInvite(tester, stateWith(myRole: ChatRole.owner));

    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNull);
    expect(find.text(l10n.inviteAddSelected(0)), findsOneWidget);
  });

  testWidgets('renders in the dark theme as well', (tester) async {
    await pumpInvite(
      tester,
      stateWith(myRole: ChatRole.owner),
      theme: AppTheme.dark(),
    );

    expect(tester.takeException(), isNull);
  });
}
