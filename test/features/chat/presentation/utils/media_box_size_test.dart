import 'dart:ui' show Size;

import 'package:flutter_test/flutter_test.dart';

import 'package:chatix/core/theme/app_tokens.dart';
import 'package:chatix/features/chat/presentation/utils/album_layout.dart';
import 'package:chatix/features/chat/presentation/utils/media_box_size.dart';

/// A box within [tolerance] of [width] × [height].
Matcher sizeCloseTo(double width, double height, {double tolerance = 0.01}) =>
    isA<Size>()
        .having((size) => size.width, 'width', closeTo(width, tolerance))
        .having((size) => size.height, 'height', closeTo(height, tolerance));

void main() {
  /// The two feeds every case is checked in: a phone column and the chat
  /// pane of a 1440 px window next to an 80 px rail and a 360 px list.
  const phone = Size(390, 640);
  const desktop = Size(1000, 780);

  Size fit(double? ratio, Size feed) => MediaBoxSize.fit(
    ratio: ratio,
    maxWidth: ChatLayout.mediaMaxWidthFor(feed.width),
    maxHeight: ChatLayout.mediaMaxHeightFor(feed.height),
  );

  group('ChatLayout', () {
    test('a text bubble is 80% of the feed, never past 560', () {
      expect(ChatLayout.bubbleMaxWidthFor(390), closeTo(312, 0.001));
      expect(ChatLayout.bubbleMaxWidthFor(1000), 560);
    });

    test('media is 72% of the feed, capped at 380 on a phone, 420 wider', () {
      expect(ChatLayout.mediaMaxWidthFor(390), closeTo(280.8, 0.001));
      // 72% of 560 is 403 — still a phone-width feed, so the phone cap.
      expect(ChatLayout.mediaMaxWidthFor(560), ChatLayout.mediaMaxWidthCompact);
      expect(ChatLayout.mediaMaxWidthFor(1000), ChatLayout.mediaMaxWidthWide);
      expect(ChatLayout.mediaMaxWidthFor(2400), ChatLayout.mediaMaxWidthWide);
    });

    test('media is half the feed tall at most, never past 440', () {
      expect(ChatLayout.mediaMaxHeightFor(640), 320);
      expect(ChatLayout.mediaMaxHeightFor(2000), ChatLayout.mediaMaxHeight);
    });

    test('only a pane wider than 1000 gets a centred column', () {
      expect(ChatLayout.columnWidthFor(390), 390);
      expect(ChatLayout.columnWidthFor(1000), 1000);
      expect(ChatLayout.columnWidthFor(1001), ChatLayout.columnMaxWidth);
      expect(ChatLayout.columnWidthFor(1920), ChatLayout.columnMaxWidth);
    });
  });

  group('one picture on a 390 px phone', () {
    test('a 9:16 portrait is held to half the feed in height', () {
      // 280.8 wide would make it 499 tall; the 320 height cap wins and the
      // width follows the shape down.
      expect(fit(9 / 16, phone), sizeCloseTo(180, 320));
    });

    test('a 16:9 landscape takes the full media width', () {
      expect(fit(16 / 9, phone), sizeCloseTo(280.8, 157.95));
    });

    test('a 4:1 panorama is cropped to the minimum height, not squashed', () {
      // Its own shape would be 70 px tall.
      expect(fit(4, phone), sizeCloseTo(280.8, ChatLayout.mediaMinHeight));
    });

    test('a square is as wide as media gets', () {
      expect(fit(1, phone), sizeCloseTo(280.8, 280.8));
    });

    test('an unmeasured picture is drawn square', () {
      expect(fit(null, phone), sizeCloseTo(280.8, 280.8));
    });
  });

  group('one picture in a 1000 px desktop pane', () {
    test('a 9:16 portrait is held to the height cap', () {
      expect(fit(9 / 16, desktop), sizeCloseTo(390 * 9 / 16, 390));
    });

    test('a 16:9 landscape stops at 420, not at 72% of the pane', () {
      expect(fit(16 / 9, desktop), sizeCloseTo(420, 236.25));
    });

    test('a 4:1 panorama keeps its shape when it clears the minimum', () {
      expect(fit(4, desktop), sizeCloseTo(420, 105));
    });

    test('a square is bounded by the height cap first', () {
      expect(fit(1, desktop), sizeCloseTo(390, 390));
    });

    test('an unmeasured picture is drawn square', () {
      expect(fit(null, desktop), sizeCloseTo(390, 390));
    });
  });

  group('the bounds hold whatever the shape', () {
    for (final feed in [phone, desktop]) {
      for (final ratio in <double?>[
        null,
        0,
        -1,
        double.nan,
        double.infinity,
        0.05,
        0.2,
        9 / 16,
        1,
        16 / 9,
        4,
        20,
      ]) {
        test('ratio $ratio in a ${feed.width.toInt()} px feed', () {
          final maxWidth = ChatLayout.mediaMaxWidthFor(feed.width);
          final maxHeight = ChatLayout.mediaMaxHeightFor(feed.height);
          final size = fit(ratio, feed);

          expect(size.width, lessThanOrEqualTo(maxWidth + 0.001));
          expect(size.height, lessThanOrEqualTo(maxHeight + 0.001));
          expect(size.width, greaterThanOrEqualTo(ChatLayout.mediaMinWidth));
          expect(size.height, greaterThanOrEqualTo(ChatLayout.mediaMinHeight));
        });
      }
    }

    test('a needle-thin screenshot is cropped to the minimum width', () {
      expect(fit(0.1, phone), sizeCloseTo(ChatLayout.mediaMinWidth, 320));
    });

    test('a feed narrower than the minimum still contains the picture', () {
      final size = MediaBoxSize.fit(ratio: 1, maxWidth: 100, maxHeight: 80);

      expect(size.width, lessThanOrEqualTo(100));
      expect(size.height, lessThanOrEqualTo(80));
    });
  });

  group('forMedia', () {
    test('a lone picture keeps its own shape, not the clamped album one', () {
      // AlbumLayout would square a 9:16 portrait up to 0.62; the feed has a
      // height to fit into, so it does not need to.
      expect(
        MediaBoxSize.forMedia([9 / 16], maxWidth: 280.8, maxHeight: 320),
        sizeCloseTo(180, 320),
      );
      expect(AlbumLayout.of([9 / 16]).aspectRatio, greaterThan(9 / 16));
    });

    test('an album is scaled as a whole, keeping the mosaic\'s shape', () {
      final ratios = <double?>[0.6, 0.6, 0.6, 0.6, 0.6];
      final albumRatio = AlbumLayout.of(ratios).aspectRatio;
      final size = MediaBoxSize.forMedia(
        ratios,
        maxWidth: 280.8,
        maxHeight: 320,
      );

      expect(size.width / size.height, closeTo(albumRatio, 0.001));
      expect(size.width, lessThanOrEqualTo(280.8));
      expect(size.height, lessThanOrEqualTo(320));
    });

    test('nothing to draw is no box', () {
      expect(
        MediaBoxSize.forMedia(const [], maxWidth: 300, maxHeight: 300),
        Size.zero,
      );
    });
  });
}
