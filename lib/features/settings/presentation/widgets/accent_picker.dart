import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:chatix/core/providers/theme_providers.dart';
import 'package:chatix/core/theme/app_tokens.dart';
import 'package:chatix/core/ui/feedback/app_snackbar.dart';
import 'package:chatix/features/settings/presentation/providers/avatar_accent_provider.dart';
import 'package:chatix/gen/l10n/app_localizations.dart';

/// The accent swatches.
///
/// Lives in the settings feature rather than in `core/ui` because picking a
/// brand accent is a settings affordance, not a general primitive. A colour
/// the eyedropper produced is shown as a ninth swatch, so the reader can see
/// what they are on and get back to it after trying the curated ones.
class AccentPicker extends StatelessWidget {
  const AccentPicker({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  final Color selected;
  final ValueChanged<Color> onSelected;

  static const double swatchSize = 40;

  bool get _isCustom => !AppPalette.accentSeeds.contains(selected);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

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
            _Swatch(
              color: seed,
              isSelected: seed == selected,
              semanticLabel: null,
              onTap: () => onSelected(seed),
            ),
          if (_isCustom)
            _Swatch(
              color: selected,
              isSelected: true,
              semanticLabel: l10n.accentCustom,
              onTap: () => onSelected(selected),
            ),
        ],
      ),
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({
    required this.color,
    required this.isSelected,
    required this.onTap,
    required this.semanticLabel,
  });

  final Color color;
  final bool isSelected;
  final VoidCallback onTap;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Semantics(
      selected: isSelected,
      button: true,
      label: semanticLabel,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: AnimatedContainer(
          duration: AppMotion.fast,
          curve: AppMotion.curve,
          width: AccentPicker.swatchSize,
          height: AccentPicker.swatchSize,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(
              color: isSelected ? scheme.onSurface : color,
              width: 2,
            ),
          ),
          child: isSelected
              ? Icon(
                  Icons.check,
                  size: 20,
                  color: AppContrast.foregroundOn(color),
                )
              : null,
        ),
      ),
    );
  }
}

/// "Take the colour from my photo".
///
/// The one place the accent can leave the curated eight. It reports what
/// happened rather than failing quietly: a greyscale avatar and a missing
/// one are different answers, and the reader can act on both.
class AccentEyedropperButton extends ConsumerStatefulWidget {
  const AccentEyedropperButton({super.key});

  @override
  ConsumerState<AccentEyedropperButton> createState() =>
      _AccentEyedropperButtonState();
}

class _AccentEyedropperButtonState
    extends ConsumerState<AccentEyedropperButton> {
  bool _working = false;

  Future<void> _pick() async {
    if (_working) return;
    setState(() => _working = true);

    final result = await ref.read(avatarAccentPickerProvider)();

    if (!mounted) return;
    setState(() => _working = false);

    final l10n = AppLocalizations.of(context);
    final accent = result.accent;

    if (result.status == AvatarAccentStatus.found && accent != null) {
      await ref.read(appearanceProvider.notifier).setAccentSeed(accent);
      if (!mounted) return;
      AppSnackbar.quiet(context, l10n.accentFromAvatarApplied);
      return;
    }

    AppSnackbar.quiet(context, switch (result.status) {
      AvatarAccentStatus.noAvatar => l10n.accentFromAvatarMissing,
      AvatarAccentStatus.noColour => l10n.accentFromAvatarEmpty,
      _ => l10n.accentFromAvatarFailed,
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.x4,
        AppSpacing.x2,
        AppSpacing.x4,
        0,
      ),
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: OutlinedButton.icon(
          onPressed: _working ? null : _pick,
          icon: _working
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.colorize_outlined),
          label: Text(l10n.accentFromAvatar),
        ),
      ),
    );
  }
}
