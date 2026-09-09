import 'package:flutter/material.dart';

import 'package:chatix/features/chat/domain/entities/reaction_entity.dart';
import 'package:chatix/features/chat/domain/usecases/set_reaction_use_case.dart';
import 'package:chatix/gen/l10n/app_localizations.dart';

const List<String> kQuickReactions = [
  '👍',
  '❤️',
  '🔥',
  '😁',
  '😮',
  '😢',
  '🎉',
  '🙏',
];

class ReactionPicker extends StatelessWidget {
  const ReactionPicker({
    super.key,
    required this.reactions,
    required this.policy,
    required this.onSelected,
  });

  final MessageReactionsEntity reactions;

  final ChatReactionPolicy policy;

  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);

    if (!policy.enabled) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        child: Text(
          l10n.reactionsDisabled,
          style: theme.textTheme.bodySmall?.copyWith(color: scheme.outline),
        ),
      );
    }

    final available = kQuickReactions.where(policy.isAllowed).toList();
    if (available.isEmpty) return const SizedBox.shrink();

    final mine = reactions.myEmojis;
    final atLimit = mine.length >= ReactionLimits.maxPerUserPerMessage;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              for (final emoji in available)
                _ReactionButton(
                  emoji: emoji,
                  isMine: mine.contains(emoji),
                  enabled: mine.contains(emoji) || !atLimit,
                  onTap: () => onSelected(emoji),
                ),
            ],
          ),
        ),
        if (atLimit)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              l10n.reactionLimitReached(ReactionLimits.maxPerUserPerMessage),
              style: theme.textTheme.labelSmall?.copyWith(
                color: scheme.outline,
              ),
            ),
          ),
      ],
    );
  }
}

class _ReactionButton extends StatelessWidget {
  const _ReactionButton({
    required this.emoji,
    required this.isMine,
    required this.enabled,
    required this.onTap,
  });

  final String emoji;
  final bool isMine;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(24),
        child: Opacity(
          opacity: enabled ? 1 : 0.35,
          child: Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isMine
                  ? scheme.primary.withValues(alpha: 0.16)
                  : Colors.transparent,
              border: Border.all(
                color: isMine ? scheme.primary : Colors.transparent,
              ),
            ),
            child: Text(emoji, style: const TextStyle(fontSize: 22)),
          ),
        ),
      ),
    );
  }
}
