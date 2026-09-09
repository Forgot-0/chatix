import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chatix/features/chat/domain/entities/chat_profile_entity.dart';
import 'package:chatix/features/chat/presentation/widgets/chat_avatar.dart';

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

  Future<CircleAvatar> pumpAvatar(
    WidgetTester tester,
    ChatProfileEntity? subject,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ChatAvatar(profile: subject)),
      ),
    );
    return tester.widget<CircleAvatar>(find.byType(CircleAvatar));
  }

  testWidgets('caches by avatar_s3_key, never by the presigned URL', (
    tester,
  ) async {
    final avatar = await pumpAvatar(
      tester,
      profile(url: 'https://s3.example.com/a.jpg?X-Amz-Signature=abc123'),
    );

    final image = avatar.foregroundImage;
    expect(image, isA<CachedNetworkImageProvider>());

    // `ChatProfileDTO.avatar_url` is minted per response (api-docs §5.3): its
    // signature changes every fetch, so keying the cache on it would miss
    // every time and break once a signature expires under a live widget.
    expect((image! as CachedNetworkImageProvider).cacheKey, s3Key);
  });

  testWidgets('two different signatures of the same file share a cache key', (
    tester,
  ) async {
    final first = await pumpAvatar(
      tester,
      profile(url: 'https://s3.example.com/a.jpg?sig=one'),
    );
    final firstKey =
        (first.foregroundImage! as CachedNetworkImageProvider).cacheKey;

    final second = await pumpAvatar(
      tester,
      profile(url: 'https://s3.example.com/a.jpg?sig=two'),
    );
    final secondKey =
        (second.foregroundImage! as CachedNetworkImageProvider).cacheKey;

    expect(firstKey, secondKey);
  });

  testWidgets('falls back to the URL as key when the backend sent no s3_key', (
    tester,
  ) async {
    const url = 'https://s3.example.com/a.jpg';
    final avatar = await pumpAvatar(tester, profile(url: url, key: null));

    expect(
      (avatar.foregroundImage! as CachedNetworkImageProvider).cacheKey,
      url,
    );
  });

  testWidgets('shows an initial instead of an image when there is no avatar', (
    tester,
  ) async {
    final avatar = await pumpAvatar(tester, profile(url: null));

    expect(avatar.foregroundImage, isNull);
    expect(find.text('A'), findsOneWidget);
  });

  testWidgets('strips the @ sigil so the circle shows a letter', (
    tester,
  ) async {
    // bestName degrades to "@handle" when there is no display name.
    final avatar = await pumpAvatar(
      tester,
      const ChatProfileEntity(
        userId: 42,
        username: 'ada',
        displayName: null,
        avatarUrl: null,
        avatarS3Key: null,
      ),
    );

    expect(avatar.foregroundImage, isNull);
    expect(find.text('A'), findsOneWidget);
  });

  testWidgets('degrades to "?" with no profile at all', (tester) async {
    await pumpAvatar(tester, null);
    expect(find.text('?'), findsOneWidget);
  });
}
