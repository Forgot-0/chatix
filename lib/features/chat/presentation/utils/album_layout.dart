import 'dart:math' as math;

/// Where one photo sits inside an album, in fractions of the album's box.
///
/// Fractions rather than pixels so the same layout serves a bubble in a
/// narrow phone column and the same album on a tablet without being
/// recomputed — the widget multiplies by whatever width it ends up with.
class AlbumTile {
  const AlbumTile({
    required this.left,
    required this.top,
    required this.width,
    required this.height,
  });

  final double left;
  final double top;
  final double width;
  final double height;

  double get right => left + width;
  double get bottom => top + height;

  @override
  String toString() =>
      'AlbumTile(${left.toStringAsFixed(3)}, ${top.toStringAsFixed(3)}, '
      '${width.toStringAsFixed(3)}, ${height.toStringAsFixed(3)})';
}

/// The mosaic several photos make when they travel as one message.
///
/// Messengers lay albums out rather than stacking them, and the shapes are
/// conventional: one photo keeps its own proportions, two sit side by side
/// (or stacked, when both are wide), three put one large next to a pair, and
/// beyond that the photos fall into justified rows — every row the full
/// width, heights chosen so the images in it keep their relative shapes.
///
/// Aspect ratios come from `AttachmentDTO.width/height` once the server has
/// measured the file, and from the local file before that (api-docs §5.5
/// fills those in asynchronously), so this takes plain ratios and never asks
/// where they came from. Tiles are cropped to fill, so a ratio that is
/// missing or absurd costs a crop, not a broken layout.
class AlbumLayout {
  const AlbumLayout({required this.aspectRatio, required this.tiles});

  /// Width ÷ height of the whole mosaic.
  final double aspectRatio;

  final List<AlbumTile> tiles;

  /// Ratios outside this range are treated as its ends: a panorama or a
  /// very tall shot would otherwise flatten everything sharing its row.
  static const double minRatio = 0.5;
  static const double maxRatio = 2.4;

  /// How square-ish a lone photo is allowed to be shown, so one portrait
  /// cannot take over the screen.
  static const double minSingleRatio = 0.62;
  static const double maxSingleRatio = 1.8;

  /// Bounds on the mosaic as a whole, for the same reason.
  static const double minAlbumRatio = 0.7;
  static const double maxAlbumRatio = 1.6;

  /// A ratio counts as "wide" above this, which is what decides whether two
  /// photos stack or stand beside each other.
  static const double wideRatio = 1.2;

  /// Builds the mosaic for [ratios] (width ÷ height, in message order).
  ///
  /// A null or nonsensical ratio is read as square — an attachment the
  /// server has not measured yet still has to be drawn somewhere.
  static AlbumLayout of(List<double?> ratios) {
    final safe = [for (final ratio in ratios) _clamp(ratio)];

    return switch (safe.length) {
      0 => const AlbumLayout(aspectRatio: 1, tiles: []),
      1 => _single(safe.first),
      2 => _justified(safe, safe.every(_isWide) ? const [1, 1] : const [2]),
      3 => _isWide(safe.first)
          ? _justified(safe, const [1, 2])
          : _tallLead(safe),
      _ => _justified(safe, _partition(safe.length)),
    };
  }

  static bool _isWide(double ratio) => ratio >= wideRatio;

  static double _clamp(double? ratio) {
    if (ratio == null || !ratio.isFinite || ratio <= 0) return 1;
    return ratio.clamp(minRatio, maxRatio);
  }

  static AlbumLayout _single(double ratio) {
    return AlbumLayout(
      aspectRatio: ratio.clamp(minSingleRatio, maxSingleRatio),
      tiles: const [AlbumTile(left: 0, top: 0, width: 1, height: 1)],
    );
  }

