import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:chatix/core/providers/theme_providers.dart';
import 'package:chatix/core/theme/app_theme_extension.dart';
import 'package:chatix/core/theme/app_tokens.dart';
import 'package:chatix/core/theme/theme_config.dart';
import 'package:chatix/features/chat/presentation/widgets/bubble_shape.dart';
import 'package:chatix/features/settings/presentation/screens/settings_screen.dart'
    show AccentPicker;
import 'package:chatix/gen/l10n/app_localizations.dart';

/// One screen that renders the whole ChatiX design system.
///
/// Every value on it is read from the live theme, so flipping the controls at
/// the top is a real check that a token change lands everywhere — and that
/// light and dark are equally finished.
class ComponentShowcaseScreen extends ConsumerWidget {
  const ComponentShowcaseScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final appearance = ref.watch(appearanceProvider);
    final controller = ref.read(appearanceProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.designSystem)),
      body: ListView(
        padding: const EdgeInsets.only(bottom: AppSpacing.x8),
        children: [
          _Controls(appearance: appearance, controller: controller),
          _Section(title: l10n.showcaseAccents, child: const _Accents()),
          _Section(title: l10n.showcaseNeutrals, child: const _Neutrals()),
          _Section(title: l10n.showcaseRadii, child: const _Radii()),
          _Section(title: l10n.showcaseSpacing, child: const _Spacing()),
          _Section(title: l10n.showcaseElevation, child: const _Elevation()),
          _Section(title: l10n.showcaseMotion, child: const _Motion()),
          _Section(title: l10n.showcaseTypography, child: const _Typography()),
          _Section(title: l10n.showcaseBubbles, child: const _Bubbles()),
          _Section(title: l10n.showcaseReactions, child: const _Reactions()),
          _Section(title: l10n.showcaseAuthors, child: const _Authors()),
          _Section(
            title: l10n.showcaseComponents,
            child: const _Components(),
          ),
        ],
      ),
    );
  }
}

class _Controls extends StatelessWidget {
  const _Controls({required this.appearance, required this.controller});

  final AppearanceSettings appearance;
  final AppearanceController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.x4,
        AppSpacing.x4,
        AppSpacing.x4,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: AppSpacing.x3,
        children: [
          SegmentedButton<AppThemeMode>(
            segments: [
              ButtonSegment(
                value: AppThemeMode.system,
                label: Text(l10n.systemMode),
              ),
              ButtonSegment(
                value: AppThemeMode.light,
                label: Text(l10n.lightMode),
              ),
              ButtonSegment(
                value: AppThemeMode.dark,
                label: Text(l10n.darkMode),
              ),
            ],
            selected: {appearance.themeMode},
            onSelectionChanged: (selection) =>
                controller.setThemeMode(selection.first),
          ),
          SegmentedButton<AppDensity>(
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
            selected: {appearance.density},
            onSelectionChanged: (selection) =>
                controller.setDensity(selection.first),
          ),
          AccentPicker(
            selected: appearance.accentSeed,
            onSelected: controller.setAccentSeed,
          ),
        ],
      ),
    );
  }
}

class _Accents extends StatelessWidget {
  const _Accents();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final chatix = ChatixTheme.of(context);

    return Wrap(
      spacing: AppSpacing.x2,
      runSpacing: AppSpacing.x2,
      children: [
        _Swatch(color: scheme.primary, label: 'primary'),
        _Swatch(color: scheme.secondary, label: 'secondary'),
        _Swatch(color: scheme.tertiary, label: 'tertiary'),
        _Swatch(color: scheme.error, label: 'error'),
        _Swatch(color: chatix.success, label: 'success'),
        _Swatch(color: chatix.danger, label: 'danger'),
        _Swatch(color: chatix.attention, label: 'attention'),
        _Swatch(color: chatix.onlineDot, label: 'online'),
      ],
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      width: 96,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 48,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(AppRadii.md),
              border: Border.all(color: theme.colorScheme.outlineVariant),
            ),
          ),
          const SizedBox(height: AppSpacing.x1),
          Text(label, style: theme.textTheme.labelSmall),
          Text(
            _hex(color),
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  static String _hex(Color color) =>
      '#${(color.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';
}

class _Neutrals extends StatelessWidget {
  const _Neutrals();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _RampLabel(label: l10n.showcaseNeutralsLight),
        const _Ramp(colors: AppNeutrals.light),
        const SizedBox(height: AppSpacing.x3),
        _RampLabel(label: l10n.showcaseNeutralsDark),
        const _Ramp(colors: AppNeutrals.dark),
      ],
    );
  }
}

class _RampLabel extends StatelessWidget {
  const _RampLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.x1),
      child: Text(label, style: Theme.of(context).textTheme.labelSmall),
    );
  }
}

