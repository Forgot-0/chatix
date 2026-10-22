import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:go_router/go_router.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:mocktail/mocktail.dart';

import 'package:chatix/core/error/failures.dart';
import 'package:chatix/core/models/page_result.dart';
import 'package:chatix/core/network/request_cancellation.dart';
import 'package:chatix/core/router/app_routes.dart';
import 'package:chatix/core/storage/key_value_table.dart';
import 'package:chatix/core/theme/app_theme.dart';
import 'package:chatix/features/auth/domain/entities/user_entity.dart';
import 'package:chatix/features/auth/presentation/providers/auth_provider.dart';
import 'package:chatix/features/chat/domain/entities/chat_entity.dart';
import 'package:chatix/features/chat/domain/entities/chat_pages.dart';
import 'package:chatix/features/chat/domain/entities/chat_profile_entity.dart';
import 'package:chatix/features/chat/domain/usecases/create_chat_use_case.dart';
import 'package:chatix/features/chat/domain/usecases/get_chats_use_case.dart';
import 'package:chatix/features/chat/domain/usecases/get_local_chats_use_case.dart';
import 'package:chatix/features/chat/domain/usecases/upload_chat_avatar_use_case.dart';
import 'package:chatix/features/chat/presentation/providers/chat_list_provider.dart';
import 'package:chatix/features/chat/presentation/providers/chat_presence_provider.dart';
import 'package:chatix/features/chat/presentation/providers/chat_providers.dart';
import 'package:chatix/features/chat/presentation/screens/new_chat_details_screen.dart';
import 'package:chatix/features/chat/presentation/screens/new_chat_people_screen.dart';
import 'package:chatix/features/chat/presentation/screens/new_message_screen.dart';
import 'package:chatix/features/chat/presentation/utils/new_chat_draft.dart';
import 'package:chatix/features/chat/presentation/widgets/new_chat/chat_photo_picker.dart';
import 'package:chatix/features/contacts/data/datasources/contacts_local_store.dart';
import 'package:chatix/features/contacts/data/repositories/contacts_repository_impl.dart';
import 'package:chatix/features/contacts/domain/entities/contact.dart';
import 'package:chatix/features/contacts/domain/entities/contact_sync.dart';
import 'package:chatix/features/contacts/presentation/providers/contacts_lifecycle_provider.dart';
import 'package:chatix/features/profile/domain/entities/profile_entity.dart';
import 'package:chatix/features/profile/domain/usecases/get_profiles_use_case.dart';
import 'package:chatix/features/profile/presentation/providers/profile_providers.dart';
import 'package:chatix/gen/l10n/app_localizations.dart';

import 'contacts_fixtures.dart';
import 'pane_frame.dart';

class MockCreateChat extends Mock implements CreateChatUseCase {}

class MockUploadChatAvatar extends Mock implements UploadChatAvatarUseCase {}

class MockGetChats extends Mock implements GetChatsUseCase {}

class MockLocalChats extends Mock implements GetLocalChatsUseCase {}

class MockGetProfiles extends Mock implements GetProfilesUseCase {}

class _FakeAuth extends AuthController {
  @override
  Future<UserEntity?> build() async =>
      const UserEntity(id: kOwnerId, username: 'me', email: 'me@x.io');
}

class _FakeChatList extends ChatListController {
  _FakeChatList(this._state, {super.isArchive});

  final ChatListState _state;

  @override
  Future<ChatListState> build() async => _state;

  @override
  Future<void> refresh() async {}
}

/// Presence as if the member list had already answered.
class _KnownPresence extends ChatPresenceController {
  _KnownPresence(this._online);

  final Map<String, bool> _online;

  @override
  Map<String, bool> build() => _online;

  @override
  void ensureFresh(String chatId) {}
}

/// The book every "new …" test starts from: Russian and Latin names, a
/// handle-only contact, a favourite — the mix the contacts tab is tested on.
final List<Contact> kNewChatBook = [
  contact(1, displayName: 'Анна Смирнова', username: 'anna', isFavorite: true),
  contact(2, displayName: 'Борис Петров', username: 'boris'),
  contact(3, displayName: 'Ivan Petrov', firstName: 'Ваня', lastName: 'Работа'),
  contact(4, displayName: 'Ёлка Новогодняя', username: 'yolka'),
  contact(5, displayName: 'Емельян', username: 'emelyan'),
  contact(6, displayName: 'Anna Schmidt', username: 'anna_s'),
  contact(8, username: 'linus'),
  contact(9, displayName: 'Zoe', username: 'zoe'),
];

ProfileEntity personProfile(int id, String username, [String? name]) =>
    ProfileEntity(
      id: id,
      username: username,
      avatars: const {},
      specialization: null,
      displayName: name,
      bio: null,
      dateBirthday: null,
      skills: const [],
      contacts: const [],
    );

