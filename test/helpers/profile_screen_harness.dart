import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:go_router/go_router.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:mocktail/mocktail.dart';

import 'package:chatix/core/error/failures.dart';
import 'package:chatix/core/localization/app_date_format.dart';
import 'package:chatix/core/storage/file_sharer.dart';
import 'package:chatix/core/storage/key_value_table.dart';
import 'package:chatix/core/theme/app_theme.dart';
import 'package:chatix/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:chatix/features/auth/domain/entities/session_entity.dart';
import 'package:chatix/features/auth/domain/entities/user_entity.dart';
import 'package:chatix/features/auth/domain/repositories/auth_repository.dart';
import 'package:chatix/features/auth/presentation/providers/auth_provider.dart';
import 'package:chatix/features/chat/domain/entities/chat_entity.dart';
import 'package:chatix/features/chat/domain/entities/chat_member_entity.dart';
import 'package:chatix/features/chat/domain/entities/chat_pages.dart';
import 'package:chatix/features/chat/domain/entities/message_entity.dart';
import 'package:chatix/features/chat/domain/usecases/get_local_messages_use_case.dart';
import 'package:chatix/features/chat/domain/usecases/get_members_use_case.dart';
import 'package:chatix/features/chat/presentation/providers/chat_profile_provider.dart';
import 'package:chatix/features/chat/presentation/providers/chat_providers.dart';
import 'package:chatix/features/chat/presentation/providers/chat_state_actions.dart';
import 'package:chatix/features/contacts/data/datasources/block_list_local_store.dart';
import 'package:chatix/features/contacts/data/datasources/contacts_local_store.dart';
import 'package:chatix/features/contacts/data/repositories/blocked_users_repository_impl.dart';
import 'package:chatix/features/contacts/domain/entities/blocked_user.dart';
import 'package:chatix/features/contacts/domain/entities/contact.dart';
import 'package:chatix/features/contacts/domain/entities/contact_sync.dart';
import 'package:chatix/features/contacts/presentation/providers/contacts_lifecycle_provider.dart';
import 'package:chatix/features/profile/data/repositories/profile_repository_impl.dart';
import 'package:chatix/features/profile/domain/entities/contact_entity.dart';
import 'package:chatix/features/profile/domain/entities/profile_entity.dart';
import 'package:chatix/features/profile/domain/repositories/profile_repository.dart';
import 'package:chatix/features/profile/presentation/screens/profile_screen.dart';
import 'package:chatix/gen/l10n/app_localizations.dart';

import 'blocked_users_fixtures.dart';
import 'pane_frame.dart';

/// The signed-in reader, and the person whose profile is usually open.
const int kProfileMe = 7;
const int kProfileOther = 42;

/// The direct chat between the two, when a test says there is one.
const String kProfileChatId = 'direct-42';

class MockProfileRepository extends Mock implements ProfileRepository {}

class MockAuthRepository extends Mock implements AuthRepository {}

class MockGetMembersUseCase extends Mock implements GetMembersUseCase {}

class _FakeAuthController extends AuthController {
  @override
  Future<UserEntity?> build() async => const UserEntity(
    id: kProfileMe,
    username: 'maria',
    email: 'maria@example.com',
  );
}

/// Nothing this device holds: the shared tabs are empty and say so.
class _EmptyLocalMessages implements GetLocalMessagesUseCase {
  @override
  List<MessageEntity> execute(String chatId, {int limit = 60}) => const [];
}

/// A share sheet that is never there, so sharing falls back to the
/// clipboard the way it does on Linux.
class _NoShareSheet extends FileSharer {
  const _NoShareSheet();

  @override
  bool get isSupported => false;
}

/// Records silencing instead of sending it.
class RecordingChatStateActions extends ChatStateActions {
  RecordingChatStateActions(super.ref);

  final List<({String chatId, bool muted, DateTime? until})> mutes = [];

  @override
  Future<Failure?> setMuted(
    String chatId, {
    required bool muted,
    DateTime? until,
  }) async {
    mutes.add((chatId: chatId, muted: muted, until: until));
    return null;
  }
}

