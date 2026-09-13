import 'package:flutter/material.dart';

import 'package:chatix/core/theme/app_tokens.dart';
import 'package:chatix/features/chat/domain/entities/reaction_catalog.dart';
import 'package:chatix/features/chat/domain/entities/reaction_entity.dart';
import 'package:chatix/features/chat/domain/usecases/set_reaction_use_case.dart';
import 'package:chatix/gen/l10n/app_localizations.dart';

/// The whole catalog, in a sheet.
///
/// The quick bar over the context menu covers the common case in one tap;
/// this is where the rest of the catalog lives. Nothing outside the server's
/// curated list is ever drawn (api-docs §5.7.2), and a chat in
/// `reactions_mode = "some"` narrows it further — an emoji that would come
/// back `INVALID_REACTION` or `REACTION_NOT_ALLOWED` is not offered at all.
///
/// Both caps from §5.7.4 are enforced here too: past three of our own, or
/// twenty distinct on the message, the emoji that would be refused go flat
/// and untappable, with a line underneath saying why. Taking one of ours
/// back stays available, since that is the only way out.
class ReactionPicker extends StatelessWidget {
  const ReactionPicker({
    super.key,
    required this.reactions,
    required this.policy,
    required this.onSelected,
    this.recent = const [],
  });

  /// Opens the catalog over the conversation and answers with the emoji that
  /// was picked, or null if the sheet was dismissed.
  static Future<String?> show(
    BuildContext context, {
    required MessageReactionsEntity reactions,
    required ChatReactionPolicy policy,
    List<String> recent = const [],
  }) {
    return showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => ReactionPicker(
        reactions: reactions,
        policy: policy,
        recent: recent,
        onSelected: (emoji) => Navigator.of(sheetContext).pop(emoji),
      ),
    );
  }

  final MessageReactionsEntity reactions;

  final ChatReactionPolicy policy;

  /// This device's own history, drawn above the catalog. Anything the policy
  /// rejects is dropped here as well, so a stale recent cannot leak through.
  final List<String> recent;

  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);

    if (!policy.enabled) return _Notice(text: l10n.reactionsDisabled);

    final sections = <_CatalogSection>[
      if (_allowed(recent) case final recents when recents.isNotEmpty)
        _CatalogSection(title: l10n.reactionSectionRecent, emojis: recents),
      for (final entry in ReactionCatalog.sections.entries)
        if (_allowed(entry.value) case final allowed when allowed.isNotEmpty)
          _CatalogSection(title: _titleOf(entry.key, l10n), emojis: allowed),
    ];

    // A whitelist can name emoji the catalog does not carry, which leaves
    // nothing at all to offer.
    if (sections.isEmpty) return _Notice(text: l10n.reactionsNoneAllowed);

    final block = reactions.nextBlock;

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.62,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Header(used: reactions.myEmojis.length),
            Divider(height: 1, color: scheme.outlineVariant),
            Flexible(
              child: ListView.builder(
                padding: const EdgeInsets.only(bottom: AppSpacing.x2),
                itemCount: sections.length,
                itemBuilder: (context, index) => _Section(
                  section: sections[index],
                  reactions: reactions,
                  onSelected: onSelected,
                ),
              ),
            ),
            if (block != null) _CapNotice(block: block),
          ],
        ),
      ),
    );
  }

  List<String> _allowed(List<String> emojis) => [
    for (final emoji in emojis)
      if (policy.isAllowed(emoji)) emoji,
  ];

  static String _titleOf(ReactionSection section, AppLocalizations l10n) =>
      switch (section) {
        ReactionSection.faces => l10n.reactionSectionFaces,
        ReactionSection.people => l10n.reactionSectionPeople,
        ReactionSection.hearts => l10n.reactionSectionHearts,
        ReactionSection.celebration => l10n.reactionSectionCelebration,
        ReactionSection.food => l10n.reactionSectionFood,
        ReactionSection.nature => l10n.reactionSectionNature,
        ReactionSection.symbols => l10n.reactionSectionSymbols,
      };
}

class _CatalogSection {
  const _CatalogSection({required this.title, required this.emojis});

  final String title;
  final List<String> emojis;
}

/// Nothing to pick from, and why.
class _Notice extends StatelessWidget {
  const _Notice({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.x4,
        AppSpacing.x3,
        AppSpacing.x4,
        AppSpacing.x6,
      ),
      child: Text(
        text,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.outline,
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.used});

  /// How many of this reader's three are already spent on the message.
  final int used;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.x4,
        0,
        AppSpacing.x4,
        AppSpacing.x3,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(l10n.addReaction, style: theme.textTheme.titleSmall),
          ),
          Text(
            l10n.reactionsUsed(used, ReactionLimits.maxPerUserPerMessage),
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.section,
    required this.reactions,
    required this.onSelected,
  });

  final _CatalogSection section;
  final MessageReactionsEntity reactions;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.x4,
            AppSpacing.x3,
            AppSpacing.x4,
            AppSpacing.x1,
          ),
          child: Text(
            section.title,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x3),
          child: Wrap(
            children: [
              for (final emoji in section.emojis)
                ReactionEmojiButton(
                  emoji: emoji,
                  isMine: reactions.isMine(emoji),
                  enabled: reactions.canReactWith(emoji),
                  onTap: () => onSelected(emoji),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// The line that explains why the rest of the catalog has gone flat.
class _CapNotice extends StatelessWidget {
  const _CapNotice({required this.block});

  final ReactionBlock block;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.x4,
        AppSpacing.x2,
        AppSpacing.x4,
        AppSpacing.x3,
      ),
      child: Text(
        switch (block) {
          ReactionBlock.perUser => l10n.reactionLimitReached(
            ReactionLimits.maxPerUserPerMessage,
          ),
          ReactionBlock.perMessage => l10n.reactionMessageLimitReached(
            ReactionLimits.maxDistinctPerMessage,
          ),
        },
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.outline,
        ),
      ),
    );
  }
}

/// One emoji, tappable — the catalog sheet's cell, and the quick bar's.
class ReactionEmojiButton extends StatelessWidget {
  const ReactionEmojiButton({
    super.key,
    required this.emoji,
    required this.isMine,
    required this.enabled,
    required this.onTap,
    this.size = 44,
  });

  final String emoji;

  /// Ours already: highlighted, and always tappable so it can come back off.
  final bool isMine;

  /// False when a cap from §5.7.4 stands in the way.
  final bool enabled;

  final VoidCallback onTap;

  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Semantics(
      button: true,
      selected: isMine,
      enabled: enabled,
      label: emoji,
      // Absorbing rather than merely ignoring: a tap that falls through a
      // flat emoji reaches the scrim behind the quick bar (or the sheet's
      // barrier) and closes the whole thing, which reads as the app
      // dismissing itself over a button that was never going to work.
      child: AbsorbPointer(
        absorbing: !enabled,
        child: InkWell(
          onTap: enabled ? onTap : null,
          customBorder: const CircleBorder(),
          child: Opacity(
            opacity: enabled ? 1 : 0.32,
            child: Container(
              width: size,
              height: size,
              margin: const EdgeInsets.all(2),
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
              child: Text(emoji, style: TextStyle(fontSize: size * 0.5)),
            ),
          ),
        ),
      ),
    );
  }
}
