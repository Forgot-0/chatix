import 'package:flutter/material.dart';

import 'package:chatix/core/router/app_layout.dart';
import 'package:chatix/core/theme/app_tokens.dart';

/// The windows a screen is checked in, and what the shell puts beside it.
///
/// A screen inside the shell is never as wide as the window: on a tablet the
/// rail and its divider take 81 px, on a desktop the chat list takes another
/// 360. Goldens that drew the screen at window width hid exactly the bug
/// where a header measured the window instead of the pane it lives in.
enum PaneWindow {
  /// One pane, the whole window.
  phone(Size(390, 844)),

  /// Rail beside the screen: a 719 px pane.
  tablet(Size(800, 1024)),

  /// Rail, chat list and the screen: a 999 px pane.
  desktop(Size(1440, 900));

  const PaneWindow(this.size);

  final Size size;

  static const double rail = 80;
  static const double divider = 1;

  bool get hasRail => this != PaneWindow.phone;
  bool get hasList => this == PaneWindow.desktop;

  AppLayoutMode get mode => AppBreakpoints.modeFor(size.width);

  /// How wide the screen itself ends up.
  double get paneWidth =>
      size.width -
      (hasRail ? rail + divider : 0) -
      (hasList ? AppBreakpoints.listPaneWidth : 0);
}

/// Draws [child] where the shell would put it in [window]: after a rail, and
/// after a chat list as well on a desktop. The rail and the list are plain
/// shapes — only their widths matter here.
class PaneFrame extends StatelessWidget {
  const PaneFrame({super.key, required this.window, required this.child});

  final PaneWindow window;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final pane = AppLayoutScope(mode: window.mode, child: child);
    if (!window.hasRail) return pane;

    final scheme = Theme.of(context).colorScheme;

    return ColoredBox(
      color: scheme.surface,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: PaneWindow.rail,
            child: ColoredBox(
              color: scheme.surfaceContainer,
              child: Column(
                children: [
                  const SizedBox(height: AppSpacing.x4),
                  for (var i = 0; i < 4; i++)
                    Container(
                      width: 40,
                      height: 40,
                      margin: const EdgeInsets.symmetric(
                        vertical: AppSpacing.x2,
                      ),
                      decoration: BoxDecoration(
                        color: i == 0
                            ? scheme.secondaryContainer
                            : scheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(AppRadii.md),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const VerticalDivider(
            width: PaneWindow.divider,
            thickness: PaneWindow.divider,
          ),
          if (window.hasList) const _ListStub(),
          Expanded(child: pane),
        ],
      ),
    );
  }
}

class _ListStub extends StatelessWidget {
  const _ListStub();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      width: AppBreakpoints.listPaneWidth,
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(right: BorderSide(color: scheme.outlineVariant)),
      ),
      child: Column(
        children: [
          for (var i = 0; i < 9; i++)
            Container(
              height: 72,
              color: i == 0 ? scheme.secondaryContainer : null,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x4),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHighest,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.x3),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _Bar(width: 140, color: scheme.onSurfaceVariant),
                      const SizedBox(height: AppSpacing.x2),
                      _Bar(width: 200, color: scheme.outlineVariant),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.width, required this.color});

  final double width;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: width,
    height: 8,
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.5),
      borderRadius: BorderRadius.circular(AppRadii.full),
    ),
  );
}
