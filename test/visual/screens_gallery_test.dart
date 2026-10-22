import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:go_router/go_router.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:mocktail/mocktail.dart';

import 'package:chatix/core/localization/app_date_format.dart';
import 'package:chatix/core/network/connectivity_providers.dart';
import 'package:chatix/core/router/app_layout.dart';
import 'package:chatix/core/router/app_routes.dart';
import 'package:chatix/core/storage/key_value_table.dart';
import 'package:chatix/core/theme/app_theme.dart';
import 'package:chatix/core/theme/app_theme_extension.dart';
import 'package:chatix/core/websocket/chat_socket_service.dart';
import 'package:chatix/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:chatix/features/auth/domain/entities/user_entity.dart';
import 'package:chatix/features/auth/domain/repositories/auth_repository.dart';
import 'package:chatix/features/auth/presentation/providers/auth_provider.dart';
import 'package:chatix/features/auth/presentation/screens/login_screen.dart';
import 'package:chatix/features/auth/presentation/widgets/oauth_buttons.dart';
import 'package:chatix/features/chat/data/datasources/chat_local_prefs_store.dart';
import 'package:chatix/features/chat/data/datasources/voice_local_store.dart';
import 'package:chatix/features/chat/domain/entities/attachment_entity.dart';
import 'package:chatix/features/chat/domain/entities/chat_entity.dart';
import 'package:chatix/features/chat/domain/entities/chat_member_entity.dart';
import 'package:chatix/features/chat/domain/entities/chat_pages.dart';
import 'package:chatix/features/chat/domain/entities/chat_profile_entity.dart';
import 'package:chatix/features/chat/domain/entities/message_entity.dart';
import 'package:chatix/features/chat/domain/usecases/get_local_messages_use_case.dart';
import 'package:chatix/features/chat/domain/usecases/get_members_use_case.dart';
import 'package:chatix/features/chat/presentation/providers/attachment_file_provider.dart';
import 'package:chatix/features/chat/presentation/providers/chat_detail_provider.dart';
import 'package:chatix/features/chat/presentation/providers/chat_list_provider.dart';
import 'package:chatix/features/chat/presentation/providers/chat_local_prefs_provider.dart';
import 'package:chatix/features/chat/presentation/providers/chat_presence_provider.dart';
import 'package:chatix/features/chat/presentation/providers/chat_providers.dart';
import 'package:chatix/features/chat/presentation/providers/chat_socket_provider.dart';
import 'package:chatix/features/chat/presentation/providers/voice_playback_provider.dart';
import 'package:chatix/features/chat/presentation/screens/chat_profile_screen.dart';
import 'package:chatix/features/chat/presentation/screens/chats_list_screen.dart';
import 'package:chatix/features/chat_organizer/data/datasources/chat_organizer_local_data_source.dart';
import 'package:chatix/features/chat_organizer/presentation/providers/chat_organizer_provider.dart';
import 'package:chatix/features/chat_organizer/presentation/providers/chat_organizer_providers.dart';
import 'package:chatix/features/contacts/data/datasources/contacts_local_store.dart';
import 'package:chatix/features/contacts/data/repositories/contacts_repository_impl.dart';
import 'package:chatix/features/contacts/domain/entities/contact_sync.dart';
import 'package:chatix/features/contacts/presentation/providers/contacts_lifecycle_provider.dart';
import 'package:chatix/features/contacts/presentation/screens/contacts_screen.dart';
import 'package:chatix/features/notification/presentation/providers/notification_badge_provider.dart';
import 'package:chatix/gen/l10n/app_localizations.dart';

import '../helpers/chat_golden.dart';
import '../helpers/chat_screen_harness.dart';
import '../helpers/contacts_fixtures.dart';
import '../helpers/new_chat_harness.dart';
import '../helpers/pane_frame.dart';
import '../helpers/pump_app.dart';
import '../helpers/profile_screen_harness.dart';
import '../helpers/settings_harness.dart';
import '../helpers/test_photos.dart';

