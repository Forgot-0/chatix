import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:chatix/core/providers/theme_providers.dart';
import 'package:chatix/core/router/app_routes.dart';
import 'package:chatix/core/theme/app_tokens.dart';
import 'package:chatix/core/theme/theme_config.dart';
import 'package:chatix/gen/l10n/app_localizations.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final appearance = ref.watch(appearanceProvider);
    final controller = ref.read(appearanceProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settings)),
      body: ListView(
        key: const PageStorageKey<String>('settings-list'),
        children: [
          ListTile(
            leading: const Icon(Icons.person_outline),
            title: Text(l10n.profile),
            subtitle: Text(l10n.profileSettingsHint),
            onTap: () => context.push(ProfileRoute.location),
          ),

          ListTile(
            leading: const Icon(Icons.language),
            title: Text(l10n.language),
            subtitle: Text(l10n.change_language),
            onTap: () => context.push(LanguageSettingsRoute.location),
          ),

          ListTile(
            leading: const Icon(Icons.devices),
            title: Text(l10n.myDevices),
            onTap: () => context.push(SessionsRoute.location),
          ),

          if (kDebugMode)
            ListTile(
              leading: const Icon(Icons.palette_outlined),
              title: Text(l10n.designSystem),
              onTap: () => context.push(ComponentShowcaseRoute.location),
            ),

          const Divider(),

          _SectionLabel(label: l10n.theme),
          RadioGroup<AppThemeMode>(
            groupValue: appearance.themeMode,
            onChanged: (mode) {
              if (mode != null) {
                controller.setThemeMode(mode);
              }
            },
            child: Column(
              children: [
                RadioListTile<AppThemeMode>(
                  value: AppThemeMode.system,
                  title: Text(l10n.systemMode),
                ),
                RadioListTile<AppThemeMode>(
                  value: AppThemeMode.light,
                  title: Text(l10n.lightMode),
                ),
                RadioListTile<AppThemeMode>(
                  value: AppThemeMode.dark,
                  title: Text(l10n.darkMode),
                ),
              ],
            ),
          ),

          const Divider(),

          _SectionLabel(label: l10n.accentColor),
          AccentPicker(
            selected: appearance.accentSeed,
            onSelected: controller.setAccentSeed,
          ),

          const Divider(),

          _SectionLabel(label: l10n.messageDensity),
          RadioGroup<AppDensity>(
            groupValue: appearance.density,
            onChanged: (value) {
              if (value != null) {
                controller.setDensity(value);
              }
            },
            child: Column(
              children: [
                RadioListTile<AppDensity>(
                  value: AppDensity.compact,
                  title: Text(l10n.densityCompact),
                ),
                RadioListTile<AppDensity>(
                  value: AppDensity.cozy,
                  title: Text(l10n.densityCozy),
                ),
                RadioListTile<AppDensity>(
                  value: AppDensity.comfortable,
                  title: Text(l10n.densityComfortable),
                ),
              ],
            ),
          ),

          const Divider(),

          _SectionLabel(label: l10n.chatWallpaper),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x4),
            child: SegmentedButton<AppWallpaper>(
              segments: [
                ButtonSegment(
                  value: AppWallpaper.aurora,
                  label: Text(l10n.wallpaperAurora),
                ),
                ButtonSegment(
                  value: AppWallpaper.mesh,
                  label: Text(l10n.wallpaperMesh),
                ),
                ButtonSegment(
                  value: AppWallpaper.plain,
                  label: Text(l10n.wallpaperPlain),
                ),
              ],
              selected: {appearance.wallpaper},
              onSelectionChanged: (selection) =>
                  controller.setWallpaper(selection.first),
            ),
          ),

          const Divider(height: AppSpacing.x8),

          _SectionLabel(label: l10n.textSize),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x4),
            child: SegmentedButton<double>(
              segments: [
                ButtonSegment(value: 0.85, label: Text(l10n.textSizeSmall)),
                ButtonSegment(value: 1, label: Text(l10n.textSizeDefault)),
                ButtonSegment(value: 1.15, label: Text(l10n.textSizeLarge)),
                ButtonSegment(
                  value: 1.3,
                  label: Text(l10n.textSizeExtraLarge),
                ),
              ],
              selected: {appearance.textScale},
              onSelectionChanged: (selection) =>
                  controller.setTextScale(selection.first),
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.x4,
              AppSpacing.x5,
              AppSpacing.x4,
              AppSpacing.x6,
            ),
            child: OutlinedButton.icon(
              onPressed: controller.reset,
              icon: const Icon(Icons.restart_alt),
              label: Text(l10n.resetAppearance),
            ),
          ),
        ],
      ),
    );
  }
}

/// The accent swatches. Lives here rather than in `core/ui` because picking a
/// brand accent is a settings affordance, not a general primitive.
class AccentPicker extends StatelessWidget {
  const AccentPicker({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  final Color selected;
  final ValueChanged<Color> onSelected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.x4,
        vertical: AppSpacing.x2,
      ),
      child: Wrap(
        spacing: AppSpacing.x3,
        runSpacing: AppSpacing.x3,
        children: [
          for (final seed in AppPalette.accentSeeds)
            Semantics(
              selected: seed == selected,
              button: true,
              child: InkWell(
                onTap: () => onSelected(seed),
                customBorder: const CircleBorder(),
                child: AnimatedContainer(
                  duration: AppMotion.fast,
                  curve: AppMotion.curve,
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: seed,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: seed == selected ? scheme.onSurface : seed,
                      width: 2,
                    ),
                  ),
                  child: seed == selected
                      ? Icon(
                          Icons.check,
                          size: 20,
                          color:
                              ThemeData.estimateBrightnessForColor(seed) ==
                                  Brightness.dark
                              ? Colors.white
                              : AppNeutrals.light[11],
                        )
                      : null,
                ),
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
        label,
        style: theme.textTheme.labelLarge?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
