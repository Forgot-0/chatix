import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:chatix/core/theme/app_tokens.dart';
import 'package:chatix/features/chat/domain/entities/chat_entity.dart';
import 'package:chatix/features/chat_organizer/domain/entities/folder_rule.dart';
import 'package:chatix/features/chat_organizer/presentation/providers/known_people_provider.dart';
import 'package:chatix/features/chat_organizer/presentation/widgets/folder_labels.dart';
import 'package:chatix/gen/l10n/app_localizations.dart';

/// Picks a kind of rule, then lets it be filled in. Null means the reader
/// backed out of either step.
Future<FolderRule?> addFolderRule(BuildContext context) async {
  final l10n = AppLocalizations.of(context);

  // Scroll-controlled and scrollable: five kinds plus a heading do not fit
  // the default half-height sheet on a short screen, and would not fit any
  // of them at a large text scale.
  final kind = await showModalBottomSheet<FolderRuleKind>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) => SafeArea(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _SheetTitle(title: l10n.addFolderRule),
            for (final kind in FolderRuleKind.values)
              ListTile(
                leading: Icon(folderRuleIcon(kind)),
                title: Text(folderRuleKindLabel(kind, l10n)),
                onTap: () => Navigator.of(sheetContext).pop(kind),
              ),
          ],
        ),
      ),
    ),
  );

  if (kind == null || !context.mounted) return null;

  return editFolderRule(context, _defaultRuleOf(kind));
}

FolderRule _defaultRuleOf(FolderRuleKind kind) {
  switch (kind) {
    case FolderRuleKind.chatType:
      return const ChatTypeRule({ChatType.direct});
    case FolderRuleKind.unread:
      return const UnreadRule();
    case FolderRuleKind.pinned:
      return const PinnedRule();
    case FolderRuleKind.noReplyFromMe:
      return const NoReplyFromMeRule();
    case FolderRuleKind.member:
      return const MemberRule(userId: 0);
  }
}

/// Opens the editor that belongs to [rule]. Null means nothing changed.
Future<FolderRule?> editFolderRule(BuildContext context, FolderRule rule) {
  switch (rule) {
    case ChatTypeRule():
      return _showSheet<FolderRule>(
        context,
        (_) => SingleChildScrollView(child: _ChatTypeRuleSheet(rule)),
      );
    case UnreadRule():
      return _showSheet<FolderRule>(
        context,
        (_) => SingleChildScrollView(child: _BoolRuleSheet(rule)),
      );
    case PinnedRule():
      return _showSheet<FolderRule>(
        context,
        (_) => SingleChildScrollView(child: _BoolRuleSheet(rule)),
      );
    case NoReplyFromMeRule():
      return _showSheet<FolderRule>(
        context,
        (_) => SingleChildScrollView(child: _NoReplyRuleSheet(rule)),
      );
    case MemberRule():
      return _showSheet<FolderRule>(context, (_) => _MemberRuleSheet(rule));
  }
}

Future<T?> _showSheet<T>(
  BuildContext context,
  WidgetBuilder builder,
) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) => SafeArea(child: builder(sheetContext)),
  );
}

class _SheetTitle extends StatelessWidget {
  const _SheetTitle({required this.title, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final note = subtitle;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.x4,
        AppSpacing.x4,
        AppSpacing.x4,
        AppSpacing.x2,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.titleMedium),
          if (note != null) ...[
            const SizedBox(height: AppSpacing.x1),
            Text(
              note,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// `type ∈ {...}`: at least one type has to stay ticked, since a rule that
/// accepts nothing would make the folder permanently empty.
class _ChatTypeRuleSheet extends StatefulWidget {
  const _ChatTypeRuleSheet(this.rule);

  final ChatTypeRule rule;

  @override
  State<_ChatTypeRuleSheet> createState() => _ChatTypeRuleSheetState();
}

class _ChatTypeRuleSheetState extends State<_ChatTypeRuleSheet> {
  late Set<ChatType> _types = {...widget.rule.types};

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SheetTitle(title: l10n.folderRuleChatType),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x4),
          child: Wrap(
            spacing: AppSpacing.x2,
            runSpacing: AppSpacing.x2,
            children: [
              for (final type in ChatType.values)
                FilterChip(
                  label: Text(chatTypeLabel(type, l10n)),
                  selected: _types.contains(type),
                  onSelected: (selected) => setState(() {
                    if (selected) {
                      _types = {..._types, type};
                    } else if (_types.length > 1) {
                      _types = _types.where((t) => t != type).toSet();
                    }
                  }),
                ),
            ],
          ),
        ),
        _SheetActions(
          onSave: () => Navigator.of(context).pop(ChatTypeRule(_types)),
        ),
      ],
    );
  }
}