/// The photo album: every key screen, in every window, in both themes.
///
/// Each screen already has goldens of its own for the states and the details
/// it is responsible for. This file is the other axis — one picture of each
/// screen at rest, side by side, so a change that only shows at a particular
/// width (a header measured off the window, a row that stops fitting, a
/// circle squeezed into an oval) has nowhere to hide.
///
/// Three windows: a phone, a tablet behind the rail, and a desktop with the
/// chat list beside the screen ([PaneWindow] — a pane is never as wide as its
/// window, which is the whole point). Two themes. Nothing here reaches a
/// backend; every screen is drawn over fixed data and a pinned clock, so the
/// pictures only move when the layout does.
void main() {
  setUpAll(() {
    dotenv.testLoad(fileInput: 'BASE_URL=https://api.example.com');
    ChatScreenHarness.setUpAll();
    ProfileScreenHarness.setUpAll();
    NewChatHarness.registerFallbacks();
  });

  _everyScreen(gallery);

  // The same screens again at the two text sizes the accessibility settings
  // can reach. A screen that cannot take them does not merely look cramped:
  // it throws a layout overflow, which fails the test on its own.
  for (final MapEntry(key: suffix, value: scale) in galleryTextScales.entries) {
    group('at ×$scale', () => _everyScreen(textScaled(suffix, scale)));
  }
}

void _everyScreen(GallerySection gallery) {
  group('the chat list', () => chatsListGallery(gallery));
  group('a conversation', () => conversationGallery(gallery));
  group('a chat profile', () => chatProfileGallery(gallery));
  group('a person', () => personGallery(gallery));
  group('the address book', () => contactsGallery(gallery));
  group('settings', () => settingsGallery(gallery));
  group('a new group', () => newGroupGallery(gallery));
  group('signing in', () => signInGallery(gallery));
}

/// Runs [body] once per window and theme, under `gallery_<name>_…`.
void gallery(String name, GalleryBody body) {
  for (final window in PaneWindow.values) {
    for (final MapEntry(key: theme, value: dark) in galleryThemes.entries) {
      testGoldens('$name · ${window.name} · $theme', (tester) async {
        await body(tester, window, dark);
        await screenMatchesGolden(
          tester,
          'gallery_${name}_${window.name}_$theme',
        );
      });
    }
  }
}

/// The two sizes a reader can enlarge type to, and what their pictures are
/// called.
const Map<String, double> galleryTextScales = {'x13': 1.3, 'x20': 2.0};

/// Runs [body] on a phone with the OS text scale turned up to [scale].
///
/// One window and one theme: what a larger text size breaks is a row that
/// stops fitting, and the narrowest pane is where it stops fitting first.
/// The scale goes on the platform rather than into each screen's own
/// `MediaQuery`, so it reaches every app these sections build without any
/// of them knowing about it — exactly as the OS setting does.
///
/// It is turned up *after* the screen is mounted because `pumpWidgetBuilder`
/// pins the platform scale to 1.0 on every pump; the frame after is the one
/// that counts, and it is the same thing the OS does when the setting is
/// changed under a running app.
GallerySection textScaled(String suffix, double scale) {
  return (String name, GalleryBody body) {
    testGoldens('$name · $scale', (tester) async {
      await body(tester, PaneWindow.phone, false);

      tester.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpAndSettle();

      await screenMatchesGolden(tester, 'scaled_${name}_$suffix');
    });
  };
}

typedef GalleryBody =
    Future<void> Function(WidgetTester tester, PaneWindow window, bool dark);

/// What [gallery] does with one screen: the signature the sections take, so
/// each section can be a plain function.
typedef GallerySection = void Function(String name, GalleryBody body);

const Map<String, bool> galleryThemes = {'light': false, 'dark': true};

// ---------------------------------------------------------------------------
// Shared fixtures
// ---------------------------------------------------------------------------

const int _me = 7;
const UserEntity _meUser = UserEntity(
  id: _me,
  username: 'maria',
  email: 'maria@example.com',
);

/// Noon on a Saturday: the list's stamps come out as a clock time, "вчера",
/// a weekday and a date, so one picture shows all four shapes.
final DateTime _now = DateTime(2026, 10, 10, 12);

class _FakeAuth extends AuthController {
  @override
  Future<UserEntity?> build() async => _meUser;
}

class _FakeChatList extends ChatListController {
  _FakeChatList(this._state, {super.isArchive});

  final ChatListState _state;

