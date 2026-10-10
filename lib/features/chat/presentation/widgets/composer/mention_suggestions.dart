import 'package:flutter/material.dart';

import 'package:chatix/core/theme/app_tokens.dart';
import 'package:chatix/features/chat/domain/entities/chat_member_entity.dart';
import 'package:chatix/features/chat/presentation/widgets/chat_avatar.dart';
import 'package:chatix/gen/l10n/app_localizations.dart';

/// Who an `@` being typed could mean, in a card that floats over the bottom
/// of the conversation, just above the composer.
///
/// Over the feed rather than in the composer's column: the list comes and
/// goes with every keystroke, and taking its height out of the feed each
/// time would bounce the messages up and down as the person types.
class MentionSuggestions extends StatelessWidget {
  const MentionSuggestions({
    super.key,
    required this.candidates,
    required this.onSelected,
    this.highlighted,
  });

  final List<ChatMemberEntity> candidates;
  final ValueChanged<ChatMemberEntity> onSelected;

  /// The row the arrow keys are on, on a desktop. Enter or Tab picks it.
  final int? highlighted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final brightness = theme.brightness;
    final l10n = AppLocalizations.of(context);

    return Semantics(
      container: true,
      label: l10n.mentionListLabel,
      // Docked on the composer: rounded on top, square where it meets the
      // bar, with no gap underneath for the conversation to show through.
      // The host lets the bottom border fall just below its edge, so the
      // composer's own top line is the only one there.
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: AppSpacing.x2),
        constraints: const BoxConstraints(
          maxHeight: MentionListSizes.maxHeight,
        ),
        decoration: BoxDecoration(
          color: AppElevations.surfaceOf(brightness, scheme.surface, 2),
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppRadii.lg),
          ),
          border: Border.all(color: scheme.outlineVariant),
          boxShadow: AppElevations.shadows(brightness, 2),
        ),
        clipBehavior: Clip.antiAlias,
        child: Material(
          type: MaterialType.transparency,
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.x1),
            shrinkWrap: true,
            itemExtent: MentionListSizes.rowHeight,
            itemCount: candidates.length,
            itemBuilder: (context, index) => _MentionRow(
              member: candidates[index],
              isHighlighted: index == highlighted,
              onTap: () => onSelected(candidates[index]),
            ),
          ),
        ),
      ),
    );
  }
}

class _MentionRow extends StatelessWidget {
  const _MentionRow({
    required this.member,
    required this.isHighlighted,
    required this.onTap,
  });

  final ChatMemberEntity member;
  final bool isHighlighted;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final profile = member.profile;
    final username = profile?.username ?? '';
    final name = profile?.displayName?.trim();

    return InkWell(
      onTap: onTap,
      child: Container(
        color: isHighlighted ? scheme.primary.withValues(alpha: 0.10) : null,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x3),
        child: Row(
          children: [
            ChatAvatar.profile(
              profile,
              userId: member.userId,
              size: ChatAvatarSize.sm,
            ),
            const SizedBox(width: AppSpacing.x3),
            Expanded(
              child: Text.rich(
                TextSpan(
                  children: [
                    if (name != null && name.isNotEmpty) ...[
                      TextSpan(
                        text: name,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const TextSpan(text: '  '),
                    ],
                    TextSpan(
                      text: '@$username',
                      style: TextStyle(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
