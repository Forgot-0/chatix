import 'package:flutter_test/flutter_test.dart';

import 'package:chatix/core/media/avatar_variants.dart';

void main() {
  const full = <String, Map<String, String>>{
    '32': {'jpg': '32.jpg', 'webp': '32.webp', 'avif': '32.avif'},
    '64': {'jpg': '64.jpg', 'webp': '64.webp', 'avif': '64.avif'},
    '256': {'jpg': '256.jpg', 'webp': '256.webp', 'avif': '256.avif'},
    '512': {'jpg': '512.jpg', 'webp': '512.webp', 'avif': '512.avif'},
  };

  group('size', () {
    test('takes the smallest variant that is still big enough', () {
      expect(pickAvatarUrl(full, preferredSize: 33), '64.webp');
      expect(pickAvatarUrl(full, preferredSize: 64), '64.webp');
      expect(pickAvatarUrl(full, preferredSize: 65), '256.webp');
    });

    test('never upscales when a large enough variant exists', () {
      expect(pickAvatarUrl(full, preferredSize: 1), '32.webp');
    });

    test('falls back to the largest available when asked for more', () {
      expect(pickAvatarUrl(full, preferredSize: 4096), '512.webp');
    });

    test('skips a size whose formats are empty', () {
      const gappy = <String, Map<String, String>>{
        '64': <String, String>{},
        '256': {'jpg': '256.jpg'},
      };
      expect(pickAvatarUrl(gappy, preferredSize: 64), '256.jpg');
    });

    test('ignores a size key that is not a number', () {
      const odd = <String, Map<String, String>>{
        'original': {'jpg': 'original.jpg'},
        '256': {'jpg': '256.jpg'},
      };
      expect(pickAvatarUrl(odd, preferredSize: 100), '256.jpg');
    });
  });

  group('format', () {
    test('prefers webp, then jpg, then avif', () {
      expect(
        pickAvatarUrl(const {
          '256': {'avif': 'a.avif', 'jpg': 'a.jpg', 'webp': 'a.webp'},
        }, preferredSize: 256),
        'a.webp',
      );
      expect(
        pickAvatarUrl(const {
          '256': {'avif': 'a.avif', 'jpg': 'a.jpg'},
        }, preferredSize: 256),
        'a.jpg',
      );
      expect(
        pickAvatarUrl(const {
          '256': {'avif': 'a.avif'},
        }, preferredSize: 256),
        'a.avif',
      );
    });

    test('takes an unknown format rather than showing nothing', () {
      expect(
        pickAvatarUrl(const {
          '256': {'heic': 'a.heic'},
        }, preferredSize: 256),
        'a.heic',
      );
    });

    test('skips an empty URL', () {
      expect(
        pickAvatarUrl(const {
          '256': {'webp': '', 'jpg': 'a.jpg'},
        }, preferredSize: 256),
        'a.jpg',
      );
    });
  });

  test('a user with no avatar yields null, never an empty string', () {
    // api-docs §4.3: `avatars` is `{}` until the upload pipeline finishes.
    expect(pickAvatarUrl(const {}, preferredSize: 256), isNull);
    expect(
      pickAvatarUrl(const {'256': <String, String>{}}, preferredSize: 256),
      isNull,
    );
  });

  test('the documented sizes are the ones we expect back', () {
    expect(kAvatarVariantSizes, [32, 64, 256, 512]);
    expect(kAvatarFormatPriority.first, 'webp');
  });
}