/// Ada, as `GET /profiles/42/` answers: a bio, a birthday, two links — and
/// the template's work fields, which the profile no longer shows.
final ProfileEntity kAda = ProfileEntity(
  id: kProfileOther,
  username: 'ada',
  avatars: const {},
  specialization: 'Analytical engines',
  displayName: 'Ada Lovelace',
  bio: 'Writes the first programs for machines that do not exist yet.',
  dateBirthday: DateTime(1990, 4, 12),
  skills: const ['math', 'poetry'],
  contacts: const [
    ContactEntity(
      profileId: kProfileOther,
      provider: 'github',
      contact: 'ada-l',
    ),
    ContactEntity(
      profileId: kProfileOther,
      provider: 'telegram',
      contact: '@ada_codes',
    ),
  ],
);

/// Someone who filled in nothing but a name.
const ProfileEntity kGrace = ProfileEntity(
  id: kProfileOther,
  username: 'grace',
  avatars: {},
  specialization: null,
  displayName: 'Grace Hopper',
  bio: 'Found the first actual bug.',
  dateBirthday: null,
  skills: [],
  contacts: [],
);

/// One's own profile.
final ProfileEntity kMaria = ProfileEntity(
  id: kProfileMe,
  username: 'maria',
  avatars: const {},
  specialization: 'Инженер по релизам',
  displayName: 'Мария Иванова',
  bio: 'Выпускаю релизы по четвергам.',
  dateBirthday: DateTime(1990, 4, 12),
  skills: const ['dart'],
  contacts: const [],
);

/// Ada as the reader saved her.
final Contact kAdaInBook = Contact(
  ownerId: kProfileMe,
  userId: kProfileOther,
  firstName: 'Ада',
  lastName: 'из клуба',
  isMutual: true,
  createdAt: DateTime.utc(2026, 1, 1),
  updatedAt: DateTime.utc(2026, 1, 1),
  profile: const ContactProfile(
    id: kProfileOther,
    username: 'ada',
    displayName: 'Ada Lovelace',
  ),
);

/// Everything a mounted [ProfileScreen] reaches for, faked, and the handles
/// a test asserts on.
class ProfileScreenHarness {
  ProfileScreenHarness();

  final MockProfileRepository profiles = MockProfileRepository();
  final MockAuthRepository auth = MockAuthRepository();
  final FakeBlockedUsersRemote blocks = FakeBlockedUsersRemote();
  final MockGetMembersUseCase getMembers = MockGetMembersUseCase();

  late MemoryBlockListLocalStore blockList;
  RecordingChatStateActions? stateActions;
  late GoRouter router;

  /// Where the router was asked to go, newest last.
  final List<String> visited = [];

  static void setUpAll() {
    dotenv.testLoad(fileInput: 'BASE_URL=https://api.example.com');
  }

