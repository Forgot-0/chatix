import 'dart:math' as math;

/// The shape of a voice message, as a fixed number of bars between 0 and 1.
///
/// Amplitudes are sampled while the microphone is open — the backend stores
/// no waveform (`AttachmentDTO` carries `duration_seconds` and nothing else,
/// api-docs §5.5) and the file itself is opus in an ogg container, which
/// cannot be decoded to samples on the client without pulling in a decoder.
/// So the bars are captured at record time, kept beside the message, and
/// drawn from there.
///
/// A recording that arrived from somebody else has no bars of its own. Those
/// fall back to [placeholder], which is deterministic in the attachment id:
/// the same message draws the same shape on every open, on every device,
/// which is what makes it read as a waveform rather than as noise.
class VoiceWaveform {
  const VoiceWaveform(this.bars);

  /// How many bars a stored waveform keeps.
  ///
  /// Wide enough to look like speech at the width a bubble gives it, small
  /// enough that the encoded form is one short string per message.
  static const int barCount = 48;

  /// Bars in `[0, 1]`, oldest first. Always [barCount] long.
  final List<double> bars;

  static const VoiceWaveform empty = VoiceWaveform(<double>[]);

  bool get isEmpty => bars.isEmpty;

  /// Squeezes however many amplitude readings were taken into [barCount]
  /// bars, then lifts the quietest of them so a soft recording still has a
  /// shape instead of a flat line.
  ///
  /// Normalisation is against the loudest bar rather than against full
  /// scale: what matters in a bubble is where this recording got louder,
  /// not how close it came to clipping.
  factory VoiceWaveform.fromSamples(List<double> samples) {
    if (samples.isEmpty) return empty;

    final buckets = List<double>.filled(barCount, 0);
    for (var i = 0; i < barCount; i++) {
      final start = (i * samples.length / barCount).floor();
      final end = math.max(
        start + 1,
        ((i + 1) * samples.length / barCount).floor(),
      );

      var peak = 0.0;
      for (var j = start; j < end && j < samples.length; j++) {
        peak = math.max(peak, samples[j].clamp(0.0, 1.0));
      }
      buckets[i] = peak;
    }

    final loudest = buckets.reduce(math.max);
    if (loudest <= 0) return empty;

    return VoiceWaveform([
      for (final bar in buckets) (0.08 + 0.92 * (bar / loudest)).clamp(0.0, 1.0),
    ]);
  }

  /// A stand-in for a recording whose bars this device never saw.
  ///
  /// Seeded by the attachment id so it is stable, and shaped like speech —
  /// a couple of overlaid slow waves rather than uniform random noise, which
  /// reads as a bar chart of nothing.
  factory VoiceWaveform.placeholder(String attachmentId) {
    final random = math.Random(attachmentId.hashCode);

    return VoiceWaveform([
      for (var i = 0; i < barCount; i++)
        (0.25 +
                0.35 * (0.5 + 0.5 * math.sin(i * 0.7)) +
                0.4 * random.nextDouble())
            .clamp(0.0, 1.0),
    ]);
  }

  /// One hex digit per bar, so a whole waveform is a 48-character string and
  /// a chat's worth of them fits in device preferences without ceremony.
  String encode() {
    final buffer = StringBuffer();
    for (final bar in bars) {
      buffer.write(
        (bar.clamp(0.0, 1.0) * 15).round().toRadixString(16),
      );
    }
    return buffer.toString();
  }

  /// The inverse of [encode]. Anything that is not a run of hex digits of
  /// the expected length is treated as absent rather than as an error: a
  /// stored waveform is a nicety, and a wrong one is worse than none.
  static VoiceWaveform decode(String? encoded) {
    if (encoded == null || encoded.length != barCount) return empty;

    final bars = <double>[];
    for (final char in encoded.split('')) {
      final value = int.tryParse(char, radix: 16);
      if (value == null) return empty;
      bars.add(value / 15);
    }
    return VoiceWaveform(bars);
  }

  /// The bars to draw for an attachment: its own if this device recorded it,
  /// otherwise a stable stand-in.
  static VoiceWaveform forAttachment(String attachmentId, String? stored) {
    final decoded = decode(stored);
    return decoded.isEmpty ? VoiceWaveform.placeholder(attachmentId) : decoded;
  }
}
