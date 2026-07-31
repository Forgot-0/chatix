import 'package:flutter_test/flutter_test.dart';
import 'package:chatix/features/profile/domain/entities/profile_entity.dart';

void main() {
  ProfileEntity profileWithAvatars(Map<String, Map<String, String>> avatars) {
    return ProfileEntity(
      id: 1,
      avatars: avatars,
      specialization: null,
      displayName: null,
      bio: null,
      dateBirthday: null,
      skills: const [],
      contacts: const [],
    );
  }

  group('ProfileEntity.bestAvatarUrl', () {
    test('returns null when avatars is empty ("no avatar" per api-docs §4.3)', () {
      final profile = profileWithAvatars(const {});
      expect(profile.bestAvatarUrl(64), isNull);
      expect(profile.hasAvatar, isFalse);
    });

    test('picks the exact requested size when present, preferring webp', () {
      final profile = profileWithAvatars({
        '64': {'jpg': 'jpg64', 'webp': 'webp64', 'avif': 'avif64'},
        '256': {'jpg': 'jpg256', 'webp': 'webp256', 'avif': 'avif256'},
      });

      expect(profile.bestAvatarUrl(64), 'webp64');
    });

    test('falls back jpg then avif within a size when webp is missing', () {
      final profileWithJpg = profileWithAvatars({
        '64': {'jpg': 'jpg64', 'avif': 'avif64'},
      });
      expect(profileWithJpg.bestAvatarUrl(64), 'jpg64');

      final profileWithOnlyAvif = profileWithAvatars({
        '64': {'avif': 'avif64'},
      });
      expect(profileWithOnlyAvif.bestAvatarUrl(64), 'avif64');
    });

    test('prefers the nearest larger size over a smaller one when exact size is missing', () {
      final profile = profileWithAvatars({
        '32': {'webp': 'webp32'},
        '256': {'webp': 'webp256'},
        '512': {'webp': 'webp512'},
      });

      // 64 isn't available; 256 is the nearest size >= 64.
      expect(profile.bestAvatarUrl(64), 'webp256');
    });

    test('falls back to the nearest smaller size when nothing larger is available', () {
      final profile = profileWithAvatars({
        '32': {'webp': 'webp32'},
        '64': {'webp': 'webp64'},
      });

      // 512 isn't available and nothing is larger; falls back to 64 (the
      // largest size below 512), not 32.
      expect(profile.bestAvatarUrl(512), 'webp64');
    });

    test('skips a size whose format map is empty and uses the next best size', () {
      final profile = profileWithAvatars({
        '64': {},
        '256': {'webp': 'webp256'},
      });

      expect(profile.bestAvatarUrl(64), 'webp256');
    });
  });
}
