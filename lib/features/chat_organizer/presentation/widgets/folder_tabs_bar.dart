import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:chatix/core/theme/app_tokens.dart';
import 'package:chatix/features/chat_organizer/presentation/providers/chat_organizer_provider.dart';
import 'package:chatix/features/chat_organizer/presentation/providers/folder_selection_provider.dart';
import 'package:chatix/features/chat_organizer/presentation/widgets/folder_labels.dart';
import 'package:chatix/gen/l10n/app_localizations.dart';

/// The strip of folder tabs under the app bar.
///
/// It is not drawn at all when there is nothing to draw — no folders, or a
/// reader who asked for it to be hidden — so an account that never opens the
/// folders screen never pays a row of chrome for it.
class FolderTabsBar extends ConsumerWidget implements PreferredSizeWidget {
  const FolderTabsBar({super.key});

  /// Fixed, because an app bar has to reserve the room before it knows what
  /// is in it. Sized to hold a tab at the clamped text scale below.
  static const double height = 50;

  /// How far type in the strip is allowed to grow. Chrome of a fixed height
  /// cannot honour an unbounded scale, and a tab that has been cut off is
  /// worse than one that stopped growing — the list below it scales freely.
  static const double maxTextScale = 1.3;

  @override
  Size get preferredSize => const Size.fromHeight(height);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final folders = ref.watch(organizerDataProvider).folders;
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    final selected = ref.watch(activeFolderProvider);
    final counts = ref.watch(folderUnreadCountsProvider);

    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: maxTextScale,
      child: SizedBox(
        height: height,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: height - 1,
              child: Row(
                children: [
                  const SizedBox(width: AppSpacing.x2),
                  _FolderTab(
                    label: l10n.chatFoldersAll,
                    icon: Icons.forum_outlined,
                    count: ref.watch(visibleUnreadCountProvider),
                    isSelected: selected == null,
                    onTap: () =>
                        ref.read(activeFolderProvider.notifier).select(null),
                  ),
                  Expanded(
                    child: ReorderableListView.builder(
                      scrollDirection: Axis.horizontal,
                      buildDefaultDragHandles: false,
                      padding: const EdgeInsets.only(right: AppSpacing.x2),
                      itemCount: folders.length,
                      onReorder: (oldIndex, newIndex) => ref
                          .read(chatOrganizerProvider.notifier)
                          .reorderFolders(
                            oldIndex: oldIndex,
                            newIndex: newIndex,
                          ),
                      proxyDecorator: (child, index, animation) => Material(
                        color: Colors.transparent,
                        child: child,
                      ),
                      itemBuilder: (context, index) {
                        final folder = folders[index];

                        return ReorderableDelayedDragStartListener(
                          key: ValueKey<String>(folder.id),
                          index: index,
                          child: _FolderTab(
                            label: folderTitleOf(folder, l10n),
                            icon: FolderIcons.resolve(folder.iconKey),
                            count: counts[folder.id] ?? 0,
                            isSelected: selected == folder.id,
                            onTap: () => ref
                                .read(activeFolderProvider.notifier)
                                .select(folder.id),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: theme.colorScheme.outlineVariant),
          ],
        ),
      ),
    );
  }
}

/// One tab: a pill that fills in when it is the one you are reading.
class _FolderTab extends StatelessWidget {
  const _FolderTab({
    required this.label,
    required this.icon,
    required this.count,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final int count;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final foreground = isSelected
        ? scheme.onSecondaryContainer
        : scheme.onSurfaceVariant;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.x1,
        vertical: 6,
      ),
      child: Material(
        color: isSelected ? scheme.secondaryContainer : Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.x3,
              vertical: AppSpacing.x1,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 16, color: foreground),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: foreground,
                    fontWeight: isSelected
                        ? FontWeight.w700
                        : FontWeight.w500,
                  ),
                ),
                if (count > 0) ...[
                  const SizedBox(width: 6),
                  _TabCount(count: count, isSelected: isSelected),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TabCount extends StatelessWidget {
  const _TabCount({required this.count, required this.isSelected});

  final int count;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final background = isSelected ? scheme.primary : scheme.surfaceContainerHighest;
    final foreground = isSelected ? scheme.onPrimary : scheme.onSurfaceVariant;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        count > 99 ? '99+' : '$count',
        style: theme.textTheme.labelSmall?.copyWith(
          color: foreground,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
