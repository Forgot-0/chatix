import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:chatix/features/chat/data/datasources/video_note_recorder.dart';
import 'package:chatix/features/chat/domain/entities/chat_attachment_limits.dart';

/// Which recorder the composer's round button is currently holding.
///
/// One button, two things it can capture — a tap swaps them, a hold uses
/// whichever is showing. App-wide rather than per chat: it is a habit, not a
/// property of a conversation, and a reader who films rather than talks does
/// so everywhere.
enum ComposerRecordMode { voice, videoNote }

class ComposerRecordModeController extends Notifier<ComposerRecordMode> {
  @override
  ComposerRecordMode build() => ComposerRecordMode.voice;

  void toggle() {
    unawaited(HapticFeedback.selectionClick());
    state = state == ComposerRecordMode.voice
        ? ComposerRecordMode.videoNote
        : ComposerRecordMode.voice;
  }
}

final composerRecordModeProvider =
    NotifierProvider<ComposerRecordModeController, ComposerRecordMode>(
      ComposerRecordModeController.new,
    );

enum VideoNoteStage {
  idle,

  /// The thumb is down and the camera is opening. Nothing is being recorded
  /// yet — a camera takes a few hundred milliseconds to wake, and saying so
  /// is better than a circle that is black for no stated reason.
  preparing,

  /// The thumb is still down. Letting go sends; sliding first decides
  /// whether it sends at all.
  recording,

  /// The thumb let go above the lock threshold and the camera stayed open.
  locked,

  /// The sixty-second cap closed the camera. The take is held rather than
  /// sent or thrown away — the same courtesy a voice message gets.
  completed,

  /// No camera, no permission, or nothing this camera offers is small
  /// enough. [VideoNoteRecordState.readiness] says which.
  unavailable,
}

class VideoNoteRecordState extends Equatable {
  const VideoNoteRecordState({
    this.stage = VideoNoteStage.idle,
    this.elapsed = Duration.zero,
    this.readiness,
    this.lens = VideoNoteLens.front,
    this.canSwitchLens = false,
    this.willCancel = false,
    this.cancelProgress = 0,
  });

  final VideoNoteStage stage;
  final Duration elapsed;

  /// Why there is nothing to record with, when [stage] is
  /// [VideoNoteStage.unavailable].
  final VideoNoteReadiness? readiness;

  final VideoNoteLens lens;
  final bool canSwitchLens;

  /// Sliding left has gone far enough that letting go now throws this away.
  final bool willCancel;
  final double cancelProgress;

  static const Duration limit = Duration(
    seconds: ChatAttachmentLimits.maxVideoNoteDurationSeconds,
  );

  bool get isRecording =>
      stage == VideoNoteStage.recording || stage == VideoNoteStage.locked;

  bool get holdsRecording => stage == VideoNoteStage.completed;

  /// Whether the composer should be showing the circle rather than the text
  /// field. Includes the wait for the camera: the thumb is already down.
  bool get isActive =>
      isRecording || holdsRecording || stage == VideoNoteStage.preparing;

  /// How much of the sixty seconds is spent, `[0, 1]` — what the ring around
  /// the button draws.
  double get progress => isActive
      ? (elapsed.inMilliseconds / limit.inMilliseconds).clamp(0.0, 1.0)
      : 0;

  Duration get remaining {
    final left = limit - elapsed;
    return left.isNegative ? Duration.zero : left;
  }

  VideoNoteRecordState copyWith({
    VideoNoteStage? stage,
    Duration? elapsed,
    VideoNoteReadiness? readiness,
    VideoNoteLens? lens,
    bool? canSwitchLens,
    bool? willCancel,
    double? cancelProgress,
  }) => VideoNoteRecordState(
    stage: stage ?? this.stage,
    elapsed: elapsed ?? this.elapsed,
    readiness: readiness ?? this.readiness,
    lens: lens ?? this.lens,
    canSwitchLens: canSwitchLens ?? this.canSwitchLens,
    willCancel: willCancel ?? this.willCancel,
    cancelProgress: cancelProgress ?? this.cancelProgress,
  );

  @override
  List<Object?> get props => [
    stage,
    elapsed,
    readiness,
    lens,
    canSwitchLens,
    willCancel,
    cancelProgress,
  ];
}

/// The camera, as far as the composer is concerned.
///
/// Owns the clock and the sixty-second cap from api-docs §5.5, which stops
/// the take on its own. The camera itself is taken when the thumb goes down
/// and given back the moment the take is decided: a camera held open behind
/// a composer is a recording light nobody can account for.
class VideoNoteRecordController extends Notifier<VideoNoteRecordState> {
  Timer? _ticker;
  VideoNoteRecorder? _recorder;

  /// The take the cap ended, waiting to be sent or thrown away. Held here
  /// rather than in state so the value the composer rebuilds on stays
  /// comparable.
  VideoNoteTake? _completed;

  /// The thumb came up while the camera was still opening. Nothing to stop
  /// yet, so the intention is remembered until there is.
  bool _abandoned = false;

  @override
  VideoNoteRecordState build() {
    ref.onDispose(() {
      _ticker?.cancel();
      unawaited(_recorder?.dispose());
    });
    return const VideoNoteRecordState();
  }

  /// The live camera, for the circle above the composer to draw. Null
  /// whenever there is nothing open.
  VideoNoteRecorder? get recorder => _recorder;

