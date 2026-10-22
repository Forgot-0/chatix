import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:mocktail/mocktail.dart';

import 'package:chatix/core/error/failures.dart';
import 'package:chatix/core/theme/app_theme.dart';
import 'package:chatix/features/auth/domain/entities/user_entity.dart';
import 'package:chatix/features/auth/presentation/providers/auth_provider.dart';
import 'package:chatix/features/chat/domain/entities/chat_entity.dart';
import 'package:chatix/features/chat/domain/entities/chat_member_entity.dart';
import 'package:chatix/features/chat/domain/usecases/update_chat_use_case.dart';
import 'package:chatix/features/chat/domain/usecases/upload_chat_avatar_use_case.dart';
import 'package:chatix/features/chat/presentation/providers/chat_detail_provider.dart';
import 'package:chatix/features/chat/presentation/providers/chat_list_provider.dart';
import 'package:chatix/features/chat/presentation/providers/chat_providers.dart';
import 'package:chatix/features/chat/presentation/providers/supergroup_upgrade_provider.dart';
import 'package:chatix/features/chat/presentation/screens/chat_settings_screen.dart';
import 'package:chatix/features/chat/presentation/utils/new_chat_draft.dart';
import 'package:chatix/features/chat/presentation/widgets/new_chat/chat_photo_picker.dart';
import 'package:chatix/gen/l10n/app_localizations.dart';
import 'package:chatix/gen/l10n/app_localizations_en.dart';
import 'package:chatix/gen/l10n/app_localizations_ru.dart';

import '../../../../helpers/pane_frame.dart';
import '../../../../helpers/test_photos.dart';

class _FakeChatDetailController extends ChatDetailController {
  _FakeChatDetailController(super.chatId, this._state);

  final ChatDetailState _state;
  int refreshes = 0;

  @override
  Future<ChatDetailState> build() async => _state;

  @override
  Future<void> refresh() async => refreshes++;
}

class _FakeChatList extends ChatListController {
  @override
  Future<ChatListState> build() async => const ChatListState();

  @override
  Future<void> refresh() async {}
}

class _FakeAuth extends AuthController {
  @override
  Future<UserEntity?> build() async =>
      const UserEntity(id: 7, username: 'me', email: 'me@x.io');
}

class _MockUpdateChat extends Mock implements UpdateChatUseCase {}

class _MockUploadAvatar extends Mock implements UploadChatAvatarUseCase {}

