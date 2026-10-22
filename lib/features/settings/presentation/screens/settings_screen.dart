import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:chatix/core/router/app_routes.dart';
import 'package:chatix/core/settings/dev_menu.dart';
import 'package:chatix/core/theme/app_tokens.dart';
import 'package:chatix/core/ui/cards/app_grouped_section.dart';
import 'package:chatix/core/ui/desktop/desktop_input.dart';
import 'package:chatix/core/ui/illustrations/app_illustrations.dart';
import 'package:chatix/core/ui/states/app_async_states.dart';
import 'package:chatix/core/ui/typography/highlighted_text.dart';
import 'package:chatix/core/ui/widgets/app_content_width.dart';
import 'package:chatix/features/notification/presentation/providers/notification_badge_provider.dart';
import 'package:chatix/features/notification/presentation/widgets/notification_bell.dart';
import 'package:chatix/features/settings/presentation/utils/settings_catalog.dart';
import 'package:chatix/features/settings/presentation/utils/settings_navigation.dart';
import 'package:chatix/features/settings/presentation/widgets/settings_profile_card.dart';
import 'package:chatix/features/settings/presentation/widgets/sign_out_tile.dart';
import 'package:chatix/gen/l10n/app_localizations.dart';
import 'package:chatix/l10n/app_localizations_delegate.dart';

/// The settings list: the reader's card, then the sections in coloured
/// groups, then signing out on a card of its own.
///
/// On a phone it is the whole tab and every row pushes its section. In a
/// two-pane window it is the left pane and [selected] is the section open
/// beside it, kept marked the way the chat list marks the open chat. A
/// search field on top narrows it to the rows — and the rows inside the
/// sections — whose names match.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key, this.selected});

  /// The section open in the right pane, or null on one pane and before
  /// anything is picked.
  final SettingsSection? selected;

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final TextEditingController _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _open(SettingsSection section) {
    if (!section.opensInPane) {
      context.push(section.location);
      return;
    }
    openSettingsLocation(context, section.location);
  }

  void _clearSearch() {
    _search.clear();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final developer = ref.watch(devMenuUnlockedProvider);
    final query = _search.text.trim();

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settings)),
      body: AppContentWidth(
        child: Column(
          children: [
            _SearchField(
              controller: _search,
              onChanged: (_) => setState(() {}),
              onClear: _clearSearch,
            ),
            Expanded(
              child: query.isEmpty
                  ? _list(_groups(l10n, developer: developer))
                  : _results(l10n, query, developer: developer),
            ),
          ],
        ),
      ),
    );
  }

  Widget _list(List<Widget> children) => ListView(
    key: const PageStorageKey<String>('settings-list'),
    padding: const EdgeInsets.only(bottom: AppSpacing.x8),
    children: children,
  );

  List<Widget> _groups(AppLocalizations l10n, {required bool developer}) {
    return [
      SettingsProfileCard(
        selected: widget.selected == SettingsSection.profile,
        onOpen: () => _open(SettingsSection.profile),
        onEdit: () => openSettingsLocation(context, ProfileEditRoute.location),
      ),
      for (final group in SettingsSection.groups(developer: developer)) ...[
        const SizedBox(height: SettingsLayout.groupGap),
        AppGroupedSection(
          children: [
            for (final section in group)
              _SectionRow(
                section: section,
                selected: widget.selected == section,
                onTap: () => _open(section),
              ),
          ],
        ),
      ],
      const SizedBox(height: SettingsLayout.groupGap),
      const AppGroupedSection(children: [SignOutTile()]),
    ];
  }

  Widget _results(
    AppLocalizations l10n,
    String query, {
    required bool developer,
  }) {
    final hits = searchSettings(
      settingsSearchIndex(
        l10n,
        developer: developer,
        desktop: DesktopInput.isDesktop,
      ),
      query,
    );

    if (hits.isEmpty) {
      return AppEmptyState(
        illustration: AppIllustrationKind.search,
        title: l10n.settingsSearchEmpty(query),
        message: l10n.settingsSearchEmptyHint,
      );
    }

    return ListView(
      key: const PageStorageKey<String>('settings-search'),
      padding: const EdgeInsets.only(bottom: AppSpacing.x8),
      children: [
        AppGroupedSection(
          children: [
            for (final hit in hits)
              _SearchHitRow(
                hit: hit,
                query: query,
                selected: hit.isSection && widget.selected == hit.section,
                onTap: () => _open(hit.section),
              ),
          ],
        ),
      ],
    );
  }
}