  @override
  Future<ChatListState> build() async => _state;

  @override
  Future<void> refresh() async {}
}

class _FakeBadge extends NotificationBadgeController {
  _FakeBadge(this._count);

  final int _count;

  @override
  int build() => _count;
}

class _KnownPresence extends ChatPresenceController {
  _KnownPresence(this._online);

  final Map<String, bool> _online;

  @override
  Map<String, bool> build() => _online;

  @override
  void ensureFresh(String chatId) {}
}

class _FakeChatDetail extends ChatDetailController {
  _FakeChatDetail(super.chatId, this._state);

  final ChatDetailState _state;

  @override
  Future<ChatDetailState> build() async => _state;
}

class _MockGetMembers extends Mock implements GetMembersUseCase {}

class _MockAuthRepository extends Mock implements AuthRepository {}

class _EmptyLocalMessages implements GetLocalMessagesUseCase {
  @override
  List<MessageEntity> execute(String chatId, {int limit = 60}) => const [];
}

ChatProfileEntity _person(int id, String name, {String? username}) =>
    ChatProfileEntity(
      userId: id,
      username: username ?? name.toLowerCase(),
      displayName: name,
      avatarUrl: null,
      avatarS3Key: null,
    );

/// The chat area beside the list on a desktop, for the screens that are
/// themselves the list. Only its colour matters here.
class _ChatPaneStub extends StatelessWidget {
  const _ChatPaneStub();

  @override
  Widget build(BuildContext context) =>
      ColoredBox(color: ChatixTheme.of(context).chatBackground);
}

/// Puts [list] where the shell puts the 360 px list pane, with the chat area
/// after it — for a screen that *is* the list rather than one that opens
/// beside it.
Widget _listPane(PaneWindow window, Widget list) {
  if (!window.hasList) return PaneFrame(window: window, child: list);

  return PaneFrame(
    window: window,
    listStub: false,
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(width: AppBreakpoints.listPaneWidth, child: list),
        const VerticalDivider(width: 1, thickness: 1),
        const Expanded(child: _ChatPaneStub()),
      ],
    ),
  );
}