/// The two rules that are a single yes-or-no: unread, and pinned.
class _BoolRuleSheet extends StatefulWidget {
  const _BoolRuleSheet(this.rule);

  final FolderRule rule;

  @override
  State<_BoolRuleSheet> createState() => _BoolRuleSheetState();
}

class _BoolRuleSheetState extends State<_BoolRuleSheet> {
  late bool _expected = switch (widget.rule) {
    UnreadRule(:final expected) => expected,
    PinnedRule(:final expected) => expected,
    _ => true,
  };

  bool get _isUnread => widget.rule is UnreadRule;

  FolderRule get _result => _isUnread
      ? UnreadRule(expected: _expected)
      : PinnedRule(expected: _expected);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    final onLabel = _isUnread ? l10n.folderRuleUnread : l10n.folderRulePinned;
    final offLabel = _isUnread
        ? l10n.folderRuleRead
        : l10n.folderRuleNotPinned;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SheetTitle(
          title: folderRuleKindLabel(
            _isUnread ? FolderRuleKind.unread : FolderRuleKind.pinned,
            l10n,
          ),
        ),
        RadioGroup<bool>(
          groupValue: _expected,
          onChanged: (value) => setState(() => _expected = value ?? true),
          child: Column(
            children: [
              RadioListTile<bool>(value: true, title: Text(onLabel)),
              RadioListTile<bool>(value: false, title: Text(offLabel)),
            ],
          ),
        ),
        _SheetActions(onSave: () => Navigator.of(context).pop(_result)),
      ],
    );
  }
}

/// "I have not answered for longer than N days", with zero meaning "however
/// recently they wrote".
class _NoReplyRuleSheet extends StatefulWidget {
  const _NoReplyRuleSheet(this.rule);

  final NoReplyFromMeRule rule;

  @override
  State<_NoReplyRuleSheet> createState() => _NoReplyRuleSheetState();
}

class _NoReplyRuleSheetState extends State<_NoReplyRuleSheet> {
  static const int _maxSliderDays = 30;

  late double _days = widget.rule.days
      .clamp(0, _maxSliderDays)
      .toDouble();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final days = _days.round();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SheetTitle(
          title: l10n.folderRuleDaysLabel,
          subtitle: l10n.folderRuleNoReplyDays(days),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x4),
          child: Slider(
            value: _days,
            min: 0,
            max: _maxSliderDays.toDouble(),
            divisions: _maxSliderDays,
            label: days == 0 ? l10n.folderRuleDaysAny : '$days',
            onChanged: (value) => setState(() => _days = value),
          ),
        ),
        _SheetActions(
          onSave: () =>
              Navigator.of(context).pop(NoReplyFromMeRule(days: days)),
        ),
      ],
    );
  }
}

/// Picks the person a member rule looks for, out of the people the list can
/// already name.
class _MemberRuleSheet extends ConsumerWidget {
  const _MemberRuleSheet(this.rule);

  final MemberRule rule;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final people = ref.watch(knownPeopleProvider);
    final theme = Theme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SheetTitle(
          title: l10n.folderRulePickPerson,
          subtitle: l10n.folderRuleMemberLocalNote,
        ),
        if (people.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.x4,
              AppSpacing.x2,
              AppSpacing.x4,
              AppSpacing.x6,
            ),
            child: Text(
              l10n.folderRuleNoPeople,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          )
        else
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: people.length,
              itemBuilder: (context, index) {
                final person = people[index];

                final isChosen = person.userId == rule.userId;

                return ListTile(
                  title: Text(person.name),
                  trailing: isChosen
                      ? Icon(Icons.check, color: theme.colorScheme.primary)
                      : null,
                  onTap: () => Navigator.of(context).pop(
                    MemberRule(userId: person.userId, label: person.name),
                  ),
                );
              },
            ),
          ),
        const SizedBox(height: AppSpacing.x2),
      ],
    );
  }
}

class _SheetActions extends StatelessWidget {
  const _SheetActions({required this.onSave});

  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.x4,
        AppSpacing.x2,
        AppSpacing.x4,
        AppSpacing.x4,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.cancel),
          ),
          const SizedBox(width: AppSpacing.x2),
          FilledButton(onPressed: onSave, child: Text(l10n.save)),
        ],
      ),
    );
  }
}
