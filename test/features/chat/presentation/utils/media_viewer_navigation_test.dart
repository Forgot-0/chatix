import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chatix/core/theme/app_tokens.dart';
import 'package:chatix/features/chat/presentation/utils/media_viewer_navigation.dart';

void main() {
  group('MediaViewerCursor', () {
    test('steps one either way inside the strip', () {
      const cursor = MediaViewerCursor(index: 2, length: 5);

      expect(cursor.step(-1), 1);
      expect(cursor.step(1), 3);
      expect(cursor.position, 3);
    });

    test('does not wrap round at either end', () {
      const first = MediaViewerCursor(index: 0, length: 3);
      const last = MediaViewerCursor(index: 2, length: 3);

      expect(first.step(-1), isNull);
      expect(first.hasPrevious, isFalse);
      expect(last.step(1), isNull);
      expect(last.hasNext, isFalse);
    });

    test('a big step is still one item', () {
      const cursor = MediaViewerCursor(index: 1, length: 4);

      expect(cursor.step(5), 2);
      expect(cursor.step(-9), 0);
      expect(cursor.step(0), isNull);
    });

    test('an empty strip goes nowhere', () {
      const cursor = MediaViewerCursor(index: 0, length: 0);

      expect(cursor.isEmpty, isTrue);
      expect(cursor.step(1), isNull);
      expect(cursor.jumpTo(0), isNull);
    });

    test('a thumbnail jumps straight there, but not to where it is', () {
      const cursor = MediaViewerCursor(index: 1, length: 4);

      expect(cursor.jumpTo(3), 3);
      expect(cursor.jumpTo(1), isNull);
      expect(cursor.jumpTo(4), isNull);
      expect(cursor.jumpTo(-1), isNull);
    });

    group('after a deletion', () {
      test('lands on what came next', () {
        // [a, b, (c), d] → [a, b, d]: d, now at 2.
        const cursor = MediaViewerCursor(index: 2, length: 4);

        expect(cursor.afterRemoval({2}), 2);
      });

      test('an album goes whole and the strip closes up', () {
        // [a, (b1), (b2), (b3), c] open on b2 → [a, c]: c, now at 1.
        const cursor = MediaViewerCursor(index: 2, length: 5);

        expect(cursor.afterRemoval({1, 2, 3}), 1);
      });

      test('at the end it steps back instead', () {
        // [a, b, (c)] → [a, b]: b.
        const cursor = MediaViewerCursor(index: 2, length: 3);

        expect(cursor.afterRemoval({2}), 1);
      });

      test('removing earlier items shifts the open one down', () {
        // [(a), b, c] open on c → [b, c]: c, now at 1.
        const cursor = MediaViewerCursor(index: 2, length: 3);

        expect(cursor.afterRemoval({0}), 1);
      });

      test('nothing left is nowhere to land', () {
        const cursor = MediaViewerCursor(index: 0, length: 2);

        expect(cursor.afterRemoval({0, 1}), isNull);
      });
    });
  });

  group('MediaViewerKeys', () {
    test('the arrows page, Esc closes, anything else is not ours', () {
      expect(MediaViewerKeys.stepFor(LogicalKeyboardKey.arrowLeft), -1);
      expect(MediaViewerKeys.stepFor(LogicalKeyboardKey.arrowRight), 1);
      expect(MediaViewerKeys.stepFor(LogicalKeyboardKey.arrowUp), isNull);
      expect(MediaViewerKeys.closes(LogicalKeyboardKey.escape), isTrue);
      expect(MediaViewerKeys.closes(LogicalKeyboardKey.enter), isFalse);
    });
  });

  group('WheelPager', () {
    const t0 = Duration(seconds: 1);

    test('one mouse notch is one page, in its direction', () {
      final down = WheelPager();
      final up = WheelPager();

      expect(down.scroll(100, t0), 1);
      expect(up.scroll(-100, t0), -1);
    });

    test('a touchpad trickle adds up to a page', () {
      final pager = WheelPager();

      expect(pager.scroll(15, t0), isNull);
      expect(pager.scroll(15, t0 + const Duration(milliseconds: 10)), isNull);
      expect(pager.scroll(15, t0 + const Duration(milliseconds: 20)), 1);
    });

    test('the tail of a hard flick does not race on while the page turns', () {
      final pager = WheelPager();

      expect(pager.scroll(100, t0), 1);
      for (var i = 1; i <= 5; i++) {
        expect(
          pager.scroll(100, t0 + Duration(milliseconds: 30 * i)),
          isNull,
          reason: 'still turning',
        );
      }

      expect(pager.scroll(100, t0 + AppMotion.slow), 1);
    });
  });

  group('ViewerZoom', () {
    test('magnifies about the tap: that point does not move', () {
      const focal = Offset(120, 300);
      final matrix = ViewerZoom.about(focal, 2.5);

      expect(MatrixUtils.transformPoint(matrix, focal), focal);
      expect(matrix.getMaxScaleOnAxis(), 2.5);
      expect(ViewerZoom.isZoomed(matrix), isTrue);
    });

    test('the picture still covers the screen after zooming at its edge', () {
      const viewport = Size(390, 844);
      final matrix = ViewerZoom.about(Offset.zero, 2.5);

      // The corner stays put and the far corner moves out past the screen.
      expect(MatrixUtils.transformPoint(matrix, Offset.zero), Offset.zero);
      final far = MatrixUtils.transformPoint(
        matrix,
        Offset(viewport.width, viewport.height),
      );
      expect(far.dx, greaterThan(viewport.width));
      expect(far.dy, greaterThan(viewport.height));
    });

    test('the identity is not zoomed', () {
      expect(ViewerZoom.isZoomed(Matrix4.identity()), isFalse);
    });
  });

  group('videos', () {
    test('short ones go round, long ones stop', () {
      expect(ViewerVideoRules.loops(const Duration(seconds: 6)), isTrue);
      expect(
        ViewerVideoRules.loops(const Duration(seconds: 14, milliseconds: 999)),
        isTrue,
      );
      expect(ViewerVideoRules.loops(const Duration(seconds: 15)), isFalse);
      expect(ViewerVideoRules.loops(const Duration(minutes: 3)), isFalse);
      expect(ViewerVideoRules.loops(Duration.zero), isFalse);
    });

    test('a share of the seek bar is that share of the video, clamped', () {
      const duration = Duration(seconds: 80);

      expect(
        ViewerVideoRules.positionAt(0.25, duration),
        const Duration(seconds: 20),
      );
      expect(ViewerVideoRules.positionAt(1.4, duration), duration);
      expect(ViewerVideoRules.positionAt(-1, duration), Duration.zero);
      expect(
        ViewerVideoRules.fractionOf(const Duration(seconds: 40), duration),
        0.5,
      );
      expect(ViewerVideoRules.fractionOf(duration, Duration.zero), 0);
    });

    test('speeds cycle and are spelled like a voice message\'s', () {
      expect(VideoSpeed.normal.next, VideoSpeed.fast);
      expect(VideoSpeed.fastest.next, VideoSpeed.half);
      expect(VideoSpeed.values.map((speed) => speed.label), [
        '0.5x',
        '1x',
        '1.5x',
        '2x',
      ]);
    });
  });
}