/// One app around [home] or [router], with the clock pinned and the locale
/// fixed, so nothing in a picture depends on the day it was taken.
Widget _app({
  required ProviderContainer container,
  required bool dark,
  Widget? home,
  GoRouter? router,
}) {
  final theme = dark ? AppTheme.dark() : AppTheme.light();
  Widget clock(BuildContext context, Widget? inner) =>
      AppClock(now: _now, child: inner!);

  return UncontrolledProviderScope(
    container: container,
    child: router != null
        ? MaterialApp.router(
            debugShowCheckedModeBanner: false,
            theme: theme,
            locale: const Locale('ru'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            builder: clock,
            routerConfig: router,
          )
        : MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: theme,
            locale: const Locale('ru'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            builder: clock,
            home: home,
          ),
  );
}

Future<void> _pumpApp(
  WidgetTester tester,
  Widget app, {
  required PaneWindow window,
}) async {
  await tester.pumpWidgetBuilder(
    app,
    wrapper: (child) => child,
    surfaceSize: window.size,
  );
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpAndSettle();
}

/// A page every route a screen can open lands on, so a picture of a screen
/// is never a picture of a router error.
class _Probe extends StatelessWidget {
  const _Probe(this.label);

  final String label;

  @override
  Widget build(BuildContext context) =>
      Scaffold(body: Center(child: Text(label)));
}

// ---------------------------------------------------------------------------
// The chat list
// ---------------------------------------------------------------------------

void chatsListGallery(GallerySection gallery) {
  MessageEntity last(
    String chatId,
    String content, {
    required int seq,
    int authorId = 12,
    String author = 'Грейс',
    DateTime? at,
  }) => MessageEntity(
    id: '$chatId-m$seq',
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
    createdAt: at ?? _now,
    profile: _person(authorId, author),
  );

  ChatEntity chat(
    String id, {
    String? name,
    ChatType type = ChatType.group,
    int unread = 0,
    bool pinned = false,
    bool muted = false,
    ChatProfileEntity? peer,
    MessageEntity? message,
    DateTime? at,
  }) => ChatEntity(
    id: id,
    seqCounter: 3,
    lastActivityAt: at ?? _now,
    type: type,
    name: type == ChatType.direct ? null : (name ?? 'Chat $id'),
    description: null,
    avatarS3Key: null,
    isPublic: false,
    adminOnly: false,
    slowModeSeconds: 0,
    permissions: const {},
    createdBy: 1,
    memberCount: type == ChatType.direct ? 2 : 5,
    unreadCount: unread,
    lastMessage: message,
    peer: peer,
    state: pinned || muted
        ? ChatStateEntity(isPinned: pinned, isMutedByMe: muted)
        : null,
  );

  /// The mix a list has to hold: a pinned group with a mention, a direct
  /// chat of somebody who is here now, a silenced group, a channel, and a
  /// few older rows down to a dated one.
  final rows = <ChatEntity>[
    chat(
      'pinned',
      name: 'Release crew',
      unread: 12,
      pinned: true,
      message: last('pinned', 'Мария, посмотри заметки', seq: 3),
      at: _now.subtract(const Duration(minutes: 4)),
    ),
    chat(
      'direct-ada',
      type: ChatType.direct,
      peer: _person(42, 'Ada Lovelace', username: 'ada'),
      unread: 2,
      message: last(
        'direct-ada',
        'Отправила правки, глянь когда будет минутка',
        seq: 9,
        authorId: 42,
        author: 'Ada Lovelace',
      ),
      at: _now.subtract(const Duration(hours: 1)),
    ),
    chat(
      'muted',
      name: 'Дизайн · обои и иконки',
      unread: 48,
      muted: true,
      message: last('muted', 'Залил новую сетку в фигму', seq: 31),
      at: _now.subtract(const Duration(hours: 5)),
    ),
    chat(
      'channel',
      name: 'ChatiX · что нового',
      type: ChatType.channel,
      message: last(
        'channel',
        'Голосовые теперь рисуют форму волны',
        seq: 2,
        authorId: 1,
        author: 'ChatiX',
      ),
      at: _now.subtract(const Duration(days: 1)),
    ),
    chat(
      'direct-grace',
      type: ChatType.direct,
      peer: _person(12, 'Grace Hopper', username: 'grace'),
      message: last(
        'direct-grace',
        'Спасибо!',
        seq: 4,
        authorId: 12,
        author: 'Grace Hopper',
      ),
      at: _now.subtract(const Duration(days: 3)),
    ),
    chat(
      'old',
      name: 'Отпуск 2025',
      message: last('old', 'Фото я сложила в альбом', seq: 7),
      at: DateTime(2026, 4, 2, 9),
    ),
  ];

  gallery('chats', (tester, window, dark) async {
    final getMembers = _MockGetMembers();
    when(
      () => getMembers.execute(
        any(),
        limit: any(named: 'limit'),
        includePresence: any(named: 'includePresence'),
      ),
    ).thenAnswer(
      (invocation) async => Right(
        MembersPage(
          members: const [
            ChatMemberEntity(
              userId: 1000,
              roleId: 4,
              isMuted: false,
              isBanned: false,
              permissionsOverrides: {},
            ),
          ],
          hasNext: false,
          nextUserId: null,
          presence: [
            MemberPresenceEntity(
              userId: 1000,
              isOnline: invocation.positionalArguments.first == 'direct-ada',
            ),
          ],
        ),
      ),
    );

    final container = ProviderContainer(
      retry: (_, _) => null,
      overrides: [
        authProvider.overrideWith(_FakeAuth.new),
        chatLocalPrefsStoreProvider.overrideWithValue(
          InMemoryChatLocalPrefsStore(),
        ),
        chatOrganizerDataSourceProvider.overrideWithValue(
          InMemoryChatOrganizerDataSource(),
        ),
        contactsLocalStoreProvider.overrideWithValue(
          KeyValueContactsLocalStore(MemoryKeyValueTable()),
        ),
        chatListProvider.overrideWith(
          () => _FakeChatList(ChatListState(items: rows)),
        ),
        archivedChatListProvider.overrideWith(
          () => _FakeChatList(const ChatListState(), isArchive: true),
        ),
        notificationBadgeProvider.overrideWith(() => _FakeBadge(3)),
        getMembersUseCaseProvider.overrideWithValue(getMembers),
        chatSocketStateProvider.overrideWith((ref) => ChatSocketStatus.ready),
        hasNetworkLinkProvider.overrideWithValue(true),
      ],
    );
    addTearDown(container.dispose);

    // Resolved before the first frame: the rows that ask for presence on
    // mount need to know who is asking.
    await container.read(authProvider.future);
    await container.read(chatOrganizerProvider.future);

    final router = GoRouter(
      initialLocation: ChatsRoute.location,
      routes: [
        GoRoute(
          path: ChatsRoute.path,
          builder: (context, _) => _listPane(
            window,
            ChatsListScreen(
              selectedChatId: window.hasList ? 'direct-ada' : null,
            ),
          ),
          routes: [
            GoRoute(
              path: CreateChatRoute.path,
              builder: (_, _) => const _Probe('create'),
            ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);

    await _pumpApp(
      tester,
      _app(container: container, dark: dark, router: router),
      window: window,
    );
  });
}

// ---------------------------------------------------------------------------
// A conversation with one of everything in it
// ---------------------------------------------------------------------------

/// [ChatScreenHarness] over a conversation that has a photo, a document, a
/// voice message and a reply in it, rather than text alone.
class _RichConversation extends ChatScreenHarness {
  _RichConversation() : super(type: ChatType.group);

  AttachmentEntity _attachment(
    String id, {
    required AttachmentType type,
    required String filename,
    required String mimeType,
    int? width,
    int? height,
    int? duration,
    int size = 2048,
  }) => AttachmentEntity(
    id: id,
    messageId: null,
    chatId: ChatScreenHarness.chatId,
    uploaderId: ChatScreenHarness.ada.id,
    attachmentType: type,
    attachmentStatus: AttachmentStatus.success,
    url: null,
    urlExpiresIn: null,
    s3Key: 'chats/${ChatScreenHarness.chatId}/$id',
    mimeType: mimeType,
    originalFilename: filename,
    size: size,
    width: width,
    height: height,
    durationSeconds: duration,
    createdAt: DateTime(2026, 10, 10, 9),
  );

  MessageEntity _rich(
    int seq,
    HarnessPerson author, {
    String? content,
    List<AttachmentEntity> attachments = const [],
    MessageEntity? replyTo,
    MessageType type = MessageType.text,
  }) => MessageEntity(
    id: 'm$seq',
    chatId: ChatScreenHarness.chatId,
    seq: seq,
    authorId: author.id,
    type: type,
    content: content,
    replyToId: replyTo?.id,
    forwardedFromChatId: null,
    forwardedFromMessageId: null,
    forwardedFromAuthorId: null,
    isEdited: false,
    createdAt: DateTime(2026, 10, 10, 9).add(Duration(minutes: seq)),
    attachments: attachments,
    profile: author.profile,
    replyTo: replyTo,
  );

  /// The photo in the feed, written where the file cache would have put it.
  static const String photoId = 'ridge';

  @override
  List<MessageEntity> get messages {
    final opening = _rich(
      1,
      ChatScreenHarness.ada,
      content: 'Заметки к релизу готовы?',
    );

    return [
      _rich(
        6,
        ChatScreenHarness.myself,
        content: 'Да, всё в документе выше — правки вносите прямо в него',
        replyTo: opening,
      ),
      _rich(
        5,
        ChatScreenHarness.ada,
        type: MessageType.voice,
        attachments: [
          _attachment(
            'voice-1',
            type: AttachmentType.voice,
            filename: 'voice.ogg',
            mimeType: 'audio/ogg',
            duration: 65,
            size: 5120,
          ),
        ],
      ),
      _rich(
        4,
        ChatScreenHarness.myself,
        type: MessageType.file,
        attachments: [
          _attachment(
            'doc-1',
            type: AttachmentType.file,
            filename: 'Заметки к релизу 2.4.pdf',
            mimeType: 'application/pdf',
            size: 184320,
          ),
        ],
      ),
      _rich(
        3,
        ChatScreenHarness.ada,
        type: MessageType.image,
        content: 'Вид с хребта — стоило каждого шага подъёма',
        attachments: [
          _attachment(
            photoId,
            type: AttachmentType.image,
            filename: '$photoId.png',
            mimeType: 'image/png',
            width: 1600,
            height: 1200,
          ),
        ],
      ),
      _rich(
        2,
        ChatScreenHarness.myself,
        content: 'Почти — осталось два раздела',
      ),
      opening,
    ];
  }
}

void conversationGallery(GallerySection gallery) {
  late Directory photosDir;
  late File photo;
  late _RichConversation harness;

  setUpAll(() {
    photosDir = Directory.systemTemp.createTempSync('screens_gallery');
    photo = TestPhotos.write(
      photosDir,
      name: _RichConversation.photoId,
      width: 160,
      height: 120,
      palette: 2,
    );
  });

  tearDownAll(() {
    if (photosDir.existsSync()) photosDir.deleteSync(recursive: true);
  });

  setUp(() {
    // A picture the previous test started loading is still pending in the
    // shared cache, tied to that test's fake clock, and would never finish.
    PaintingBinding.instance.imageCache
      ..clear()
      ..clearLiveImages();

    harness = _RichConversation()..setUp();
  });

  tearDown(() => harness.tearDown());

  gallery('chat', (tester, window, dark) async {
    await harness.pump(
      tester,
      window: window,
      dark: dark,
      overrides: [
        voiceLocalStoreProvider.overrideWithValue(InMemoryVoiceLocalStore()),
        // The file cache is the seam: what is on disk is what is drawn.
        autoAttachmentFileProvider.overrideWith(
          (ref, key) async =>
              key.attachment.id == _RichConversation.photoId ? photo : null,
        ),
        attachmentFileProvider.overrideWith((ref, key) async => photo),
      ],
    );

    await waitForImages(tester);
    await tester.pumpAndSettle();
  });
}

// ---------------------------------------------------------------------------
// A chat's profile
// ---------------------------------------------------------------------------

void chatProfileGallery(GallerySection gallery) {
  ChatMemberEntity member(int userId, String? name, {ChatRole? role}) =>
      ChatMemberEntity(
        userId: userId,
        roleId: (role ?? ChatRole.member).id,
        isMuted: false,
        isBanned: false,
        permissionsOverrides: const {},
        profile: name == null ? null : _person(userId, name),
      );

  final crew = ChatEntity(
    id: 'crew',
    seqCounter: 4,
    lastActivityAt: _now,
    type: ChatType.group,
    name: 'Release crew',
    description: 'Всё про релиз 2.4 — заметки, сборки и даты',
    avatarS3Key: null,
    isPublic: false,
    adminOnly: false,
    slowModeSeconds: 0,
    permissions: const {},
    createdBy: 42,
    memberCount: 4,
    members: [
      member(_me, 'Мария Иванова'),
      member(42, 'Ada Lovelace', role: ChatRole.owner),
      member(43, 'Grace Hopper'),
      member(44, 'Линус Торвальдс'),
    ],
  );

  gallery('chat_profile', (tester, window, dark) async {
    final container = ProviderContainer(
      retry: (_, _) => null,
      overrides: [
        authProvider.overrideWith(_FakeAuth.new),
        getLocalMessagesUseCaseProvider.overrideWithValue(
          _EmptyLocalMessages(),
        ),
        chatDetailProvider(crew.id).overrideWith(
          () => _FakeChatDetail(
            crew.id,
            ChatDetailState(chat: crew, myUserId: _me),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    await container.read(authProvider.future);

    final router = GoRouter(
      initialLocation: ChatInfoRoute.locationOf(crew.id),
      routes: [
        GoRoute(
          path: ChatInfoRoute.locationOf(crew.id),
          builder: (_, _) => PaneFrame(
            window: window,
            child: ChatProfileScreen(chatId: crew.id),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);

    await _pumpApp(
      tester,
      _app(container: container, dark: dark, router: router),
      window: window,
    );
  });
}

// ---------------------------------------------------------------------------
// A person's profile
// ---------------------------------------------------------------------------

void personGallery(GallerySection gallery) {
  late ProfileScreenHarness harness;

  setUp(() => harness = ProfileScreenHarness());

  gallery('person', (tester, window, dark) async {
    await harness.pump(
      tester,
      profile: kAda,
      contact: kAdaInBook,
      directChatId: kProfileChatId,
      online: true,
      window: window,
      dark: dark,
    );
  });
}

// ---------------------------------------------------------------------------
// The address book
// ---------------------------------------------------------------------------

void contactsGallery(GallerySection gallery) {
  final book = [
    contact(1, displayName: 'Анна Смирнова', isFavorite: true, isMutual: true),
    contact(2, displayName: 'Борис Петров', username: 'boris'),
    contact(
      3,
      displayName: 'Ivan Petrov',
      firstName: 'Ваня',
      lastName: 'Работа',
    ),
    contact(4, displayName: 'Ёлка Новогодняя'),
    contact(5, displayName: 'Емельян', isMutual: true),
    contact(6, displayName: 'Anna Schmidt', username: 'anna_s'),
    contact(7, displayName: 'Grace Hopper', isFavorite: true),
    contact(8, username: 'linus'),
    contact(9, displayName: 'Zoe', isMutual: true),
    contact(10, displayName: '42 Pizza', username: 'pizza42'),
  ];

  gallery('contacts', (tester, window, dark) async {
    final store = KeyValueContactsLocalStore(MemoryKeyValueTable());
    await tester.runAsync(
      () => store.save(
        ContactsSnapshot(ownerId: kOwnerId, contacts: book, version: 'v1'),
      ),
    );
    final remote = FakeContactsRemote(
      onPage: pagesOf(book, size: 500, version: 'v2'),
    );

    final container = ProviderContainer(
      retry: (_, _) => null,
      overrides: [
        authProvider.overrideWith(_FakeAuth.new),
        contactsLocalStoreProvider.overrideWithValue(store),
        contactsRepositoryProvider.overrideWith(
          (ref) => ContactsRepositoryImpl(remote: remote, local: store),
        ),
        // Grace has a direct chat, and is here right now.
        directChatIdsProvider.overrideWithValue(const {7: 'chat-grace'}),
        chatPresenceProvider.overrideWith(
          () => _KnownPresence(const {'chat-grace': true}),
        ),
      ],
    );
    addTearDown(container.dispose);
    // Signed in before the tab opens, as in the app: the sync on open has
    // somebody to sync for.
    await tester.runAsync(() => container.read(authProvider.future));

    await _pumpApp(
      tester,
      _app(
        container: container,
        dark: dark,
        home: _listPane(window, const ContactsScreen()),
      ),
      window: window,
    );
  });
}

// ---------------------------------------------------------------------------
// Settings
// ---------------------------------------------------------------------------

void settingsGallery(GallerySection gallery) {
  gallery('settings', (tester, window, dark) async {
    // The shell draws its own list beside the section on a desktop, so this
    // one needs no stub of ours.
    await SettingsHarness(
      alerts: 3,
      cacheUsage: 48 * 1024 * 1024,
    ).pump(tester, window: window, dark: dark);
  });
}

// ---------------------------------------------------------------------------
// Making a group
// ---------------------------------------------------------------------------

void newGroupGallery(GallerySection gallery) {
  gallery('new_group', (tester, window, dark) async {
    // The step that picks people: the chips, the search field and the roster
    // under them, which is where a narrow pane shows first.
    await NewChatHarness().pump(
      tester,
      location: NewGroupRoute.location,
      window: window,
      dark: dark,
    );
  });
}

// ---------------------------------------------------------------------------
// Signing in
// ---------------------------------------------------------------------------

void signInGallery(GallerySection gallery) {
  gallery('sign_in', (tester, window, dark) async {
    final container = ProviderContainer(
      retry: (_, _) => null,
      overrides: [
        ...defaultTestOverrides(),
        authRepositoryProvider.overrideWithValue(_MockAuthRepository()),
        // Switched on so the buttons' layout is in the picture; the shipped
        // build offers none until the backend's callback can hand a session
        // back (see `oauthProvidersProvider`).
        oauthProvidersProvider.overrideWithValue(OAuthProvider.values),
      ],
    );
    addTearDown(container.dispose);

    // Signed out: no rail and no list beside the form, so this one is the
    // whole window at every size.
    await _pumpApp(
      tester,
      _app(container: container, dark: dark, home: const LoginScreen()),
      window: window,
    );

    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
  });
}