  Future<void> start() async {
    if (state.stage != VideoNoteStage.idle &&
        state.stage != VideoNoteStage.unavailable) {
      return;
    }

    _abandoned = false;
    _completed = null;
    state = const VideoNoteRecordState(stage: VideoNoteStage.preparing);

    final recorder = ref.read(videoNoteRecorderFactoryProvider)();
    _recorder = recorder;

    final readiness = await recorder.prepare();
    if (readiness != VideoNoteReadiness.ready) {
      await _release();
      state = VideoNoteRecordState(
        stage: VideoNoteStage.unavailable,
        readiness: readiness,
      );
      return;
    }

    if (_abandoned) {
      await _release();
      state = const VideoNoteRecordState();
      return;
    }

    await recorder.start();
    if (!recorder.isRecording) {
      await _release();
      state = const VideoNoteRecordState(
        stage: VideoNoteStage.unavailable,
        readiness: VideoNoteReadiness.failed,
      );
      return;
    }

    // The start of a take is the one moment the thumb is over the button and
    // cannot see it.
    unawaited(HapticFeedback.mediumImpact());

    state = VideoNoteRecordState(
      stage: VideoNoteStage.recording,
      lens: recorder.lens,
      canSwitchLens: recorder.canSwitchLens,
    );

    _ticker = Timer.periodic(const Duration(milliseconds: 100), (_) => _tick());
  }

  void _tick() {
    if (!state.isRecording) return;

    final next = state.copyWith(
      elapsed: state.elapsed + const Duration(milliseconds: 100),
    );
    state = next;

    if (next.elapsed >= VideoNoteRecordState.limit) unawaited(_autoStop());
  }

  /// The sixty-second cap, reached. Closes the camera and holds what came of
  /// it: a minute of somebody's face is not something to decide on their
  /// behalf.
  Future<void> _autoStop() async {
    if (!state.isRecording) return;

    final elapsed = state.elapsed;
    _completed = await _finish();

    if (_completed == null) {
      state = const VideoNoteRecordState();
      return;
    }

    unawaited(HapticFeedback.heavyImpact());
    state = VideoNoteRecordState(
      stage: VideoNoteStage.completed,
      elapsed: elapsed,
    );
  }

  /// How far left the thumb has travelled, as a fraction of the distance
  /// that cancels.
  void updateDrag({required double cancelProgress}) {
    if (state.stage != VideoNoteStage.recording) return;

    final clamped = cancelProgress.clamp(0.0, 1.0);
    final willCancel = clamped >= 1;
    if (state.cancelProgress == clamped && state.willCancel == willCancel) {
      return;
    }

    if (willCancel && !state.willCancel) {
      unawaited(HapticFeedback.selectionClick());
    }

    state = state.copyWith(cancelProgress: clamped, willCancel: willCancel);
  }

  void lock() {
    if (state.stage != VideoNoteStage.recording) return;

    unawaited(HapticFeedback.mediumImpact());
    state = state.copyWith(
      stage: VideoNoteStage.locked,
      willCancel: false,
      cancelProgress: 0,
    );
  }

  /// Turns the camera around. Only between takes — no platform can swap the
  /// sensor under an open encoder without ending the file.
  Future<void> switchLens() async {
    final recorder = _recorder;
    if (recorder == null || !recorder.canSwitchLens) return;

    unawaited(HapticFeedback.selectionClick());
    await recorder.switchLens();

    state = state.copyWith(
      lens: recorder.lens,
      canSwitchLens: recorder.canSwitchLens,
    );
  }

  /// Closes the camera and hands back the take. Null when there is nothing
  /// worth sending — a mis-tap, or a file that could not be read back.
  Future<VideoNoteTake?> stop() async {
    if (state.holdsRecording) {
      // Already stopped by the cap; this is the send button collecting it.
      final completed = _completed;
      _completed = null;
      state = const VideoNoteRecordState();
      await _release();
      return completed;
    }

    if (state.stage == VideoNoteStage.preparing) {
      // The camera is still opening. It will find out on arrival.
      _abandoned = true;
      return null;
    }

    if (!state.isRecording) return null;

    final take = await _finish();
    state = const VideoNoteRecordState();
    await _release();
    return take;
  }

  Future<void> cancel() async {
    if (state.stage == VideoNoteStage.preparing) {
      _abandoned = true;
      return;
    }

    if (!state.isActive) {
      if (state.stage == VideoNoteStage.unavailable) dismissUnavailable();
      return;
    }

    _stopTicker();
    _completed = null;
    state = const VideoNoteRecordState();

    unawaited(HapticFeedback.lightImpact());

    await _recorder?.cancel();
    await _release();
  }

  void dismissUnavailable() {
    if (state.stage == VideoNoteStage.unavailable) {
      state = const VideoNoteRecordState();
    }
  }

  Future<VideoNoteTake?> _finish() async {
    _stopTicker();
    return _recorder?.stop();
  }

  Future<void> _release() async {
    final recorder = _recorder;
    _recorder = null;
    await recorder?.dispose();
  }

  void _stopTicker() {
    _ticker?.cancel();
    _ticker = null;
  }
}

final videoNoteRecordProvider =
    NotifierProvider<VideoNoteRecordController, VideoNoteRecordState>(
      VideoNoteRecordController.new,
    );
