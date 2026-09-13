import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chatix/features/chat/domain/entities/chat_entity.dart';
import 'package:chatix/features/chat/domain/entities/chat_member_entity.dart';
import 'package:chatix/features/chat/presentation/widgets/composer/composer_locked_notice.dart';
import 'package:chatix/gen/l10n/app_localizations.dart';

/// A reader who cannot post gets a sentence, not a greyed-out box. Which
/// sentence depends on which right is missing (api-docs §8.1).
void main() {
  ChatEntity chat({
    bool adminOnly = false,
    ChatType type = ChatType.group,
    Map<String, bool> permissions = const {},
  }) => ChatEntity(
    id: 'c1',
    seqCounter: 10,
    lastActivityAt: DateTime.utc(2026, 1, 1),
    type: type,
    name: 'Team',
    description: null,
    avatarS3Key: null,
    isPublic: false,
    adminOnly: adminOnly,
    slowModeSeconds: 0,
    permissions: permissions,
    createdBy: 1,
    memberCount: 3,
    unreadCount: 0,
  );

  ChatMemberEntity member(
    ChatRole role, {
    bool isMuted = false,
    bool isBanned = false,
    Map<String, bool> overrides = const {},
  }) => ChatMemberEntity(
    userId: 7,
    roleId: role.id,
    isMuted: isMuted,
    isBanned: isBanned,
    permissionsOverrides: overrides,
  );

  group('who is locked out', () {
    test('an ordinary member of an ordinary chat is not', () {
      expect(
        ComposerLockedNotice.reasonFor(chat(), member(ChatRole.member)),
        isNull,
      );
    });

    test('nobody at all — not a member of this chat', () {
      expect(
        ComposerLockedNotice.reasonFor(chat(), null),
        ComposerLockReason.notAMember,
      );
    });

    test('a banned member hears that first', () {
      expect(
        ComposerLockedNotice.reasonFor(
          chat(adminOnly: true),
          member(ChatRole.member, isBanned: true),
        ),
        ComposerLockReason.banned,
      );
    });

    test('a muted member hears that, not the chat setting', () {
      expect(
        ComposerLockedNotice.reasonFor(
          chat(adminOnly: true),
          member(ChatRole.member, isMuted: true),
        ),
        ComposerLockReason.muted,
      );
    });

    test('admin_only locks out a member without message:send_admin_only', () {
      expect(
        ComposerLockedNotice.reasonFor(
          chat(adminOnly: true),
          member(ChatRole.member),
        ),
        ComposerLockReason.adminsOnly,
      );
    });

    test('admin_only lets an admin through', () {
      expect(
        ComposerLockedNotice.reasonFor(
          chat(adminOnly: true),
          member(ChatRole.admin),
        ),
        isNull,
      );
    });

    test('a channel viewer has no message:send at all', () {
      expect(
        ComposerLockedNotice.reasonFor(
          chat(type: ChatType.channel),
          member(ChatRole.viewer),
        ),
        ComposerLockReason.adminsOnly,
      );
    });

    test('a per-member override can take the right away', () {
      expect(
        ComposerLockedNotice.reasonFor(
          chat(),
          member(
            ChatRole.member,
            overrides: const {ChatPermissions.messageSend: false},
          ),
        ),
        ComposerLockReason.noPermission,
      );
    });

    test('and a chat-level override can hand it back in admin_only', () {
      expect(
        ComposerLockedNotice.reasonFor(
          chat(
            adminOnly: true,
            permissions: const {ChatPermissions.messageSendAdminOnly: true},
          ),
          member(ChatRole.member),
        ),
        isNull,
      );
    });
  });

  group('what it says', () {
    Future<void> pump(WidgetTester tester, ComposerLockReason reason) {
      return tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Align(
              alignment: Alignment.bottomCenter,
              child: ComposerLockedNotice(reason: reason),
            ),
          ),
        ),
      );
    }

    testWidgets('an admin-only chat names the reason', (tester) async {
      await pump(tester, ComposerLockReason.adminsOnly);

      expect(find.text('Only admins can post in this chat'), findsOneWidget);
    });

    testWidgets('every reason has a line, and no text field anywhere', (
      tester,
    ) async {
      for (final reason in ComposerLockReason.values) {
        await pump(tester, reason);

        expect(find.byType(TextField), findsNothing, reason: reason.name);
        expect(find.byType(Text), findsOneWidget, reason: reason.name);
      }
    });
  });
}
