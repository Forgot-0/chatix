import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chatix/features/chat/data/datasources/voice_recorder.dart';
import 'package:chatix/features/chat/domain/entities/chat_attachment_limits.dart';
import 'package:chatix/features/chat/presentation/providers/voice_recorder_provider.dart';

class FakeVoiceRecorder implements VoiceRecorder {
  FakeVoiceRecorder({this.permitted = true, this.result});

  bool permitted;
  VoiceRecording? result;

  int startCount = 0;
  int stopCount = 0;
  int cancelCount = 0;

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
  Stream<double> get amplitude => _amplitude.stream;

  @override
  Future<void> dispose() async => _amplitude.close();
}

void main() {
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
      notifier.updateDrag(willCancel: true);
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
      notifier.updateDrag(willCancel: true);

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

  group('duration limit (api-docs §5.5: 600s)', () {
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