/// A 1:1 chat with [peer], as `GET /chats/` lists it.
ChatEntity directChatWith(String id, int peer, {String? name}) => ChatEntity(
  id: id,
  seqCounter: 3,
  lastActivityAt: DateTime.utc(2026, 10, 20),
  type: ChatType.direct,
  name: null,
  description: null,
  avatarS3Key: null,
  isPublic: false,
  adminOnly: false,
  slowModeSeconds: 0,
  permissions: const {},
  createdBy: kOwnerId,
  memberCount: 2,
  peer: ChatProfileEntity(
    userId: peer,
    username: 'user$peer',
    displayName: name ?? 'User $peer',
    avatarUrl: null,
    avatarS3Key: null,
  ),
);

/// One last page of `GET /chats/` holding [chats].
ChatsPage chatsPage(List<ChatEntity> chats) =>
    ChatsPage(chats: chats, hasNext: false, nextDate: null, nextChatId: null);

/// A chat as `POST /chats/` answers.
ChatEntity createdChat(String id, ChatType type, {String name = 'Релиз'}) =>
    ChatEntity(
      id: id,
      seqCounter: 0,
      lastActivityAt: DateTime.utc(2026, 10, 22),
      type: type,
      name: type == ChatType.direct ? null : name,
      description: null,
      avatarS3Key: null,
      isPublic: false,
      adminOnly: false,
      slowModeSeconds: 0,
      permissions: const {},
      createdBy: kOwnerId,
      memberCount: 1,
    );

/// The "new message / new group / new channel" screens behind a real
/// router, over a scripted address book, chat list and server.
///
/// Every route the flow uses is here, framed the way the shell frames a
/// screen in [PaneWindow], and a chat it opens lands on a probe that
/// records its id in [opened].
class NewChatHarness {
  NewChatHarness({
    List<Contact>? book,
    this.chats = const [],
    this.directChats = const {},
    this.online = const {},
  }) : book = book ?? kNewChatBook {
    // Here rather than in [pump], so a test can still stub over them.
    _defaults();
  }

  final List<Contact> book;
  final List<ChatEntity> chats;

  /// user id → chat id, for presence.
  final Map<int, String> directChats;

  /// chat id → online.
  final Map<String, bool> online;

  final FakeContactsRemote remote = FakeContactsRemote();
  final MockGetProfiles getProfiles = MockGetProfiles();
  final MockCreateChat createChat = MockCreateChat();
  final MockUploadChatAvatar uploadAvatar = MockUploadChatAvatar();
  final MockGetChats getChats = MockGetChats();
  final MockLocalChats localChats = MockLocalChats();

  /// What the photo picker hands back when it is asked.
  NewChatPhoto? pickedPhoto;

  /// Chat ids the router was sent to, in order.
  final List<String> opened = [];

  /// Every `POST /chats/`, by argument name.
  final List<Map<Symbol, Object?>> creates = [];

  late ProviderContainer container;
  late GoRouter router;

  static void registerFallbacks() {
    registerFallbackValue(ChatType.group);
    registerFallbackValue(RequestCancellation());
    registerFallbackValue(Uint8List(0));
    registerFallbackValue(
      const ChatsPage(
        chats: [],
        hasNext: false,
        nextDate: null,
        nextChatId: null,
      ),
    );
  }

  /// `POST /chats/` answers with [answer].
  void answerCreate(Either<Failure, ChatEntity> Function(Invocation) answer) {
    when(
      () => createChat.execute(
        name: any(named: 'name'),
        description: any(named: 'description'),
        chatType: any(named: 'chatType'),
        memberIds: any(named: 'memberIds'),
        isPublic: any(named: 'isPublic'),
        adminOnly: any(named: 'adminOnly'),
        slowModeSeconds: any(named: 'slowModeSeconds'),
        permissions: any(named: 'permissions'),
      ),
    ).thenAnswer((call) async {
      creates.add(call.namedArguments);
      return answer(call);
    });
  }

  void _defaults() {
    when(
      () => getProfiles.execute(
        q: any(named: 'q'),
        pageSize: any(named: 'pageSize'),
        cancellation: any(named: 'cancellation'),
      ),
    ).thenAnswer(
      (_) async => Right(
        PageResult<ProfileEntity>(
          items: [
            personProfile(6, 'anna_s', 'Anna Schmidt'), // in the book
            personProfile(30, 'annlee', 'Ann Lee'),
            personProfile(31, 'annabel'),
          ],
          total: 3,
          page: 1,
          pageSize: 20,
        ),
      ),
    );
    when(
      () => getChats.execute(
        limit: any(named: 'limit'),
        archived: any(named: 'archived'),
      ),
    ).thenAnswer(
      (_) async => const Right(
        ChatsPage(chats: [], hasNext: false, nextDate: null, nextChatId: null),
      ),
    );
    when(
      () => localChats.execute(archived: any(named: 'archived')),
    ).thenReturn(null);
    when(
      () => uploadAvatar.execute(
        any(),
        bytes: any(named: 'bytes'),
        mimeType: any(named: 'mimeType'),
      ),
    ).thenAnswer((_) async => const Right(null));
  }

