import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:chatix/features/chat/data/datasources/voice_recorder.dart';
import 'package:chatix/features/chat/domain/entities/chat_attachment_limits.dart';
import 'package:chatix/features/chat/domain/entities/voice_waveform.dart';

enum VoiceRecordStage {
  idle,

  /// The thumb is still down. Letting go sends; sliding first decides
  /// whether it sends at all.
  holding,

  /// The thumb let go above the lock threshold and the microphone stayed
  /// open. Now there are two buttons instead of one gesture.
  locked,

  /// The 600-second cap closed the microphone. The recording is held, not
  /// sent and not thrown away — ten minutes of talking is not something to
  /// decide on somebody's behalf — and the same two buttons decide it.
  completed,

  denied,
}

class VoiceRecordState extends Equatable {
  const VoiceRecordState({
    this.stage = VoiceRecordStage.idle,
    this.elapsed = Duration.zero,
    this.amplitude = 0,
    this.willCancel = false,
    this.cancelProgress = 0,
    this.live = const <double>[],
  });

  final VoiceRecordStage stage;
  final Duration elapsed;

  /// The most recent loudness reading, `[0, 1]`.
  final double amplitude;

  /// Sliding left has gone far enough that letting go now throws this away.
  final bool willCancel;

  /// How far along that slide is, `[0, 1]` — what moves the bin and fades
  /// the rest of the bar out, so the gesture is legible before it commits.
  final double cancelProgress;

  /// The tail of the readings, newest last, for the bar in the composer.
  ///
  /// Only the visible tail: the full recording accumulates out of state, in
  /// the controller, because a growing list in a value that rebuilds the
  /// composer ten times a second is a growing list copied ten times a
  /// second.
  final List<double> live;

  bool get isRecording =>
      stage == VoiceRecordStage.holding || stage == VoiceRecordStage.locked;

  /// The microphone is closed but there is still a recording waiting on a
  /// decision.
  bool get holdsRecording => stage == VoiceRecordStage.completed;

  /// Whether the composer should be showing the recording bar rather than
  /// the text field.
  bool get isActive => isRecording || holdsRecording;

  bool get atLimit =>
      elapsed.inSeconds >= ChatAttachmentLimits.maxVoiceDurationSeconds;

  /// The last thirty seconds, where the recorder starts counting down out
  /// loud instead of just counting up.
  bool get isNearLimit =>
      elapsed.inSeconds >= ChatAttachmentLimits.voiceWarnAfterSeconds;

  Duration get remaining => Duration(
    seconds:
        (ChatAttachmentLimits.maxVoiceDurationSeconds - elapsed.inSeconds)
            .clamp(0, ChatAttachmentLimits.maxVoiceDurationSeconds),
  );

  VoiceRecordState copyWith({
    VoiceRecordStage? stage,
    Duration? elapsed,
    double? amplitude,
    bool? willCancel,
    double? cancelProgress,
    List<double>? live,
  }) => VoiceRecordState(
    stage: stage ?? this.stage,
    elapsed: elapsed ?? this.elapsed,
    amplitude: amplitude ?? this.amplitude,
    willCancel: willCancel ?? this.willCancel,
    cancelProgress: cancelProgress ?? this.cancelProgress,
    live: live ?? this.live,
  );

  @override
  List<Object?> get props => [
    stage,
    elapsed,
    amplitude,
    willCancel,
    cancelProgress,
    live,
  ];
}

/// The microphone, as far as the composer is concerned.
///
/// Owns the clock, the loudness readings and the two thresholds that end a
/// recording: the 600-second cap from api-docs §5.5, which stops it, and the
/// warning thirty seconds before that, which only says so.
class VoiceRecordController extends Notifier<VoiceRecordState> {
  /// How many readings the composer's live bar shows at once.
  static const int liveBars = 34;

  Timer? _ticker;
  StreamSubscription<double>? _amplitude;

  /// Every reading of the recording so far, which becomes the waveform kept
  /// with the message.
  final List<double> _samples = <double>[];

  /// The recording the 600-second cap ended, waiting to be sent or thrown
  /// away. Held here rather than in state so the value the composer rebuilds
  /// on stays comparable.
  VoiceRecording? _completed;

  /// Whether the warning has already been felt, so it is felt once and not
  /// once a second for the last thirty.
  bool _warned = false;

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

    try {
      await _recorder.start();
    } on Exception {
      // Nothing opened, so there is nothing to stop. The composer treats a
      // microphone that will not open the same way it treats one that was
      // refused: it says so instead of pretending to record.
      state = const VoiceRecordState(stage: VoiceRecordStage.denied);
      return;
    }

