import 'package:flutter/material.dart';

import 'package:chatix/features/chat/presentation/utils/album_layout.dart';

/// Lays children out as an album: one box, tiles inside it, no scrolling.
///
/// Geometry comes from [AlbumLayout]; this only turns its fractions into
/// pixels. Kept apart from what the tiles contain so the same mosaic serves
/// a sent message, a message still going out, and the preview screen before
/// anything is sent at all.
class AlbumMosaic extends StatelessWidget {
  const AlbumMosaic({
    super.key,
    required this.ratios,
    required this.itemBuilder,
    this.spacing = 3,
    this.borderRadius,
    this.tileRadius = 4,
  });

  /// Width ÷ height per item, in order. Null where it is not known yet.
  final List<double?> ratios;

  final Widget Function(BuildContext context, int index) itemBuilder;

  /// The seam between neighbouring tiles. Never applied to the outer edges.
  final double spacing;

  /// Rounds the album as a whole.
  final BorderRadius? borderRadius;

  /// Rounds each tile inside it, so the seams read as gaps rather than as
  /// lines drawn on one image.
  final double tileRadius;

  @override
  Widget build(BuildContext context) {
    if (ratios.isEmpty) return const SizedBox.shrink();

    final layout = AlbumLayout.of(ratios);
    final radius = borderRadius ?? BorderRadius.circular(12);

    return ClipRRect(
      borderRadius: radius,
      child: AspectRatio(
        aspectRatio: layout.aspectRatio,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final height = constraints.maxHeight.isFinite
                ? constraints.maxHeight
                : width / layout.aspectRatio;

            return Stack(
              children: [
                for (var i = 0; i < layout.tiles.length; i++)
                  _positioned(context, layout.tiles[i], i, width, height),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _positioned(
    BuildContext context,
    AlbumTile tile,
    int index,
    double width,
    double height,
  ) {
    final rect = AlbumLayout.rectOf(
      tile,
      width: width,
      height: height,
      spacing: spacing,
    );

    return Positioned(
      left: rect.left,
      top: rect.top,
      width: rect.width,
      height: rect.height,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(tileRadius),
        child: itemBuilder(context, index),
      ),
    );
  }
}
