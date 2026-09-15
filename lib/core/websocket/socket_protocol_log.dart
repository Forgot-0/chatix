import 'dart:collection';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Which way a frame was going.
enum SocketFrameDirection {
  /// Server to client.
  inbound,

  /// Client to server.
  outbound,

  /// Neither: a connect, a close, a pause — the things between frames that
  /// explain why the frames around them look the way they do.
  note,
}

/// One line of a recorded session.
class SocketLogEntry {
  const SocketLogEntry({
    required this.at,
    required this.direction,
    required this.text,
  });

  final DateTime at;
  final SocketFrameDirection direction;
  final String text;

  String get _arrow => switch (direction) {
    SocketFrameDirection.inbound => '<-',
    SocketFrameDirection.outbound => '->',
    SocketFrameDirection.note => '--',
  };

  @override
  String toString() =>
      '${at.toUtc().toIso8601String()} $_arrow $text';
}

/// A recording of the WebSocket conversation, kept only when asked for.
///
/// The protocol is the hardest part of this client to debug from a bug
/// report: what went wrong is a sequence of frames that happened on someone
/// else's phone, minutes ago, and none of it is visible in the UI. This
/// keeps the last few hundred of those frames in memory so they can be read
/// back — without a debug build, and without shipping a logger that writes
/// everybody's messages to the console by default.
///
/// Off unless the feature flag says otherwise: recording costs memory and
/// puts message text in a buffer, neither of which is acceptable as a
/// default. While off, [record] does nothing at all — not even the string
/// work of building the line.
class SocketProtocolLog {
  SocketProtocolLog({this.capacity = 300, this.maxFrameLength = 2000})
    : assert(capacity > 0, 'a log with no room is not a log');

  /// How many lines are kept. The oldest goes when the newest arrives.
  final int capacity;

  /// Longest single frame kept, in characters. A page of history is tens of
  /// kilobytes and would push everything else out of the window.
  final int maxFrameLength;

  /// Whether anything is being recorded at all.
  bool enabled = false;

  final Queue<SocketLogEntry> _entries = Queue<SocketLogEntry>();

  /// What has been recorded, oldest first.
  List<SocketLogEntry> get entries => List.unmodifiable(_entries);

  bool get isEmpty => _entries.isEmpty;

  int get length => _entries.length;

  /// Records a frame. Cheap to call when recording is off.
  ///
  /// [frame] must already have had anything secret taken out of it — the
  /// connect URL carries the access token, and this buffer is meant to be
  /// handed to somebody else.
  void record(SocketFrameDirection direction, String frame) {
    if (!enabled) return;
    _add(direction, frame);
  }

  /// Records something that is not a frame: connecting, a close code, a
  /// pause. [record] with [SocketFrameDirection.note], spelled out because
  /// almost every call site is one of these.
  void note(String line) {
    if (!enabled) return;
    _add(SocketFrameDirection.note, line);
  }

  void _add(SocketFrameDirection direction, String text) {
    _entries.add(
      SocketLogEntry(
        at: DateTime.now(),
        direction: direction,
        text: text.length > maxFrameLength
            ? '${text.substring(0, maxFrameLength)}… (${text.length} chars)'
            : text,
      ),
    );

    while (_entries.length > capacity) {
      _entries.removeFirst();
    }
  }

  /// The whole recording as text, ready to be shared or pasted into a report.
  String dump() {
    if (_entries.isEmpty) return 'No WebSocket frames recorded.';
    return _entries.map((entry) => entry.toString()).join('\n');
  }

  void clear() => _entries.clear();
}

/// The recording this run shares.
///
/// One instance, reached by both the socket that fills it and the screen that
/// reads it back. Deliberately free of any dependency on the flag service:
/// whether it is switched on is decided once, in the chat socket's lifecycle
/// provider, so that building a socket in a test does not build a feature
/// flag service, an analytics service and everything under them.
final socketProtocolLogProvider = Provider<SocketProtocolLog>((ref) {
  final log = SocketProtocolLog();
  ref.onDispose(log.clear);
  return log;
});