  Future<void> pump(
    WidgetTester tester, {
    String location = CreateChatRoute.location,
    PaneWindow window = PaneWindow.phone,
    bool dark = false,
    Locale locale = const Locale('ru'),
    Size? surface,
    List<Override> overrides = const [],
  }) async {
    final store = KeyValueContactsLocalStore(MemoryKeyValueTable());
    await tester.runAsync(
      () => store.save(
        ContactsSnapshot(ownerId: kOwnerId, contacts: book, version: 'v1'),
      ),
    );
    // The sync on open answers with the same book.
    remote.onPage = pagesOf(book, size: 500, version: 'v2');

    container = ProviderContainer(
      retry: (_, _) => null,
      overrides: [
        authProvider.overrideWith(_FakeAuth.new),
        contactsLocalStoreProvider.overrideWithValue(store),
        contactsRepositoryProvider.overrideWith(
          (ref) => ContactsRepositoryImpl(remote: remote, local: store),
        ),
        getProfilesUseCaseProvider.overrideWithValue(getProfiles),
        directChatIdsProvider.overrideWithValue(directChats),
        chatPresenceProvider.overrideWith(() => _KnownPresence(online)),
        chatListProvider.overrideWith(
          () => _FakeChatList(ChatListState(items: chats)),
        ),
        archivedChatListProvider.overrideWith(
          () => _FakeChatList(const ChatListState(), isArchive: true),
        ),
        getChatsUseCaseProvider.overrideWithValue(getChats),
        getLocalChatsUseCaseProvider.overrideWithValue(localChats),
        createChatUseCaseProvider.overrideWithValue(createChat),
        uploadChatAvatarUseCaseProvider.overrideWithValue(uploadAvatar),
        chatPhotoPickerProvider.overrideWithValue(
          (context, source) async => pickedPhoto,
        ),
        ...overrides,
      ],
    );
    addTearDown(container.dispose);
    await tester.runAsync(() async {
      await container.read(authProvider.future);
      await container.read(chatListProvider.future);
    });

    Widget framed(Widget screen) => PaneFrame(window: window, child: screen);

    router = GoRouter(
      initialLocation: location,
      routes: [
        GoRoute(
          path: ChatsRoute.path,
          builder: (_, _) => const _Probe('chats'),
          routes: [
            GoRoute(
              path: CreateChatRoute.path,
              redirect: (_, state) => CreateChatRoute.redirectFor(state),
              builder: (_, _) => framed(const NewMessageScreen()),
              routes: [
                GoRoute(
                  path: NewGroupRoute.path,
                  builder: (_, _) => framed(
                    const NewChatPeopleScreen(kind: NewChatKind.group),
                  ),
                  routes: [
                    GoRoute(
                      path: NewGroupDetailsRoute.path,
                      builder: (_, _) => framed(
                        const NewChatDetailsScreen(kind: NewChatKind.group),
                      ),
                    ),
                  ],
                ),
                GoRoute(
                  path: NewChannelRoute.path,
                  builder: (_, _) => framed(
                    const NewChatDetailsScreen(kind: NewChatKind.channel),
                  ),
                  routes: [
                    GoRoute(
                      path: NewChannelSubscribersRoute.path,
                      builder: (_, _) => framed(
                        const NewChatPeopleScreen(kind: NewChatKind.channel),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            GoRoute(
              path: ChatDetailRoute.path,
              builder: (_, state) {
                final id = ChatDetailRoute.idFrom(state)!;
                opened.add(id);
                return _Probe('chat:$id');
              },
            ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidgetBuilder(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          debugShowCheckedModeBanner: false,
          theme: dark ? AppTheme.dark() : AppTheme.light(),
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
        ),
      ),
      wrapper: (child) => child,
      surfaceSize: surface ?? window.size,
    );
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpAndSettle();
  }

  /// Taps the button that moves the step on: the app bar's, which every
  /// width has.
  Future<void> tapAppBarAction(WidgetTester tester, String label) async {
    await tester.tap(
      find.descendant(
        of: find.byType(AppBar).last,
        matching: find.widgetWithText(TextButton, label),
      ),
    );
    await tester.pumpAndSettle();
  }
}

class _Probe extends StatelessWidget {
  const _Probe(this.label);

  final String label;

  @override
  Widget build(BuildContext context) =>
      Scaffold(body: Center(child: Text(label)));
}
