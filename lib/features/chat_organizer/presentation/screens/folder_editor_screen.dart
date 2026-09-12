import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import 'package:chatix/core/error/failures.dart';
import 'package:chatix/core/theme/app_tokens.dart';
import 'package:chatix/features/chat_organizer/domain/entities/chat_folder.dart';
import 'package:chatix/features/chat_organizer/domain/entities/folder_rule.dart';
import 'package:chatix/features/chat_organizer/domain/entities/organizer_failures.dart';
import 'package:chatix/features/chat_organizer/presentation/providers/chat_organizer_provider.dart';
import 'package:chatix/features/chat_organizer/presentation/widgets/folder_labels.dart';
import 'package:chatix/features/chat_organizer/presentation/widgets/folder_rule_sheets.dart';
import 'package:chatix/gen/l10n/app_localizations.dart';

/// The rule constructor: what makes a chat belong to one folder.
///
/// Editing a preset is allowed and turns it into a folder of your own — the
/// preset was only ever a starting set of rules, and pretending otherwise
/// would mean a screen full of controls that refuse to do anything.
class FolderEditorScreen extends ConsumerStatefulWidget {
  const FolderEditorScreen({super.key, this.folderId});

  /// The folder being edited, or null for one that does not exist yet.
  final String? folderId;

  @override
  ConsumerState<FolderEditorScreen> createState() => _FolderEditorScreenState();
}

class _FolderEditorScreenState extends ConsumerState<FolderEditorScreen> {
  static const Uuid _uuid = Uuid();

  final TextEditingController _title = TextEditingController();

  late String _id;
  late String _iconKey;
  late FolderMatchMode _matchMode;
  late List<FolderRule> _rules;

  /// The preset this started from, kept only while nothing has been touched.
  ChatFolder? _original;

  bool _loaded = false;

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    _loadOnce(l10n);

