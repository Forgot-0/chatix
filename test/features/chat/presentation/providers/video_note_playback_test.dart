import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chatix/features/chat/presentation/providers/video_note_playback_provider.dart';

/// What a video note in the feed does on its own, and what it does when it
/// is asked. A feed where three notes are talking at once is not a feed
/// anybody reads, and one that spends mobile data unasked is worse.
void main() {
  group('how much of a note counts as on screen', () {
    bool onScreen(double visible, {bool was = false}) =>
        videoNoteIsOnScreen(visible: visible, wasOnScreen: was);

    test('fully visible plays', () {
      expect(onScreen(1), isTrue);
    });

    test('entirely gone does not', () {
      expect(onScreen(0, was: true), isFalse);
    });

    test('a note on the threshold keeps doing what it was doing', () {
      // The gap between the two thresholds is what stops a slow scroll from
      // starting and stopping the same note on every frame.
      const between = (videoNotePlayAbove + videoNotePauseBelow) / 2;

      expect(onScreen(between, was: true), isTrue);
      expect(onScreen(between, was: false), isFalse);
    });

    test('the thresholds are far enough apart to be a gap at all', () {
      expect(videoNotePlayAbove, greaterThan(videoNotePauseBelow));
      expect(videoNotePlayAbove - videoNotePauseBelow, greaterThan(0.2));
    });
  });

  group('whether a note should be playing', () {
    bool play({
      bool onScreen = true,
      bool hasSound = false,
      bool autoplayAllowed = true,
      bool handedOver = false,
    }) => videoNoteShouldPlay(
      onScreen: onScreen,
      hasSound: hasSound,
      autoplayAllowed: autoplayAllowed,
      handedOver: handedOver,
    );

    test('on screen and allowed to autoplay: yes, silently', () {
      expect(play(), isTrue);
    });

    test('off screen: never, whatever else is true', () {
      expect(play(onScreen: false), isFalse);
      expect(play(onScreen: false, hasSound: true), isFalse);
    });

    test('autoplay off leaves it waiting for a tap', () {
      expect(play(autoplayAllowed: false), isFalse);
    });

    test('a tap plays it even where autoplay would not have', () {
      // Deliberate is not the same as automatic: the reader asked for this
      // one, so the connection has already been consented to.
      expect(play(autoplayAllowed: false, hasSound: true), isTrue);
    });

    test('the full-screen viewer takes over completely', () {
      expect(play(handedOver: true), isFalse);
      expect(play(handedOver: true, hasSound: true), isFalse);
    });
  });

  group('which note has the sound', () {
    ProviderContainer boot() {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.listen(videoNoteSoundProvider, (_, _) {});
      return container;
    }

    test('none of them, to begin with', () {
      expect(boot().read(videoNoteSoundProvider), isNull);
    });

    test('a tap gives it to one note and a second tap takes it back', () {
      final container = boot();
      final sound = container.read(videoNoteSoundProvider.notifier);

      sound.toggle('a');
      expect(container.read(videoNoteSoundProvider), 'a');

      sound.toggle('a');
      expect(container.read(videoNoteSoundProvider), isNull);
    });

    test('only ever one at a time', () {
      final container = boot();
      final sound = container.read(videoNoteSoundProvider.notifier);

      sound.toggle('a');
      sound.toggle('b');

      expect(container.read(videoNoteSoundProvider), 'b');
    });

    test('scrolling away silences the feed', () {
      final container = boot();
      final sound = container.read(videoNoteSoundProvider.notifier);

      sound.toggle('a');
      sound.silence();

      expect(container.read(videoNoteSoundProvider), isNull);
    });
  });
}