  /// Mounts the profile of [profileId] (the reader's own when null).
  ///
  /// [directChatId] is the 1:1 chat with them — found among the loaded
  /// chats, or the one the page was opened from when [openedFromChat].
  /// [online] is what that chat's member list says; null leaves presence
  /// unknown. [window] draws it beside a rail and a list, for goldens.
  Future<void> pump(
    WidgetTester tester, {
    required ProfileEntity profile,
    int? profileId = kProfileOther,
    Contact? contact,
    String? directChatId,
    bool openedFromChat = false,
    bool? online,
    bool? muted,
    bool blocked = false,
    PaneWindow? window,
    bool dark = false,
    Locale? locale = const Locale('ru'),
    List<Override> overrides = const [],
  }) async {
    when(() => profiles.getMyProfile()).thenAnswer((_) async => right(profile));
    when(
      () => profiles.getProfile(any()),
    ).thenAnswer((_) async => right(profile));
    when(() => auth.getMySessions()).thenAnswer(
      (_) async => Right<Failure, List<SessionEntity>>(const [
        SessionEntity(
          id: 1,
          userId: kProfileMe,
          deviceInfo: 'Pixel 8',
          userAgent: 'chatix/1.0',
          lastActivity: null,
          isActive: true,
        ),
        SessionEntity(
          id: 2,
          userId: kProfileMe,
          deviceInfo: 'Windows',
          userAgent: 'chatix/1.0',
          lastActivity: null,
          isActive: true,
        ),
      ]),
    );
    when(
      () => getMembers.execute(
        any(),
        limit: any(named: 'limit'),
        includePresence: any(named: 'includePresence'),
      ),
    ).thenAnswer(
      (_) async => Right(
        MembersPage(
          members: const [
            ChatMemberEntity(
              userId: kProfileMe,
              roleId: 7,
              isMuted: false,
              isBanned: false,
              permissionsOverrides: {},
            ),
            ChatMemberEntity(
              userId: kProfileOther,
              roleId: 7,
              isMuted: false,
              isBanned: false,
              permissionsOverrides: {},
            ),
          ],
          hasNext: false,
          nextUserId: null,
          presence: [
            if (online != null)
              MemberPresenceEntity(userId: kProfileOther, isOnline: online),
          ],
        ),
      ),
    );

    blockList = MemoryBlockListLocalStore(
      blocked
          ? const BlockList(ownerId: kProfileMe, userIds: {kProfileOther})
          : null,
    );

    final book = KeyValueContactsLocalStore(MemoryKeyValueTable());
    if (contact != null) {
      await tester.runAsync(
        () => book.save(
          ContactsSnapshot(ownerId: kProfileMe, contacts: [contact]),
        ),
      );
    }

    final screen = ProfileScreen(
      profileId: profileId,
      chatId: openedFromChat ? directChatId : null,
    );

    Widget record(BuildContext _, GoRouterState state) {
      visited.add(state.uri.toString());
      return const Scaffold(body: SizedBox.shrink());
    }

    router = GoRouter(
      initialLocation: '/here',
      routes: [
        GoRoute(path: '/here', builder: (_, _) => screen),
        GoRoute(
          path: '/chats/:chatId',
          builder: record,
          routes: [GoRoute(path: 'call', builder: record)],
        ),
        GoRoute(path: '/profile/edit', builder: record),
      ],
      errorBuilder: record,
    );
    addTearDown(router.dispose);

    final app = ProviderScope(
      retry: (_, _) => null,
      overrides: [
        authProvider.overrideWith(_FakeAuthController.new),
        profileRepositoryProvider.overrideWithValue(profiles),
        authRepositoryProvider.overrideWithValue(auth),
        contactsLocalStoreProvider.overrideWithValue(book),
        blockListLocalStoreProvider.overrideWithValue(blockList),
        blockedUsersRepositoryProvider.overrideWith(
          (ref) => BlockedUsersRepositoryImpl(remote: blocks, local: blockList),
        ),
        directChatIdsProvider.overrideWithValue({
          if (directChatId != null && !openedFromChat)
            kProfileOther: directChatId,
        }),
        getMembersUseCaseProvider.overrideWithValue(getMembers),
        getLocalMessagesUseCaseProvider.overrideWithValue(
          _EmptyLocalMessages(),
        ),
        fileSharerProvider.overrideWithValue(const _NoShareSheet()),
        chatStateActionsProvider.overrideWith(
          (ref) => stateActions = RecordingChatStateActions(ref),
        ),
        if (directChatId != null)
          chatRowStateProvider(
            directChatId,
          ).overrideWithValue(ChatStateEntity(isMutedByMe: muted ?? false)),
        ...overrides,
      ],
      child: MaterialApp.router(
        debugShowCheckedModeBanner: false,
        routerConfig: router,
        theme: dark ? AppTheme.dark() : AppTheme.light(),
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        // The age next to a birthday is counted from "today": pinned, so
        // the golden says the same thing next year.
        builder: (context, child) => AppClock(
          now: DateTime(2026, 10, 10, 12),
          child: window == null
              ? child!
              : PaneFrame(window: window, child: child!),
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
}
