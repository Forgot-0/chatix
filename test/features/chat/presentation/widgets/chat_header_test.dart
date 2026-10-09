import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';

import 'package:chatix/core/constants/app_constants.dart';
import 'package:chatix/core/theme/app_theme.dart';
import 'package:chatix/core/websocket/chat_socket_service.dart';
import 'package:chatix/features/chat/domain/entities/chat_entity.dart';
import 'package:chatix/features/chat/domain/entities/chat_member_entity.dart';
import 'package:chatix/features/chat/domain/entities/chat_profile_entity.dart';
import 'package:chatix/features/chat/presentation/providers/chat_socket_provider.dart';
import 'package:chatix/features/chat/presentation/widgets/chat_avatar.dart';
import 'package:chatix/features/chat/presentation/widgets/chat_header.dart';
import 'package:chatix/gen/l10n/app_localizations.dart';

import '../../../../helpers/fakes/fake_secure_storage_service.dart';
import '../../../../helpers/fakes/fake_web_socket_channel.dart';
import '../../../../helpers/pane_frame.dart';

/// The chat's app bar: every kind of chat has a face in it, the same one its
/// row in the list has, ready to fly into the profile.
void main() {
  const me = 7;

  ChatProfileEntity profile(int userId, String name) => ChatProfileEntity(
    userId: userId,
    username: name.toLowerCase(),
    displayName: name,
    avatarUrl: null,
    avatarS3Key: null,
  );

  ChatMemberEntity member(int userId, String name) => ChatMemberEntity(
    userId: userId,
    roleId: ChatRole.member.id,
    isMuted: false,
    isBanned: false,
    permissionsOverrides: const {},
    profile: profile(userId, name),
  );

  ChatEntity chat(
    String id,
    ChatType type, {
    String? name,
    ChatProfileEntity? peer,
    List<ChatMemberEntity>? members,
    int memberCount = 2,
  }) => ChatEntity(
    id: id,
    seqCounter: 1,
    lastActivityAt: DateTime(2026, 3, 2, 10),
    type: type,
    name: name,
    description: null,
    avatarS3Key: null,
    isPublic: type == ChatType.channel,
    adminOnly: false,
    slowModeSeconds: 0,
    permissions: const {},
    createdBy: me,
    memberCount: memberCount,
    peer: peer,
    members: members,
  );

  final directChat = chat('direct', ChatType.direct, peer: profile(42, 'Ada'));

  final groupChat = chat(
    'group',
    ChatType.group,
    name: 'Design Team',
    memberCount: 4,
    members: [
      member(me, 'Me'),
      member(42, 'Ada'),
      member(43, 'Grace'),
      member(44, 'Linus'),
    ],
  );

  // The detail endpoint hands a channel's roster over like any other; the
  // header must not turn its subscribers into the channel's face.
  final channelChat = chat(
    'channel',
    ChatType.channel,
    name: 'Release Notes',
    memberCount: 1200,
    members: [member(me, 'Me'), member(42, 'Ada'), member(43, 'Grace')],
  );

  late FakeWebSocketChannel socketChannel;
  late ChatSocketService socket;

  setUp(() {
    socketChannel = FakeWebSocketChannel();
    socket = ChatSocketService(
      secureStorage: FakeSecureStorageService(
        initialValues: {AppConstants.accessTokenKey: 'token'},
      ),
      channelFactory: (_) => socketChannel,
    );
  });

  tearDown(() async {
    await socket.dispose();
    await socketChannel.dispose();
  });

  Widget bar(ChatEntity source, {required bool back}) => AppBar(
    automaticallyImplyLeading: false,
    leading: back ? const BackButton() : null,
    titleSpacing: 0,
    title: ChatHeaderTitle(
      chatId: source.id,
      chat: source,
      myUserId: me,
      onTap: () {},
    ),
    actions: [
      IconButton(onPressed: () {}, icon: const Icon(Icons.search)),
      IconButton(onPressed: () {}, icon: const Icon(Icons.call_outlined)),
    ],
  );

  Future<void> pump(
    WidgetTester tester, {
    PaneWindow window = PaneWindow.phone,
    bool dark = false,
  }) async {
    final back = !window.hasList;

    await tester.pumpWidgetBuilder(
      ProviderScope(
        overrides: [chatSocketServiceProvider.overrideWithValue(socket)],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: dark ? AppTheme.dark() : AppTheme.light(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: PaneFrame(
            window: window,
            child: Scaffold(
              body: Column(
                children: [
                  for (final source in [
                    directChat,
                    groupChat,
                    channelChat,
                  ]) ...[bar(source, back: back), const Divider(height: 1)],
                ],
              ),
            ),
          ),
        ),
      ),
      wrapper: (child) => child,
      surfaceSize: window.size,
    );
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpAndSettle();
  }

  Finder heroOf(String chatId) => find.byWidgetPredicate(
    (widget) => widget is Hero && widget.tag == chatAvatarHeroTag(chatId),
  );

  Size circleIn(WidgetTester tester, Finder hero) => tester.getSize(
    find
        .descendant(
          of: hero,
          matching: find.byWidgetPredicate(
            (widget) => widget is ClipPath || widget is ClipOval,
          ),
        )
        .first,
  );

  testWidgets('every kind of chat has a face, ready to fly', (tester) async {
    await pump(tester);

    for (final id in ['direct', 'group', 'channel']) {
      expect(heroOf(id), findsOneWidget, reason: id);
      expect(
        circleIn(tester, heroOf(id)),
        Size.square(ChatAvatarSize.md.diameter),
        reason: id,
      );
    }
  });

  testWidgets('a direct chat shows the person', (tester) async {
    await pump(tester);

    expect(
      find.descendant(of: heroOf('direct'), matching: find.text('A')),
      findsOneWidget,
    );
  });

  testWidgets('a group without a picture shows its members', (tester) async {
    await pump(tester);

    expect(
      find.descendant(
        of: heroOf('group'),
        matching: find.byType(ChatAvatarMosaic),
      ),
      findsOneWidget,
    );
  });

  testWidgets('a channel shows its initial, not its subscribers', (
    tester,
  ) async {
    await pump(tester);

    expect(
      find.descendant(
        of: heroOf('channel'),
        matching: find.byType(ChatAvatarMosaic),
      ),
      findsNothing,
    );
    expect(
      find.descendant(of: heroOf('channel'), matching: find.text('R')),
      findsOneWidget,
    );
  });

  group('goldens', () {
    for (final window in [PaneWindow.phone, PaneWindow.desktop]) {
      for (final theme in {'light': false, 'dark': true}.entries) {
        testGoldens('chat headers, ${window.name}, ${theme.key}', (
          tester,
        ) async {
          await pump(tester, window: window, dark: theme.value);

          await screenMatchesGolden(
            tester,
            'chat_header_${window.name}_${theme.key}',
          );
        });
      }
    }
  });
}
