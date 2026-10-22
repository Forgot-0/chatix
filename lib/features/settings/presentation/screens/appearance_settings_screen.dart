import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:chatix/core/providers/theme_providers.dart';
import 'package:chatix/core/settings/send_shortcut.dart';
import 'package:chatix/core/theme/app_tokens.dart';
import 'package:chatix/core/theme/theme_config.dart';
import 'package:chatix/core/ui/desktop/desktop_input.dart';
import 'package:chatix/core/ui/wallpaper/mesh_wallpaper.dart';
import 'package:chatix/core/ui/widgets/app_content_width.dart';
import 'package:chatix/features/settings/presentation/widgets/accent_picker.dart';
import 'package:chatix/features/settings/presentation/widgets/appearance_preview.dart';
import 'package:chatix/features/settings/presentation/widgets/wallpaper_gallery.dart';
import 'package:chatix/gen/l10n/app_localizations.dart';

/// Everything about how ChatiX looks and feels, on one screen, applied as
/// it is touched. What it downloads and keeps on disk moved to Data and
/// storage.
///
/// The preview at the top is the contract: nothing here is written down
/// without being visible first, and nothing is visible that is not what a
/// conversation will actually look like. Every control writes through to
/// storage, so what is on screen survives a restart — the sliders defer the
/// write until the finger lifts, which is the only place that is not literal.
class AppearanceSettingsScreen extends ConsumerWidget {
  const AppearanceSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    final settings = ref.watch(appearanceProvider);
    final controller = ref.read(appearanceProvider.notifier);

    final highContrast = MediaQuery.highContrastOf(context);
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    final wallpaperSpec = wallpaperSpecOf(
      context,
      layoutSeed: AppearancePreview.layoutSeed,
    );

