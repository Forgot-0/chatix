import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:chatix/core/router/app_layout.dart';
import 'package:chatix/core/router/app_routes.dart';
import 'package:chatix/core/theme/app_theme_extension.dart';
import 'package:chatix/core/theme/app_tokens.dart';
import 'package:chatix/core/ui/brand/chatix_logo.dart';
import 'package:chatix/core/ui/illustrations/app_illustrations.dart';
import 'package:chatix/core/ui/wallpaper/mesh_wallpaper.dart';
import 'package:chatix/core/ui/widgets/app_content_width.dart';
import 'package:chatix/features/onboarding/presentation/providers/onboarding_providers.dart';
import 'package:chatix/features/onboarding/presentation/widgets/onboarding_page_view.dart';
import 'package:chatix/gen/l10n/app_localizations.dart';

/// The first thing a new install shows: what ChatiX is for, and the way in.
///
/// Two shapes, picked by the room the screen is given (measured here, not
/// read off the window):
///
///  * a phone or a tablet gets the tour — three slides, page dots, "Skip" in
///    the corner, "Next" and then "Get started" under them;
///  * a desktop window has room for all of it at once, so it gets one page:
///    the picture on the left, the three reasons and the buttons on the
///    right. Nothing to page through, so nothing to skip.
///
/// One route either way, so "Skip" means the same thing everywhere. Every
/// animation here is implicit and collapses to nothing under
/// `MediaQuery.disableAnimations` — the screen has to be as readable
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

  static final int _pageCount = OnboardingReason.values.length;

  bool get _isLastPage => _index == _pageCount - 1;

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

  /// Seen once is seen for good, whichever way out was taken: the splash
  /// redirect reads this flag.
  Future<void> _leave(String location) async {
    await ref.read(onboardingSeenProvider.notifier).markSeen();
    if (!mounted) return;
    context.go(location);
  }

  void _startUsing() => _leave(RegisterRoute.location);

  void _signIn() => _leave(LoginRoute.location);

  void _advance() {
    if (_isLastPage) {
      _startUsing();
      return;
    }

    if (MediaQuery.disableAnimationsOf(context)) {
      _pages.jumpToPage(_index + 1);
      return;
    }
    _pages.nextPage(duration: AppMotion.slow, curve: AppMotion.curve);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth >= AppBreakpoints.expanded) {
            return _WelcomePage(
              entered: _entered,
              onStart: _startUsing,
              onSignIn: _signIn,
            );
          }
          return _tour(context);
        },
      ),
    );
  }

  Widget _tour(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.x5,
              AppSpacing.x2,
              AppSpacing.x2,
              0,
            ),
            child: Row(
              children: [
                const ChatixLogo(size: OnboardingLayout.markSize),
                const Spacer(),
                // Held in place on the last slide, where there is nothing
                // left to skip, so the row does not jump.
                Visibility(
                  visible: !_isLastPage,
                  maintainSize: true,
                  maintainAnimation: true,
                  maintainState: true,
                  child: TextButton(
                    onPressed: _signIn,
                    child: Text(l10n.onboardingSkip),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: PageView(
              controller: _pages,
              onPageChanged: (index) => setState(() => _index = index),
              children: [
                for (final reason in OnboardingReason.values)
                  OnboardingSlide(
                    reason: reason,
                    // Only the first slide makes an entrance: the others
                    // are reached by paging, which is motion enough.
                    entered: _entered || reason.index > 0,
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
            child: AppContentWidth(
              // The same column as the sign-in form it leads to: a button
              // the width of a tablet is not a button.
              maxWidth: AppContentWidths.auth,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Semantics(
                    label: l10n.onboardingPageOf(_index + 1, _pageCount),
                    child: OnboardingDots(count: _pageCount, current: _index),
                  ),
                  const SizedBox(height: AppSpacing.x6),
                  FilledButton(
                    onPressed: _advance,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.x4,
                      ),
                    ),
                    child: Text(
                      _isLastPage
                          ? l10n.welcomeGetStarted
                          : l10n.onboardingNext,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.x2),
                  Center(
                    child: TextButton(
                      onPressed: _signIn,
                      child: Text(l10n.welcomeSignIn),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The desktop's single page: the picture on the reader's own wallpaper to
/// the left, the welcome, the three reasons and the way in to the right.
class _WelcomePage extends StatelessWidget {
  const _WelcomePage({
    required this.entered,
    required this.onStart,
    required this.onSignIn,
  });

  final bool entered;
  final VoidCallback onStart;
  final VoidCallback onSignIn;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final still = MediaQuery.disableAnimationsOf(context);

    // The entrance is staggered, not choreographed to the millisecond: each
    // step is one of the motion tokens, and the delays are tokens too.
    Duration at(Duration duration) => still ? Duration.zero : duration;

    Widget fadeUp(Duration delay, Widget child) => _FadeUp(
      entered: entered,
      duration: at(AppMotion.slow),
      delay: at(delay),
      child: child,
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: MeshWallpaperView(
            spec: wallpaperSpecOf(context),
            ground: ChatixTheme.of(context).chatBackground,
            child: Center(
              child: OnboardingPicture(
                kind: AppIllustrationKind.conversations,
                entered: entered,
                plateSize: OnboardingLayout.widePlateSize,
                size: OnboardingLayout.wideIllustrationSize,
                plate: scheme.surface,
              ),
            ),
          ),
        ),
        Expanded(
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.x8),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: OnboardingLayout.textMaxWidth,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: ChatixLogo(size: OnboardingLayout.wideMarkSize),
                      ),
                      const SizedBox(height: AppSpacing.x6),
                      fadeUp(
                        AppMotion.fast,
                        Semantics(
                          header: true,
                          child: Text(
                            l10n.welcomeHeadline,
                            style: theme.textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: scheme.onSurface,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.x2),
                      fadeUp(
                        AppMotion.base,
                        Text(
                          l10n.welcomeTagline,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.x8),
                      for (final reason in OnboardingReason.values) ...[
                        fadeUp(
                          AppMotion.slow,
                          OnboardingReasonRow(reason: reason),
                        ),
                        const SizedBox(height: AppSpacing.x5),
                      ],
                      const SizedBox(height: AppSpacing.x3),
                      FilledButton(
                        onPressed: onStart,
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            vertical: AppSpacing.x4,
                          ),
                        ),
                        child: Text(l10n.welcomeGetStarted),
                      ),
                      const SizedBox(height: AppSpacing.x2),
                      Center(
                        child: TextButton(
                          onPressed: onSignIn,
                          child: Text(l10n.welcomeSignIn),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
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
    final curve = Interval(_fraction(delay, total), 1, curve: AppMotion.curve);

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
