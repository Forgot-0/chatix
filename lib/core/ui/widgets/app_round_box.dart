import 'package:flutter/widgets.dart';

/// Keeps a round child a circle whatever box it is put in.
///
/// Anything drawn with `BoxShape.circle`, `CircleBorder` or `ClipOval` is
/// only round while its box is square, and a widget does not get to choose
/// its box: a `Row` with `CrossAxisAlignment.stretch`, an `Expanded`, a
/// `SizedBox` that names one side, a grid cell with an aspect ratio of its
/// own and a `Stack` with `StackFit.expand` all hand down constraints the
/// child has to take. A 52 px avatar in a 52 × 40 box becomes an oval; so
/// does a badge in a row that grew with the text beside it.
///
/// So every circle in the app is wrapped here rather than trusting its
/// parents. [diameter] is the size it wants; in a box too small for that it
/// shrinks to the largest circle that fits rather than spilling out, and in
/// a bigger box it sits in the middle at its own size.
///
/// This started as `ChatAvatar`'s own guard (П-2) and is shared because the
/// same squeeze reaches every round thing — play badges, unread counts, pick
/// checks, progress rings.
class AppRoundBox extends StatelessWidget {
  const AppRoundBox({
    super.key,
    required this.diameter,
    required this.child,
    this.alignment = Alignment.center,
  });

  final double diameter;

  /// Where the circle sits in a box bigger than it asked for.
  final AlignmentGeometry alignment;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      widthFactor: 1,
      heightFactor: 1,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: diameter, maxHeight: diameter),
        child: AspectRatio(aspectRatio: 1, child: child),
      ),
    );
  }
}
