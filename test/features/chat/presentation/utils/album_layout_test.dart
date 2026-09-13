import 'package:flutter_test/flutter_test.dart';

import 'package:chatix/features/chat/presentation/utils/album_layout.dart';

/// Whether the tiles together cover the box exactly once: no overlaps, no
/// holes. Checked by sampling, because the shapes differ per count and the
/// point is the result, not the arithmetic that produced it.
void expectCoversBox(AlbumLayout layout) {
  const steps = 40;

  for (var x = 0; x < steps; x++) {
    for (var y = 0; y < steps; y++) {
      final px = (x + 0.5) / steps;
      final py = (y + 0.5) / steps;

      final hits = layout.tiles
          .where(
            (tile) =>
                px >= tile.left &&
                px < tile.right &&
                py >= tile.top &&
                py < tile.bottom,
          )
          .length;

      expect(
        hits,
        1,
        reason:
            'point ($px, $py) is covered $hits times by '
            '${layout.tiles.length} tiles',
      );
    }
  }
}

void main() {
  group('one photo', () {
    test('fills the box and keeps its own shape', () {
      final layout = AlbumLayout.of([1.5]);

      expect(layout.tiles, hasLength(1));
      expect(layout.aspectRatio, closeTo(1.5, 0.001));
      expect(layout.tiles.single.width, 1);
      expect(layout.tiles.single.height, 1);
    });

    test('a very tall photo is not allowed to take over the screen', () {
      final layout = AlbumLayout.of([0.2]);

      expect(layout.aspectRatio, greaterThanOrEqualTo(AlbumLayout.minSingleRatio));
    });

    test('an unmeasured photo is square rather than broken', () {
      final layout = AlbumLayout.of([null]);

      expect(layout.aspectRatio, closeTo(1, 0.001));
      expect(layout.tiles, hasLength(1));
    });
  });

  group('two photos', () {
    test('two portraits stand side by side', () {
      final layout = AlbumLayout.of([0.75, 0.75]);

      expect(layout.tiles, hasLength(2));
      expect(layout.tiles[0].top, 0);
      expect(layout.tiles[1].top, 0);
      expect(layout.tiles[0].height, 1);
      expect(layout.tiles[1].left, closeTo(0.5, 0.001));
      expectCoversBox(layout);
    });

    test('two wide shots stack, so neither becomes a sliver', () {
      final layout = AlbumLayout.of([1.8, 1.8]);

      expect(layout.tiles, hasLength(2));
      expect(layout.tiles[0].width, 1);
      expect(layout.tiles[1].width, 1);
      expect(layout.tiles[1].top, greaterThan(0));
      expectCoversBox(layout);
    });

    test('the wider of two columns gets the wider share', () {
      final layout = AlbumLayout.of([1.0, 0.5]);

      expect(layout.tiles[0].width, greaterThan(layout.tiles[1].width));
      expectCoversBox(layout);
    });
  });

  group('three photos', () {
    test('a wide lead runs across the top with a pair beneath', () {
      final layout = AlbumLayout.of([1.6, 1.0, 1.0]);

      expect(layout.tiles, hasLength(3));
      expect(layout.tiles[0].width, 1);
      expect(layout.tiles[1].top, closeTo(layout.tiles[0].bottom, 0.001));
      expect(layout.tiles[2].top, closeTo(layout.tiles[0].bottom, 0.001));
      expectCoversBox(layout);
    });

    test('a tall lead runs down the left with a pair beside it', () {
      final layout = AlbumLayout.of([0.7, 1.0, 1.0]);

      expect(layout.tiles, hasLength(3));
      expect(layout.tiles[0].height, 1);
      expect(layout.tiles[0].width, lessThan(1));
      expect(layout.tiles[1].left, closeTo(layout.tiles[0].right, 0.001));
      expect(layout.tiles[2].top, closeTo(layout.tiles[1].bottom, 0.001));
      expectCoversBox(layout);
    });
  });

  group('four and more', () {
    test('four make two rows of two', () {
      final layout = AlbumLayout.of([1, 1, 1, 1]);

      expect(layout.tiles, hasLength(4));
      expect(layout.tiles[0].top, 0);
      expect(layout.tiles[1].top, 0);
      expect(layout.tiles[2].top, greaterThan(0));
      expect(layout.tiles[3].top, closeTo(layout.tiles[2].top, 0.001));
      expectCoversBox(layout);
    });

    test('every count up to the ten-per-message cap lays out cleanly', () {
      for (var count = 1; count <= 10; count++) {
        final layout = AlbumLayout.of(
          List<double?>.generate(count, (i) => i.isEven ? 1.4 : 0.8),
        );

        expect(layout.tiles, hasLength(count), reason: '$count photos');
        expect(
          layout.aspectRatio,
          inInclusiveRange(
            AlbumLayout.minAlbumRatio - 0.001,
            AlbumLayout.maxSingleRatio + 0.001,
          ),
          reason: '$count photos',
        );
        expectCoversBox(layout);
      }
    });

    test('rows hold at most three, as evenly as the count allows', () {
      final layout = AlbumLayout.of(List<double?>.filled(7, 1));

      final rows = <double, int>{};
      for (final tile in layout.tiles) {
        final top = double.parse(tile.top.toStringAsFixed(3));
        rows[top] = (rows[top] ?? 0) + 1;
      }

      expect(rows.values, everyElement(lessThanOrEqualTo(3)));
      expect(rows.values.reduce((a, b) => a + b), 7);
    });

    test('nothing is laid out for an empty album', () {
      final layout = AlbumLayout.of(const []);

      expect(layout.tiles, isEmpty);
    });
  });

  group('pixels', () {
    test('the seams are only between tiles, never around the album', () {
      final layout = AlbumLayout.of([1, 1, 1, 1]);

      final topLeft = AlbumLayout.rectOf(
        layout.tiles.first,
        width: 300,
        height: 200,
        spacing: 4,
      );
      final bottomRight = AlbumLayout.rectOf(
        layout.tiles.last,
        width: 300,
        height: 200,
        spacing: 4,
      );

      // Flush against the outer edges...
      expect(topLeft.left, 0);
      expect(topLeft.top, 0);
      expect(bottomRight.left + bottomRight.width, closeTo(300, 0.001));
      expect(bottomRight.top + bottomRight.height, closeTo(200, 0.001));

      // ...and half the spacing taken off each inner one.
      expect(topLeft.width, closeTo(150 - 2, 0.001));
      expect(topLeft.height, closeTo(100 - 2, 0.001));
    });

    test('a rect never comes out negative, however tight the spacing', () {
      final layout = AlbumLayout.of(List<double?>.filled(9, 1));

      for (final tile in layout.tiles) {
        final rect = AlbumLayout.rectOf(
          tile,
          width: 40,
          height: 40,
          spacing: 64,
        );

        expect(rect.width, greaterThanOrEqualTo(0));
        expect(rect.height, greaterThanOrEqualTo(0));
      }
    });
  });
}
