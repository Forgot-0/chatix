import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:video_player/video_player.dart';

import 'package:chatix/core/utils/logger.dart';
import 'package:chatix/features/chat/presentation/utils/media_viewer_navigation.dart';

/// The one video the viewer is playing.
///
/// One player for the whole viewer rather than one per page: the page on
/// screen and the controls in the bottom bar are different widgets that
/// have to agree about the same video, two pages must never both be making
/// noise, and the speed and the volume belong to the viewer — a reader who
/// turned the sound down does not want it back on the next video.
///
/// Notifies when a player opens, fails or closes, and when the speed or
/// the volume changes. Position is not here: the controls listen to the
/// player itself, so the whole viewer is not rebuilt thirty times a second.
class ViewerPlayback extends ChangeNotifier {
  VideoPlayerController? _controller;
  String? _attachmentId;
  String? _path;
  bool _failed = false;
  bool _disposed = false;

  /// Bumped by every open and close, so an `initialize` that finishes after
  /// the reader has already swiped on knows to throw its player away.
  int _generation = 0;

  VideoSpeed _speed = VideoSpeed.normal;
  double _volume = 1;
  bool _muted = false;

  VideoSpeed get speed => _speed;
  double get volume => _volume;
  bool get isMuted => _muted || _volume == 0;

  /// The player for [attachmentId] once it is open and ready to draw; null
  /// while it is opening, after it failed, or when another video is the
  /// open one.
  VideoPlayerController? controllerOf(String attachmentId) {
    final controller = _controller;
    if (_attachmentId != attachmentId || controller == null) return null;
    return controller.value.isInitialized ? controller : null;
  }

  /// Whether [attachmentId] is the open video and could not be played — no
  /// player on this platform, or a file the platform cannot decode.
  bool hasFailed(String attachmentId) =>
      _attachmentId == attachmentId && _failed;

  /// Opens [file] as the video of [attachmentId] and starts it, closing
  /// whatever was open. Opening the same file again does nothing.
  Future<void> open(String attachmentId, File file) async {
    if (_disposed) return;
    if (_attachmentId == attachmentId && _path == file.path) return;

    _release();
    final generation = ++_generation;
    _attachmentId = attachmentId;
    _path = file.path;

    final controller = VideoPlayerController.file(file);
    _controller = controller;
    notifyListeners();

    try {
      await controller.initialize();
    } catch (error) {
      Logger.warning('Viewer: video ${file.path} cannot be played ($error)');
      unawaited(controller.dispose());
      if (generation != _generation || _disposed) return;

      _controller = null;
      _failed = true;
      notifyListeners();
      return;
    }

    if (generation != _generation || _disposed) {
      unawaited(controller.dispose());
      return;
    }

    await controller.setLooping(
      ViewerVideoRules.loops(controller.value.duration),
    );
    await controller.setPlaybackSpeed(_speed.rate);
    await controller.setVolume(isMuted ? 0 : _volume);
    if (generation != _generation || _disposed) return;

    notifyListeners();
    await controller.play();
  }

  /// Stops and lets go of the open video — the reader has swiped on.
  void close() {
    if (_attachmentId == null && _controller == null) return;
    _release();
    if (!_disposed) notifyListeners();
  }

  void togglePlay() {
    final controller = _ready;
    if (controller == null) return;

    final value = controller.value;
    if (value.isPlaying) {
      unawaited(controller.pause());
      return;
    }

    // A video that ran to its end starts again rather than doing nothing.
    if (value.duration > Duration.zero && value.position >= value.duration) {
      unawaited(controller.seekTo(Duration.zero));
    }
    unawaited(controller.play());
  }

  Future<void> seekTo(Duration position) async {
    await _ready?.seekTo(position);
  }

  void cycleSpeed() {
    _speed = _speed.next;
    unawaited(_ready?.setPlaybackSpeed(_speed.rate));
    notifyListeners();
  }

  void setVolume(double volume) {
    _volume = volume.clamp(0.0, 1.0);
    _muted = false;
    unawaited(_ready?.setVolume(_volume));
    notifyListeners();
  }

  void toggleMute() {
    if (isMuted) {
      _muted = false;
      if (_volume == 0) _volume = 1;
    } else {
      _muted = true;
    }
    unawaited(_ready?.setVolume(isMuted ? 0 : _volume));
    notifyListeners();
  }

  VideoPlayerController? get _ready {
    final controller = _controller;
    return controller != null && controller.value.isInitialized
        ? controller
        : null;
  }

  void _release() {
    _generation++;
    final controller = _controller;
    _controller = null;
    _attachmentId = null;
    _path = null;
    _failed = false;
    if (controller != null) unawaited(controller.dispose());
  }

  @override
  void dispose() {
    _disposed = true;
    _release();
    super.dispose();
  }
}
