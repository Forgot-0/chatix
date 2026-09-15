import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chatix/features/chat/data/datasources/voice_recorder.dart';
import 'package:chatix/features/chat/domain/entities/chat_attachment_limits.dart';
import 'package:chatix/features/chat/domain/entities/voice_waveform.dart';
import 'package:chatix/features/chat/presentation/providers/voice_recorder_provider.dart';

class FakeVoiceRecorder implements VoiceRecorder {
  FakeVoiceRecorder({this.permitted = true, this.result});

  bool permitted;
  VoiceRecording? result;

  int startCount = 0;
  int stopCount = 0;
  int cancelCount = 0;
  final List<VoiceRecording> discarded = [];

  final StreamController<double> _amplitude =
      StreamController<double>.broadcast();

  @override
  Future<bool> hasPermission() async => permitted;

  @override
  Future<void> start() async => startCount++;

  @override
  Future<VoiceRecording?> stop() async {
    stopCount++;
    return result;
  }

  @override
  Future<void> cancel() async => cancelCount++;

  @override
  Future<void> discard(VoiceRecording recording) async =>
      discarded.add(recording);

  @override
  Stream<double> get amplitude => _amplitude.stream;

  /// Pushes one loudness reading, the way the platform would.
  void emit(double value) => _amplitude.add(value);

  @override
  Future<void> dispose() async => _amplitude.close();
}

/// Walks the controller's clock to the 600-second cap.
///
/// The ticker runs on real time, so the state is simply advanced to one
/// second short of the limit and then allowed to tick once.
Future<void> _runOut(ProviderContainer container) async {
  final notifier = container.read(voiceRecordProvider.notifier);
  notifier.state = notifier.state.copyWith(
    elapsed: const Duration(
      seconds: ChatAttachmentLimits.maxVoiceDurationSeconds - 1,
    ),
  );

  await Future<void>.delayed(const Duration(milliseconds: 1100));
  await pumpEventQueue();
}