    _samples.clear();
    _warned = false;
    _completed = null;
    state = const VoiceRecordState(stage: VoiceRecordStage.holding);

    // The start of a recording is the one moment the thumb is covering the
    // button and cannot see it.
    unawaited(HapticFeedback.mediumImpact());

    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());

    _amplitude = _recorder.amplitude.listen(_onAmplitude);
  }

  void _tick() {
    if (!state.isRecording) return;

    final next = state.copyWith(
      elapsed: state.elapsed + const Duration(seconds: 1),
    );
    state = next;

    if (next.atLimit) {
      unawaited(_autoStop());
      return;
    }
    if (next.isNearLimit && !_warned) {
      _warned = true;
      unawaited(HapticFeedback.heavyImpact());
    }
  }

  void _onAmplitude(double value) {
    if (!state.isRecording) return;

    _samples.add(value);

    final live = [...state.live, value];
    if (live.length > liveBars) live.removeRange(0, live.length - liveBars);

    state = state.copyWith(amplitude: value, live: live);
  }

  /// The 600-second cap, reached. Closes the microphone and holds what came
  /// of it: the recording is not lost to the limit, and it is not sent
  /// without being asked for either.
  Future<void> _autoStop() async {
    if (!state.isRecording) return;

    final elapsed = state.elapsed;
    final live = state.live;

    _completed = await _finish();
    if (_completed == null) {
      state = const VoiceRecordState();
      return;
    }

    // The limit is worth feeling: the microphone closing is the one thing
    // here that nobody asked for.
    unawaited(HapticFeedback.heavyImpact());
    state = VoiceRecordState(
      stage: VoiceRecordStage.completed,
      elapsed: elapsed,
      live: live,
    );
  }

  /// Closes the microphone and turns what it captured into a recording, or
  /// null if there is nothing worth sending.
  Future<VoiceRecording?> _finish() async {
    _stopTimers();

    final recording = await _recorder.stop();
    final samples = List<double>.from(_samples);
    _samples.clear();

    if (recording == null || recording.duration < minimumDuration) return null;
    return recording.withWaveform(VoiceWaveform.fromSamples(samples));
  }

  /// How far left the thumb has travelled, as a fraction of the distance
  /// that cancels.
  void updateDrag({required double cancelProgress}) {
    if (state.stage != VoiceRecordStage.holding) return;

    final clamped = cancelProgress.clamp(0.0, 1.0);
    final willCancel = clamped >= 1;
    if (state.cancelProgress == clamped && state.willCancel == willCancel) {
      return;
    }

    // Felt once, as the slide crosses the line — the moment the gesture
    // changes meaning is the moment worth reporting.
    if (willCancel && !state.willCancel) unawaited(HapticFeedback.selectionClick());

    state = state.copyWith(cancelProgress: clamped, willCancel: willCancel);
  }

  void lock() {
    if (state.stage != VoiceRecordStage.holding) return;

    unawaited(HapticFeedback.mediumImpact());
    state = state.copyWith(
      stage: VoiceRecordStage.locked,
      willCancel: false,
      cancelProgress: 0,
    );
  }

  /// Closes the microphone and hands back what was recorded, waveform and
  /// all. Null when there is nothing worth sending.
  Future<VoiceRecording?> stop() async {
    if (state.holdsRecording) {
      // Already stopped by the cap; this is the send button collecting it.
      final completed = _completed;
      _completed = null;
      state = const VoiceRecordState();
      return completed;
    }

    if (!state.isRecording) return null;

    final recording = await _finish();
    state = const VoiceRecordState();
    return recording;
  }

  /// Below this a recording is a slip of the thumb rather than a message.
  static const Duration minimumDuration = Duration(milliseconds: 700);

  Future<void> cancel() async {
    if (!state.isActive) return;

    final completed = _completed;
    final wasRecording = state.isRecording;

    _stopTimers();
    _samples.clear();
    _completed = null;
    state = const VoiceRecordState();

    unawaited(HapticFeedback.lightImpact());

    // Either the microphone is still open and the recorder throws the file
    // away with it, or the cap already closed it and the file is ours to
    // delete.
    if (wasRecording) {
      await _recorder.cancel();
    } else if (completed != null) {
      await _recorder.discard(completed);
    }
  }

  void dismissDenied() {
    if (state.stage == VoiceRecordStage.denied) {
      state = const VoiceRecordState();
    }
  }

  void _stopTimers() {
    _ticker?.cancel();
    _ticker = null;
    unawaited(_amplitude?.cancel());
    _amplitude = null;
  }
}

final voiceRecordProvider =
    NotifierProvider<VoiceRecordController, VoiceRecordState>(
      VoiceRecordController.new,
    );