class _Ramp extends StatelessWidget {
  const _Ramp({required this.colors});

  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      // The pale end of the light ramp is nearly the page colour; the outline
      // is what keeps the first step from disappearing into it.
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadii.sm),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final color in colors) Expanded(child: ColoredBox(color: color)),
        ],
      ),
    );
  }
}

class _Radii extends StatelessWidget {
  const _Radii();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Wrap(
      spacing: AppSpacing.x3,
      runSpacing: AppSpacing.x3,
      children: [
        for (final radius in AppRadii.scale)
          Column(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(radius),
                  border: Border.all(color: theme.colorScheme.outlineVariant),
                ),
              ),
              const SizedBox(height: AppSpacing.x1),
              Text(
                radius == AppRadii.full ? 'full' : radius.toInt().toString(),
                style: theme.textTheme.labelSmall,
              ),
            ],
          ),
      ],
    );
  }
}

class _Spacing extends StatelessWidget {
  const _Spacing();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final space in AppSpacing.scale)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.x1),
            child: Row(
              children: [
                SizedBox(
                  width: 36,
                  child: Text(
                    space.toInt().toString(),
                    style: theme.textTheme.labelSmall,
                  ),
                ),
                Container(
                  width: space * 4,
                  height: 12,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(AppRadii.xs),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _Elevation extends StatelessWidget {
  const _Elevation();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brightness = theme.brightness;

    return Wrap(
      spacing: AppSpacing.x4,
      runSpacing: AppSpacing.x4,
      children: [
        for (var level = 1; level <= AppElevations.levels; level++)
          Container(
            width: 72,
            height: 72,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppElevations.surfaceOf(
                brightness,
                theme.colorScheme.surfaceContainer,
                level,
              ),
              borderRadius: BorderRadius.circular(AppRadii.md),
              boxShadow: AppElevations.shadows(brightness, level),
            ),
            child: Text('$level', style: theme.textTheme.labelMedium),
          ),
      ],
    );
  }
}

class _Motion extends StatefulWidget {
  const _Motion();

  @override
  State<_Motion> createState() => _MotionState();
}

class _MotionState extends State<_Motion> {
  bool _shifted = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    final steps = <(String, Duration)>[
      (l10n.showcaseMotionFast, AppMotion.fast),
      (l10n.showcaseMotionBase, AppMotion.base),
      (l10n.showcaseMotionSlow, AppMotion.slow),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (label, duration) in steps)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.x2),
            child: Row(
              children: [
                SizedBox(
                  width: 96,
                  child: Text(
                    '$label · ${duration.inMilliseconds} ms',
                    style: theme.textTheme.labelSmall,
                  ),
                ),
                Expanded(
                  child: Align(
                    alignment: _shifted
                        ? Alignment.centerRight
                        : Alignment.centerLeft,
                    child: AnimatedContainer(
                      duration: duration,
                      curve: AppMotion.curve,
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary,
                        borderRadius: BorderRadius.circular(AppRadii.sm),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => setState(() => _shifted = !_shifted),
            icon: const Icon(Icons.play_arrow),
            label: Text(l10n.showcaseMotionReplay),
          ),
        ),
      ],
    );
  }
}

class _Typography extends StatelessWidget {
  const _Typography();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = theme.textTheme;
    final l10n = AppLocalizations.of(context);

    final samples = <(String, TextStyle?)>[
      ('headlineSmall', text.headlineSmall),
      ('titleMedium', text.titleMedium),
      ('bodyLarge', text.bodyLarge),
      ('bodyMedium', text.bodyMedium),
      ('labelMedium', text.labelMedium),
      ('labelSmall', text.labelSmall),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (name, style) in samples)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.x2),
            child: Text('$name — ${AppTypography.fontFamily}', style: style),
          ),
        const Divider(height: AppSpacing.x6),
        Text(l10n.showcaseTabularFigures, style: text.labelSmall),
        const SizedBox(height: AppSpacing.x1),
        // Both rows are the same width only because the digits are tabular.
        Text('00:00  11:11  99+', style: text.labelMedium),
        Text('18:45  23:59  12+', style: text.labelMedium),
      ],
    );
  }
}

