import 'package:flutter_test/flutter_test.dart';

import 'package:chatix/features/chat/domain/entities/chat_entity.dart';
import 'package:chatix/features/chat/presentation/utils/chat_header_status.dart';
import 'package:chatix/gen/l10n/app_localizations_en.dart';
import 'package:chatix/gen/l10n/app_localizations_ru.dart';

/// The line under a chat's name: only what the API can back up.
void main() {
  final en = AppLocalizationsEn();
  final ru = AppLocalizationsRu();

  ChatEntity chat(ChatType type, {int members = 2}) => ChatEntity(
    id: 'c1',
    seqCounter: 1,
    lastActivityAt: null,
    type: type,
    name: type == ChatType.direct ? null : 'Team',
    description: null,
    avatarS3Key: null,
    isPublic: false,
    adminOnly: false,
    slowModeSeconds: 0,
    permissions: const {},
    createdBy: 1,
    memberCount: members,
  );

  group('a direct chat', () {
    test('says "online", in the accent, while the other side is', () {
      final status = ChatHeaderStatus.of(
        chat(ChatType.direct),
        peerOnline: true,
      );

      expect(status, const PeerOnlineStatus());
      expect(status!.isAccent, isTrue);
      expect(status.label(en), 'online');
      expect(status.label(ru), 'в сети');
    });

    test('says nothing when they are not: there is no last-seen to quote', () {
      expect(
        ChatHeaderStatus.of(chat(ChatType.direct), peerOnline: false),
        isNull,
      );
    });

    test('says nothing until presence is known', () {
      expect(ChatHeaderStatus.of(chat(ChatType.direct)), isNull);
    });
  });

  group('a group', () {
    test('counts its members and who of them is here', () {
      final status = ChatHeaderStatus.of(
        chat(ChatType.group, members: 12),
        membersOnline: 3,
      );

      expect(status, const MembersStatus(members: 12, online: 3));
      expect(status!.isAccent, isFalse);
      expect(status.label(en), '12 members, 3 online');
      expect(status.label(ru), '12 участников, 3 в сети');
    });

    test('leaves the online part out while it is unknown', () {
      final status = ChatHeaderStatus.of(chat(ChatType.group, members: 12));

      expect(status!.label(en), '12 members');
    });

    test('leaves it out rather than saying "0 online"', () {
      final status = ChatHeaderStatus.of(
        chat(ChatType.group, members: 12),
        membersOnline: 0,
      );

      expect(status!.label(ru), '12 участников');
    });

    test('is a supergroup too', () {
      final status = ChatHeaderStatus.of(
        chat(ChatType.supergroup, members: 2400),
        membersOnline: 31,
      );

      expect(status!.label(en), '2,400 members, 31 online');
      // Grouped with the no-break space Russian puts between thousands.
      expect(status.label(ru), '2 400 участников, 31 в сети');
    });

    test('ignores a direct peer\'s presence', () {
      final status = ChatHeaderStatus.of(
        chat(ChatType.group, members: 4),
        peerOnline: true,
      );

      expect(status, const MembersStatus(members: 4));
    });
  });

  group('a channel', () {
    test('names its audience as subscribers', () {
      final status = ChatHeaderStatus.of(
        chat(ChatType.channel, members: 1240),
        membersOnline: 9,
      );

      expect(status, const SubscribersStatus(subscribers: 1240));
      expect(status!.label(en), '1,240 subscribers');
      expect(status.label(ru), '1 240 подписчиков');
    });

    test('inflects the word the way Russian does', () {
      String ru1(int count) => SubscribersStatus(subscribers: count).label(ru);

      expect(ru1(1), '1 подписчик');
      expect(ru1(3), '3 подписчика');
      expect(ru1(5), '5 подписчиков');
      expect(ru1(21), '21 подписчик');
      expect(ru1(0), 'Нет подписчиков');
    });
  });
}
