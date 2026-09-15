import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';

import 'package:chatix/features/chat/domain/entities/voice_waveform.dart';

void main() {
  group('fromSamples', () {
    test('always produces the stored bar count, however few readings', () {
      final waveform = VoiceWaveform.fromSamples([0.1, 0.9, 0.4]);
      expect(waveform.bars, hasLength(VoiceWaveform.barCount));
    });

    test('squeezes a long recording down to the same count', () {
      final samples = [for (var i = 0; i < 6000; i++) (i % 100) / 100];
      expect(
        VoiceWaveform.fromSamples(samples).bars,
        hasLength(VoiceWaveform.barCount),
      );
    });

    test('normalises against its own loudest moment', () {
      // Nothing here comes near full scale, but the shape should still fill
      // the bubble rather than hugging the baseline.
      final waveform = VoiceWaveform.fromSamples([
        for (var i = 0; i < 96; i++) i.isEven ? 0.05 : 0.2,
      ]);

      expect(waveform.bars.reduce(math.max), closeTo(1, 0.001));
      expect(waveform.bars.reduce(math.min), greaterThan(0));
    });

    test('keeps the loud half loud and the quiet half quiet', () {
      final waveform = VoiceWaveform.fromSamples([
        ...List<double>.filled(100, 0.1),
        ...List<double>.filled(100, 1),
      ]);

      final half = VoiceWaveform.barCount ~/ 2;
      final quiet = waveform.bars.take(half).reduce(math.max);
      final loud = waveform.bars.skip(half).reduce(math.min);

      expect(quiet, lessThan(loud));
    });

    test('silence has no shape worth keeping', () {
      expect(VoiceWaveform.fromSamples(List<double>.filled(50, 0)).isEmpty,
          isTrue);
      expect(VoiceWaveform.fromSamples(const []).isEmpty, isTrue);
    });
  });

  group('encode/decode', () {
    test('round-trips within the precision of one hex digit', () {
      final original = VoiceWaveform.fromSamples([
        for (var i = 0; i < 480; i++) (math.sin(i / 7) + 1) / 2,
      ]);

      final restored = VoiceWaveform.decode(original.encode());

      expect(restored.bars, hasLength(VoiceWaveform.barCount));
      for (var i = 0; i < original.bars.length; i++) {
        expect(restored.bars[i], closeTo(original.bars[i], 1 / 15));
      }
    });

    test('one character per bar', () {
      final encoded = VoiceWaveform.fromSamples([0.5, 1, 0.2]).encode();
      expect(encoded.length, VoiceWaveform.barCount);
    });

    test('anything the wrong shape decodes to nothing rather than throwing',
        () {
      expect(VoiceWaveform.decode(null).isEmpty, isTrue);
      expect(VoiceWaveform.decode('').isEmpty, isTrue);
      expect(VoiceWaveform.decode('abc').isEmpty, isTrue);
      expect(
        VoiceWaveform.decode('z' * VoiceWaveform.barCount).isEmpty,
        isTrue,
      );
    });
  });

  group('placeholder', () {
    test('the same message always draws the same shape', () {
      expect(
        VoiceWaveform.placeholder('att-1').bars,
        VoiceWaveform.placeholder('att-1').bars,
      );
    });

    test('different messages do not', () {
      expect(
        VoiceWaveform.placeholder('att-1').bars,
        isNot(VoiceWaveform.placeholder('att-2').bars),
      );
    });

    test('stays inside the drawable range', () {
      final bars = VoiceWaveform.placeholder('att-3').bars;
      expect(bars, hasLength(VoiceWaveform.barCount));
      expect(bars.every((bar) => bar >= 0 && bar <= 1), isTrue);
    });
  });

  group('forAttachment', () {
    test('prefers what this device recorded', () {
      final recorded = VoiceWaveform.fromSamples([0.9, 0.1, 0.5, 0.3]);

      expect(
        VoiceWaveform.forAttachment('att-1', recorded.encode()).bars,
        VoiceWaveform.decode(recorded.encode()).bars,
      );
    });

    test('falls back to the stand-in for somebody else\'s recording', () {
      expect(
        VoiceWaveform.forAttachment('att-1', null).bars,
        VoiceWaveform.placeholder('att-1').bars,
      );
    });
  });
}