  /// Rows of the full width, each row's height following from the shapes in
  /// it (`height = width ÷ Σ ratio`).
  ///
  /// This is the one geometry behind most of the arrangements: a stacked
  /// pair is rows of `[1, 1]`, a side-by-side pair is `[2]`, a wide photo
  /// over a pair is `[1, 2]`, and four or more use [_partition].
  static AlbumLayout _justified(List<double> ratios, List<int> rows) {
    // Row heights in units of the album's width, before they are scaled to
    // fractions of the finished box.
    final heights = <double>[];
    var index = 0;
    for (final size in rows) {
      final sum = ratios
          .sublist(index, index + size)
          .fold<double>(0, (total, ratio) => total + ratio);
      heights.add(sum > 0 ? 1 / sum : 1);
      index += size;
    }

    final totalHeight = heights.fold<double>(0, (total, h) => total + h);

    final tiles = <AlbumTile>[];
    var top = 0.0;
    index = 0;
    for (var row = 0; row < rows.length; row++) {
      final size = rows[row];
      final height = heights[row] / totalHeight;

      var left = 0.0;
      for (var i = 0; i < size; i++) {
        // The last tile in a row takes whatever is left rather than its own
        // computed width, so rounding cannot leave a hairline gap at the
        // right edge.
        final width = i == size - 1
            ? 1 - left
            : ratios[index + i] * heights[row];

        tiles.add(
          AlbumTile(
            left: left,
            top: top,
            width: width,
            // Same, for the bottom edge of the last row.
            height: row == rows.length - 1 ? 1 - top : height,
          ),
        );
        left += width;
      }

      top += height;
      index += size;
    }

    return AlbumLayout(aspectRatio: _albumRatio(1 / totalHeight), tiles: tiles);
  }

  /// One tall photo down the left, two stacked beside it.
  ///
  /// The column widths are solved rather than guessed: with the lead filling
  /// the full height `H`, its width is `lead × H`, and the two on the right
  /// share what is left, so `H = S ÷ (1 + lead × S)` where `S` is the sum of
  /// their inverse ratios.
  static AlbumLayout _tallLead(List<double> ratios) {
    final lead = ratios[0];
    final inverseSum = 1 / ratios[1] + 1 / ratios[2];

    final height = inverseSum / (1 + lead * inverseSum);
    final leadWidth = (lead * height).clamp(0.4, 0.75);

    final rest = 1 - leadWidth;
    final first = rest / ratios[1];
    final split = (first / height).clamp(0.25, 0.75);

    return AlbumLayout(
      aspectRatio: _albumRatio(1 / height),
      tiles: [
        AlbumTile(left: 0, top: 0, width: leadWidth, height: 1),
        AlbumTile(left: leadWidth, top: 0, width: rest, height: split),
        AlbumTile(
          left: leadWidth,
          top: split,
          width: rest,
          height: 1 - split,
        ),
      ],
    );
  }

  /// How many photos go in each row, at most three, as evenly as the count
  /// allows: 4 → 2+2, 5 → 3+2, 7 → 3+2+2, 10 → 3+3+2+2.
  static List<int> _partition(int count) {
    final rows = (count / 3).ceil();

    final sizes = List<int>.filled(rows, count ~/ rows);
    for (var i = 0; i < count % rows; i++) {
      sizes[i]++;
    }
    return sizes;
  }

  static double _albumRatio(double ratio) {
    if (!ratio.isFinite || ratio <= 0) return 1;
    return ratio.clamp(minAlbumRatio, maxAlbumRatio);
  }

  /// The pixel rectangle for [tile] inside a box of [width] × [height],
  /// with [spacing] taken out of the seams between neighbours only — the
  /// mosaic keeps its outer edges flush.
  static ({double left, double top, double width, double height}) rectOf(
    AlbumTile tile, {
    required double width,
    required double height,
    required double spacing,
  }) {
    final half = spacing / 2;
    const epsilon = 0.001;

    final left = tile.left * width + (tile.left > epsilon ? half : 0);
    final top = tile.top * height + (tile.top > epsilon ? half : 0);
    final right = tile.right * width - (tile.right < 1 - epsilon ? half : 0);
    final bottom =
        tile.bottom * height - (tile.bottom < 1 - epsilon ? half : 0);

    return (
      left: left,
      top: top,
      width: math.max(0, right - left),
      height: math.max(0, bottom - top),
    );
  }
}