void main() {
  // The controller reaches for `HapticFeedback` on every gesture, which is a
  // platform channel — without a binding those calls throw on an unawaited
  // future and take the test down somewhere else entirely.
  TestWidgetsFlutterBinding.ensureInitialized();

  VoiceRecording recording(Duration duration) => VoiceRecording(
    path: '/tmp/voice.m4a',
    mimeType: 'audio/mp4',
    sizeBytes: 4096,
    duration: duration,
  );

  late FakeVoiceRecorder recorder;

  ProviderContainer boot() {
    final container = ProviderContainer(
      overrides: [voiceRecorderProvider.overrideWithValue(recorder)],
    );
    addTearDown(container.dispose);
    return container;
  }

  setUp(() => recorder = FakeVoiceRecorder());

  group('permission', () {
    test(
      'a refusal parks the button instead of pretending to record',
      () async {
        recorder.permitted = false;
        final container = boot();

        await container.read(voiceRecordProvider.notifier).start();

        final state = container.read(voiceRecordProvider);
        expect(state.stage, VoiceRecordStage.denied);
        expect(state.isRecording, isFalse);
        expect(recorder.startCount, 0);
      },
    );

    test('the denied state can be dismissed', () async {
      recorder.permitted = false;
      final container = boot();
      final notifier = container.read(voiceRecordProvider.notifier);

      await notifier.start();
      notifier.dismissDenied();

      expect(container.read(voiceRecordProvider).stage, VoiceRecordStage.idle);
    });
  });

  group('hold, lock, cancel', () {
    test('holding starts the recorder', () async {
      final container = boot();

      await container.read(voiceRecordProvider.notifier).start();

      expect(recorder.startCount, 1);
      expect(
        container.read(voiceRecordProvider).stage,
        VoiceRecordStage.holding,
      );
    });

    test('sliding up locks and clears the pending cancel', () async {
      final container = boot();
      final notifier = container.read(voiceRecordProvider.notifier);

      await notifier.start();
      notifier.updateDrag(cancelProgress: 1);
      notifier.lock();

      final state = container.read(voiceRecordProvider);
      expect(state.stage, VoiceRecordStage.locked);
      expect(state.willCancel, isFalse);
      expect(state.isRecording, isTrue);
    });

    test('a locked recording ignores further drag', () async {
      final container = boot();
      final notifier = container.read(voiceRecordProvider.notifier);

      await notifier.start();
      notifier.lock();
      notifier.updateDrag(cancelProgress: 1);

      expect(container.read(voiceRecordProvider).willCancel, isFalse);
    });

    test('cancelling discards the clip and returns to idle', () async {
      recorder.result = recording(const Duration(seconds: 5));
      final container = boot();
      final notifier = container.read(voiceRecordProvider.notifier);

      await notifier.start();
      await notifier.cancel();

      expect(recorder.cancelCount, 1);
      expect(container.read(voiceRecordProvider).stage, VoiceRecordStage.idle);
    });
  });

  group('stop', () {
    test('hands back a real clip', () async {
      recorder.result = recording(const Duration(seconds: 3));
      final container = boot();
      final notifier = container.read(voiceRecordProvider.notifier);

      await notifier.start();
      final clip = await notifier.stop();

      expect(clip, isNotNull);
      expect(clip!.duration, const Duration(seconds: 3));
      expect(container.read(voiceRecordProvider).stage, VoiceRecordStage.idle);
    });

    test('throws away a mis-tap that barely recorded anything', () async {
      // A quarter of a second is a fumbled press, not a message.
      recorder.result = recording(const Duration(milliseconds: 250));
      final container = boot();
      final notifier = container.read(voiceRecordProvider.notifier);

      await notifier.start();
      expect(await notifier.stop(), isNull);
    });

    test('survives the encoder producing nothing', () async {
      recorder.result = null;
      final container = boot();
      final notifier = container.read(voiceRecordProvider.notifier);

      await notifier.start();
      expect(await notifier.stop(), isNull);
    });
  });

  group('waveform', () {
    test('amplitude readings become the clip\'s bars', () async {
      recorder.result = recording(const Duration(seconds: 3));
      final container = boot();
      final notifier = container.read(voiceRecordProvider.notifier);

      await notifier.start();
      for (final value in [0.2, 0.9, 0.1, 0.7]) {
        recorder.emit(value);
      }
      await pumpEventQueue();

      final clip = await notifier.stop();

      expect(clip, isNotNull);
      expect(clip!.waveform.bars, hasLength(VoiceWaveform.barCount));
      // The loudest reading becomes the tallest bar.
      expect(clip.waveform.bars.reduce(math.max), closeTo(1, 0.001));
    });

    test('the live tail stays bounded however long the recording runs', () async {
      final container = boot();
      final notifier = container.read(voiceRecordProvider.notifier);

      await notifier.start();
      for (var i = 0; i < VoiceRecordController.liveBars * 3; i++) {
        recorder.emit(0.5);
      }
      await pumpEventQueue();

      expect(
        container.read(voiceRecordProvider).live,
        hasLength(VoiceRecordController.liveBars),
      );
    });

    test('a cancelled recording keeps none of its bars', () async {
      recorder.result = recording(const Duration(seconds: 3));
      final container = boot();
      final notifier = container.read(voiceRecordProvider.notifier);

      await notifier.start();
      recorder.emit(0.8);
      await pumpEventQueue();
      await notifier.cancel();

      await notifier.start();
      final clip = await notifier.stop();
      expect(clip!.waveform.isEmpty, isTrue);
    });
  });

  group('duration limit (api-docs §5.5: 600s)', () {
    test('the warning trips at 9:30, thirty seconds before the cap', () {
      const before = VoiceRecordState(
        elapsed: Duration(
          seconds: ChatAttachmentLimits.voiceWarnAfterSeconds - 1,
        ),
      );
      const at = VoiceRecordState(
        elapsed: Duration(seconds: ChatAttachmentLimits.voiceWarnAfterSeconds),
      );

      expect(before.isNearLimit, isFalse);
      expect(at.isNearLimit, isTrue);
      expect(ChatAttachmentLimits.voiceWarnAfterSeconds, 570);
      expect(at.remaining, const Duration(seconds: 30));
    });

    test('remaining never goes negative past the cap', () {
      const state = VoiceRecordState(elapsed: Duration(seconds: 640));
      expect(state.remaining, Duration.zero);
    });

    test('the cap stops the microphone but keeps what was said', () async {
      recorder.result = recording(const Duration(seconds: 600));
      final container = boot();
      final notifier = container.read(voiceRecordProvider.notifier);

      await notifier.start();
      await _runOut(container);

      final state = container.read(voiceRecordProvider);
      expect(recorder.stopCount, 1);
      expect(state.stage, VoiceRecordStage.completed);
      // The microphone is shut, but the composer is still showing a bar with
      // two buttons rather than the text field.
      expect(state.isRecording, isFalse);
      expect(state.holdsRecording, isTrue);
      expect(state.isActive, isTrue);
    });

    test('the held recording is what the send button collects', () async {
      recorder.result = recording(const Duration(seconds: 600));
      final container = boot();
      final notifier = container.read(voiceRecordProvider.notifier);

      await notifier.start();
      await _runOut(container);
      final clip = await notifier.stop();

      expect(clip, isNotNull);
      expect(clip!.duration, const Duration(seconds: 600));
      // Collected once; the recorder is not stopped a second time.
      expect(recorder.stopCount, 1);
      expect(container.read(voiceRecordProvider).stage, VoiceRecordStage.idle);
      expect(await notifier.stop(), isNull);
    });

    test('cancelling a held recording deletes the file it left behind',
        () async {
      recorder.result = recording(const Duration(seconds: 600));
      final container = boot();
      final notifier = container.read(voiceRecordProvider.notifier);

      await notifier.start();
      await _runOut(container);
      await notifier.cancel();

      expect(recorder.discarded, hasLength(1));
      // The recorder was already stopped — cancelling it again would be
      // cancelling the next recording.
      expect(recorder.cancelCount, 0);
      expect(container.read(voiceRecordProvider).stage, VoiceRecordStage.idle);
    });


    test('atLimit trips exactly at the documented ceiling', () {
      const under = VoiceRecordState(
        elapsed: Duration(
          seconds: ChatAttachmentLimits.maxVoiceDurationSeconds - 1,
        ),
      );
      const at = VoiceRecordState(
        elapsed: Duration(
          seconds: ChatAttachmentLimits.maxVoiceDurationSeconds,
        ),
      );

      expect(under.atLimit, isFalse);
      expect(at.atLimit, isTrue);
    });

    test('remaining counts down from the ceiling', () {
      const state = VoiceRecordState(elapsed: Duration(seconds: 590));
      expect(state.remaining.inSeconds, 10);
    });
  });
}
