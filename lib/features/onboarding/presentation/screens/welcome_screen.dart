import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:chatix/core/router/app_routes.dart';
import 'package:chatix/core/theme/app_tokens.dart';
import 'package:chatix/features/onboarding/presentation/providers/onboarding_providers.dart';
import 'package:chatix/features/onboarding/presentation/widgets/onboarding_page_view.dart';
import 'package:chatix/gen/l10n/app_localizations.dart';

/// The first thing a new install shows: a short welcome, then three pages
/// saying what ChatiX is for, with a way out of all of it at the top right.
///
/// One route rather than four so "Skip" means the same thing everywhere and
/// the back gesture walks the pages instead of the navigator. Every
/// animation here is implicit and every one of them collapses to nothing
/// under `MediaQuery.disableAnimations` — the screen has to be as readable
/// standing still as it is moving.
class WelcomeScreen extends ConsumerStatefulWidget {
  const WelcomeScreen({super.key});

  @override
  ConsumerState<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends ConsumerState<WelcomeScreen> {
  final PageController _pages = PageController();

  /// Flipped once, after the first frame, so the entrance animates from its
  /// starting values instead of being built already finished.
  bool _entered = false;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _entered = true);
    });
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  static const int _pageCount = 4;

  bool get _isLastPage => _index == _pageCount - 1;

  Future<void> _leave(String location) async {
    await ref.read(onboardingSeenProvider.notifier).markSeen();
    if (!mounted) return;
    context.go(location);
  }

  void _advance() {
    if (_isLastPage) {
      _leave(RegisterRoute.location);
      return;
    }

    final still = MediaQuery.disableAnimationsOf(context);
    if (still) {
      _pages.jumpToPage(_index + 1);
      return;
    }

    _pages.nextPage(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x2),
                child: TextButton(
                  onPressed: () => _leave(LoginRoute.location),
                  child: Text(l10n.onboardingSkip),
                ),
              ),
            ),
            Expanded(
              child: PageView(
                controller: _pages,
                onPageChanged: (index) => setState(() => _index = index),
                children: [
                  _WelcomeIntro(entered: _entered),
                  OnboardingPage(
                    icon: Icons.bolt_outlined,
                    title: l10n.onboardingRealtimeTitle,
                    body: l10n.onboardingRealtimeBody,
                  ),
                  OnboardingPage(
                    icon: Icons.groups_outlined,
                    title: l10n.onboardingTogetherTitle,
                    body: l10n.onboardingTogetherBody,
                  ),
                  OnboardingPage(
                    icon: Icons.lock_outline,
                    title: l10n.onboardingPrivacyTitle,
                    body: l10n.onboardingPrivacyBody,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.x6,
                AppSpacing.x4,
                AppSpacing.x6,
                AppSpacing.x6,
              ),
              child: Column(
                children: [
                  Semantics(
                    label: l10n.onboardingPageOf(_index + 1, _pageCount),
                    child: OnboardingDots(count: _pageCount, current: _index),
                  ),
                  const SizedBox(height: AppSpacing.x6),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _advance,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          vertical: AppSpacing.x4,
                        ),
                      ),
                      child: Text(
                        switch (_index) {
                          0 => l10n.welcomeGetStarted,
                          _ when _isLastPage => l10n.onboardingDone,
                          _ => l10n.onboardingNext,
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.x2),
                  TextButton(
                    onPressed: () => _leave(LoginRoute.location),
                    child: Text(
                      l10n.welcomeSignIn,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The animated half of the welcome: the mark grows in, the words follow.
class _WelcomeIntro extends StatelessWidget {
  const _WelcomeIntro({required this.entered});

  final bool entered;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final still = MediaQuery.disableAnimationsOf(context);

    Duration at(int milliseconds) =>
        still ? Duration.zero : Duration(milliseconds: milliseconds);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x6),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedScale(
            scale: entered ? 1 : 0.82,
            duration: at(520),
            curve: Curves.easeOutBack,
            child: AnimatedOpacity(
              opacity: entered ? 1 : 0,
              duration: at(320),
              child: const OnboardingGlyph(
                icon: Icons.chat_bubble_outline,
                size: 128,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.x8),
          _FadeUp(
            entered: entered,
            duration: at(380),
            delay: at(140),
            child: Text(
              l10n.welcomeHeadline,
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: scheme.onSurface,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.x3),
          _FadeUp(
            entered: entered,
            duration: at(380),
            delay: at(260),
            child: Text(
              l10n.welcomeTagline,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A line that slides up a few pixels as it fades in, staggered behind the
/// one above it.
class _FadeUp extends StatelessWidget {
  const _FadeUp({
    required this.entered,
    required this.duration,
    required this.delay,
    required this.child,
  });

  final bool entered;
  final Duration duration;
  final Duration delay;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    // `AnimatedFoo` has no delay of its own, so the stagger is spelled as a
    // longer animation whose curve holds its starting value for the first
    // stretch of it.
    final total = duration + delay;
    final curve = Interval(_fraction(delay, total), 1, curve: Curves.easeOutCubic);

    return AnimatedSlide(
      offset: entered ? Offset.zero : const Offset(0, 0.25),
      duration: total,
      curve: curve,
      child: AnimatedOpacity(
        opacity: entered ? 1 : 0,
        duration: total,
        curve: curve,
        child: child,
      ),
    );
  }

  static double _fraction(Duration part, Duration whole) {
    if (whole.inMicroseconds == 0) return 0;
    return (part.inMicroseconds / whole.inMicroseconds).clamp(0.0, 0.95);
  }
}
