import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';

import 'package:chatix/core/theme/app_theme.dart';
import 'package:chatix/core/theme/app_tokens.dart';
import 'package:chatix/features/auth/domain/entities/user_entity.dart';
import 'package:chatix/features/auth/presentation/providers/auth_provider.dart';
import 'package:chatix/features/chat/domain/entities/chat_entity.dart';
import 'package:chatix/features/chat/domain/entities/chat_profile_entity.dart';
import 'package:chatix/features/chat/presentation/providers/chat_list_provider.dart';
import 'package:chatix/features/chat/presentation/widgets/chat_avatar.dart';
import 'package:chatix/features/chat/presentation/widgets/chat_list_tile.dart';
import 'package:chatix/features/chat/presentation/widgets/forward_target_dialog.dart';
import 'package:chatix/gen/l10n/app_localizations.dart';

import '../../../../helpers/pane_frame.dart';

class _FakeAuthController extends AuthController {
  @override
  Future<UserEntity?> build() async =>
      const UserEntity(id: 7, username: 'me', email: 'me@example.com');
}

class _FakeChatListController extends ChatListController {
  _FakeChatListController(this._state);

  final ChatListState _state;

  @override
  Future<ChatListState> build() async => _state;
}

/// The forward picker shows every chat with the face its row in the list
/// has — a group or a channel used to get no face at all here.
void main() {
  ChatProfileEntity profile(int userId, String name) => ChatProfileEntity(
    userId: userId,
    username: name.toLowerCase(),
    displayName: name,
    avatarUrl: null,
    avatarS3Key: null,
  );

  ChatEntity chat(
    String id,
    ChatType type, {
    String? name,
    ChatProfileEntity? peer,
    List<ChatProfileEntity> preview = const [],
  }) => ChatEntity(
    id: id,
    seqCounter: 1,
    lastActivityAt: DateTime(2026, 3, 2, 10),
    type: type,
    name: name,
    description: null,
    avatarS3Key: null,
    isPublic: false,
    adminOnly: false,
    slowModeSeconds: 0,
    permissions: const {},
    createdBy: 7,
    memberCount: 3,
    peer: peer,
    membersPreview: preview,
  );

  final chats = [
    chat('source', ChatType.direct, peer: profile(99, 'Source')),
    chat('ada', ChatType.direct, peer: profile(42, 'Ada')),
    chat(
      'team',
      ChatType.group,
      name: 'Design Team',
      preview: [profile(43, 'Grace'), profile(44, 'Linus')],
    ),
    chat('notes', ChatType.channel, name: 'Release Notes'),
  ];

  Future<void> open(
    WidgetTester tester, {
    PaneWindow window = PaneWindow.phone,
    bool dark = false,
  }) async {
    await tester.pumpWidgetBuilder(
      ProviderScope(
        overrides: [
          authProvider.overrideWith(_FakeAuthController.new),
          chatListProvider.overrideWith(
            () => _FakeChatListController(ChatListState(items: chats)),
          ),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: dark ? AppTheme.dark() : AppTheme.light(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: PaneFrame(
            window: window,
            child: Scaffold(
              body: Builder(
                builder: (context) => Center(
                  child: TextButton(
                    onPressed: () => ForwardTargetDialog.pick(
                      context,
                      excludeChatId: 'source',
                    ),
                    child: const Text('open'),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      wrapper: (child) => child,
      surfaceSize: window.size,
    );
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('every target has a 40 px face, groups and channels too', (
    tester,
  ) async {
    await open(tester);

    final faces = find.descendant(
      of: find.byType(ForwardTargetDialog),
      matching: find.byType(ChatRowAvatar),
    );
    expect(faces, findsNWidgets(3));

    for (final face in faces.evaluate()) {
      final circle = find
          .descendant(
            of: find.byWidget(face.widget),
            matching: find.byWidgetPredicate(
              (widget) => widget is ClipPath || widget is ClipOval,
            ),
          )
          .first;
      expect(tester.getSize(circle), Size.square(ChatAvatarSize.md.diameter));
    }
  });

  /// The dialog's card: the first surface inside it.
  Size cardSize(WidgetTester tester) => tester.getSize(
    find
        .descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(Material),
        )
        .first,
  );

  testWidgets('on a desktop it stops at the picker width', (tester) async {
    await open(tester, window: PaneWindow.desktop);

    expect(cardSize(tester).width, AppDialogSizes.pickerMaxWidth);
  });

  testWidgets('on a phone it takes the screen less its insets', (tester) async {
    await open(tester);

    // The stock dialog keeps 40 px clear on either side.
    expect(cardSize(tester).width, PaneWindow.phone.size.width - 2 * 40);
  });

  group('goldens', () {
    for (final window in [PaneWindow.phone, PaneWindow.desktop]) {
      for (final theme in {'light': false, 'dark': true}.entries) {
        testGoldens('forward picker, ${window.name}, ${theme.key}', (
          tester,
        ) async {
          await open(tester, window: window, dark: theme.value);

          await screenMatchesGolden(
            tester,
            'forward_picker_${window.name}_${theme.key}',
          );
        });
      }
    }
  });
}
