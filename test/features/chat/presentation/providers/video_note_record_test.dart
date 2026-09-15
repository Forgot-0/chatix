import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chatix/features/chat/data/datasources/video_note_recorder.dart';
import 'package:chatix/features/chat/domain/entities/chat_attachment_limits.dart';
import 'package:chatix/features/chat/presentation/providers/video_note_record_provider.dart';

import '../../../../helpers/fakes/fake_video_note_recorder.dart';

/// The composer's hold-to-record. The camera is taken when the thumb goes
/// down and given back the moment the take is decided — a camera held open
/// behind a composer is a recording light nobody can account for — and the
/// sixty-second cap from api-docs §5.5 closes it on its own.
void main() {
  late FakeVideoNoteRecorder recorder;

  ProviderContainer boot() {
    recorder = FakeVideoNoteRecorder(hasSecondCamera: true);
    final container = ProviderContainer(
      overrides: [
        videoNoteRecorderFactoryProvider.overrideWithValue(() => recorder),
      ],
    );
    addTearDown(container.dispose);
    container.listen(videoNoteRecordProvider, (_, _) {});
    return container;
  }

  VideoNoteRecordController notifier(ProviderContainer c) =>
      c.read(videoNoteRecordProvider.notifier);

  VideoNoteRecordState state(ProviderContainer c) =>
      c.read(videoNoteRecordProvider);

  group('starting', () {
    test('opens the camera and records', () async {
      final container = boot();
      await notifier(container).start();

      expect(state(container).stage, VideoNoteStage.recording);
      expect(state(container).isActive, isTrue);
      expect(recorder.starts, 1);
    });

    test('a refused camera says so instead of pretending to record', () async {
      final container = boot();
      recorder.readiness = VideoNoteReadiness.denied;

      await notifier(container).start();

      expect(state(container).stage, VideoNoteStage.unavailable);
      expect(state(container).readiness, VideoNoteReadiness.denied);
      expect(recorder.starts, 0);
      expect(recorder.disposals, 1, reason: 'and nothing is left open');
    });

    test('a camera that only records above the cap is not a camera', () async {
      final container = boot();
      recorder.readiness = VideoNoteReadiness.tooLarge;

      await notifier(container).start();

      expect(state(container).readiness, VideoNoteReadiness.tooLarge);
    });

    test('the notice can be dismissed', () async {
      final container = boot();
      recorder.readiness = VideoNoteReadiness.noCamera;
      await notifier(container).start();

      notifier(container).dismissUnavailable();

      expect(state(container).stage, VideoNoteStage.idle);
    });
  });

  group('the thumb coming up', () {
    test('sends the take and gives the camera back', () async {
      final container = boot();
      await notifier(container).start();

      final take = await notifier(container).stop();

      expect(take, isNotNull);
      expect(state(container).stage, VideoNoteStage.idle);
      expect(recorder.disposals, 1);
    });

    test('a take too short to keep comes back as nothing', () async {
      final container = boot();
      recorder.take = null;
      await notifier(container).start();

      expect(await notifier(container).stop(), isNull);
      expect(state(container).stage, VideoNoteStage.idle);
    });

    test('while the camera is still opening, nothing is recorded at all', () async {
      final container = boot();
      recorder.opening = Completer<void>();

      final starting = notifier(container).start();
      expect(state(container).stage, VideoNoteStage.preparing);
      expect(state(container).isActive, isTrue);

      // The thumb comes up before the camera is awake.
      expect(await notifier(container).stop(), isNull);
      recorder.opening!.complete();
      await starting;

      expect(state(container).stage, VideoNoteStage.idle);
      expect(recorder.starts, 0, reason: 'nothing to record');
      expect(recorder.disposals, 1, reason: 'and nothing left open');
    });
  });

  group('sliding', () {
    test('far enough left throws the take away', () async {
      final container = boot();
      await notifier(container).start();

      notifier(container).updateDrag(cancelProgress: 1);
      expect(state(container).willCancel, isTrue);

      await notifier(container).cancel();

      expect(recorder.cancels, 1);
      expect(recorder.stops, 0, reason: 'a cancelled take is never collected');
      expect(state(container).stage, VideoNoteStage.idle);
      expect(recorder.disposals, 1);
    });

    test('not far enough only says how far', () async {
      final container = boot();
      await notifier(container).start();

      notifier(container).updateDrag(cancelProgress: 0.5);

      expect(state(container).cancelProgress, 0.5);
      expect(state(container).willCancel, isFalse);
      expect(state(container).stage, VideoNoteStage.recording);
    });

    test('up leaves the hands free, and the slide stops meaning anything', () async {
      final container = boot();
      await notifier(container).start();
      notifier(container).updateDrag(cancelProgress: 0.6);

      notifier(container).lock();

      expect(state(container).stage, VideoNoteStage.locked);
      expect(state(container).cancelProgress, 0);

      notifier(container).updateDrag(cancelProgress: 1);
      expect(state(container).willCancel, isFalse);
    });
  });

  group('the sixty-second cap', () {
    test('is the one api-docs §5.5 names', () {
      expect(
        VideoNoteRecordState.limit.inSeconds,
        ChatAttachmentLimits.maxVideoNoteDurationSeconds,
      );
      expect(VideoNoteRecordState.limit, const Duration(seconds: 60));
    });

    testWidgets('closes the camera and holds the take rather than sending it', (
      tester,
    ) async {
      final container = boot();
      await notifier(container).start();

      // The widget tester's clock drives the controller's own ticker.
      await tester.pump(VideoNoteRecordState.limit);
      await tester.pump();

      expect(state(container).stage, VideoNoteStage.completed);
      expect(state(container).holdsRecording, isTrue);
      expect(state(container).progress, 1, reason: 'a full ring');
      expect(recorder.stops, 1, reason: 'the camera is closed');
      expect(recorder.disposals, 0, reason: 'but the take is still in hand');

      expect(await notifier(container).stop(), isNotNull);
      expect(recorder.disposals, 1);
    });

    testWidgets('and the held take can be thrown away instead', (tester) async {
      final container = boot();
      await notifier(container).start();

      await tester.pump(VideoNoteRecordState.limit);
      await tester.pump();
      await notifier(container).cancel();

      expect(state(container).stage, VideoNoteStage.idle);
      expect(recorder.disposals, 1);
    });

    testWidgets('the ring fills as the seconds go', (tester) async {
      final container = boot();
      expect(state(container).progress, 0);

      await notifier(container).start();
      await tester.pump(const Duration(seconds: 30));

      expect(state(container).progress, closeTo(0.5, 0.02));

      // Half a minute of camera does not get to outlive the test.
      await notifier(container).cancel();
    });
  });

  group('turning the camera around', () {
    test('works mid-take, because the plugin hands the encoder over', () async {
      final container = boot();
      await notifier(container).start();

      expect(state(container).lens, VideoNoteLens.front);
      expect(state(container).canSwitchLens, isTrue);

      await notifier(container).switchLens();

      expect(state(container).lens, VideoNoteLens.back);
      expect(recorder.isRecording, isTrue, reason: 'one file, not two');
    });

    test('is not offered on a phone with one camera', () async {
      final container = boot();
      recorder.hasSecondCamera = false;

      await notifier(container).start();

      expect(state(container).canSwitchLens, isFalse);
    });
  });

  group('which recorder the button holds', () {
    test('starts on the microphone', () {
      final container = boot();

      expect(
        container.read(composerRecordModeProvider),
        ComposerRecordMode.voice,
      );
    });

    test('a tap swaps it, and swaps it back', () {
      final container = boot();
      container.listen(composerRecordModeProvider, (_, _) {});
      final mode = container.read(composerRecordModeProvider.notifier);

      mode.toggle();
      expect(
        container.read(composerRecordModeProvider),
        ComposerRecordMode.videoNote,
      );

      mode.toggle();
      expect(
        container.read(composerRecordModeProvider),
        ComposerRecordMode.voice,
      );
    });
  });
}
