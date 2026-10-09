import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:golden_toolkit/golden_toolkit.dart';

import 'package:chatix/core/router/app_routes.dart';
import 'package:chatix/core/theme/app_theme.dart';
import 'package:chatix/features/auth/domain/entities/user_entity.dart';
import 'package:chatix/features/auth/presentation/providers/auth_provider.dart';
import 'package:chatix/features/chat/domain/entities/chat_entity.dart';
import 'package:chatix/features/chat/domain/entities/chat_member_entity.dart';
import 'package:chatix/features/chat/domain/entities/chat_profile_entity.dart';
import 'package:chatix/features/chat/domain/entities/message_entity.dart';
import 'package:chatix/features/chat/domain/usecases/get_local_messages_use_case.dart';
import 'package:chatix/features/chat/presentation/providers/chat_detail_provider.dart';
import 'package:chatix/features/chat/presentation/providers/chat_providers.dart';
import 'package:chatix/features/chat/presentation/screens/chat_profile_screen.dart';
import 'package:chatix/features/chat/presentation/widgets/chat_avatar.dart';
import 'package:chatix/gen/l10n/app_localizations.dart';

import '../../../../helpers/pane_frame.dart';

class _FakeAuthController extends AuthController {
  @override
  Future<UserEntity?> build() async =>
      const UserEntity(id: _me, username: 'me', email: 'me@example.com');
}

class _FakeChatDetailController extends ChatDetailController {
  _FakeChatDetailController(super.chatId, this._state);

  final ChatDetailState _state;

  @override
  Future<ChatDetailState> build() async => _state;
}

class _EmptyLocalMessages implements GetLocalMessagesUseCase {
  @override
  List<MessageEntity> execute(String chatId, {int limit = 60}) => const [];
}

const int _me = 7;
const String _chatId = 'c1';

/// Where the chat profile's header puts the chat's face, in every window the
/// profile can be opened in — beside the list on a desktop, which is where
/// centring on the window used to push it a list's width off the title.
void main() {
  setUpAll(
    () => dotenv.testLoad(fileInput: 'BASE_URL=https://api.example.com'),
  );

  ChatMemberEntity member(int userId, String? name, {ChatRole? role}) =>
      ChatMemberEntity(
        userId: userId,
        roleId: (role ?? ChatRole.member).id,
        isMuted: false,
        isBanned: false,
        permissionsOverrides: const {},
        profile: name == null
            ? null
            : ChatProfileEntity(
                userId: userId,
                username: name.toLowerCase(),
                displayName: name,
                avatarUrl: null,
                avatarS3Key: null,
              ),
      );

  final team = ChatEntity(
    id: _chatId,
    seqCounter: 4,
    lastActivityAt: DateTime.utc(2026, 5, 1),
    type: ChatType.group,
    name: 'Design Team',
    description: 'Everything about the new look',
    avatarS3Key: null,
    isPublic: false,
    adminOnly: false,
    slowModeSeconds: 0,
    permissions: const {},
    createdBy: 42,
    memberCount: 4,
    members: [
      member(_me, 'Me'),
      member(42, 'Ada', role: ChatRole.owner),
      member(43, 'Grace'),
      member(44, 'Linus'),
    ],
  );

  Future<void> pump(
    WidgetTester tester, {
    required PaneWindow window,
    bool dark = false,
  }) async {
    final state = ChatDetailState(chat: team, myUserId: _me);

    final router = GoRouter(
      initialLocation: ChatInfoRoute.locationOf(_chatId),
      routes: [
        GoRoute(
          path: ChatInfoRoute.locationOf(_chatId),
          builder: (_, _) => const ChatProfileScreen(chatId: _chatId),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidgetBuilder(
      ProviderScope(
        overrides: [
          authProvider.overrideWith(_FakeAuthController.new),
          getLocalMessagesUseCaseProvider.overrideWithValue(
            _EmptyLocalMessages(),
          ),
          chatDetailProvider(
            _chatId,
          ).overrideWith(() => _FakeChatDetailController(_chatId, state)),
        ],
        child: MaterialApp.router(
          debugShowCheckedModeBanner: false,
          routerConfig: router,
          theme: dark ? AppTheme.dark() : AppTheme.light(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => PaneFrame(window: window, child: child!),
        ),
      ),
      wrapper: (child) => child,
      surfaceSize: window.size,
    );
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpAndSettle();
  }

  /// The big face in the header — a mosaic, since the group has no picture.
  Finder face() => find.descendant(
    of: find.byType(Hero),
    matching: find.byType(ChatAvatarMosaic),
  );

  group('the face sits over the title', () {
    for (final window in PaneWindow.values) {
      testWidgets('in a ${window.paneWidth.round()} px pane (${window.name})', (
        tester,
      ) async {
        await pump(tester, window: window);

        final avatar = tester.getCenter(face());
        final title = tester.getCenter(find.text('Design Team'));

        expect(avatar.dx, moreOrLessEquals(title.dx, epsilon: 1));

        final paneLeft = window.size.width - window.paneWidth;
        expect(
          avatar.dx,
          moreOrLessEquals(paneLeft + window.paneWidth / 2, epsilon: 1),
        );
      });
    }

    testWidgets('and is drawn at the profile size, round', (tester) async {
      await pump(tester, window: PaneWindow.desktop);

      expect(
        tester.getSize(
          find.descendant(of: face(), matching: find.byType(ClipOval)),
        ),
        Size.square(ChatAvatarSize.xl.diameter),
      );
    });
  });

  group('goldens', () {
    for (final window in PaneWindow.values) {
      for (final theme in {'light': false, 'dark': true}.entries) {
        testGoldens('chat profile, ${window.name}, ${theme.key}', (
          tester,
        ) async {
          await pump(tester, window: window, dark: theme.value);

          await screenMatchesGolden(
            tester,
            'chat_profile_${window.name}_${theme.key}',
          );
        });
      }
    }
  });
}
