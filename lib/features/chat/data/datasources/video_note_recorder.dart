import 'dart:io' show File, Platform;

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:chatix/core/utils/logger.dart';
import 'package:chatix/features/chat/domain/entities/attachment_entity.dart';
import 'package:chatix/features/chat/domain/entities/chat_attachment_limits.dart';
import 'package:chatix/features/chat/presentation/utils/chat_attachment_picker.dart';

/// Whether a video note can be recorded here, and why not when it cannot.
enum VideoNoteReadiness {
  ready,

  /// No camera on this device, or a platform with no camera plugin.
  noCamera,

  /// The camera or microphone grant was refused.
  denied,

  /// Every resolution this camera offers is above the server's 640 px cap.
  tooLarge,

  failed,
}

/// A finished recording, ready to be uploaded as `attachment_type:
/// "video_note"`.
class VideoNoteTake {
  const VideoNoteTake({required this.upload, required this.duration});

  final AttachmentUploadRequestEntity upload;
  final Duration duration;
}

/// Records the round video the API calls a `video_note`.
///
/// Not the system camera. `video_note` is capped at 640 px and 60 s
/// (api-docs §5.5), a capture that breaks either is thrown away in a
/// background worker with nothing but `attachment_status: "error"` to show
/// for it, and there is no transcoder on either side of the wire. A phone
/// camera left to its own devices records 1080p, so the only way to land
/// under the cap is to record under it in the first place — which means
/// owning the camera rather than asking the system for a file.
abstract interface class VideoNoteRecorder {
  /// Opens the camera at a resolution the server will accept.
  Future<VideoNoteReadiness> prepare();

  /// The live camera, for the sheet to draw inside its circle. Only valid
  /// between a [prepare] that answered [VideoNoteReadiness.ready] and
  /// [dispose].
  Widget buildPreview();

  /// What the preview's natural shape is, so the circle can crop it without
  /// squashing anyone. 1 when there is nothing to go on.
  double get aspectRatio;

  bool get isRecording;

  Future<void> start();

  /// Ends the recording and hands back the file, or null if there is nothing
  /// usable — too short, unreadable, or somehow still over the cap.
  Future<VideoNoteTake?> stop();

  Future<void> cancel();

  Future<void> dispose();
}

class CameraVideoNoteRecorder implements VideoNoteRecorder {
  CameraVideoNoteRecorder();

  /// Tried in order, best first.
  ///
  /// `medium` is 640×480 on iOS and 720×480 on Android — 480 on the short
  /// side either way, which is what the cap is measured on, so it is the
  /// one that normally wins. `high` is 720p, whose 720 short side is over
  /// the cap, so there is nothing above `medium` to try. `low` (352×288,
  /// ~240p) is there for cameras that cannot do 480p at all.
  ///
  /// Which one a device actually gives is read back after initialising
  /// rather than assumed from the platform: a preset is a request.
  static const List<ResolutionPreset> presets = [
    ResolutionPreset.medium,
    ResolutionPreset.low,
  ];

  /// Telegram-sized: a circle on screen is small, and a video note is worth
  /// far less bandwidth than a real video.
  static const int videoBitrate = 900 * 1000;
  static const int audioBitrate = 64 * 1000;

  /// The frame rate the worker's `frame_rate_limit_exceeded` check is most
  /// likely written against, and what every other client records at.
  static const int fps = 30;

  /// Shorter than this and it was a mis-tap, not a message.
  static const Duration minimumTake = Duration(milliseconds: 700);

  static bool get isSupportedPlatform =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  CameraController? _controller;
  bool _isRecording = false;

  @override
  bool get isRecording => _isRecording;

  @override
  double get aspectRatio {
    final size = _controller?.value.previewSize;
    if (size == null || size.height == 0) return 1;
    return size.width / size.height;
  }

  @override
  Future<VideoNoteReadiness> prepare() async {
    if (!isSupportedPlatform) return VideoNoteReadiness.noCamera;
    if (_controller != null) return VideoNoteReadiness.ready;

    final List<CameraDescription> cameras;
    try {
      cameras = await availableCameras();
    } on CameraException catch (error) {
      return _readinessOf(error);
    }

    if (cameras.isEmpty) return VideoNoteReadiness.noCamera;

    // A video note is a face, so the selfie camera unless there is none.
    final camera = cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.front,
      orElse: () => cameras.first,
    );

