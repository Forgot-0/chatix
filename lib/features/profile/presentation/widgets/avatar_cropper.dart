import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'package:chatix/features/profile/presentation/utils/avatar_crop_geometry.dart';
import 'package:chatix/gen/l10n/app_localizations.dart';

/// Picks the square of [image] that becomes the avatar, behind a circular
/// mask.
///
/// Returns the crop in the picture's own pixels, or null if it was
/// cancelled. A full-screen dialog rather than a route because it belongs to
/// the picture that was just picked: there is nothing to put in a URL, and
/// coming back to it later would mean coming back to a file this device may
/// no longer have.
Future<ui.Rect?> showAvatarCropper(
  BuildContext context, {
  required ui.Image image,
}) {
  return showDialog<ui.Rect>(
    context: context,
    useSafeArea: false,
    barrierDismissible: false,
    builder: (dialogContext) => _AvatarCropperDialog(image: image),
  );
}

class _AvatarCropperDialog extends StatefulWidget {
  const _AvatarCropperDialog({required this.image});

  final ui.Image image;

  @override
  State<_AvatarCropperDialog> createState() => _AvatarCropperDialogState();
}

class _AvatarCropperDialogState extends State<_AvatarCropperDialog> {
  final TransformationController _transform = TransformationController();

  /// The side of the square window the picture is cropped to, in logical
  /// pixels. Set once the layout is known.
  double? _viewport;

  @override
  void dispose() {
    _transform.dispose();
    super.dispose();
  }

  Size get _imageSize => Size(
    widget.image.width.toDouble(),
    widget.image.height.toDouble(),
  );

  /// Lays the picture out centred, covering the window exactly.
  void _reset(double viewport) {
    final fit = avatarFitScale(imageSize: _imageSize, viewportSide: viewport);
    final childWidth = _imageSize.width * fit;
    final childHeight = _imageSize.height * fit;

    _transform.value = Matrix4.identity()
      ..translateByDouble(
        -(childWidth - viewport) / 2,
        -(childHeight - viewport) / 2,
        0,
        1,
      );
  }

  void _confirm() {
    final viewport = _viewport;
    if (viewport == null) return;

    final matrix = _transform.value;

    Navigator.of(context).pop(
      avatarCropRect(
        imageSize: _imageSize,
        viewportSide: viewport,
        fitScale: avatarFitScale(
          imageSize: _imageSize,
          viewportSide: viewport,
        ),
        zoom: matrix.getMaxScaleOnAxis(),
        translation: Offset(matrix[12], matrix[13]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    // Dark in both themes, like every other surface where a picture is the
    // whole point: a light surround changes how the picture itself reads.
    return Theme(
      data: ThemeData.dark(useMaterial3: true),
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          elevation: 0,
          title: Text(l10n.avatarCropTitle),
          leading: IconButton(
            tooltip: l10n.cancel,
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: Column(
          children: [
            Expanded(
              child: Center(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final side = _sideFor(constraints);

                    if (_viewport != side) {
                      _viewport = side;
                      // The controller is not part of the tree, so setting
                      // it during layout changes nothing that is already
                      // being painted.
                      _reset(side);
                    }

                    final fit = avatarFitScale(
                      imageSize: _imageSize,
                      viewportSide: side,
                    );

                    return SizedBox(
                      width: side,
                      height: side,
                      child: ClipRect(
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            InteractiveViewer(
                              transformationController: _transform,
                              // Unconstrained so the picture keeps its own
                              // size and can be panned behind the window;
                              // a zero boundary margin is what stops it
                              // being dragged off the edge and leaving a
                              // transparent sliver inside the circle.
                              constrained: false,
                              boundaryMargin: EdgeInsets.zero,
                              minScale: 1,
                              maxScale: 5,
                              child: SizedBox(
                                width: _imageSize.width * fit,
                                height: _imageSize.height * fit,
                                child: RawImage(
                                  image: widget.image,
                                  fit: BoxFit.fill,
                                  filterQuality: FilterQuality.medium,
                                ),
                              ),
                            ),
                            const IgnorePointer(child: _CircleMask()),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      l10n.avatarCropHint,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _confirm,
                        child: Text(l10n.avatarCropConfirm),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// A square that fits the space with a little air around it, and never
  /// collapses to nothing on a very short window.
  double _sideFor(BoxConstraints constraints) {
    final available = constraints.biggest.shortestSide - 32;
    return available < 120 ? 120 : available;
  }
}

/// Everything outside the inscribed circle, dimmed.
class _CircleMask extends StatelessWidget {
  const _CircleMask();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _CircleMaskPainter(), child: const SizedBox());
  }
}

class _CircleMaskPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Offset.zero & size;
    final radius = size.shortestSide / 2;
    final centre = bounds.center;

    final hole = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(bounds)
      ..addOval(Rect.fromCircle(center: centre, radius: radius));

    canvas.drawPath(hole, Paint()..color = Colors.black.withValues(alpha: 0.6));

    canvas.drawCircle(
      centre,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = Colors.white.withValues(alpha: 0.85),
    );
  }

  @override
  bool shouldRepaint(covariant _CircleMaskPainter oldDelegate) => false;
}
