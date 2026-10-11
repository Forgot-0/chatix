import 'package:flutter_test/flutter_test.dart';

import 'package:chatix/features/profile/domain/entities/contact_entity.dart';
import 'package:chatix/features/profile/domain/entities/profile_entity.dart';
import 'package:chatix/features/profile/presentation/utils/profile_view.dart';

void main() {
  group('ProfilePresence', () {
    test('online is said in so many words', () {
      expect(
        ProfilePresence.of(isMe: false, online: true),
        ProfilePresence.online,
      );
    });

    test('known to be away is "last seen recently"', () {
      expect(
        ProfilePresence.of(isMe: false, online: false),
        ProfilePresence.recently,
      );
    });

    test('nothing known — no chat to read it from — says nothing', () {
      // There is no last-seen time in the API (api-docs §5.3): guessing
      // "recently" for someone nothing is known about would be made up.
      expect(
        ProfilePresence.of(isMe: false, online: null),
        ProfilePresence.unknown,
      );
    });

    test('one is always online on one\'s own profile', () {
      expect(
        ProfilePresence.of(isMe: true, online: null),
        ProfilePresence.online,
      );
      expect(
        ProfilePresence.of(isMe: true, online: false),
        ProfilePresence.online,
      );
    });
  });

  group('ProfileActions.quickFor', () {
    test('somebody else: write, call, mute, more', () {
      expect(ProfileActions.quickFor(isMe: false), [
        ProfileQuickAction.message,
        ProfileQuickAction.call,
        ProfileQuickAction.mute,
        ProfileQuickAction.more,
      ]);
    });

    test('a silenced chat offers to unmute in the same place', () {
      expect(ProfileActions.quickFor(isMe: false, muted: true), [
        ProfileQuickAction.message,
        ProfileQuickAction.call,
        ProfileQuickAction.unmute,
        ProfileQuickAction.more,
      ]);
    });

    test('an unknown chat state reads as not silenced', () {
      expect(
        ProfileActions.quickFor(isMe: false, muted: null),
        contains(ProfileQuickAction.mute),
      );
    });

    test('oneself: no chat to open or silence, only share and QR', () {
      expect(ProfileActions.quickFor(isMe: true), [
        ProfileQuickAction.share,
        ProfileQuickAction.qr,
      ]);
    });
  });

  group('ProfileActions.isEnabled', () {
    bool enabled(
      ProfileQuickAction action, {
      bool busy = false,
      bool blocked = false,
      bool hasDirectChat = true,
    }) => ProfileActions.isEnabled(
      action,
      busy: busy,
      blocked: blocked,
      hasDirectChat: hasDirectChat,
    );

    test('everything is pressable on an ordinary profile', () {
      for (final action in ProfileQuickAction.values) {
        expect(enabled(action), isTrue, reason: action.name);
      }
    });

    test('writing and calling wait while the chat is being found', () {
      expect(enabled(ProfileQuickAction.message, busy: true), isFalse);
      expect(enabled(ProfileQuickAction.call, busy: true), isFalse);
      expect(enabled(ProfileQuickAction.more, busy: true), isTrue);
    });

    test('a blocked person cannot be called, but the chat still opens', () {
      expect(enabled(ProfileQuickAction.call, blocked: true), isFalse);
      expect(enabled(ProfileQuickAction.message, blocked: true), isTrue);
    });

    test('there is nothing to silence without a chat', () {
      expect(enabled(ProfileQuickAction.mute, hasDirectChat: false), isFalse);
      expect(enabled(ProfileQuickAction.unmute, hasDirectChat: false), isFalse);
      expect(enabled(ProfileQuickAction.message, hasDirectChat: false), isTrue);
    });
  });

  group('ProfileActions.menuFor', () {
    test('a stranger: share, add, block', () {
      expect(ProfileActions.menuFor(isContact: false, isBlocked: false), [
        ProfileMenuAction.share,
        ProfileMenuAction.addContact,
        ProfileMenuAction.block,
      ]);
    });

    test('a contact: share, rename, remove, block', () {
      expect(ProfileActions.menuFor(isContact: true, isBlocked: false), [
        ProfileMenuAction.share,
        ProfileMenuAction.rename,
        ProfileMenuAction.removeContact,
        ProfileMenuAction.block,
      ]);
    });

    test('someone blocked is offered the way back instead', () {
      final menu = ProfileActions.menuFor(isContact: true, isBlocked: true);
      expect(menu.last, ProfileMenuAction.unblock);
      expect(menu, isNot(contains(ProfileMenuAction.block)));
    });

    test('only removing and blocking are drawn as dangerous', () {
      expect(ProfileMenuAction.values.where((action) => action.isDestructive), [
        ProfileMenuAction.removeContact,
        ProfileMenuAction.block,
      ]);
    });
  });

  group('ProfileFacts', () {
    ProfileEntity profile({
      String? bio,
      DateTime? birthday,
      List<ContactEntity> links = const [],
      String? specialization,
      List<String> skills = const [],
    }) => ProfileEntity(
      id: 42,
      username: ' ada ',
      avatars: const {},
      specialization: specialization,
      displayName: 'Ada',
      bio: bio,
      dateBirthday: birthday,
      skills: skills,
      contacts: links,
    );

    test('the handle carries its @', () {
      expect(ProfileFacts.of(profile()).handle, '@ada');
    });

    test('blank text is no text', () {
      final facts = ProfileFacts.of(profile(bio: '   '));
      expect(facts.bio, isNull);
      expect(facts.isBlank, isTrue);
    });

    test('the bio is trimmed', () {
      expect(ProfileFacts.of(profile(bio: '  Hello  ')).bio, 'Hello');
    });

    test('a birthday or a link is enough not to be blank', () {
      expect(
        ProfileFacts.of(profile(birthday: DateTime(1990, 4, 12))).isBlank,
        isFalse,
      );
      expect(
        ProfileFacts.of(
          profile(
            links: const [
              ContactEntity(profileId: 42, provider: 'site', contact: 'a.b'),
            ],
          ),
        ).isBlank,
        isFalse,
      );
    });

    test('specialization and skills stay hidden while the flag is off', () {
      final facts = ProfileFacts.of(
        profile(specialization: 'Engines', skills: const ['math']),
        workFields: false,
      );

      expect(facts.specialization, isNull);
      expect(facts.skills, isEmpty);
      // Nor do they make a profile look filled in.
      expect(facts.isBlank, isTrue);
    });

    test('the flag brings them back', () {
      final facts = ProfileFacts.of(
        profile(specialization: ' Engines ', skills: const ['math']),
        workFields: true,
      );

      expect(facts.specialization, 'Engines');
      expect(facts.skills, ['math']);
      expect(facts.isBlank, isFalse);
    });

    test('the flag ships off', () {
      expect(ProfileFieldVisibility.workFields, isFalse);
    });
  });
}
