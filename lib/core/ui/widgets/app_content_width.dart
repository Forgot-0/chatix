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
