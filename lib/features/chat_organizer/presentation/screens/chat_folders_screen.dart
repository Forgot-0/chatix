import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:chatix/core/router/app_routes.dart';
import 'package:chatix/core/theme/app_tokens.dart';
import 'package:chatix/features/chat_organizer/domain/entities/chat_folder.dart';
import 'package:chatix/features/chat_organizer/domain/entities/folder_preset.dart';
import 'package:chatix/features/chat_organizer/domain/entities/organizer_failures.dart';
import 'package:chatix/features/chat_organizer/presentation/providers/chat_organizer_provider.dart';
import 'package:chatix/features/chat_organizer/presentation/widgets/folder_labels.dart';
import 'package:chatix/gen/l10n/app_localizations.dart';

/// Where folders are made, ordered and thrown away, and where the two
/// switches that change how the list behaves live.
class ChatFoldersScreen extends ConsumerWidget {
  const ChatFoldersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final data = ref.watch(organizerDataProvider);

    final missingPresets = FolderPreset.values
        .where((preset) => data.folderById(preset.folderId) == null)
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.chatFolders),
        actions: [
          IconButton(
            onPressed: () =>
                context.push(FolderEditorRoute.locationOf(null)),
            icon: const Icon(Icons.add),
            tooltip: l10n.newFolder,
          ),
        ],
      ),
      body: ListView(
        key: const PageStorageKey<String>('chat-folders'),
        padding: const EdgeInsets.only(bottom: AppSpacing.x8),
        children: [
          const _DeviceOnlyNotice(),

          if (data.folders.isEmpty)
            _EmptyFolders(l10n: l10n)
          else ...[
            _SectionLabel(label: l10n.folderYours),
            ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: data.folders.length,
              onReorder: (oldIndex, newIndex) => ref
                  .read(chatOrganizerProvider.notifier)
                  .reorderFolders(oldIndex: oldIndex, newIndex: newIndex),
              itemBuilder: (context, index) {
                final folder = data.folders[index];

                return _FolderRow(
                  key: ValueKey<String>(folder.id),
                  folder: folder,
                  index: index,
                );
              },
            ),
          ],

          if (missingPresets.isNotEmpty) ...[
            _SectionLabel(label: l10n.folderReadyMade),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.x4,
                vertical: AppSpacing.x1,
              ),
              child: Wrap(
                spacing: AppSpacing.x2,
                runSpacing: AppSpacing.x2,
                children: [
                  for (final preset in missingPresets)
                    ActionChip(
                      avatar: Icon(FolderIcons.resolve(preset.iconKey)),
                      label: Text(folderPresetTitle(preset, l10n)),
                      onPressed: () => _addPreset(context, ref, preset),
                    ),
                ],
              ),
            ),
          ],

          const Divider(height: AppSpacing.x6),

          SwitchListTile(
            value: data.settings.foldersHidden,
            onChanged: (hidden) => ref
                .read(chatOrganizerProvider.notifier)
                .setFoldersHidden(hidden: hidden),
            title: Text(l10n.hideFolderTabs),
            subtitle: Text(l10n.hideFolderTabsHint),
            secondary: const Icon(Icons.visibility_off_outlined),
          ),
          SwitchListTile(
            value: data.settings.unarchiveOnNewMessage,
            onChanged: (enabled) => ref
                .read(chatOrganizerProvider.notifier)
                .setUnarchiveOnNewMessage(enabled: enabled),
            title: Text(l10n.unarchiveOnNewMessage),
            subtitle: Text(l10n.unarchiveOnNewMessageHint),
            secondary: const Icon(Icons.unarchive_outlined),
          ),
        ],
      ),
    );
  }

  Future<void> _addPreset(
    BuildContext context,
    WidgetRef ref,
    FolderPreset preset,
  ) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);

    final failure = await ref
        .read(chatOrganizerProvider.notifier)
        .saveFolder(ChatFolder.fromPreset(preset));

    if (failure == null) return;

    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            failure is FolderLimitFailure
                ? l10n.folderLimitReached(failure.limit)
                : l10n.errorOccurred,
          ),
        ),
      );
  }
}

/// One folder in the list: what it is called, what it keeps, and a handle to
/// drag it by.
class _FolderRow extends ConsumerWidget {
  const _FolderRow({
    super.key,
    required this.folder,
    required this.index,
  });

  final ChatFolder folder;
  final int index;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    final summary = folder.rules
        .map((rule) => folderRuleSummary(rule, l10n))
        .join(' · ');

    return ListTile(
      leading: Icon(FolderIcons.resolve(folder.iconKey)),
      title: Text(folderTitleOf(folder, l10n)),
      subtitle: Text(
        summary,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      onTap: () => context.push(FolderEditorRoute.locationOf(folder.id)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            onPressed: () => _confirmDelete(context, ref, l10n),
            icon: const Icon(Icons.delete_outline),
            tooltip: l10n.deleteFolder,
          ),
          ReorderableDragStartListener(
            index: index,
            child: Icon(
              Icons.drag_handle,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
  ) async {
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

    if (confirmed != true) return;

    await ref.read(chatOrganizerProvider.notifier).deleteFolder(folder.id);
  }
}

/// Says out loud what the backend does not keep, because a reader who
/// reinstalls and finds their folders gone deserves to have been told.
class _DeviceOnlyNotice extends StatelessWidget {
  const _DeviceOnlyNotice();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.x4,
        AppSpacing.x4,
        AppSpacing.x4,
        AppSpacing.x2,
      ),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.x3),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.phonelink_lock_outlined,
              size: 20,
              color: scheme.onSurfaceVariant,
            ),
            const SizedBox(width: AppSpacing.x3),
            Expanded(
              child: Text(
                AppLocalizations.of(context).organizerDeviceOnly,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyFolders extends StatelessWidget {
  const _EmptyFolders({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.x4,
        AppSpacing.x6,
        AppSpacing.x4,
        AppSpacing.x2,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.foldersEmpty, style: theme.textTheme.titleMedium),
          const SizedBox(height: AppSpacing.x2),
          Text(
            l10n.foldersEmptyHint,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
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
        AppSpacing.x4,
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
