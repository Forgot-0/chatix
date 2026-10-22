import 'package:flutter/material.dart';

import 'package:chatix/core/router/app_layout.dart';
import 'package:chatix/core/ui/illustrations/app_illustrations.dart';
import 'package:chatix/core/ui/states/app_async_states.dart';
import 'package:chatix/features/settings/presentation/screens/settings_screen.dart';
import 'package:chatix/features/settings/presentation/utils/settings_catalog.dart';
import 'package:chatix/gen/l10n/app_localizations.dart';

/// The settings branch's body — one pane, or the list and a section.
///
/// The same arrangement `ChatsPaneShell` makes for conversations. Below
/// [AppBreakpoints.expanded] this is a pass-through and the branch's
/// navigator stacks the list and its sections as usual. At and above it
/// the list moves out of the navigator to the left, and the navigator —
/// the section, and whatever was opened from it — becomes the right pane.
///
/// Which section is open comes from the location, not from a field, so it
/// survives the window being dragged across the breakpoint.
class SettingsPaneShell extends StatelessWidget {
  const SettingsPaneShell({
    super.key,
    required this.location,
    required this.child,
  });

  /// Where the branch is: `/settings/appearance`, `/profile/edit`…
  final String location;

  /// The branch navigator: the section and anything pushed over it.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!AppLayoutScope.of(context).isTwoPane) return child;

    return Row(
      children: [
        SizedBox(
          width: AppBreakpoints.listPaneWidth,
          child: SettingsScreen(selected: SettingsSection.at(location)),
        ),
        const VerticalDivider(width: 1, thickness: 1),
        Expanded(child: child),
      ],
    );
  }
}

/// What `/settings` itself renders: the list on one pane; beside the list,
/// in two, the placeholder the right pane shows until a section is picked.
class SettingsHomePane extends StatelessWidget {
  const SettingsHomePane({super.key});

  @override
  Widget build(BuildContext context) {
    return AppLayoutScope.of(context).isTwoPane
        ? const SettingsPlaceholderPane()
        : const SettingsScreen();
  }
}

/// The right pane before a section is picked.
class SettingsPlaceholderPane extends StatelessWidget {
  const SettingsPlaceholderPane({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerLowest,
      body: AppEmptyState(
        illustration: AppIllustrationKind.settings,
        title: l10n.settingsPanePlaceholderTitle,
        message: l10n.settingsPanePlaceholderHint,
      ),
    );
  }
}