    for (final preset in presets) {
      final controller = CameraController(
        camera,
        preset,
        enableAudio: true,
        fps: fps,
        videoBitrate: videoBitrate,
        audioBitrate: audioBitrate,
      );

      try {
        await controller.initialize();
      } on CameraException catch (error) {
        await controller.dispose();
        return _readinessOf(error);
      }

      // A preset is a request, not a promise — the device answers with what
      // it has, so what it actually gave is what decides.
      final size = controller.value.previewSize;
      if (size == null || fits(size)) {
        _controller = controller;
        Logger.info('Video note: recording at ${size?.width}×${size?.height}');
        return VideoNoteReadiness.ready;
      }

      Logger.info(
        'Video note: $preset gave ${size.width}×${size.height}, trying smaller',
      );
      await controller.dispose();
    }

    return VideoNoteReadiness.tooLarge;
  }

  @override
  Widget buildPreview() {
    final controller = _controller;
    if (controller == null) return const SizedBox.shrink();
    return CameraPreview(controller);
  }

  @override
  Future<void> start() async {
    final controller = _controller;
    if (controller == null || _isRecording) return;

    try {
      await controller.startVideoRecording();
      _isRecording = true;
    } on CameraException catch (error) {
      Logger.warning('Video note: could not start ($error)');
    }
  }

  @override
  Future<VideoNoteTake?> stop() async {
    final controller = _controller;
    if (controller == null || !_isRecording) return null;

    _isRecording = false;

    final XFile file;
    try {
      file = await controller.stopVideoRecording();
    } on CameraException catch (error) {
      Logger.warning('Video note: could not stop ($error)');
      return null;
    }

    // The preset check above is what keeps this under the cap; the probe is
    // the belt to its braces, and the only way to know how long the take
    // really was rather than how long the UI thinks it was.
    final probe = await ChatAttachmentPicker.probeVideo(file.path);
    if (probe == null) {
      Logger.warning('Video note: recorded file could not be read back');
      return null;
    }

    if (probe.duration < minimumTake) return null;

    if (!ChatAttachmentLimits.fitsVideoNoteFrame(probe.width, probe.height)) {
      Logger.warning(
        'Video note: ${probe.width}×${probe.height} is over the cap after all',
      );
      return null;
    }

    return VideoNoteTake(
      duration: probe.duration,
      upload: AttachmentUploadRequestEntity.videoNote(
        filename: file.name,
        mimeType: file.mimeType ?? 'video/mp4',
        fileSize: await File(file.path).length(),
        filePath: file.path,
      ),
    );
  }

  @override
  Future<void> cancel() async {
    if (!_isRecording) return;
    _isRecording = false;

    try {
      await _controller?.stopVideoRecording();
    } on CameraException catch (error) {
      Logger.warning('Video note: could not discard ($error)');
    }
  }

  @override
  Future<void> dispose() async {
    await cancel();
    await _controller?.dispose();
    _controller = null;
  }

  /// Whether a preview of this size is one the server will take, by the
  /// domain's rule rather than a second copy of it here.
  static bool fits(Size size) => ChatAttachmentLimits.fitsVideoNoteFrame(
    size.width.round(),
    size.height.round(),
  );

  /// Camera plugins report a refused grant as an exception code rather than
  /// a result, and the codes differ per platform.
  static VideoNoteReadiness _readinessOf(CameraException error) {
    const denied = {
      'CameraAccessDenied',
      'CameraAccessDeniedWithoutPrompt',
      'CameraAccessRestricted',
      'AudioAccessDenied',
      'AudioAccessDeniedWithoutPrompt',
      'AudioAccessRestricted',
    };

    Logger.warning('Video note: camera refused (${error.code})');
    return denied.contains(error.code)
        ? VideoNoteReadiness.denied
        : VideoNoteReadiness.failed;
  }
}

/// Nothing to record with — every platform without a camera, and every test
/// that does not say otherwise.
class UnavailableVideoNoteRecorder implements VideoNoteRecorder {
  const UnavailableVideoNoteRecorder();

  @override
  Future<VideoNoteReadiness> prepare() async => VideoNoteReadiness.noCamera;

  @override
  Widget buildPreview() => const SizedBox.shrink();

  @override
  double get aspectRatio => 1;

  @override
  bool get isRecording => false;

  @override
  Future<void> start() async {}

  @override
  Future<VideoNoteTake?> stop() async => null;

  @override
  Future<void> cancel() async {}

  @override
  Future<void> dispose() async {}
}

/// How to make a recorder, rather than one to share.
///
/// A camera held open behind a closed sheet is a recording indicator the
/// reader cannot explain, so each sheet takes its own and closes it on the
/// way out — which is a lifetime the sheet can be trusted with and a
/// provider cannot.
typedef VideoNoteRecorderFactory = VideoNoteRecorder Function();

final videoNoteRecorderFactoryProvider = Provider<VideoNoteRecorderFactory>((
  ref,
) {
  return CameraVideoNoteRecorder.isSupportedPlatform
      ? CameraVideoNoteRecorder.new
      : UnavailableVideoNoteRecorder.new;
});
