import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';

import 'package:chatix/features/chat/domain/entities/chat_profile_entity.dart';
import 'package:chatix/features/chat/presentation/widgets/chat_avatar.dart';

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

  ImageProvider? providerOf(WidgetTester tester) {
    final images = tester.widgetList<Image>(find.byType(Image));
    return images.isEmpty ? null : images.first.image;
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
      final first = (providerOf(tester)! as CachedNetworkImageProvider).cacheKey;

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

      expect(
        (providerOf(tester)! as CachedNetworkImageProvider).cacheKey,
        url,
      );
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
        const ChatAvatar(
          name: 'Ada',
          source: AvatarSource.none,
        ),
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

  group('goldens', () {
    for (final entry in chatGoldenThemes.entries) {
      testGoldens('avatars on the ${entry.key} theme', (tester) async {
        await pumpChatGolden(
          tester,
          name: 'chat_avatar_${entry.key}',
          dark: entry.value,
          surfaceSize: const Size(420, 300),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                spacing: 12,
                children: [
                  for (final size in ChatAvatarSize.values)
                    ChatAvatar(
                      size: size,
                      userId: size.index,
                      name: 'Ada',
                    ),
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
                    source: AvatarSource.provider(
                      MemoryImage(kStubImageBytes),
                    ),
                  ),
                  ChatAvatar(
                    size: ChatAvatarSize.md,
                    source: AvatarSource.provider(
                      MemoryImage(kStubImageBytes),
                    ),
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
                  const ChatAvatarMosaic(
                    size: ChatAvatarSize.md,
                    faces: [],
                  ),
                ],
              ),
            ],
          ),
        );
      });
    }
  });
}
