import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chatix/core/images/dominant_color.dart';

/// The eyedropper's job is not "the most common colour" — that is nearly
/// always a background or a skin tone — but "the colour a person would say
/// the picture is", delivered on the narrow band where the theme generator
/// can build a readable bubble out of it.
void main() {
  /// [count] pixels of one colour, as straight RGBA.
  Uint8List pixels(List<Color> colours) {
    final bytes = Uint8List(colours.length * 4);
    for (var i = 0; i < colours.length; i++) {
      final colour = colours[i];
      bytes[i * 4] = (colour.r * 255).round();
      bytes[i * 4 + 1] = (colour.g * 255).round();
      bytes[i * 4 + 2] = (colour.b * 255).round();
      bytes[i * 4 + 3] = (colour.a * 255).round();
    }
    return bytes;
  }

  List<Color> repeat(Color colour, int count) =>
      List<Color>.filled(count, colour);

  test('a solid colour comes back as itself', () {
    const source = Color(0xFF2563C9); // azure
    final accent = DominantColor.fromPixels(pixels(repeat(source, 64)));

    expect(accent, isNotNull);
    expect(
      HSLColor.fromColor(accent!).hue,
      closeTo(HSLColor.fromColor(source).hue, 2),
    );
  });

  test('a greyscale picture has no accent to give', () {
    final accent = DominantColor.fromPixels(
      pixels(<Color>[
        ...repeat(const Color(0xFF101010), 20),
        ...repeat(const Color(0xFF808080), 20),
        ...repeat(const Color(0xFFF0F0F0), 20),
      ]),
    );

    expect(accent, isNull);
  });

  test('transparent pixels do not vote', () {
    final accent = DominantColor.fromPixels(
      pixels(repeat(const Color(0x00FF0000), 40)),
    );

    expect(accent, isNull);
  });

  test('a vivid minority beats a grey majority', () {
    const vivid = Color(0xFFE0457B); // rose
    final accent = DominantColor.fromPixels(
      pixels(<Color>[
        ...repeat(const Color(0xFF9A9A9A), 90),
        ...repeat(vivid, 10),
      ]),
    );

    expect(accent, isNotNull);
    expect(
      HSLColor.fromColor(accent!).hue,
      closeTo(HSLColor.fromColor(vivid).hue, 3),
    );
  });

  test('a near-black accent is lifted into the readable band', () {
    final accent = DominantColor.fromPixels(
      pixels(repeat(const Color(0xFF0A0030), 40)),
    );

    expect(accent, isNotNull);
    final hsl = HSLColor.fromColor(accent!);
    expect(hsl.lightness, greaterThanOrEqualTo(DominantColor.seedMinLightness));
    expect(hsl.lightness, lessThanOrEqualTo(DominantColor.seedMaxLightness));
  });

  test('a pastel accent is pushed back up to a usable saturation', () {
    final accent = DominantColor.fromPixels(
      pixels(repeat(const Color(0xFFE8E0F5), 40)),
    );

    // Pale lilac: saturated enough to pass the grey filter, far too washed
    // out to fill a bubble with.
    expect(accent, isNotNull);
    expect(
      HSLColor.fromColor(accent!).saturation,
      greaterThanOrEqualTo(DominantColor.seedMinSaturation),
    );
  });

  test('hues either side of red average to red, not to cyan', () {
    // The bucket straddling 0° is where a naive mean goes wrong.
    final accent = DominantColor.fromPixels(
      pixels(<Color>[
        ...repeat(const Color(0xFFE02020), 20), // ~0°
        ...repeat(const Color(0xFFE02040), 20), // ~350°
      ]),
    );

    expect(accent, isNotNull);
    final hue = HSLColor.fromColor(accent!).hue;
    expect(hue < 30 || hue > 330, isTrue, reason: 'hue was $hue');
  });

  test('an empty buffer is answered, not thrown at', () {
    expect(DominantColor.fromPixels(Uint8List(0)), isNull);
    expect(DominantColor.fromPixels(Uint8List(3)), isNull);
  });
}
