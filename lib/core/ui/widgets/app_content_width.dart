import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import 'package:chatix/core/theme/app_tokens.dart';

/// Holds a page's content to a readable column on a wide pane.
///
/// The column is centred in whatever width the pane gives it — measured by
/// layout, never by the window, so it centres in the right half of a
/// two-pane desktop just as it does on a phone, where it is simply the
/// whole width.
class AppContentWidth extends StatelessWidget {
  const AppContentWidth({
    super.key,
    this.maxWidth = AppContentWidths.form,
    required this.child,
  });

  final double maxWidth;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}

/// [AppContentWidth] for a sliver: the same centred column, inside a
/// [CustomScrollView] whose other slivers — a collapsing header, say — still
/// run the full width of the pane.
///
/// Padding rather than a constraint, so the column is centred rather than
/// pinned to the start of a wide pane; it is worked out from the width the
/// sliver is actually given, never from the window.
class SliverContentWidth extends StatelessWidget {
  const SliverContentWidth({
    super.key,
    this.maxWidth = AppContentWidths.form,
    required this.sliver,
  });

  final double maxWidth;
  final Widget sliver;

  @override
  Widget build(BuildContext context) {
    return SliverLayoutBuilder(
      builder: (context, constraints) {
        final side = math.max(
          0.0,
          (constraints.crossAxisExtent - maxWidth) / 2,
        );
        return SliverPadding(
          padding: EdgeInsets.symmetric(horizontal: side),
          sliver: sliver,
        );
      },
    );
  }
}
