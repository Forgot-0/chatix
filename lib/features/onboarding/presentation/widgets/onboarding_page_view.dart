import 'package:flutter/material.dart';

import 'package:chatix/core/router/app_layout.dart';
import 'package:chatix/core/theme/app_tokens.dart';
import 'package:chatix/core/ui/illustrations/app_illustrations.dart';
import 'package:chatix/gen/l10n/app_localizations.dart';

/// The three things the tour says ChatiX is for, in the order it says them.
///
/// One list for both shapes of the tour: three slides on a phone, three rows
/// beside the picture on a desktop.
enum OnboardingReason {
  realtime(AppIllustrationKind.messages),
  together(AppIllustrationKind.people),
  privacy(AppIllustrationKind.locked);

  const OnboardingReason(this.illustration);

  /// Drawn from the app's own empty-state set, so the tour and the empty
  /// screens it leads to share one hand.
  final AppIllustrationKind illustration;

  String titleIn(AppLocalizations l10n) => switch (this) {
    OnboardingReason.realtime => l10n.onboardingRealtimeTitle,
    OnboardingReason.together => l10n.onboardingTogetherTitle,
    OnboardingReason.privacy => l10n.onboardingPrivacyTitle,
  };

  String bodyIn(AppLocalizations l10n) => switch (this) {
    OnboardingReason.realtime => l10n.onboardingRealtimeBody,
    OnboardingReason.together => l10n.onboardingTogetherBody,
    OnboardingReason.privacy => l10n.onboardingPrivacyBody,
  };
}

/// One slide: the picture on its disc, a title, a paragraph.
///
/// Scrolls rather than overflows when a phone on its side leaves it less
/// height than it wants, and centres itself when there is more.
class OnboardingSlide extends StatelessWidget {
  const OnboardingSlide({required this.reason, this.entered = true, super.key});

  final OnboardingReason reason;

  /// False for the first frame of the tour, so the picture grows in.
  final bool entered;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        // A tablet held upright has a phone's tour and far more room for
        // the picture.
        final roomy =
            constraints.maxWidth >= AppBreakpoints.medium &&
            constraints.maxHeight >= OnboardingLayout.widePictureFromHeight;

        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x6),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: OnboardingLayout.textMaxWidth,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    OnboardingPicture(
                      kind: reason.illustration,
                      entered: entered,
                      plateSize: roomy
                          ? OnboardingLayout.widePlateSize
                          : OnboardingLayout.plateSize,
                      size: roomy
                          ? OnboardingLayout.wideIllustrationSize
                          : OnboardingLayout.illustrationSize,
                    ),
                    const SizedBox(height: AppSpacing.x8),
                    Semantics(
                      header: true,
                      child: Text(
                        reason.titleIn(l10n),
                        textAlign: TextAlign.center,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: scheme.onSurface,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.x3),
                    Text(
                      reason.bodyIn(l10n),
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: scheme.onSurfaceVariant,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// An illustration on the round plate it stands on, growing in as the tour
/// opens — and standing still under `MediaQuery.disableAnimations`.
///
/// The plate is a theme surface rather than a fixed tint, so it is as
/// finished on the dark theme as on the light one; [plate] picks the
/// surface, since on the desktop the plate stands on a wallpaper rather
/// than on the page.
class OnboardingPicture extends StatelessWidget {
  const OnboardingPicture({
    required this.kind,
    this.entered = true,
    this.plateSize = OnboardingLayout.plateSize,
    this.size = OnboardingLayout.illustrationSize,
    this.plate,
    super.key,
  });

  final AppIllustrationKind kind;
  final bool entered;
  final double plateSize;
  final double size;
  final Color? plate;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final still = MediaQuery.disableAnimationsOf(context);

    return AnimatedScale(
      scale: entered ? 1 : OnboardingLayout.entranceScale,
      duration: still ? Duration.zero : AppMotion.expressive,
      curve: AppMotion.arrive,
      child: AnimatedOpacity(
        opacity: entered ? 1 : 0,
        duration: still ? Duration.zero : AppMotion.slow,
        child: Container(
          width: plateSize,
          height: plateSize,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: plate ?? scheme.surfaceContainer,
          ),
          child: AppIllustration(kind: kind, size: size),
        ),
      ),
    );
  }
}

/// A reason as one row of the desktop page: a small picture, then the words.
class OnboardingReasonRow extends StatelessWidget {
  const OnboardingReasonRow({required this.reason, super.key});

  final OnboardingReason reason;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        OnboardingPicture(
          kind: reason.illustration,
          plateSize: OnboardingLayout.reasonPlateSize,
          size: OnboardingLayout.reasonIllustrationSize,
        ),
        const SizedBox(width: AppSpacing.x4),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                reason.titleIn(l10n),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: scheme.onSurface,
                ),
              ),
              const SizedBox(height: AppSpacing.x1),
              Text(
                reason.bodyIn(l10n),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// The row of dots under the slides.
class OnboardingDots extends StatelessWidget {
  const OnboardingDots({required this.count, required this.current, super.key});

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
            duration: still ? Duration.zero : AppMotion.base,
            curve: AppMotion.curve,
            margin: const EdgeInsets.symmetric(horizontal: AppSpacing.x1),
            height: OnboardingLayout.dotSize,
            width: index == current
                ? OnboardingLayout.dotActiveWidth
                : OnboardingLayout.dotSize,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadii.full),
              color: index == current ? scheme.primary : scheme.outlineVariant,
            ),
          ),
      ],
    );
  }
}
