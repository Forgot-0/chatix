import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chatix/features/profile/domain/entities/contact_entity.dart';
import 'package:chatix/features/profile/presentation/utils/profile_contact_link.dart';

ContactEntity link(String provider, String contact) =>
    ContactEntity(profileId: 1, provider: provider, contact: contact);

void main() {
  group('contactUriOf — known providers expand a bare handle', () {
    test('telegram', () {
      expect(
        contactUriOf('telegram', '@ivan'),
        Uri.parse('https://t.me/ivan'),
      );
    });

    test('github', () {
      expect(
        contactUriOf('github', 'ivan'),
        Uri.parse('https://github.com/ivan'),
      );
    });

    test('a leading @ is punctuation, not part of the handle', () {
      expect(contactUriOf('x', '@ivan'), Uri.parse('https://x.com/ivan'));
    });

    test('whatsapp drops the plus the way wa.me wants it', () {
      expect(
        contactUriOf('whatsapp', '+7 900 123-45-67'),
        Uri.parse('https://wa.me/79001234567'),
      );
    });

    test('phone becomes a tel: URI with the plus kept', () {
      expect(contactUriOf('phone', '+7 (900) 123-45-67').toString(),
          'tel:+79001234567');
    });

    test('email becomes a mailto: URI', () {
      expect(
        contactUriOf('email', 'ivan@example.com').toString(),
        'mailto:ivan@example.com',
      );
    });

    test('a bare website host gets https', () {
      expect(
        contactUriOf('website', 'example.com/ivan'),
        Uri.parse('https://example.com/ivan'),
      );
    });
  });

  group('contactUriOf — a spelled-out URL wins over the provider', () {
    test('an https value is used as written', () {
      expect(
        contactUriOf('telegram', 'https://t.me/joinchat/abc'),
        Uri.parse('https://t.me/joinchat/abc'),
      );
    });

    test('a mailto: value is kept as a mailto:', () {
      expect(
        contactUriOf('site', 'mailto:ivan@example.com').toString(),
        'mailto:ivan@example.com',
      );
    });
  });

  group('contactUriOf — nothing is invented', () {
    test('an empty contact has no URI', () {
      expect(contactUriOf('telegram', '   '), isNull);
    });

    test('a discord handle is not addressable', () {
      expect(contactUriOf('discord', 'ivan#1234'), isNull);
    });

    test('an unknown provider with an opaque handle has no URI', () {
      expect(contactUriOf('somewhere', 'ivan'), isNull);
    });

    test('an all-digits handle is not silently dialled', () {
      // Fewer than five digits is a nickname, not a phone number.
      expect(contactUriOf('somewhere', '1234'), isNull);
    });

    test('an unknown provider still recognises a real address', () {
      expect(
        contactUriOf('work', 'ivan@example.com').toString(),
        'mailto:ivan@example.com',
      );
    });
  });

  group('profileContactLinkOf', () {
    test('tidies the provider for reading but keeps the value verbatim', () {
      final result = profileContactLinkOf(link('telegram', '@ivan'));

      expect(result.label, 'Telegram');
      expect(result.value, '@ivan');
      expect(result.isOpenable, isTrue);
    });

    test('leaves a provider its author already capitalised alone', () {
      expect(profileContactLinkOf(link('GitHub', 'ivan')).label, 'GitHub');
    });

    test('an unopenable row is still a row', () {
      final result = profileContactLinkOf(link('discord', 'ivan#1234'));

      expect(result.isOpenable, isFalse);
      expect(result.value, 'ivan#1234');
      expect(result.icon, Icons.forum_outlined);
    });
  });
}
