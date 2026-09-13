import 'package:flutter/material.dart';

import 'package:chatix/core/theme/app_theme_extension.dart';
import 'package:chatix/core/theme/app_tokens.dart';
import 'package:chatix/features/chat/domain/entities/chat_entity.dart';
import 'package:chatix/features/chat/domain/entities/chat_member_entity.dart';
import 'package:chatix/features/chat/presentation/utils/chat_permissions.dart';
import 'package:chatix/gen/l10n/app_localizations.dart';

/// What stands where the composer would be when this reader cannot write.
///
/// The composer is not disabled, it is absent: a greyed-out box invites a
/// tap that does nothing, and the reason it would refuse is worth a sentence.
/// Which sentence depends on why (api-docs §8.1) — an `admin_only` chat, a
/// `viewer` in a channel, a mute and a ban are four different situations and
/// only one of them is the reader's own doing.
class ComposerLockedNotice extends StatelessWidget {
  const ComposerLockedNotice({super.key, required this.reason});

  final ComposerLockReason reason;

  /// Why this reader cannot post, or null when they can.
  ///
  /// Ordered by how specific the answer is: being banned outranks the chat
  /// being admin-only, because that is what the reader needs to hear first.
  static ComposerLockReason? reasonFor(ChatEntity? chat, ChatMemberEntity? me) {
    if (canSendMessage(chat, me)) return null;

    if (me == null) return ComposerLockReason.notAMember;
    if (me.isBanned) return ComposerLockReason.banned;
    if (me.isMuted) return ComposerLockReason.muted;

    // `admin_only` swaps which right is asked for: without
    // `message:send_admin_only` a member is a reader here, not an author.
    if (chat?.adminOnly == true) return ComposerLockReason.adminsOnly;

    // A channel's subscribers are `viewer` (role 6), which carries no
    // `message:send` at all — the same wording fits.
    if (me.role == ChatRole.viewer) return ComposerLockReason.adminsOnly;

    return ComposerLockReason.noPermission;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final chatix = ChatixTheme.of(context);
    final l10n = AppLocalizations.of(context);

    final text = switch (reason) {
      ComposerLockReason.notAMember => l10n.composerJoinToSend,
      ComposerLockReason.banned => l10n.composerBanned,
      ComposerLockReason.muted => l10n.composerMuted,
      ComposerLockReason.adminsOnly => l10n.composerAdminsOnly,
      ComposerLockReason.noPermission => l10n.composerNoPermission,
    };

    return DecoratedBox(
      decoration: BoxDecoration(
        color: chatix.composerSurface,
        border: Border(
          top: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.x4,
            vertical: AppSpacing.x4,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                reason == ComposerLockReason.adminsOnly
                    ? Icons.campaign_outlined
                    : Icons.lock_outline,
                size: 16,
                color: theme.colorScheme.outline,
              ),
              const SizedBox(width: AppSpacing.x2),
              Flexible(
                child: Text(
                  text,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum ComposerLockReason {
  notAMember,
  banned,
  muted,

  /// The chat is `admin_only`, or this reader is a channel `viewer`.
  adminsOnly,

  noPermission,
}
