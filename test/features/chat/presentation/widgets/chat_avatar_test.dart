import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';

import 'package:chatix/core/theme/app_theme_extension.dart';
import 'package:chatix/features/chat/domain/entities/chat_profile_entity.dart';
import 'package:chatix/features/chat/presentation/widgets/chat_avatar.dart';
import 'package:chatix/features/profile/domain/entities/profile_entity.dart';

import '../../../../helpers/chat_golden.dart';

void main() {
  const s3Key = 'avatars/42/portrait.jpg';

  ChatProfileEntity profile({String? url, String? key = s3Key}) =>
      ChatProfileEntity(
        userId: 42,
        username: 'ada',
        displayName: 'Ada Lovelace',
        avatarUrl: url,
        avatarS3Key: key,
      );

  Future<void> pumpAvatar(WidgetTester tester, Widget avatar) =>
      tester.pumpWidget(MaterialApp(home: Scaffold(body: avatar)));

  /// The provider the avatar is drawn from, with the decode cap unwrapped.
  ///
  /// Every face is wrapped in a [ResizeImage] so a 256-px variant is not
  /// decoded at 256 px for a 24-px circle; what the tests below care about
  /// is the provider underneath, and its cache key.
  ImageProvider? providerOf(WidgetTester tester) {
    final images = tester.widgetList<Image>(find.byType(Image));
    if (images.isEmpty) return null;

    final image = images.first.image;
    return image is ResizeImage ? image.imageProvider : image;
  }

  /// The width the same face is capped to.
  int? decodeWidthOf(WidgetTester tester) {
    final images = tester.widgetList<Image>(find.byType(Image));
    if (images.isEmpty) return null;

    final image = images.first.image;
    return image is ResizeImage ? image.width : null;
  }

  group('image source', () {
    testWidgets('caches by avatar_s3_key, never by the presigned URL', (
      tester,
    ) async {
      await pumpAvatar(
        tester,
        ChatAvatar.profile(
          profile(url: 'https://s3.example.com/a.jpg?X-Amz-Signature=abc123'),
        ),
      );

      final image = providerOf(tester);
      expect(image, isA<CachedNetworkImageProvider>());

      // `ChatProfileDTO.avatar_url` is minted per response (api-docs §5.3):
      // its signature changes every fetch, so keying the cache on it would
      // miss every time and break once a signature expires under a live
      // widget.
      expect((image! as CachedNetworkImageProvider).cacheKey, s3Key);
    });

    testWidgets('two signatures of the same file share a cache key', (
      tester,
    ) async {
      await pumpAvatar(
        tester,
        ChatAvatar.profile(profile(url: 'https://s3.example.com/a.jpg?sig=1')),
      );
      final first =
          (providerOf(tester)! as CachedNetworkImageProvider).cacheKey;

      await pumpAvatar(
        tester,
        ChatAvatar.profile(profile(url: 'https://s3.example.com/a.jpg?sig=2')),
      );
      final second =
          (providerOf(tester)! as CachedNetworkImageProvider).cacheKey;

      expect(first, second);
    });

    testWidgets('falls back to the URL as key when there is no s3_key', (
      tester,
    ) async {
      const url = 'https://s3.example.com/a.jpg';
      await pumpAvatar(
        tester,
        ChatAvatar.profile(profile(url: url, key: null)),
      );

      expect((providerOf(tester)! as CachedNetworkImageProvider).cacheKey, url);
    });

    testWidgets('picks a variant for the size it is drawn at (api-docs §4.3)', (
      tester,
    ) async {
      await pumpAvatar(
        tester,
        ChatAvatar(
          size: ChatAvatarSize.xs,
          source: AvatarSource.variants(const {
            '32': {'webp': 'small.webp'},
            '256': {'webp': 'large.webp'},
          }),
        ),
      );

      // 28 logical px at the test's 3× ratio wants more than the 32 variant.
      expect(
        (providerOf(tester)! as CachedNetworkImageProvider).url,
        'large.webp',
      );
    });

    testWidgets('an empty avatars object is not an image', (tester) async {
      await pumpAvatar(
        tester,
        const ChatAvatar(name: 'Ada', source: AvatarSource.none),
      );

      expect(find.byType(Image), findsNothing);
      expect(find.text('A'), findsOneWidget);
    });
  });

  group('initials', () {
    testWidgets('shows the first letter of the best name', (tester) async {
      await pumpAvatar(tester, ChatAvatar.profile(profile(url: null)));
      expect(find.text('A'), findsOneWidget);
    });

    testWidgets('strips the @ sigil so the circle shows a letter', (
      tester,
    ) async {
      await pumpAvatar(
        tester,
        ChatAvatar.profile(
          const ChatProfileEntity(
            userId: 42,
            username: 'ada',
            displayName: null,
            avatarUrl: null,
            avatarS3Key: null,
          ),
        ),
      );

      expect(find.text('A'), findsOneWidget);
    });

    testWidgets('degrades to "?" with no profile at all', (tester) async {
      await pumpAvatar(tester, ChatAvatar.profile(null));
      expect(find.text('?'), findsOneWidget);
    });

    testWidgets('the same user keeps the same colour', (tester) async {
      await pumpAvatar(
        tester,
        const Row(
          children: [
            ChatAvatar(userId: 7, name: 'Grace'),
            ChatAvatar(userId: 7, name: 'Grace', size: ChatAvatarSize.lg),
          ],
        ),
      );

      final fills = tester
          .widgetList<Container>(find.byType(Container))
          .map((c) => c.color)
          .whereType<Color>()
          .toSet();

      expect(fills, hasLength(1));
    });
  });

  group('sizes', () {
    // The diameters every surface is held to, in one place, so a new size
    // has to be added here on purpose.
    test('match the places they are drawn in', () {
      expect(ChatAvatarSize.sm.diameter, 32, reason: 'message gutter');
      expect(ChatAvatarSize.md.diameter, 40, reason: 'app bar');
      expect(ChatAvatarSize.lg.diameter, inInclusiveRange(52, 54));
      expect(ChatAvatarSize.xl.diameter, inInclusiveRange(96, 112));
      expect(ChatAvatarSize.xxl.diameter, inInclusiveRange(96, 112));
    });

    test('run smallest to largest', () {
      final diameters = [
        for (final size in ChatAvatarSize.values) size.diameter,
      ];
      expect(diameters, [...diameters]..sort());
    });
  });

  /// The circle itself: the box the face is clipped to.
  Finder face() => find
      .descendant(of: find.byType(ChatAvatar), matching: find.byType(ClipPath))
      .first;

  Widget forced(Size size, Widget child) => Center(
    child: ConstrainedBox(
      constraints: BoxConstraints.tight(size),
      child: child,
    ),
  );

  group("under someone else's constraints", () {
    // A 44 px column less 12 px of padding forced a 28 px avatar into 32×28,
    // and its clip into an oval. The circle has to survive any box.
    testWidgets('a tight box wider than it is tall leaves a circle', (
      tester,
    ) async {
      await pumpAvatar(
        tester,
        forced(
          const Size(32, 28),
          const ChatAvatar(name: 'Ada', size: ChatAvatarSize.xs),
        ),
      );

      expect(tester.getSize(face()), const Size(28, 28));
      expect(tester.getSize(find.byType(ChatAvatar)), const Size(32, 28));
    });

    testWidgets('and sits in the middle of it', (tester) async {
      await pumpAvatar(
        tester,
        forced(
          const Size(60, 28),
          const ChatAvatar(name: 'Ada', size: ChatAvatarSize.xs),
        ),
      );

      expect(
        tester.getCenter(face()),
        tester.getCenter(find.byType(ChatAvatar)),
      );
    });

    testWidgets('a box larger all round does not inflate it', (tester) async {
      await pumpAvatar(
        tester,
        forced(
          const Size(120, 90),
          const ChatAvatar(name: 'Ada', size: ChatAvatarSize.sm),
        ),
      );

      expect(tester.getSize(face()), const Size.square(32));
    });

    testWidgets('a box too small for it gets the largest circle that fits', (
      tester,
    ) async {
      await pumpAvatar(
        tester,
        forced(
          const Size(24, 20),
          const ChatAvatar(name: 'Ada', size: ChatAvatarSize.xs),
        ),
      );

      expect(tester.getSize(face()), const Size.square(20));
      expect(tester.takeException(), isNull);
    });

    testWidgets('loose and unbounded, it is exactly its diameter', (
      tester,
    ) async {
      await pumpAvatar(
        tester,
        const Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [ChatAvatar(name: 'Ada', size: ChatAvatarSize.md)],
        ),
      );

      expect(tester.getSize(face()), const Size.square(40));
    });

    testWidgets('the presence notch keeps the same circle', (tester) async {
      await pumpAvatar(
        tester,
        forced(
          const Size(48, 40),
          const ChatAvatar(
            name: 'Ada',
            size: ChatAvatarSize.md,
            isOnline: true,
          ),
        ),
      );

      expect(tester.getSize(face()), const Size.square(40));
    });

    testWidgets('so does a mosaic', (tester) async {
      await pumpAvatar(
        tester,
        forced(
          const Size(52, 40),
          ChatAvatarMosaic(
            size: ChatAvatarSize.md,
            faces: [
              for (var i = 0; i < 3; i++) AvatarFace(userId: i, name: 'U$i'),
            ],
          ),
        ),
      );

      expect(
        tester.getSize(
          find.descendant(
            of: find.byType(ChatAvatarMosaic),
            matching: find.byType(ClipOval),
          ),
        ),
        const Size.square(40),
      );
    });
  });

  group('a full profile', () {
    ProfileEntity person({
      String username = 'ada',
      String? displayName = 'Ada Lovelace',
      Map<String, Map<String, String>> avatars = const {},
    }) => ProfileEntity(
      id: 42,
      username: username,
      avatars: avatars,
      specialization: null,
      displayName: displayName,
      bio: null,
      dateBirthday: null,
      skills: const [],
      contacts: const [],
    );

    /// The ground the initial is drawn on.
    Color fillOf(WidgetTester tester, Finder avatar) => tester
        .widgetList<Container>(
          find.descendant(of: avatar, matching: find.byType(Container)),
        )
        .map((container) => container.color)
        .whereType<Color>()
        .first;

    testWidgets('is the same colour as the same person in a chat', (
      tester,
    ) async {
      // `ProfileDTO.id` is the user id (api-docs §4.3): the profile screen
      // and a chat row have to agree on it, or one person is two colours.
      await pumpAvatar(
        tester,
        Row(
          children: [
            ChatAvatar.person(person(), key: const Key('profile')),
            ChatAvatar.profile(profile(url: null), key: const Key('chat')),
          ],
        ),
      );

      final fromProfile = fillOf(tester, find.byKey(const Key('profile')));
      final fromChat = fillOf(tester, find.byKey(const Key('chat')));

      expect(fromProfile, fromChat);
      expect(
        fromProfile,
        ChatixTheme.of(tester.element(find.byType(Row))).authorColor(42),
      );
    });

    testWidgets('and the same initial', (tester) async {
      await pumpAvatar(tester, ChatAvatar.person(person()));
      expect(find.text('A'), findsOneWidget);
    });

    testWidgets('falls back to the handle when there is no name', (
      tester,
    ) async {
      await pumpAvatar(
        tester,
        ChatAvatar.person(person(username: 'grace', displayName: '  ')),
      );
      expect(find.text('G'), findsOneWidget);
    });

    testWidgets('draws from the avatars matrix', (tester) async {
      await pumpAvatar(
        tester,
        ChatAvatar.person(
          person(
            avatars: const {
              '64': {'jpg': 'https://cdn.example.com/64.jpg'},
              '256': {
                'webp': 'https://cdn.example.com/256.webp',
                'jpg': 'https://cdn.example.com/256.jpg',
              },
            },
          ),
        ),
      );

      // 40 px at the test's 3× ratio is 120 physical: the 256 variant, and
      // webp ahead of jpg.
      expect(
        (providerOf(tester)! as CachedNetworkImageProvider).url,
        'https://cdn.example.com/256.webp',
      );
    });

    testWidgets('an empty matrix is initials, not a broken image', (
      tester,
    ) async {
      await pumpAvatar(tester, ChatAvatar.person(person()));
      expect(find.byType(Image), findsNothing);
    });
  });

  // Scaffold lays its own slots out with LayoutId, so tiles are only the
  // ones inside the mosaic itself.
  Finder tiles() => find.descendant(
    of: find.byType(ChatAvatarMosaic),
    matching: find.byType(LayoutId),
  );

  group('mosaic', () {
    testWidgets('draws one tile per member, up to four', (tester) async {
      await pumpAvatar(
        tester,
        ChatAvatarMosaic(
          faces: [
            for (var i = 0; i < 6; i++) AvatarFace(userId: i, name: 'User $i'),
          ],
        ),
      );

      expect(tiles(), findsNWidgets(ChatAvatarMosaic.maxTiles));
    });

    testWidgets('falls back to the chat-type icon with nobody to show', (
      tester,
    ) async {
      await pumpAvatar(tester, const ChatAvatarMosaic(faces: []));

      expect(find.byIcon(Icons.groups_outlined), findsOneWidget);
      expect(tiles(), findsNothing);
    });
  });

  group('decode size', () {
    // Two hundred rows of a chat list each hold a face. Decoded at the
    // variant's own size they are a hundred megabytes of bitmap; decoded at
    // the circle they are drawn in, they are a rounding error.
    testWidgets('a face is decoded for the circle, not for the file', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);

      await pumpAvatar(
        tester,
        ChatAvatar.profile(
          profile(url: 'https://s3.example.com/a.jpg?X-Amz-Signature=abc'),
          size: ChatAvatarSize.xs,
        ),
      );

      expect(decodeWidthOf(tester), (ChatAvatarSize.xs.diameter * 2).round());
    });

    testWidgets('a larger circle asks for a larger decode', (tester) async {
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);

      await pumpAvatar(
        tester,
        ChatAvatar.profile(
          profile(url: 'https://s3.example.com/a.jpg?X-Amz-Signature=abc'),
          size: ChatAvatarSize.lg,
        ),
      );

      expect(decodeWidthOf(tester), (ChatAvatarSize.lg.diameter * 2).round());
    });

    // A repaint boundary per face is what keeps one arriving picture from
    // redrawing every other row in the list.
    testWidgets('each face is its own layer', (tester) async {
      await pumpAvatar(
        tester,
        ChatAvatar.profile(
          profile(url: 'https://s3.example.com/a.jpg?X-Amz-Signature=abc'),
        ),
      );

      expect(
        find.descendant(
          of: find.byType(ChatAvatar),
          matching: find.byType(RepaintBoundary),
        ),
        findsWidgets,
      );
    });
  });

  group('goldens', () {
    for (final entry in chatGoldenThemes.entries) {
      testGoldens('avatars on the ${entry.key} theme', (tester) async {
        await pumpChatGolden(
          tester,
          name: 'chat_avatar_${entry.key}',
          dark: entry.value,
          surfaceSize: const Size(560, 380),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                spacing: 12,
                children: [
                  for (final size in ChatAvatarSize.values)
                    ChatAvatar(size: size, userId: size.index, name: 'Ada'),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                spacing: 12,
                children: [
                  ChatAvatar(
                    size: ChatAvatarSize.md,
                    userId: 3,
                    name: 'Grace',
                    isOnline: true,
                  ),
                  ChatAvatar(
                    size: ChatAvatarSize.md,
                    source: AvatarSource.provider(MemoryImage(kStubImageBytes)),
                  ),
                  ChatAvatar(
                    size: ChatAvatarSize.md,
                    source: AvatarSource.provider(MemoryImage(kStubImageBytes)),
                    isOnline: true,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                spacing: 12,
                children: [
                  for (var count = 1; count <= 4; count++)
                    ChatAvatarMosaic(
                      size: ChatAvatarSize.md,
                      faces: [
                        for (var i = 0; i < count; i++)
                          AvatarFace(userId: i, name: 'User $i'),
                      ],
                    ),
                  const ChatAvatarMosaic(size: ChatAvatarSize.md, faces: []),
                ],
              ),
              const SizedBox(height: 16),
              // Forced into boxes that are not their shape — the gutter that
              // used to squash them, a slot too small, a slot too wide. The
              // outline is the box; what is inside it should be a circle.
              Builder(
                builder: (context) => Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  spacing: 12,
                  children: [
                    for (final box in const [
                      Size(32, 28),
                      Size(24, 20),
                      Size(64, 40),
                    ])
                      DecoratedBox(
                        position: DecorationPosition.foreground,
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: Theme.of(context).colorScheme.outline,
                            width: 0.5,
                          ),
                        ),
                        child: SizedBox.fromSize(
                          size: box,
                          child: const ChatAvatar(
                            size: ChatAvatarSize.xs,
                            userId: 5,
                            name: 'Ada',
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      });
    }
  });
}