void main() {
  const chatId = 'c1';
  const me = 7;

  final l10n = AppLocalizationsEn();
  final ru = AppLocalizationsRu();

  late _MockUpdateChat updateChat;
  late _MockUploadAvatar uploadAvatar;

  setUpAll(() {
    registerFallbackValue(ChatReactionsMode.all);
    registerFallbackValue(TestPhotos.encode(1, 1));
  });

  setUp(() {
    updateChat = _MockUpdateChat();
    uploadAvatar = _MockUploadAvatar();
  });

  ChatEntity chat({
    ChatType type = ChatType.group,
    int slowMode = 0,
    bool adminOnly = false,
    ChatReactionsMode reactionsMode = ChatReactionsMode.all,
    List<String> allowed = const [],
  }) => ChatEntity(
    id: chatId,
    seqCounter: 1,
    lastActivityAt: null,
    type: type,
    name: 'Team',
    description: null,
    avatarS3Key: null,
    isPublic: false,
    adminOnly: adminOnly,
    slowModeSeconds: slowMode,
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
    ChatMemberEntity membership, {
    Locale locale = const Locale('en'),
    List<Override> overrides = const [],
    PaneWindow? window,
    bool dark = false,
  }) async {
    if (window == null) {
      // The form is long. A tall surface lets the whole of it be built, so
      // a field that is not found is one that is not there, rather than one
      // below the fold.
      tester.view.physicalSize = const Size(900, 3000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
    }

    final state = ChatDetailState(
      chat: source.copyWith(members: [membership]),
      myUserId: me,
    );

    final app = ProviderScope(
      retry: (_, _) => null,
      overrides: [
        authProvider.overrideWith(_FakeAuth.new),
        chatDetailProvider(
          chatId,
        ).overrideWith(() => _FakeChatDetailController(chatId, state)),
        chatListProvider.overrideWith(_FakeChatList.new),
        updateChatUseCaseProvider.overrideWithValue(updateChat),
        uploadChatAvatarUseCaseProvider.overrideWithValue(uploadAvatar),
        ...overrides,
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: dark ? AppTheme.dark() : AppTheme.light(),
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: window == null
            ? const ChatSettingsScreen(chatId: chatId)
            : PaneFrame(
                window: window,
                child: const ChatSettingsScreen(chatId: chatId),
              ),
      ),
    );

    if (window == null) {
      await tester.pumpWidget(app);
    } else {
      await tester.pumpWidgetBuilder(
        app,
        wrapper: (child) => child,
        surfaceSize: window.size,
      );
      addTearDown(() => tester.binding.setSurfaceSize(null));
    }
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
    expect(find.text(l10n.chatSlowModeOffShort), findsOneWidget);
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

  group('who may post, and how often', () {
    testWidgets('slow mode is a row of chips, in Russian', (tester) async {
      await pumpSettings(
        tester,
        chat(),
        member(ChatRole.owner),
        locale: const Locale('ru'),
      );

      for (final label in [
        'Выкл',
        '10 с',
        '30 с',
        '1 мин',
        '5 мин',
        '15 мин',
        '1 ч',
      ]) {
        expect(find.widgetWithText(ChoiceChip, label), findsOneWidget);
      }
      // No number field to type seconds into any more.
      expect(find.byType(TextField), findsNWidgets(2));
      final off = tester.widget<ChoiceChip>(
        find.widgetWithText(ChoiceChip, 'Выкл'),
      );
      expect(off.selected, isTrue);
    });

    testWidgets('a chip saves its interval in seconds, and only that', (
      tester,
    ) async {
      when(
        () => updateChat.execute(
          any(),
          name: any(named: 'name'),
          description: any(named: 'description'),
          isPublic: any(named: 'isPublic'),
          adminOnly: any(named: 'adminOnly'),
          slowModeSeconds: any(named: 'slowModeSeconds'),
          permissions: any(named: 'permissions'),
          reactionsMode: any(named: 'reactionsMode'),
          allowedReactions: any(named: 'allowedReactions'),
        ),
      ).thenAnswer((_) async => Right(chat(slowMode: 900)));
      await pumpSettings(
        tester,
        chat(),
        member(ChatRole.owner),
        locale: const Locale('ru'),
      );

      await tester.tap(find.widgetWithText(ChoiceChip, '15 мин'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(ru.saveChanges));
      await tester.pumpAndSettle();

      verify(
        () => updateChat.execute(
          chatId,
          name: null,
          description: null,
          isPublic: null,
          adminOnly: null,
          slowModeSeconds: 900,
          permissions: null,
          reactionsMode: null,
          allowedReactions: null,
        ),
      ).called(1);
    });

    testWidgets('an interval set elsewhere is kept on screen, chosen', (
      tester,
    ) async {
      await pumpSettings(
        tester,
        chat(slowMode: 45),
        member(ChatRole.owner),
        locale: const Locale('ru'),
      );

      final custom = tester.widget<ChoiceChip>(
        find.widgetWithText(ChoiceChip, '45 с'),
      );
      expect(custom.selected, isTrue);
    });

    testWidgets('"only admins" in words, never the name of the right', (
      tester,
    ) async {
      await pumpSettings(
        tester,
        chat(),
        member(ChatRole.owner),
        locale: const Locale('ru'),
      );

      expect(
        find.text('Только администраторы могут отправлять сообщения'),
        findsOneWidget,
      );
      expect(find.text(ru.chatAdminOnlyHint), findsOneWidget);
      expect(find.textContaining('message:'), findsNothing);
      expect(find.textContaining('send_admin_only'), findsNothing);
    });

    testWidgets('a channel has neither: only its admins post anyway', (
      tester,
    ) async {
      await pumpSettings(
        tester,
        chat(type: ChatType.channel),
        member(ChatRole.owner),
      );

      expect(find.text(l10n.chatAdminOnly), findsNothing);
      expect(find.text(l10n.chatSlowMode), findsNothing);
      expect(find.byType(ChoiceChip), findsNothing);
      expect(find.text(l10n.chatPublic), findsOneWidget);
    });
  });

  group('the picture', () {
    testWidgets('a group without one is offered "Set photo"', (tester) async {
      await pumpSettings(tester, chat(), member(ChatRole.owner));

      expect(find.widgetWithText(TextButton, l10n.setPhoto), findsOneWidget);
    });

    testWidgets('a picked photo goes up at once and says it is coming', (
      tester,
    ) async {
      final photo = NewChatPhoto(
        bytes: TestPhotos.encode(8, 8),
        mimeType: 'image/png',
      );
      when(
        () => uploadAvatar.execute(
          any(),
          bytes: any(named: 'bytes'),
          mimeType: any(named: 'mimeType'),
        ),
      ).thenAnswer((_) async => const Right(null));
      await pumpSettings(
        tester,
        chat(),
        member(ChatRole.owner),
        overrides: [
          chatPhotoPickerProvider.overrideWithValue((_, _) async => photo),
        ],
      );

      await tester.tap(find.widgetWithText(TextButton, l10n.setPhoto));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.choosePhoto));
      await tester.pumpAndSettle();

      verify(
        () => uploadAvatar.execute(
          chatId,
          bytes: photo.bytes,
          mimeType: 'image/png',
        ),
      ).called(1);
      expect(find.text(l10n.chatPhotoUploaded), findsOneWidget);
    });

    testWidgets('a refused photo is said, not swallowed', (tester) async {
      when(
        () => uploadAvatar.execute(
          any(),
          bytes: any(named: 'bytes'),
          mimeType: any(named: 'mimeType'),
        ),
      ).thenAnswer(
        (_) async => const Left(
          ApiFailure(
            code: 'CHAT_AVATAR_VALIDATION',
            message: 'bad',
            detail: {'reason': 'size'},
            status: 400,
          ),
        ),
      );
      await pumpSettings(
        tester,
        chat(),
        member(ChatRole.owner),
        overrides: [
          chatPhotoPickerProvider.overrideWithValue(
            (_, _) async => NewChatPhoto(
              bytes: TestPhotos.encode(8, 8),
              mimeType: 'image/png',
            ),
          ),
        ],
      );

      await tester.tap(find.widgetWithText(TextButton, l10n.setPhoto));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.choosePhoto));
      await tester.pumpAndSettle();

      expect(find.text(l10n.apiErrorChatAvatarValidation), findsOneWidget);
    });
  });

  group('supergroup', () {
    testWidgets('hidden while there is no way to do it', (tester) async {
      await pumpSettings(tester, chat(), member(ChatRole.owner));

      expect(find.text(l10n.chatSupergroupTitle), findsNothing);
      expect(find.text(l10n.chatSettingsAdvanced), findsNothing);
    });

    testWidgets('once there is, the owner sees it, explained, and confirms', (
      tester,
    ) async {
      final upgraded = <String>[];
      await pumpSettings(
        tester,
        chat(),
        member(ChatRole.owner),
        locale: const Locale('ru'),
        overrides: [
          supergroupUpgradeProvider.overrideWithValue((id) async {
            upgraded.add(id);
            return const Right(null);
          }),
        ],
      );

      final hint = ru.chatSupergroupHint(ChatType.supergroup.maxMembers);
      // Grouped the Russian way (a no-break space between thousands).
      expect(
        hint,
        matches(RegExp(r'^Большая группа до 1\s000\s000 участников$')),
      );
      expect(find.text(hint), findsOneWidget);

      await tester.tap(find.text(ru.chatSupergroupTitle));
      await tester.pumpAndSettle();
      expect(
        find.text(ru.chatSupergroupConfirm(ChatType.supergroup.maxMembers)),
        findsOneWidget,
      );
      expect(upgraded, isEmpty, reason: 'nothing happens before a yes');

      await tester.tap(find.text(ru.chatSupergroupAction));
      await tester.pumpAndSettle();

      expect(upgraded, [chatId]);
      expect(find.text(ru.chatSupergroupDone), findsOneWidget);
    });

    testWidgets('an admin who is not the owner does not see it', (
      tester,
    ) async {
      await pumpSettings(
        tester,
        chat(),
        member(ChatRole.admin),
        overrides: [
          supergroupUpgradeProvider.overrideWithValue(
            (_) async => const Right(null),
          ),
        ],
      );

      expect(find.text(l10n.chatSupergroupTitle), findsNothing);
    });

    testWidgets('a channel is not a group to grow', (tester) async {
      await pumpSettings(
        tester,
        chat(type: ChatType.channel),
        member(ChatRole.owner),
        overrides: [
          supergroupUpgradeProvider.overrideWithValue(
            (_) async => const Right(null),
          ),
        ],
      );

      expect(find.text(l10n.chatSupergroupTitle), findsNothing);
    });
  });

  group('goldens', () {
    for (final window in [PaneWindow.phone, PaneWindow.desktop]) {
      for (final theme in {'light': false, 'dark': true}.entries) {
        final suffix = '${window.name}_${theme.key}';

        testGoldens('group settings, $suffix', (tester) async {
          await pumpSettings(
            tester,
            chat(slowMode: 30, adminOnly: true),
            member(ChatRole.owner),
            locale: const Locale('ru'),
            window: window,
            dark: theme.value,
          );

          await screenMatchesGolden(tester, 'chat_settings_group_$suffix');
        });
      }

      testGoldens('supergroup option, ${window.name}', (tester) async {
        await pumpSettings(
          tester,
          chat(),
          member(ChatRole.owner),
          locale: const Locale('ru'),
          window: window,
          overrides: [
            supergroupUpgradeProvider.overrideWithValue(
              (_) async => const Right(null),
            ),
          ],
        );
        // The option sits at the very end.
        await tester.scrollUntilVisible(
          find.text(ru.chatSupergroupTitle),
          300,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();

        await screenMatchesGolden(
          tester,
          'chat_settings_supergroup_${window.name}_light',
        );
      });
    }

    testGoldens('supergroup option, phone, dark', (tester) async {
      await pumpSettings(
        tester,
        chat(),
        member(ChatRole.owner),
        locale: const Locale('ru'),
        window: PaneWindow.phone,
        dark: true,
        overrides: [
          supergroupUpgradeProvider.overrideWithValue(
            (_) async => const Right(null),
          ),
        ],
      );
      await tester.scrollUntilVisible(
        find.text(ru.chatSupergroupTitle),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      await screenMatchesGolden(tester, 'chat_settings_supergroup_phone_dark');
    });

    testGoldens('supergroup option, desktop, dark', (tester) async {
      await pumpSettings(
        tester,
        chat(),
        member(ChatRole.owner),
        locale: const Locale('ru'),
        window: PaneWindow.desktop,
        dark: true,
        overrides: [
          supergroupUpgradeProvider.overrideWithValue(
            (_) async => const Right(null),
          ),
        ],
      );
      await tester.scrollUntilVisible(
        find.text(ru.chatSupergroupTitle),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      await screenMatchesGolden(
        tester,
        'chat_settings_supergroup_desktop_dark',
      );
    });
  });
}
