import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chatix/core/theme/app_theme.dart';
import 'package:chatix/features/chat/domain/entities/chat_entity.dart';
import 'package:chatix/features/chat/domain/entities/chat_member_entity.dart';
import 'package:chatix/features/chat/presentation/providers/chat_detail_provider.dart';
import 'package:chatix/features/chat/presentation/screens/chat_settings_screen.dart';
import 'package:chatix/gen/l10n/app_localizations.dart';
import 'package:chatix/gen/l10n/app_localizations_en.dart';

class _FakeChatDetailController extends ChatDetailController {
  _FakeChatDetailController(super.chatId, this._state);

  final ChatDetailState _state;

  @override
  Future<ChatDetailState> build() async => _state;
}

void main() {
  const chatId = 'c1';
  const me = 7;

  final l10n = AppLocalizationsEn();

  ChatEntity chat({
    ChatReactionsMode reactionsMode = ChatReactionsMode.all,
    List<String> allowed = const [],
  }) => ChatEntity(
    id: chatId,
    seqCounter: 1,
    lastActivityAt: null,
    type: ChatType.group,
    name: 'Team',
    description: null,
    avatarS3Key: null,
    isPublic: false,
    adminOnly: false,
    slowModeSeconds: 0,
    permissions: const {},
    reactionsMode: reactionsMode,
    allowedReactions: allowed,
    createdBy: 1,
    memberCount: 3,
  );

  ChatMemberEntity member(ChatRole role) => ChatMemberEntity(
    userId: me,
    roleId: role.id,
    isMuted: false,
    isBanned: false,
    permissionsOverrides: const {},
  );

  Future<void> pumpSettings(
    WidgetTester tester,
    ChatEntity source,
    ChatMemberEntity membership,
  ) async {
    // The form is long. A tall surface lets the whole of it be built, so a
    // field that is not found is one that is not there, rather than one
    // below the fold.
    tester.view.physicalSize = const Size(900, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final state = ChatDetailState(
      chat: source.copyWith(members: [membership]),
      myUserId: me,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          chatDetailProvider(
            chatId,
          ).overrideWith(() => _FakeChatDetailController(chatId, state)),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const ChatSettingsScreen(chatId: chatId),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('a member without chat:update gets no form to fill in', (
    tester,
  ) async {
    await pumpSettings(tester, chat(), member(ChatRole.member));

    expect(find.text(l10n.chatSettingsNoPermission), findsOneWidget);
    expect(find.text(l10n.saveChanges), findsNothing);
  });

  testWidgets('an owner gets every field the endpoint takes', (tester) async {
    await pumpSettings(tester, chat(), member(ChatRole.owner));

    expect(find.text(l10n.chatName), findsOneWidget);
    expect(find.text(l10n.chatDescription), findsOneWidget);
    expect(find.text(l10n.chatPublic), findsOneWidget);
    expect(find.text(l10n.chatAdminOnly), findsOneWidget);
    expect(find.text(l10n.chatSlowModeSecondsField), findsOneWidget);
    expect(find.text(l10n.chatReactionsAll), findsOneWidget);
    expect(find.text(l10n.saveChanges), findsOneWidget);
  });

  testWidgets('the emoji picker only appears under "only selected"', (
    tester,
  ) async {
    await pumpSettings(tester, chat(), member(ChatRole.owner));
    expect(find.text(l10n.chatReactionsPickHint), findsNothing);

    await tester.tap(find.text(l10n.chatReactionsSome));
    await tester.pumpAndSettle();

    expect(find.text(l10n.chatReactionsPickHint), findsOneWidget);
  });

  testWidgets('a save with nothing changed says so instead of asking', (
    tester,
  ) async {
    await pumpSettings(tester, chat(), member(ChatRole.owner));

    await tester.tap(find.text(l10n.saveChanges));
    await tester.pumpAndSettle();

    expect(find.text(l10n.chatSettingsUnchanged), findsOneWidget);
  });
}
