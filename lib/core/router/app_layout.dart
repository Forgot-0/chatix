import 'package:flutter/widgets.dart';

/// How much room the window gives the shell, in Material's window-size classes.
///
/// The shell measures once, at the top, and publishes the answer through
/// [AppLayoutScope]; panes further down read it rather than measuring again, so
/// a pane that is 400px wide inside a 1200px window still knows it is part of a
/// two-pane layout.
enum AppLayoutMode {
  /// Phones, and anything narrow. Bottom navigation bar, one pane.
  compact,

  /// Tablets in portrait, small windows. Navigation rail, still one pane.
  medium,

  /// Tablets in landscape and desktop. Navigation rail, list + chat together.
  expanded;

  bool get usesBottomBar => this == AppLayoutMode.compact;

  bool get usesRail => this != AppLayoutMode.compact;

  /// Whether the chat list and the open chat are shown side by side.
  bool get isTwoPane => this == AppLayoutMode.expanded;
}

abstract final class AppBreakpoints {
  /// Below this the bottom bar wins: a rail eats too much of a phone.
  static const double medium = 600;

  /// At and above this there is room for a 360px list next to a usable chat.
  static const double expanded = 900;

  /// Width of the chat list when it shares the window with an open chat.
  static const double listPaneWidth = 360;

  static AppLayoutMode modeFor(double width) {
    if (width >= expanded) return AppLayoutMode.expanded;
    if (width >= medium) return AppLayoutMode.medium;
    return AppLayoutMode.compact;
  }
}

/// Publishes the shell's measured [AppLayoutMode] to everything below it.
class AppLayoutScope extends InheritedWidget {
  const AppLayoutScope({super.key, required this.mode, required super.child});

  final AppLayoutMode mode;

  /// Defaults to [AppLayoutMode.compact] outside the shell — a screen pushed
  /// on the root navigator, or pumped bare in a test, is a single pane.
  static AppLayoutMode of(BuildContext context) =>
      maybeOf(context) ?? AppLayoutMode.compact;

  static AppLayoutMode? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<AppLayoutScope>()
      ?.mode;

  @override
  bool updateShouldNotify(AppLayoutScope oldWidget) => mode != oldWidget.mode;
}
