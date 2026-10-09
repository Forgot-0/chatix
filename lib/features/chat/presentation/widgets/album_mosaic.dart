import 'package:flutter/material.dart';

import 'package:chatix/core/theme/app_tokens.dart';
import 'package:chatix/features/chat/presentation/utils/album_layout.dart';

/// Lays children out as an album: one box, tiles inside it, no scrolling.
///
/// Geometry comes from [AlbumLayout]; this only turns its fractions into
/// pixels. Kept apart from what the tiles contain so the same mosaic serves
/// a sent message, a message still going out, and the preview screen before
/// anything is sent at all.
///
/// The box is given, never taken from whatever room there is: an album
/// that grows to fill its parent is how a desktop-wide feed ends up with a
/// desktop-wide photo. The caller decides the size — the feed with
/// `MediaBoxSize`, the preview from its own width.
class AlbumMosaic extends StatelessWidget {
  const AlbumMosaic({
    super.key,
    required this.ratios,
    required this.size,
    required this.itemBuilder,
    this.spacing = ChatLayout.albumSeam,
    this.borderRadius,
    this.tileRadius = ChatLayout.albumSeamRadius,
  });

  /// Width ÷ height per item, in order. Null where it is not known yet.
  final List<double?> ratios;

  /// The box the whole album is drawn in. Tiles are cropped to fill their
  /// share of it, so a box that does not match the layout's own shape costs
  /// a crop, not a gap.
  final Size size;

  final Widget Function(BuildContext context, int index) itemBuilder;

  /// The seam between neighbouring tiles. Never applied to the outer edges.
  final double spacing;

  /// Rounds the album as a whole — inside a bubble, the bubble's own
  /// corners wherever the album touches its edge.
  final BorderRadius? borderRadius;

  /// Rounds each tile inside it, so the seams read as gaps rather than as
  /// lines drawn on one image.
  final double tileRadius;

  @override
  Widget build(BuildContext context) {
    if (ratios.isEmpty) return const SizedBox.shrink();

    final layout = AlbumLayout.of(ratios);

    return ClipRRect(
      borderRadius: borderRadius ?? BorderRadius.circular(AppRadii.md),
      child: SizedBox.fromSize(
        size: size,
        child: Stack(
          children: [
            for (var i = 0; i < layout.tiles.length; i++)
              _positioned(context, layout.tiles[i], i),
          ],
        ),
      ),
    );
  }

  Widget _positioned(BuildContext context, AlbumTile tile, int index) {
    final rect = AlbumLayout.rectOf(
      tile,
      width: size.width,
      height: size.height,
      spacing: spacing,
    );

    return Positioned(
      left: rect.left,
      top: rect.top,
      width: rect.width,
      height: rect.height,
      child: ClipRRect(
        borderRadius: _seamCorners(tile),
        child: itemBuilder(context, index),
      ),
    );
  }

  /// The tile's own rounding, on every corner but the album's four.
  ///
  /// Those belong to [borderRadius] — the bubble's corners, or square where
  /// a caption or a quote continues the bubble — and a tile rounding them
  /// again would nick a notch out of an edge that is meant to be straight.
  BorderRadius _seamCorners(AlbumTile tile) {
    const edge = 0.001;
    final atLeft = tile.left < edge;
    final atTop = tile.top < edge;
    final atRight = tile.right > 1 - edge;
    final atBottom = tile.bottom > 1 - edge;

    Radius corner(bool isAlbumCorner) =>
        isAlbumCorner ? Radius.zero : Radius.circular(tileRadius);

    return BorderRadius.only(
      topLeft: corner(atLeft && atTop),
      topRight: corner(atRight && atTop),
      bottomLeft: corner(atLeft && atBottom),
      bottomRight: corner(atRight && atBottom),
    );
  }
}
