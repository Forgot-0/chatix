import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

class VoiceRecording {
  const VoiceRecording({
    required this.path,
    required this.mimeType,
    required this.sizeBytes,
    required this.duration,
  });

  final String path;
  final String mimeType;
  final int sizeBytes;
  final Duration duration;
}

abstract class VoiceRecorder {
  Future<bool> hasPermission();

  Future<void> start();

  Future<VoiceRecording?> stop();

  Future<void> cancel();

  Stream<double> get amplitude;

  Future<void> dispose();
}

class VoiceRecorderImpl implements VoiceRecorder {
  VoiceRecorderImpl({AudioRecorder? recorder})
    : _recorder = recorder ?? AudioRecorder();

  final AudioRecorder _recorder;

  String? _path;
  DateTime? _startedAt;

  static const String mimeType = 'audio/mp4';

  @override
  Future<bool> hasPermission() => _recorder.hasPermission();

  @override
  Future<void> start() async {
    final dir = await getTemporaryDirectory();
    final path =
        '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';

    await _recorder.start(
      const RecordConfig(encoder: AudioEncoder.aacLc, numChannels: 1),
      path: path,
    );

    _path = path;
    _startedAt = DateTime.now();
  }

  @override
  Future<VoiceRecording?> stop() async {
    final startedAt = _startedAt;
    final recorded = await _recorder.stop();
    _startedAt = null;

    final path = recorded ?? _path;
    _path = null;
    if (path == null || startedAt == null) return null;

    final file = File(path);
    if (!file.existsSync()) return null;

    final size = await file.length();
    if (size <= 0) {
      await _safeDelete(file);
      return null;
    }

    return VoiceRecording(
      path: path,
      mimeType: mimeType,
      sizeBytes: size,
      duration: DateTime.now().difference(startedAt),
    );
  }

  @override
  Future<void> cancel() async {
    final path = _path;
    _path = null;
    _startedAt = null;

    await _recorder.stop();
    if (path != null) await _safeDelete(File(path));
  }

  @override
  Stream<double> get amplitude => _recorder
      .onAmplitudeChanged(const Duration(milliseconds: 120))
      .map((a) => ((a.current + 60) / 60).clamp(0.0, 1.0));

  @override
  Future<void> dispose() async {
    await _recorder.dispose();
  }

  Future<void> _safeDelete(File file) async {
    try {
      if (file.existsSync()) await file.delete();
    } on FileSystemException {
      // A leftover temp file is not worth failing a send over.
    }
  }
}

final voiceRecorderProvider = Provider<VoiceRecorder>((ref) {
  final recorder = VoiceRecorderImpl();
  ref.onDispose(recorder.dispose);
  return recorder;
});