/// The field over the list. Typing narrows the list in place — there is
/// no separate search screen, because there is nothing to wait for: every
/// name is already here.
class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;

    final pill = OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadii.full),
      borderSide: BorderSide.none,
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        SettingsLayout.groupInset,
        AppSpacing.x1,
        SettingsLayout.groupInset,
        AppSpacing.x4,
      ),
      child: SizedBox(
        height: SettingsLayout.searchHeight,
        child: TextField(
          controller: controller,
          onChanged: onChanged,
          textInputAction: TextInputAction.search,
          autocorrect: false,
          textAlignVertical: TextAlignVertical.center,
          decoration: InputDecoration(
            hintText: l10n.settingsSearchHint,
            prefixIcon: const Icon(Icons.search),
            suffixIcon: controller.text.isEmpty
                ? null
                : IconButton(
                    tooltip: l10n.settingsSearchClear,
                    icon: const Icon(Icons.close),
                    onPressed: onClear,
                  ),
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.x4,
            ),
            fillColor: scheme.surfaceContainerHigh,
            border: pill,
            enabledBorder: pill,
            focusedBorder: pill.copyWith(
              borderSide: BorderSide(color: scheme.primary, width: 1.5),
            ),
          ),
        ),
      ),
    );
  }
}

/// One section of the list, with whatever it has to say at its end: how
/// many alerts are unread, which language the app speaks.
class _SectionRow extends StatelessWidget {
  const _SectionRow({
    required this.section,
    required this.selected,
    required this.onTap,
  });

  final SettingsSection section;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return AppGroupedTile(
      icon: section.icon,
      plateColor: section.plate,
      title: section.title(l10n),
      selected: selected,
      onTap: onTap,
      value: switch (section) {
        // The language actually on screen, which is what the reader is
        // asking about — not a stored preference it may have fallen back
        // from.
        SettingsSection.language => LocalizationUtils.getLocaleName(
          Localizations.localeOf(context),
        ),
        _ => null,
      },
      trailing: section == SettingsSection.notificationsFeed
          ? const _AlertsBadge()
          : null,
    );
  }
}

/// How many alerts are unread, then the chevron — or the chevron alone.
class _AlertsBadge extends ConsumerWidget {
  const _AlertsBadge();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final unread = ref.watch(notificationBadgeProvider);
    final chevron = Icon(Icons.chevron_right, color: scheme.onSurfaceVariant);
    if (unread <= 0) return chevron;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          label: l10n.unreadNotificationsCount(unread),
          excludeSemantics: true,
          child: Badge(label: Text(NotificationBell.badgeLabel(unread))),
        ),
        const SizedBox(width: AppSpacing.x2),
        chevron,
      ],
    );
  }
}

/// A search hit: the name with the typed part picked out, and — for a row
/// inside a section — the section it lives in, underneath.
class _SearchHitRow extends StatelessWidget {
  const _SearchHitRow({
    required this.hit,
    required this.query,
    required this.selected,
    required this.onTap,
  });

  final SettingsSearchEntry hit;
  final String query;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final section = hit.section;

    return Semantics(
      selected: selected,
      child: Material(
        color: selected ? scheme.primaryContainer : Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: SettingsLayout.rowMinHeight,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.x4,
                vertical: AppSpacing.x2,
              ),
              child: Row(
                children: [
                  AppIconPlate(icon: section.icon, color: section.plate),
                  const SizedBox(width: SettingsLayout.plateGap),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        HighlightedText(
                          text: hit.title,
                          query: query,
                          style: theme.textTheme.bodyLarge,
                        ),
                        if (!hit.isSection) ...[
                          const SizedBox(height: SettingsLayout.lineGap),
                          Text(
                            section.title(l10n),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.x2),
                  Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
