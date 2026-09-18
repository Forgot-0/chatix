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
