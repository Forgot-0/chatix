import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:chatix/features/chat/data/datasources/voice_recorder.dart';
import 'package:chatix/features/chat/domain/entities/chat_attachment_limits.dart';

enum VoiceRecordStage { idle, holding, locked, denied }

class VoiceRecordState extends Equatable {
  const VoiceRecordState({
    this.stage = VoiceRecordStage.idle,
    this.elapsed = Duration.zero,
    this.amplitude = 0,
    this.willCancel = false,
  });

  final VoiceRecordStage stage;
  final Duration elapsed;

  final double amplitude;

  final bool willCancel;

  bool get isRecording =>
      stage == VoiceRecordStage.holding || stage == VoiceRecordStage.locked;

  bool get atLimit =>
      elapsed.inSeconds >= ChatAttachmentLimits.maxVoiceDurationSeconds;

  Duration get remaining => Duration(
    seconds: ChatAttachmentLimits.maxVoiceDurationSeconds - elapsed.inSeconds,
  );

  VoiceRecordState copyWith({
    VoiceRecordStage? stage,
    Duration? elapsed,
    double? amplitude,
    bool? willCancel,
  }) => VoiceRecordState(
    stage: stage ?? this.stage,
    elapsed: elapsed ?? this.elapsed,
    amplitude: amplitude ?? this.amplitude,
    willCancel: willCancel ?? this.willCancel,
  );

  @override
  List<Object?> get props => [stage, elapsed, amplitude, willCancel];
}

class VoiceRecordController extends Notifier<VoiceRecordState> {
  Timer? _ticker;
  StreamSubscription<double>? _amplitude;

  @override
  VoiceRecordState build() {
    ref.onDispose(_stopTimers);
    return const VoiceRecordState();
  }

  VoiceRecorder get _recorder => ref.read(voiceRecorderProvider);

  Future<void> start() async {
    if (state.isRecording) return;

    if (!await _recorder.hasPermission()) {
      state = const VoiceRecordState(stage: VoiceRecordStage.denied);
      return;
    }

    await _recorder.start();
    state = const VoiceRecordState(stage: VoiceRecordStage.holding);

    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      final next = state.copyWith(
        elapsed: state.elapsed + const Duration(seconds: 1),
      );
      state = next;
      if (next.atLimit) unawaited(_autoStop());
    });

    _amplitude = _recorder.amplitude.listen((value) {
      if (state.isRecording) state = state.copyWith(amplitude: value);
    });
  }

  Future<void> _autoStop() async {
    if (!state.isRecording) return;
    _completedByLimit = await stop();
  }

  VoiceRecording? _completedByLimit;

  void updateDrag({required bool willCancel}) {
    if (state.stage != VoiceRecordStage.holding) return;
    if (state.willCancel == willCancel) return;
    state = state.copyWith(willCancel: willCancel);
  }

  void lock() {
    if (state.stage != VoiceRecordStage.holding) return;
    state = state.copyWith(stage: VoiceRecordStage.locked, willCancel: false);
  }

  Future<VoiceRecording?> stop() async {
    if (!state.isRecording) {
      final byLimit = _completedByLimit;
      _completedByLimit = null;
      return byLimit;
    }

    _stopTimers();
    final recording = await _recorder.stop();
    state = const VoiceRecordState();

    if (recording == null || recording.duration.inMilliseconds < 700) {
      return null;
    }
    return recording;
  }

  Future<void> cancel() async {
    if (!state.isRecording) return;
    _stopTimers();
    await _recorder.cancel();
    state = const VoiceRecordState();
  }

  void dismissDenied() {
    if (state.stage == VoiceRecordStage.denied) {
      state = const VoiceRecordState();
    }
  }

  void _stopTimers() {
    _ticker?.cancel();
    _ticker = null;
    _amplitude?.cancel();
    _amplitude = null;
  }
}

final voiceRecordProvider =
    NotifierProvider<VoiceRecordController, VoiceRecordState>(
      VoiceRecordController.new,
    );
