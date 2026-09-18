import 'package:flutter/material.dart';

import 'package:chatix/core/theme/app_tokens.dart';

/// One of the "why ChatiX" pages: a glyph, a title, a paragraph.
class OnboardingPage extends StatelessWidget {
  const OnboardingPage({
    required this.icon,
    required this.title,
    required this.body,
    super.key,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x6),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          OnboardingGlyph(icon: icon),
          const SizedBox(height: AppSpacing.x8),
          Text(
            title,
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: AppSpacing.x4),
          Text(
            body,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: scheme.onSurfaceVariant,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

/// The round, tinted plate every onboarding page and the welcome mark sit in.
///
/// Built from `colorScheme` rather than from a fixed colour so the plate is
/// as finished in the dark theme as in the light one — a translucent primary
/// over the surface, which both themes already know how to render.
class OnboardingGlyph extends StatelessWidget {
  const OnboardingGlyph({required this.icon, this.size = 112, super.key});

  final IconData icon;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: scheme.primaryContainer,
        border: Border.all(color: scheme.outlineVariant),
      ),
      alignment: Alignment.center,
      child: Icon(icon, size: size * 0.44, color: scheme.onPrimaryContainer),
    );
  }
}

/// The row of dots under the pages.
class OnboardingDots extends StatelessWidget {
  const OnboardingDots({
    required this.count,
    required this.current,
    super.key,
  });

  final int count;
  final int current;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final still = MediaQuery.disableAnimationsOf(context);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var index = 0; index < count; index++)
          AnimatedContainer(
            duration: still ? Duration.zero : const Duration(milliseconds: 240),
            curve: Curves.easeOut,
            margin: const EdgeInsets.symmetric(horizontal: AppSpacing.x1),
            height: 6,
            width: index == current ? 22 : 6,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadii.full),
              color: index == current
                  ? scheme.primary
                  : scheme.outlineVariant,
            ),
          ),
      ],
    );
  }
}
