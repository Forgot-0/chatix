import 'dart:ui';

/// Which square of the original picture a circular cropper is showing.
///
/// Kept apart from the widget and from any decoding so it can be reasoned
/// about — and tested — as the arithmetic it is.
///
/// The cropper lays the picture out at [fitScale], the smallest scale that
/// still covers a [viewportSide]-wide square, and then lets the user pan and
/// zoom it. [zoom] and [translation] are what that interaction produced, in
/// the viewport's own pixels. Mapping a viewport point back to the picture
/// is therefore `(point - translation) / zoom / fitScale`, and the visible
/// square is that mapping applied to the viewport's corners.
Rect avatarCropRect({
  required Size imageSize,
  required double viewportSide,
  required double fitScale,
  required double zoom,
  required Offset translation,
}) {
  if (imageSize.isEmpty || viewportSide <= 0) return Rect.zero;

  final effective = fitScale * zoom;
  if (effective <= 0) return Rect.zero;

  final side = viewportSide / effective;

  final left = -translation.dx / effective;
  final top = -translation.dy / effective;

  // Pan is bounded by the cropper itself, so this only ever trims a
  // sub-pixel overshoot — but a rect that runs off the bitmap would sample
  // transparent edges, and a transparent ring around an avatar is the kind
  // of thing nobody notices until it ships.
  final clampedSide = side.clamp(
    1.0,
    imageSize.width < imageSize.height ? imageSize.width : imageSize.height,
  );

  final maxLeft = imageSize.width - clampedSide;
  final maxTop = imageSize.height - clampedSide;

  return Rect.fromLTWH(
    left.clamp(0.0, maxLeft < 0 ? 0.0 : maxLeft),
    top.clamp(0.0, maxTop < 0 ? 0.0 : maxTop),
    clampedSide,
    clampedSide,
  );
}

/// The scale that makes [imageSize] cover a [viewportSide]-wide square.
double avatarFitScale({required Size imageSize, required double viewportSide}) {
  if (imageSize.isEmpty || viewportSide <= 0) return 1;

  final byWidth = viewportSide / imageSize.width;
  final byHeight = viewportSide / imageSize.height;
  return byWidth > byHeight ? byWidth : byHeight;
}