    final isNew = _original == null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isNew ? l10n.newFolder : l10n.editFolder),
        actions: [
          if (!isNew)
            IconButton(
              onPressed: _confirmDelete,
              icon: const Icon(Icons.delete_outline),
              tooltip: l10n.deleteFolder,
            ),
          TextButton(onPressed: _save, child: Text(l10n.save)),
          const SizedBox(width: AppSpacing.x2),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: AppSpacing.x8),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.x4,
              AppSpacing.x4,
              AppSpacing.x4,
              AppSpacing.x2,
            ),
            child: TextField(
              controller: _title,
              maxLength: ChatFolder.maxTitleLength,
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(
                labelText: l10n.folderName,
                border: const OutlineInputBorder(),
              ),
            ),
          ),

          _SectionLabel(label: l10n.folderIcon),
          _IconPicker(
            selected: _iconKey,
            onSelected: (key) => setState(() => _iconKey = key),
          ),

          const Divider(height: AppSpacing.x6),

          _SectionLabel(label: l10n.folderMatchModeTitle),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x4),
            child: SegmentedButton<FolderMatchMode>(
              segments: [
                ButtonSegment<FolderMatchMode>(
                  value: FolderMatchMode.all,
                  label: Text(l10n.folderMatchAll),
                ),
                ButtonSegment<FolderMatchMode>(
                  value: FolderMatchMode.any,
                  label: Text(l10n.folderMatchAny),
                ),
              ],
              selected: {_matchMode},
              onSelectionChanged: (selection) =>
                  setState(() => _matchMode = selection.first),
            ),
          ),

          const Divider(height: AppSpacing.x6),

          _SectionLabel(label: l10n.folderRules),
          for (var index = 0; index < _rules.length; index++)
            _RuleTile(
              rule: _rules[index],
              onEdit: () => _editRule(index),
              onRemove: () => setState(() => _rules.removeAt(index)),
            ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.x4),
            child: OutlinedButton.icon(
              onPressed: _addRule,
              icon: const Icon(Icons.add),
              label: Text(l10n.addFolderRule),
            ),
          ),
        ],
      ),
    );
  }

  /// Reads the folder being edited once, on the first build that has an
  /// [AppLocalizations] to name a copied preset with.
  void _loadOnce(AppLocalizations l10n) {
    if (_loaded) return;
    _loaded = true;

    final existing = ref
        .read(organizerDataProvider)
        .folderById(widget.folderId);

    if (existing == null) {
      _id = 'custom.${_uuid.v4()}';
      _iconKey = ChatFolder.defaultIconKey;
      _matchMode = FolderMatchMode.all;
      _rules = <FolderRule>[];
      return;
    }

    _original = existing;
    _id = existing.id;
    _iconKey = existing.iconKey;
    _matchMode = existing.matchMode;
    _rules = [...existing.rules];
    _title.text = folderTitleOf(existing, l10n);
  }

  Future<void> _addRule() async {
    final rule = await addFolderRule(context);
    if (rule == null || !mounted) return;
    setState(() => _rules.add(rule));
  }

  Future<void> _editRule(int index) async {
    final rule = await editFolderRule(context, _rules[index]);
    if (rule == null || !mounted) return;
    setState(() => _rules[index] = rule);
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    final folder = ChatFolder(
      id: _id,
      title: _title.text.trim(),
      iconKey: _iconKey,
      matchMode: _matchMode,
      rules: List<FolderRule>.unmodifiable(_rules),
    );

    final failure = await ref
        .read(chatOrganizerProvider.notifier)
        .saveFolder(folder);

    if (failure != null) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(_messageFor(failure, l10n))));
      return;
    }

    if (navigator.canPop()) navigator.pop();
  }

  Future<void> _confirmDelete() async {
    final l10n = AppLocalizations.of(context);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.deleteFolder),
        content: Text(l10n.deleteFolderConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.deleteFolder),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final navigator = Navigator.of(context);
    await ref.read(chatOrganizerProvider.notifier).deleteFolder(_id);
    if (navigator.canPop()) navigator.pop();
  }

  String _messageFor(Failure failure, AppLocalizations l10n) {
    return switch (failure) {
      InvalidFolderFailure(:final problem) => switch (problem) {
        FolderProblem.emptyTitle => l10n.folderNameRequired,
        FolderProblem.titleTooLong => l10n.folderNameTooLong(
          ChatFolder.maxTitleLength,
        ),
        FolderProblem.noRules => l10n.folderRulesRequired,
      },
      FolderLimitFailure(:final limit) => l10n.folderLimitReached(limit),
      _ => l10n.errorOccurred,
    };
  }
}

class _RuleTile extends StatelessWidget {
  const _RuleTile({
    required this.rule,
    required this.onEdit,
    required this.onRemove,
  });

  final FolderRule rule;
  final VoidCallback onEdit;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return ListTile(
      leading: Icon(folderRuleIcon(rule.kind)),
      title: Text(folderRuleSummary(rule, l10n)),
      onTap: onEdit,
      trailing: IconButton(
        onPressed: onRemove,
        icon: const Icon(Icons.close),
        tooltip: l10n.removeFolderRule,
      ),
    );
  }
}

class _IconPicker extends StatelessWidget {
  const _IconPicker({required this.selected, required this.onSelected});

  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x4),
      child: Wrap(
        spacing: AppSpacing.x2,
        runSpacing: AppSpacing.x2,
        children: [
          for (final key in FolderIcons.keys)
            IconButton.filledTonal(
              onPressed: () => onSelected(key),
              isSelected: key == selected,
              style: IconButton.styleFrom(
                backgroundColor: key == selected
                    ? scheme.primaryContainer
                    : scheme.surfaceContainerHighest,
                foregroundColor: key == selected
                    ? scheme.onPrimaryContainer
                    : scheme.onSurfaceVariant,
              ),
              icon: Icon(FolderIcons.resolve(key)),
            ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.x4,
        AppSpacing.x3,
        AppSpacing.x4,
        AppSpacing.x1,
      ),
      child: Text(
        label.toUpperCase(),
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}
