import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

/// A `video_player` platform that plays nothing but behaves like one that
/// does: every video opens at once with [duration] and [size], and the view
/// is a painted stand-in for its first frame.
///
/// Install with `VideoPlayerPlatform.instance = FakeVideoPlayerPlatform()`
/// and put the previous one back in a tear-down.
///
/// Note that a *playing* `VideoPlayerController` polls its position on a
/// 100 ms periodic timer of its own, so a test that leaves a video playing
/// fails with "A Timer is still pending". Pause it before the test ends.
class FakeVideoPlayerPlatform extends VideoPlayerPlatform {
  FakeVideoPlayerPlatform({
    this.duration = const Duration(seconds: 12),
    this.size = const Size(1280, 720),
    this.position = Duration.zero,
    this.buffered,
    this.failToOpen = false,
  });

  final Duration duration;
  final Size size;

  /// Where every video reports itself to be until it is seeked.
  final Duration position;

  /// How much of every video reports itself downloaded, if anything.
  final Duration? buffered;

  /// Opens nothing, the way a desktop with no player does.
  final bool failToOpen;

  final Map<int, StreamController<VideoEvent>> _events = {};
  final Map<int, Duration> _positions = {};
  final Map<int, bool> looping = {};
  final Map<int, double> volumes = {};
  final Map<int, double> speeds = {};
  final List<int> playing = [];

  int _nextId = 0;

  @override
  Future<void> init() async {}

  @override
  Future<int?> create(DataSource dataSource) async {
    final id = _nextId++;
    final events = StreamController<VideoEvent>();
    _events[id] = events;

    // Buffered until the controller listens, which it does straight after.
    if (failToOpen) {
      events.addError(
        PlatformException(code: 'unsupported', message: 'no player here'),
      );
    } else {
      events.add(
        VideoEvent(
          eventType: VideoEventType.initialized,
          duration: duration,
          size: size,
        ),
      );
      final buffered = this.buffered;
      if (buffered != null) {
        events.add(
          VideoEvent(
            eventType: VideoEventType.bufferingUpdate,
            buffered: [DurationRange(Duration.zero, buffered)],
          ),
        );
      }
    }
    return id;
  }

  @override
  Stream<VideoEvent> videoEventsFor(int playerId) => _events[playerId]!.stream;

  /// Players let go of, in order.
  final List<int> disposed = [];

  @override
  Future<void> dispose(int playerId) async {
    disposed.add(playerId);
    playing.remove(playerId);
    // Not awaited: the controller has already cancelled its subscription,
    // and a closed stream nobody listens to never reports itself done.
    unawaited(_events.remove(playerId)?.close());
  }

  @override
  Future<void> setLooping(int playerId, bool looping) async {
    this.looping[playerId] = looping;
  }

  @override
  Future<void> play(int playerId) async {
    if (!playing.contains(playerId)) playing.add(playerId);
  }

  @override
  Future<void> pause(int playerId) async {
    playing.remove(playerId);
  }

  @override
  Future<void> setVolume(int playerId, double volume) async {
    volumes[playerId] = volume;
  }

  @override
  Future<void> setPlaybackSpeed(int playerId, double speed) async {
    speeds[playerId] = speed;
  }

  @override
  Future<void> seekTo(int playerId, Duration position) async {
    _positions[playerId] = position;
  }

  @override
  Future<Duration> getPosition(int playerId) async =>
      _positions[playerId] ?? position;

  @override
  Widget buildView(int playerId) => const FakeVideoFrame();
}

/// What the fake player draws: a dusk over water, so a golden shows where
/// the frame sits and how it is cropped.
class FakeVideoFrame extends StatelessWidget {
  const FakeVideoFrame({super.key});

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          stops: [0, 0.6, 0.6, 1],
          colors: [
            Color(0xFF3B2F63),
            Color(0xFFFFB38A),
            Color(0xFF2F6B7F),
            Color(0xFF1F3E4E),
          ],
        ),
      ),
      child: Align(
        alignment: Alignment(0.35, 0.05),
        child: FractionallySizedBox(
          widthFactor: 0.12,
          child: AspectRatio(
            aspectRatio: 1,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Color(0xFFFFF4D6),
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
