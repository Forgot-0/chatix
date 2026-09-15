import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import 'package:chatix/features/chat/domain/entities/voice_waveform.dart';

/// What came off the microphone, ready to be handed to the uploader.
class VoiceRecording {
  const VoiceRecording({
    required this.path,
    required this.mimeType,
    required this.sizeBytes,
    required this.duration,
    this.waveform = VoiceWaveform.empty,
  });

  final String path;
  final String mimeType;
  final int sizeBytes;
  final Duration duration;

  /// The bars sampled while this was being spoken. Kept with the message so
  /// the bubble draws the real shape rather than a stand-in — nothing in
  /// `AttachmentDTO` carries a waveform (api-docs §5.5).
  final VoiceWaveform waveform;

  VoiceRecording withWaveform(VoiceWaveform waveform) => VoiceRecording(
    path: path,
    mimeType: mimeType,
    sizeBytes: sizeBytes,
    duration: duration,
    waveform: waveform,
  );
}

/// One of the two shapes a voice message is allowed to take.
///
/// Opus in an ogg container is what this sends when the platform can make
/// one — it is what the rest of the world sends, it is a third the size of
/// AAC at speech quality, and `audio/ogg` is on the allowed list. Where the
/// platform has no opus encoder (iOS has none through `AVAudioRecorder`,
/// and Android's ogg muxer only arrives in API 29) it falls back to AAC-LC
/// in MPEG-4, which is also on the list as `audio/mp4`.
///
/// Both are mono, both are at a speech bitrate, and neither is wav: a
/// 600-second wav would be 50 MB against a 20 MB cap (api-docs §5.5).
enum VoiceCodec {
  opus(
    encoder: AudioEncoder.opus,
    mimeType: 'audio/ogg',
    extension: 'ogg',
    // Opus is designed around speech at this rate; mono voice at 32 kbps is
    // transparent enough and puts ten minutes at roughly 2.4 MB.
    bitRate: 32000,
    // Opus resamples internally to 48 kHz whatever it is handed, and the
    // Android format only accepts 8/12/16/24/48 — so ask for the one it
    // will use anyway.
    sampleRate: 48000,
  ),
  aac(
    encoder: AudioEncoder.aacLc,
    mimeType: 'audio/mp4',
    extension: 'm4a',
    // AAC needs roughly twice the bits for the same speech.
    bitRate: 64000,
    sampleRate: 44100,
  );

  const VoiceCodec({
    required this.encoder,
    required this.mimeType,
    required this.extension,
    required this.bitRate,
    required this.sampleRate,
  });

  final AudioEncoder encoder;
  final String mimeType;
  final String extension;
  final int bitRate;
  final int sampleRate;

  RecordConfig get config => RecordConfig(
    encoder: encoder,
    bitRate: bitRate,
    sampleRate: sampleRate,
    // Mono: a phone has one microphone worth of voice in it, and a second
    // channel would only double the bytes.
    numChannels: 1,
    noiseSuppress: true,
    echoCancel: true,
  );
}

abstract class VoiceRecorder {
  Future<bool> hasPermission();

  /// Opens the microphone. Throws whatever the platform throws if it cannot.
  Future<void> start();

  /// Closes the microphone and returns the file, or null if nothing usable
  /// came of it.
  Future<VoiceRecording?> stop();

  Future<void> cancel();

  /// Throws away a recording that was already stopped — the one the
  /// 600-second cap ended, if nobody wants it after all.
  Future<void> discard(VoiceRecording recording);

  /// Loudness, `[0, 1]`, roughly ten readings a second.
  Stream<double> get amplitude;

  Future<void> dispose();
}

class VoiceRecorderImpl implements VoiceRecorder {
  VoiceRecorderImpl({AudioRecorder? recorder})
    : _recorder = recorder ?? AudioRecorder();

  /// How often the loudness is read.
  ///
  /// Ten a second: fast enough that the bar in the composer tracks the
  /// voice, and at the 600-second cap it is 6000 readings squeezed down to
  /// [VoiceWaveform.barCount] — far more than enough to shape 48 bars.
  static const Duration amplitudePeriod = Duration(milliseconds: 100);

  /// The floor of the decibel scale the bars are drawn against.
  ///
  /// `Amplitude.current` is dBFS: 0 at full scale, negative below it, and
  /// unbounded downwards in a silent room. Anything under this is silence
  /// as far as a 48-bar drawing is concerned.
  static const double silenceFloorDb = -50;

  final AudioRecorder _recorder;

  String? _path;
  DateTime? _startedAt;
  VoiceCodec _codec = VoiceCodec.opus;

  /// Remembered across recordings: the answer cannot change while the app is
  /// running, and asking the platform costs a channel round trip on a code
  /// path that runs as the thumb goes down.
  bool? _opusSupported;

  @override
  Future<bool> hasPermission() => _recorder.hasPermission();

  @override
  Future<void> start() async {
    final dir = await getTemporaryDirectory();
    final stamp = DateTime.now().millisecondsSinceEpoch;

    var codec = await _preferredCodec();
    var path = '${dir.path}/voice_$stamp.${codec.extension}';

    try {
      await _recorder.start(codec.config, path: path);
    } on Exception {
      // The encoder answered for itself but the container could not be
      // written — Android only gained an ogg muxer in API 29, and
      // `isEncoderSupported` speaks for the codec, not the muxer. AAC is
      // always there.
      if (codec == VoiceCodec.aac) rethrow;

      _opusSupported = false;
      codec = VoiceCodec.aac;
      path = '${dir.path}/voice_$stamp.${codec.extension}';
      await _recorder.start(codec.config, path: path);
    }

    _codec = codec;
    _path = path;
    _startedAt = DateTime.now();
  }

  Future<VoiceCodec> _preferredCodec() async {
    _opusSupported ??= await _recorder.isEncoderSupported(AudioEncoder.opus);
    return _opusSupported! ? VoiceCodec.opus : VoiceCodec.aac;
  }

  @override
  Future<VoiceRecording?> stop() async {
    final startedAt = _startedAt;
    final codec = _codec;
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
      mimeType: codec.mimeType,
      sizeBytes: size,
      duration: DateTime.now().difference(startedAt),
    );
  }

  @override
  Future<void> cancel() async {
    final path = _path;
    _path = null;
    _startedAt = null;

    await _recorder.cancel();
    if (path != null) await _safeDelete(File(path));
  }

  @override
  Future<void> discard(VoiceRecording recording) =>
      _safeDelete(File(recording.path));

  @override
  Stream<double> get amplitude =>
      _recorder.onAmplitudeChanged(amplitudePeriod).map(normalize);

  /// dBFS to the `[0, 1]` a bar is drawn with.
  ///
  /// Linear in decibels rather than in pressure: a bar chart that is linear
  /// in amplitude spends most of its height on the loudest syllable and
  /// draws everything else as a stub.
  static double normalize(Amplitude reading) {
    final db = reading.current;
    if (db.isNaN || db.isInfinite) return 0;
    return ((db - silenceFloorDb) / -silenceFloorDb).clamp(0.0, 1.0);
  }

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
