import 'package:flutter_test/flutter_test.dart';

import 'package:chatix/features/profile/presentation/utils/profile_share_link.dart';

void main() {
  group('ProfileShareLink.of', () {
    test('is the public /u/<username> link on the configured host', () {
      expect(
        ProfileShareLink.of('ivan', baseUrl: 'https://chat.example.com/api/v1'),
        'https://chat.example.com/u/ivan',
      );
    });

    test('drops a trailing slash rather than doubling it', () {
      expect(
        ProfileShareLink.of('ivan', baseUrl: 'https://chat.example.com/'),
        'https://chat.example.com/u/ivan',
      );
    });

    test('keeps a non-default port, which a staging build needs', () {
      expect(
        ProfileShareLink.of('ivan', baseUrl: 'http://localhost:8000/api/v1'),
        'http://localhost:8000/u/ivan',
      );
    });

    test('encodes an old-style handle with a space in it', () {
      expect(
        ProfileShareLink.of('Ivan Petrov', baseUrl: 'https://chat.example.com'),
        'https://chat.example.com/u/Ivan%20Petrov',
      );
    });
  });

  group('ProfileShareLink.messageFor', () {
    const base = 'https://chat.example.com';

    test('introduces the link with the name and the handle', () {
      expect(
        ProfileShareLink.messageFor(
          username: 'ivan',
          displayName: 'Ivan Petrov',
          baseUrl: base,
        ),
        'Ivan Petrov @ivan\n$base/u/ivan',
      );
    });

    test('the handle alone when there is no name', () {
      expect(
        ProfileShareLink.messageFor(username: 'ivan', baseUrl: base),
        '@ivan\n$base/u/ivan',
      );
    });

    test('a blank name does not leave stray punctuation behind', () {
      expect(
        ProfileShareLink.messageFor(
          username: 'ivan',
          displayName: '   ',
          baseUrl: base,
        ),
        '@ivan\n$base/u/ivan',
      );
    });
  });

  group('ProfileShareLink.inAppLocation', () {
    const base = 'https://chat.example.com/api/v1';

    String? where(String link) =>
        ProfileShareLink.inAppLocation(Uri.parse(link), baseUrl: base);

    test('a link of ours opens the profile by handle in the app', () {
      expect(where('https://chat.example.com/u/ivan'), '/u/ivan');
      expect(where('https://CHAT.example.com/u/ivan/'), '/u/ivan');
      expect(
        where('https://chat.example.com/u/Ivan%20Petrov'),
        '/u/Ivan%20Petrov',
      );
    });

    test('so does one handed out before, by id', () {
      expect(where('https://chat.example.com/profiles/7'), '/profiles/7');
    });

    test('a round trip through of() lands on the same route', () {
      expect(where(ProfileShareLink.of('ada_l', baseUrl: base)), '/u/ada_l');
    });

    test('anything else stays a web link', () {
      expect(where('https://elsewhere.example.com/u/ivan'), isNull);
      expect(where('http://chat.example.com/u/ivan'), isNull);
      expect(where('https://chat.example.com:8443/u/ivan'), isNull);
      expect(where('https://chat.example.com/u/'), isNull);
      expect(where('https://chat.example.com/u/ivan/photos'), isNull);
      expect(where('https://chat.example.com/profiles/abc'), isNull);
      expect(where('https://chat.example.com/chats/1'), isNull);
      expect(where('mailto:ivan@chat.example.com'), isNull);
    });

    test('a staging build recognises its own port', () {
      expect(
        ProfileShareLink.inAppLocation(
          Uri.parse('http://localhost:8000/u/ivan'),
          baseUrl: 'http://localhost:8000/api/v1',
        ),
        '/u/ivan',
      );
    });
  });
}
