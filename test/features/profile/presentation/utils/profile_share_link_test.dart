import 'package:flutter_test/flutter_test.dart';

import 'package:chatix/features/profile/presentation/utils/profile_share_link.dart';

void main() {
  group('ProfileShareLink.of', () {
    test('points at the app route on the configured host', () {
      expect(
        ProfileShareLink.of(7, baseUrl: 'https://chat.example.com/api/v1'),
        'https://chat.example.com/profiles/7',
      );
    });

    test('drops a trailing slash rather than doubling it', () {
      expect(
        ProfileShareLink.of(7, baseUrl: 'https://chat.example.com/'),
        'https://chat.example.com/profiles/7',
      );
    });

    test('keeps a non-default port, which a staging build needs', () {
      expect(
        ProfileShareLink.of(7, baseUrl: 'http://localhost:8000/api/v1'),
        'http://localhost:8000/profiles/7',
      );
    });
  });

  group('ProfileShareLink.messageFor', () {
    const base = 'https://chat.example.com';

    test('introduces the link with the name and the handle', () {
      expect(
        ProfileShareLink.messageFor(
          7,
          displayName: 'Ivan Petrov',
          username: 'ivan',
          baseUrl: base,
        ),
        'Ivan Petrov @ivan\n$base/profiles/7',
      );
    });

    test('is just the link when nobody is named', () {
      expect(
        ProfileShareLink.messageFor(7, baseUrl: base),
        '$base/profiles/7',
      );
    });

    test('blank values do not leave stray punctuation behind', () {
      expect(
        ProfileShareLink.messageFor(
          7,
          displayName: '   ',
          username: '',
          baseUrl: base,
        ),
        '$base/profiles/7',
      );
    });
  });
}
