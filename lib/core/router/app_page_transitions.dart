import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:chatix/core/theme/app_tokens.dart';
import 'package:chatix/core/ui/motion/motion.dart';

/// The routes' half of the motion system: which of [AppTransitions] a page
/// arrives with, and how long it is given.
///
/// The transitions themselves live in `core/ui/motion` — they are not a
/// routing concern, and the same three patterns are used inside screens as
/// well. What is decided here is the mapping from *kind of navigation* to
/// pattern:
///
/// * **shared axis** for a push that moves forward in a hierarchy;
/// * **fade through** for a swap between destinations with no spatial
///   relationship — the tab bar's branches;
/// * **transparent fade** for a surface that covers without replacing, so
///   the route below keeps painting and a Hero has something to fly from.
abstract final class AppPageTransitions {
  static const Duration duration = AppMotion.slow;

  /// Forward navigation inside a section: chat list → chat → members.
  static CustomTransitionPage<T> sharedAxisHorizontal<T>({
    required LocalKey key,
    required Widget child,
    String? name,
  }) {
    return CustomTransitionPage<T>(
      key: key,
      name: name,
      child: child,
      transitionDuration: duration,
      reverseTransitionDuration: duration,
      transitionsBuilder: buildSharedAxisHorizontal,
    );
  }

  /// A lateral swap: same level of the hierarchy, no direction implied.
  static CustomTransitionPage<T> fadeThrough<T>({
    required LocalKey key,
    required Widget child,
    String? name,
  }) {
    return CustomTransitionPage<T>(
      key: key,
      name: name,
      child: child,
      transitionDuration: AppMotion.base,
      reverseTransitionDuration: AppMotion.base,
      transitionsBuilder: buildFadeThrough,
    );
  }

  /// A page that fades in over the one below without covering it.
  ///
  /// For surfaces that are meant to read as an overlay — the media viewer,
  /// which dims the conversation rather than replacing it, and lets the
  /// reader drag it back down. Not opaque, so the route underneath keeps
  /// being painted and a Hero has something to fly from.
  static CustomTransitionPage<T> transparentFade<T>({
    required LocalKey key,
    required Widget child,
    String? name,
  }) {
    return CustomTransitionPage<T>(
      key: key,
      name: name,
      child: child,
      opaque: false,
      barrierColor: null,
      transitionDuration: AppMotion.base,
      reverseTransitionDuration: AppMotion.base,
      transitionsBuilder: (context, animation, secondary, child) =>
          FadeTransition(opacity: animation, child: child),
    );
  }

  /// A section picked from a list that may still be on screen beside it —
  /// a settings section in a two-pane window.
  ///
  /// With [besideList] the list is the way back, so the section's app bar
  /// gets no back arrow even though the pane's own stack has a page under
  /// it, and changing sections fades through instead of sliding: one is
  /// swapped for the next, not entered from it. Without it — one pane —
  /// this is [sharedAxisHorizontal]. The pane reads the layout when it
  /// builds its pages, so a window dragged across the breakpoint gets the
  /// arrow back without anybody navigating.
  static Page<T> section<T>({
    required LocalKey key,
    required Widget child,
    required bool besideList,
    String? name,
  }) {
    return _SectionPage<T>(
      key: key,
      name: name,
      besideList: besideList,
      transitionDuration: besideList ? AppMotion.base : duration,
      reverseTransitionDuration: besideList ? AppMotion.base : duration,
      transitionsBuilder: besideList
          ? buildFadeThrough
          : buildSharedAxisHorizontal,
      child: child,
    );
  }

  /// Exposed separately so a `Navigator` outside go_router — a dialog route,
  /// a test harness — can reuse the same motion.
  static Widget buildSharedAxisHorizontal(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) =>
      AppTransitions.sharedAxisX(context, animation, secondaryAnimation, child);

  static Widget buildFadeThrough(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) =>
      AppTransitions.fadeThrough(context, animation, secondaryAnimation, child);
}

class _SectionPage<T> extends CustomTransitionPage<T> {
  const _SectionPage({
    required super.key,
    required super.name,
    required this.besideList,
    required super.transitionDuration,
    required super.reverseTransitionDuration,
    required super.transitionsBuilder,
    required super.child,
  });

  final bool besideList;

  @override
  Route<T> createRoute(BuildContext context) => _SectionRoute<T>(this);
}

/// go_router's own route for a [CustomTransitionPage], with one change:
/// beside a list, the app bar is not told it can go back.
///
/// The page is read through [settings] on every call, so a page rebuilt
/// for a new layout changes the answer for the route that is already up —
/// the navigator hands it the new page and the app bar rebuilds.
class _SectionRoute<T> extends PageRoute<T> {
  _SectionRoute(_SectionPage<T> page) : super(settings: page);

  _SectionPage<T> get _page => settings as _SectionPage<T>;

  @override
  bool get impliesAppBarDismissal =>
      !_page.besideList && super.impliesAppBarDismissal;

  @override
  bool get barrierDismissible => _page.barrierDismissible;

  @override
  Color? get barrierColor => _page.barrierColor;

  @override
  String? get barrierLabel => _page.barrierLabel;

  @override
  Duration get transitionDuration => _page.transitionDuration;

  @override
  Duration get reverseTransitionDuration => _page.reverseTransitionDuration;

  @override
  bool get maintainState => _page.maintainState;

  @override
  bool get fullscreenDialog => _page.fullscreenDialog;

  @override
  bool get opaque => _page.opaque;

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) => Semantics(
    scopesRoute: true,
    explicitChildNodes: true,
    child: _page.child,
  );

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => _page.transitionsBuilder(context, animation, secondaryAnimation, child);
}