class _Bubbles extends StatelessWidget {
  const _Bubbles();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final chatix = ChatixTheme.of(context);
    final l10n = AppLocalizations.of(context);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.x3),
      decoration: BoxDecoration(
        color: chatix.chatBackground,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.x3,
                vertical: AppSpacing.x1 + 1,
              ),
              decoration: BoxDecoration(
                color: chatix.dateChip,
                borderRadius: BorderRadius.circular(AppRadii.md),
              ),
              child: Text(
                l10n.dateToday,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          SizedBox(height: chatix.density.groupGap),
          _Bubble(isMine: false, text: l10n.showcaseIncomingSample),
          SizedBox(height: chatix.density.stackGap),
          _Bubble(isMine: false, text: l10n.showcaseStackedSample),
          SizedBox(height: chatix.density.groupGap),
          _Bubble(isMine: true, text: l10n.showcaseOutgoingSample),
          SizedBox(height: chatix.density.groupGap),
          Row(
            children: [
              Expanded(child: Divider(color: chatix.unreadDivider)),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.x2,
                ),
                child: Text(
                  l10n.unreadMessages,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Expanded(child: Divider(color: chatix.unreadDivider)),
            ],
          ),
          SizedBox(height: chatix.density.groupGap),
          DecoratedBox(
            decoration: BoxDecoration(
              color: chatix.composerSurface,
              borderRadius: BorderRadius.circular(AppRadii.md),
              border: Border.all(color: theme.colorScheme.outlineVariant),
            ),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.x2),
              child: Row(
                children: [
                  const Icon(Icons.attach_file, size: 20),
                  const SizedBox(width: AppSpacing.x2),
                  Expanded(
                    child: Text(
                      l10n.messageHint,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  Icon(Icons.send, size: 20, color: theme.colorScheme.primary),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.isMine, required this.text});

  final bool isMine;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final chatix = ChatixTheme.of(context);
    final density = chatix.density;

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 280),
        padding: EdgeInsets.symmetric(
          horizontal: density.bubblePaddingX,
          vertical: density.bubblePaddingY,
        ),
        decoration: ShapeDecoration(
          gradient: isMine ? chatix.bubbleOutgoingGradient : null,
          color: isMine ? null : chatix.bubbleIncoming,
          shape: BubbleShape.of(
            context,
            isOutgoing: isMine,
            side: isMine
                ? BorderSide.none
                : BorderSide(color: chatix.bubbleIncomingBorder),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              text,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: isMine
                    ? chatix.bubbleOutgoingForeground
                    : chatix.bubbleIncomingForeground,
              ),
            ),
            Text(
              '12:45',
              style: theme.textTheme.labelSmall?.copyWith(
                color:
                    (isMine
                            ? chatix.bubbleOutgoingForeground
                            : chatix.bubbleIncomingForeground)
                        .withValues(alpha: 0.66),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Reactions extends StatelessWidget {
  const _Reactions();

  @override
  Widget build(BuildContext context) {
    return const Wrap(
      spacing: AppSpacing.x2,
      runSpacing: AppSpacing.x2,
      children: [
        _ReactionChip(emoji: '👍', count: 3, selected: true),
        _ReactionChip(emoji: '🔥', count: 12, selected: false),
        _ReactionChip(emoji: '🎉', count: 1, selected: false),
      ],
    );
  }
}

class _ReactionChip extends StatelessWidget {
  const _ReactionChip({
    required this.emoji,
    required this.count,
    required this.selected,
  });

  final String emoji;
  final int count;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final chatix = ChatixTheme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.x2,
        vertical: AppSpacing.x1 / 2,
      ),
      decoration: BoxDecoration(
        color: selected ? chatix.reactionChipSelected : chatix.reactionChip,
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(
          color: selected ? theme.colorScheme.primary : Colors.transparent,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: theme.textTheme.bodySmall),
          const SizedBox(width: AppSpacing.x1),
          Text(
            '$count',
            style: theme.textTheme.labelSmall?.copyWith(
              color: selected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.outline,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _Authors extends StatelessWidget {
  const _Authors();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final chatix = ChatixTheme.of(context);

    return Wrap(
      spacing: AppSpacing.x3,
      runSpacing: AppSpacing.x2,
      children: [
        for (var index = 0; index < chatix.authorPalette.length; index++)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: chatix.authorColor(index),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: AppSpacing.x1),
              Text(
                'author $index',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: chatix.authorColor(index),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
      ],
    );
  }
}

class _Components extends StatelessWidget {
  const _Components();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: AppSpacing.x3,
      children: [
        Wrap(
          spacing: AppSpacing.x2,
          runSpacing: AppSpacing.x2,
          children: [
            FilledButton(onPressed: () {}, child: Text(l10n.save)),
            OutlinedButton(onPressed: () {}, child: Text(l10n.cancel)),
            TextButton(onPressed: () {}, child: Text(l10n.retry)),
            IconButton.filled(
              onPressed: () {},
              icon: const Icon(Icons.send),
            ),
          ],
        ),
        TextField(
          decoration: InputDecoration(
            labelText: l10n.searchByName,
            prefixIcon: const Icon(Icons.search),
          ),
        ),
        Card(
          child: ListTile(
            leading: const CircleAvatar(child: Icon(Icons.person)),
            title: Text(l10n.profile),
            subtitle: Text(l10n.settings),
            trailing: const Icon(Icons.chevron_right),
          ),
        ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.x4,
        AppSpacing.x6,
        AppSpacing.x4,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.x3),
          child,
        ],
      ),
    );
  }
}
