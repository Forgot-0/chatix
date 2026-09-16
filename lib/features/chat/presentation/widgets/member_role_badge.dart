import 'package:flutter/material.dart';

import 'package:chatix/core/theme/app_tokens.dart';
import 'package:chatix/features/chat/domain/entities/chat_member_entity.dart';
import 'package:chatix/gen/l10n/app_localizations.dart';

/// The name of a chat role as the reader should see it (api-docs §8.1).
String chatRoleLabel(ChatRole? role, AppLocalizations l10n) => switch (role) {
  ChatRole.owner => l10n.chatRoleOwner,
  ChatRole.admin => l10n.chatRoleAdmin,
  ChatRole.editor => l10n.chatRoleEditor,
  ChatRole.direct => l10n.chatRoleDirect,
  ChatRole.member => l10n.chatRoleMember,
  ChatRole.viewer => l10n.chatRoleViewer,
  null => l10n.chatRoleUnknown,
};

/// One short chip naming what a member is, when that is worth saying.
///
/// `member` and `direct` get nothing: they are the default in a group and the
/// only role in a 1:1 chat, so a badge on every row would say the same thing
/// about everyone. The three staff roles and `viewer` — who cannot post at
/// all — each get their own colour, so the administration block reads as a
/// hierarchy rather than a list.
class MemberRoleBadge extends StatelessWidget {
  const MemberRoleBadge({super.key, required this.role});

  final ChatRole? role;

  /// Whether this role says anything the row does not already show.
  static bool isWorthShowing(ChatRole? role) =>
      role != null && role != ChatRole.member && role != ChatRole.direct;

  @override
  Widget build(BuildContext context) {
    if (!isWorthShowing(role)) return const SizedBox.shrink();

    final scheme = Theme.of(context).colorScheme;

    final (Color background, Color foreground, IconData icon) = switch (role) {
      ChatRole.owner => (
        scheme.primaryContainer,
        scheme.onPrimaryContainer,
        Icons.workspace_premium_outlined,
      ),
      ChatRole.admin => (
        scheme.tertiaryContainer,
        scheme.onTertiaryContainer,
        Icons.shield_outlined,
      ),
      ChatRole.editor => (
        scheme.secondaryContainer,
        scheme.onSecondaryContainer,
        Icons.edit_outlined,
      ),
      _ => (
        scheme.surfaceContainerHighest,
        scheme.onSurfaceVariant,
        Icons.visibility_outlined,
      ),
    };

    return _Chip(
      background: background,
      foreground: foreground,
      icon: icon,
      label: chatRoleLabel(role, AppLocalizations.of(context)),
    );
  }
}

/// The moderator's mute, which is not the reader's own notification mute
/// (api-docs §5.2): this member cannot post here.
class MemberMutedBadge extends StatelessWidget {
  const MemberMutedBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return _Chip(
      background: scheme.surfaceContainerHighest,
      foreground: scheme.onSurfaceVariant,
      icon: Icons.volume_off_outlined,
      label: AppLocalizations.of(context).memberMutedBadge,
    );
  }
}

class MemberBannedBadge extends StatelessWidget {
  const MemberBannedBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return _Chip(
      background: scheme.errorContainer,
      foreground: scheme.onErrorContainer,
      icon: Icons.block,
      label: AppLocalizations.of(context).memberBannedBadge,
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.background,
    required this.foreground,
    required this.icon,
    required this.label,
  });

  final Color background;
  final Color foreground;
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.x2,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppRadii.full),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: foreground),
          const SizedBox(width: AppSpacing.x1),
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(color: foreground),
          ),
        ],
      ),
    );
  }
}
