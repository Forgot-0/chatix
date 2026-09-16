import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:chatix/core/router/app_routes.dart';
import 'package:chatix/core/theme/app_theme.dart';
import 'package:chatix/features/auth/domain/entities/user_entity.dart';
import 'package:chatix/features/auth/presentation/providers/auth_provider.dart';
import 'package:chatix/features/chat/domain/entities/chat_entity.dart';
import 'package:chatix/features/chat/domain/entities/chat_member_entity.dart';
import 'package:chatix/features/chat/domain/entities/message_entity.dart';
import 'package:chatix/features/chat/domain/usecases/get_local_messages_use_case.dart';
import 'package:chatix/features/chat/presentation/providers/chat_detail_provider.dart';
import 'package:chatix/features/chat/presentation/providers/chat_providers.dart';
import 'package:chatix/features/chat/presentation/screens/chat_profile_screen.dart';
import 'package:chatix/gen/l10n/app_localizations.dart';
import 'package:chatix/gen/l10n/app_localizations_en.dart';

class _FakeAuthController extends AuthController {
  @override
  Future<UserEntity?> build() async =>
      const UserEntity(id: 7, username: 'me', email: 'me@example.com');
}

class _FakeChatDetailController extends ChatDetailController {
  _FakeChatDetailController(super.chatId, this._state);

  final ChatDetailState _state;

  @override
  Future<ChatDetailState> build() async => _state;
}

/// Nothing this device holds is fetched, so a profile that cannot be read is
/// a profile with nothing on it.
class _EmptyLocalMessages implements GetLocalMessagesUseCase {
  @override
  List<MessageEntity> execute(String chatId, {int limit = 60}) => const [];
}

void main() {
  const chatId = 'c1';
  const me = 7;
  const creator = 99;

  final l10n = AppLocalizationsEn();

  // The invite link is built off the configured origin, which comes from
  // the environment.
  setUpAll(
    () => dotenv.testLoad(fileInput: 'BASE_URL=https://api.example.com'),
  );

  ChatEntity chat({
    String? description,
    bool isPublic = false,
    int createdBy = creator,
    Map<String, bool> permissions = const {},
  }) => ChatEntity(
    id: chatId,
    seqCounter: 4,
    lastActivityAt: DateTime.utc(2026, 5, 1),
    type: ChatType.group,
    name: 'Team',
    description: description,
    avatarS3Key: null,
    isPublic: isPublic,
    adminOnly: false,
    slowModeSeconds: 0,
    permissions: permissions,
    createdBy: createdBy,
    memberCount: 4,
  );

  ChatMemberEntity member(ChatRole role) => ChatMemberEntity(
    userId: me,
    roleId: role.id,
    isMuted: false,
    isBanned: false,
    permissionsOverrides: const {},
  );

  Future<void> pumpProfile(
    WidgetTester tester,
    ChatEntity source,
    ChatMemberEntity membership, {
    ThemeData? theme,
  }) async {
    // `ChatDetailState.me` reads the roster, so the membership goes on the
    // chat rather than beside it.
    final state = ChatDetailState(
      chat: source.copyWith(members: [membership]),
      myUserId: me,
    );

    final router = GoRouter(
      initialLocation: ChatInfoRoute.locationOf(chatId),
      routes: [
        GoRoute(
          path: ChatInfoRoute.locationOf(chatId),
          builder: (_, _) => const ChatProfileScreen(chatId: chatId),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith(_FakeAuthController.new),
          getLocalMessagesUseCaseProvider.overrideWithValue(
            _EmptyLocalMessages(),
          ),
          chatDetailProvider(
            chatId,
          ).overrideWith(() => _FakeChatDetailController(chatId, state)),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          theme: theme ?? AppTheme.light(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows the chat, its description and its member count', (
    tester,
  ) async {
    await pumpProfile(
      tester,
      chat(description: 'What we are up to'),
      member(ChatRole.member),
    );

    expect(find.text('Team'), findsOneWidget);
    expect(find.text('What we are up to'), findsOneWidget);
    expect(find.text(l10n.membersCount(4)), findsWidgets);
  });

  testWidgets('a private chat has no invite link to copy', (tester) async {
    await pumpProfile(tester, chat(), member(ChatRole.member));

    expect(find.text(l10n.chatInviteLink), findsNothing);
  });

  testWidgets('a public chat offers one', (tester) async {
    await pumpProfile(tester, chat(isPublic: true), member(ChatRole.member));

    expect(find.text(l10n.chatInviteLink), findsOneWidget);
  });

  testWidgets('an ordinary member is offered the door', (tester) async {
    await pumpProfile(tester, chat(), member(ChatRole.member));

    expect(find.text(l10n.leaveChat), findsOneWidget);
    expect(find.text(l10n.deleteChat), findsNothing);
  });

  testWidgets('the creator is told why there is no way out but delete', (
    tester,
  ) async {
    await pumpProfile(
      tester,
      chat(createdBy: me),
      member(ChatRole.owner),
    );

    expect(find.text(l10n.leaveChat), findsNothing);
    expect(find.text(l10n.leaveChatOwnerBlocked), findsOneWidget);
    expect(find.text(l10n.deleteChat), findsOneWidget);
  });

  testWidgets('an owner gets the settings pencil', (tester) async {
    await pumpProfile(tester, chat(), member(ChatRole.owner));

    expect(find.byIcon(Icons.edit_outlined), findsOneWidget);
  });

  testWidgets('a member without chat:update does not', (tester) async {
    await pumpProfile(tester, chat(), member(ChatRole.member));

    expect(find.byIcon(Icons.edit_outlined), findsNothing);
  });

  testWidgets('draws in the dark theme too', (tester) async {
    await pumpProfile(
      tester,
      chat(description: 'What we are up to', isPublic: true),
      member(ChatRole.owner),
      theme: AppTheme.dark(),
    );

    expect(find.text('Team'), findsOneWidget);
    expect(find.text(l10n.chatInviteLink), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('every shared tab is there, and says what it is showing', (
    tester,
  ) async {
    await pumpProfile(tester, chat(), member(ChatRole.member));

    expect(find.text(l10n.sharedMedia), findsWidgets);
    expect(find.text(l10n.sharedFiles), findsOneWidget);
    expect(find.text(l10n.sharedLinks), findsOneWidget);
    expect(find.text(l10n.sharedVoice), findsOneWidget);
    expect(find.text(l10n.sharedMediaEmpty), findsOneWidget);
  });
}