    final patternable = settings.wallpaper != AppWallpaper.plain;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.appearanceTitle)),
      body: AppContentWidth(
        child: ListView(
          key: const PageStorageKey<String>('appearance-list'),
          padding: const EdgeInsets.only(bottom: AppSpacing.x8),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.x4,
                AppSpacing.x4,
                AppSpacing.x4,
                AppSpacing.x2,
              ),
              child: const AppearancePreview(),
            ),

            if (reduceMotion)
              _Notice(
                icon: Icons.motion_photos_off_outlined,
                text: l10n.appearanceReduceMotionNotice,
              ),
            if (highContrast)
              _Notice(
                icon: Icons.contrast,
                text: l10n.appearanceHighContrastNotice,
              ),

            // ── Theme ──────────────────────────────────────────────────────
            _SectionLabel(label: l10n.theme),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x4),
              child: SegmentedButton<AppThemeMode>(
                segments: [
                  ButtonSegment(
                    value: AppThemeMode.system,
                    label: Text(l10n.systemMode),
                    icon: const Icon(Icons.brightness_auto_outlined),
                  ),
                  ButtonSegment(
                    value: AppThemeMode.light,
                    label: Text(l10n.lightMode),
                    icon: const Icon(Icons.light_mode_outlined),
                  ),
                  ButtonSegment(
                    value: AppThemeMode.dark,
                    label: Text(l10n.darkMode),
                    icon: const Icon(Icons.dark_mode_outlined),
                  ),
                ],
                selected: {settings.themeMode},
                showSelectedIcon: false,
                onSelectionChanged: (selection) =>
                    controller.setThemeMode(selection.first),
              ),
            ),
            SwitchListTile(
              value: settings.amoled,
              onChanged: controller.setAmoled,
              title: Text(l10n.amoledTitle),
              subtitle: Text(l10n.amoledHint),
              secondary: const Icon(Icons.contrast_outlined),
            ),

            const Divider(height: AppSpacing.x6),

            // ── Accent ─────────────────────────────────────────────────────
            _SectionLabel(label: l10n.accentColor),
            AccentPicker(
              selected: settings.accentSeed,
              onSelected: controller.setAccentSeed,
            ),
            const AccentEyedropperButton(),

            const Divider(height: AppSpacing.x6),

            // ── Wallpaper ──────────────────────────────────────────────────
            _SectionLabel(label: l10n.chatWallpaper),
            WallpaperGallery(
              spec: wallpaperSpec,
              selected: settings.wallpaper,
              onSelected: controller.setWallpaper,
            ),
            _SliderRow(
              label: l10n.wallpaperIntensity,
              value: settings.wallpaperIntensity,
              enabled: patternable,
              onChanged: controller.previewWallpaperIntensity,
              onChangeEnd: controller.commit,
            ),
            _SliderRow(
              label: l10n.wallpaperPattern,
              value: settings.wallpaperPattern,
              enabled: patternable,
              onChanged: controller.previewWallpaperPattern,
              onChangeEnd: controller.commit,
            ),

            const Divider(height: AppSpacing.x6),

            // ── Density and text ───────────────────────────────────────────
            _SectionLabel(label: l10n.appearanceDensity),
            _Hint(text: l10n.appearanceDensityHint),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x4),
              child: SegmentedButton<AppDensity>(
                segments: [
                  ButtonSegment(
                    value: AppDensity.compact,
                    label: Text(l10n.densityCompact),
                  ),
                  ButtonSegment(
                    value: AppDensity.cozy,
                    label: Text(l10n.densityCozy),
                  ),
                  ButtonSegment(
                    value: AppDensity.comfortable,
                    label: Text(l10n.densityComfortable),
                  ),
                ],
                selected: {settings.density},
                showSelectedIcon: false,
                onSelectionChanged: (selection) =>
                    controller.setDensity(selection.first),
              ),
            ),

            _SectionLabel(label: l10n.textSize),
            _Hint(text: l10n.textSizeHint),
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
                selected: {settings.textScale},
                showSelectedIcon: false,
                onSelectionChanged: (selection) =>
                    controller.setTextScale(selection.first),
              ),
            ),

            const Divider(height: AppSpacing.x6),

            // ── Bubbles ────────────────────────────────────────────────────
            _SectionLabel(label: l10n.bubbleShape),
            _SliderRow(
              label: l10n.bubbleCorners,
              value: settings.bubbleRadius,
              min: AppearanceSettings.minBubbleRadius,
              max: AppearanceSettings.maxBubbleRadius,
              divisions:
                  (AppearanceSettings.maxBubbleRadius -
                          AppearanceSettings.minBubbleRadius)
                      .round(),
              valueLabel: settings.bubbleRadius.round().toString(),
              onChanged: controller.previewBubbleRadius,
              onChangeEnd: controller.commit,
            ),
            SwitchListTile(
              value: settings.bubbleAnchored,
              onChanged: controller.setBubbleAnchored,
              title: Text(l10n.bubbleAnchor),
              subtitle: Text(l10n.bubbleAnchorHint),
              secondary: const Icon(Icons.chat_bubble_outline),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.x4,
                AppSpacing.x2,
                AppSpacing.x4,
                AppSpacing.x2,
              ),
              child: Text(l10n.bubbleFill, style: theme.textTheme.titleSmall),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x4),
              child: SegmentedButton<bool>(
                segments: [
                  ButtonSegment(
                    value: true,
                    icon: const Icon(Icons.gradient_rounded),
                    label: Text(l10n.bubbleFillGradient),
                  ),
                  ButtonSegment(
                    value: false,
                    icon: const Icon(Icons.square_rounded),
                    label: Text(l10n.bubbleFillSolid),
                  ),
                ],
                selected: {settings.bubbleGradient},
                showSelectedIcon: false,
                onSelectionChanged: (selection) =>
                    controller.setBubbleGradient(selection.first),
              ),
            ),

            const Divider(height: AppSpacing.x6),

            // ── Feel ───────────────────────────────────────────────────────
            _SectionLabel(label: l10n.appearanceFeel),
            SwitchListTile(
              value: settings.haptics,
              onChanged: controller.setHaptics,
              title: Text(l10n.appearanceHaptics),
              subtitle: Text(l10n.appearanceHapticsHint),
              secondary: const Icon(Icons.vibration_outlined),
            ),

            // ── Keyboard ───────────────────────────────────────────────────
            //
            // A physical keyboard's own question; a phone has no Enter to
            // send with. Here rather than on the settings list because it
            // is about how a conversation behaves, like the haptics above.
            if (DesktopInput.isDesktop) ...[
              const Divider(height: AppSpacing.x6),
              _SectionLabel(label: l10n.settingsKeyboardSection),
              const _SendShortcutTile(),
            ],

            const Divider(height: AppSpacing.x6),

            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.x4,
                AppSpacing.x2,
                AppSpacing.x4,
                AppSpacing.x4,
              ),
              child: OutlinedButton.icon(
                onPressed: controller.reset,
                icon: const Icon(Icons.restart_alt),
                label: Text(l10n.resetAppearance),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A labelled slider that shows its value, because a knob with no number on
/// it is a knob you cannot get back to where it was.
class _SliderRow extends StatelessWidget {
  const _SliderRow({
    required this.label,
    required this.value,
    required this.onChanged,
    required this.onChangeEnd,
    this.min = 0,
    this.max = 1,
    this.divisions = 20,
    this.valueLabel,
    this.enabled = true,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final String? valueLabel;
  final bool enabled;
  final ValueChanged<double> onChanged;
  final VoidCallback onChangeEnd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final shown =
        valueLabel ?? '${(((value - min) / (max - min)) * 100).round()}%';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x4),
      child: Row(
        children: [
          SizedBox(
            width: 92,
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: enabled
                    ? theme.colorScheme.onSurface
                    : theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Slider(
              value: value.clamp(min, max),
              min: min,
              max: max,
              divisions: divisions,
              label: shown,
              onChanged: enabled ? onChanged : null,
              onChangeEnd: enabled ? (_) => onChangeEnd() : null,
            ),
          ),
          SizedBox(
            width: 44,
            child: Text(
              shown,
              textAlign: TextAlign.end,
              style: theme.textTheme.labelMedium,
            ),
          ),
        ],
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.x4,
        AppSpacing.x1,
        AppSpacing.x4,
        AppSpacing.x1,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: AppSpacing.x2),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.x4,
        0,
        AppSpacing.x4,
        AppSpacing.x3,
      ),
      child: Text(
        text,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
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

/// Enter or Ctrl+Enter (Cmd+Enter on a Mac) to send.
///
/// Worded as the switch's "on": sending with the modifier is the choice
/// somebody makes on purpose, and the line under it says what each key
/// does now, so nobody has to remember which way round the default was.
class _SendShortcutTile extends ConsumerWidget {
  const _SendShortcutTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final modifier = DesktopInput.usesCommandKey
        ? l10n.keyboardCommandKey
        : l10n.keyboardControlKey;
    final withModifier =
        ref.watch(sendShortcutProvider) == SendShortcut.modifierEnter;

    return SwitchListTile(
      secondary: const Icon(Icons.keyboard_return_rounded),
      title: Text(l10n.settingsSendWithModifierEnter(modifier)),
      subtitle: Text(
        withModifier
            ? l10n.settingsSendWithModifierEnterOn(modifier)
            : l10n.settingsSendWithModifierEnterOff,
      ),
      value: withModifier,
      onChanged: (value) => ref
          .read(sendShortcutProvider.notifier)
          .set(value ? SendShortcut.modifierEnter : SendShortcut.enter),
    );
  }
}
