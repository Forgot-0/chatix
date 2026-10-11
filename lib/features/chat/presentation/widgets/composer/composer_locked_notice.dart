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
  const ComposerLockedNotice({super.key, required this.reason, this.action});

  final ComposerLockReason reason;

  /// The one thing that can be done about it, after the sentence — "Unblock"
  /// when the reader blocked the person on the other side.
  final Widget? action;

  /// Why this reader cannot post, or null when they can.
  ///
  /// Ordered by how specific the answer is: being banned outranks the chat
  /// being admin-only, because that is what the reader needs to hear first.
  ///
  /// [peerBlocked] — the reader blocked the other person of this direct
  /// chat — comes before everything: the server would still take the
  /// message (blocks are not checked by chats yet, api-docs §4.13), but
  /// writing to somebody one has blocked is what Telegram does not allow
  /// either, and the bar that says so is also the way back.
  static ComposerLockReason? reasonFor(
    ChatEntity? chat,
    ChatMemberEntity? me, {
    bool peerBlocked = false,
  }) {
    if (peerBlocked && chat?.type == ChatType.direct) {
      return ComposerLockReason.blockedPeer;
    }
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
      ComposerLockReason.blockedPeer => l10n.blockedChatNotice,
    };

    final style = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.outline,
    );

    final sentence = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          switch (reason) {
            ComposerLockReason.adminsOnly => Icons.campaign_outlined,
            ComposerLockReason.blockedPeer => Icons.block,
            _ => Icons.lock_outline,
          },
          size: ComposerSizes.lockedIconSize,
          color: theme.colorScheme.outline,
        ),
        const SizedBox(width: AppSpacing.x2),
        Flexible(
          child: Text(text, textAlign: TextAlign.center, style: style),
        ),
      ],
    );

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
          // A button is taller than a line of text: the bar keeps its
          // height by giving it the padding back.
          padding: EdgeInsets.symmetric(
            horizontal: AppSpacing.x4,
            vertical: action == null ? AppSpacing.x4 : AppSpacing.x2,
          ),
          child: switch (action) {
            null => Center(child: sentence),
            final action => LayoutBuilder(
              // The pane's width, not the window's: one line where the
              // sentence and the button fit side by side, the button under
              // the sentence where they do not.
              builder: (context, constraints) =>
                  constraints.maxWidth >= ComposerSizes.lockedActionInlineFrom
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Flexible(child: sentence),
                        const SizedBox(width: AppSpacing.x1),
                        Text('·', style: style),
                        const SizedBox(width: AppSpacing.x1),
                        action,
                      ],
                    )
                  : Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [sentence, action],
                      ),
                    ),
            ),
          },
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

  /// A direct chat whose other person the reader blocked.
  blockedPeer,
}
