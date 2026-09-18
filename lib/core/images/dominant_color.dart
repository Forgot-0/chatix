import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Pulls a usable accent out of a picture.
///
/// This is the eyedropper behind "take the colour from my avatar". It is not
/// a palette extractor in the Material sense: the app does not want the most
/// common colour in the image — that is nearly always a background or a skin
/// tone — it wants the colour a person would say the picture *is*, and then
/// it wants that colour dragged onto the narrow band where the theme
/// generator can make a readable bubble out of it.
///
/// Both halves are separated on purpose: [dominantSeedFromPixels] is pure
/// arithmetic over bytes and is where the behaviour is tested, while
/// [dominantSeedOf] is the thin part that has to decode an image.
abstract final class DominantColor {
  /// Longest edge the image is decoded to before it is scanned.
  ///
  /// 48px is enough to survive JPEG noise and far cheaper than the 256 or
  /// 512 variant the avatar endpoint would otherwise hand over.
  static const int sampleSize = 48;

  /// Hue buckets. 15° each: wide enough that one hue is not split across
  /// two, narrow enough to keep orange apart from yellow.
  static const int buckets = 24;

  /// Below this saturation a pixel is grey as far as an accent is concerned,
  /// however much of the picture it covers.
  static const double minSaturation = 0.12;

  /// The band a seed is delivered in. Outside it the generator's bubble fill
  /// either washes out or goes muddy, so a pastel photograph and a neon one
  /// both arrive usable.
  static const double seedMinSaturation = 0.42;
  static const double seedMaxSaturation = 0.92;
  static const double seedMinLightness = 0.40;
  static const double seedMaxLightness = 0.62;

  /// The accent [pixels] suggests, or null when the image holds no colour
  /// worth seeding from — a greyscale photo, a blank avatar, or nothing at
  /// all. Null is an answer, not a failure: the caller says so and leaves
  /// the accent alone.
  ///
  /// [pixels] is straight RGBA, four bytes per pixel, as
  /// `ui.Image.toByteData(format: rawRgba)` hands it over.
  static Color? fromPixels(Uint8List pixels, {int stride = 1}) {
    if (pixels.length < 4) return null;

    final weights = List<double>.filled(buckets, 0);
    final sinSum = List<double>.filled(buckets, 0);
    final cosSum = List<double>.filled(buckets, 0);
    final saturationSum = List<double>.filled(buckets, 0);
    final lightnessSum = List<double>.filled(buckets, 0);

    final int step = 4 * (stride < 1 ? 1 : stride);

    for (var i = 0; i + 3 < pixels.length; i += step) {
      final alpha = pixels[i + 3];
      if (alpha < 128) continue;

      final hsl = HSLColor.fromColor(
        Color.fromARGB(255, pixels[i], pixels[i + 1], pixels[i + 2]),
      );
      if (hsl.saturation < minSaturation) continue;
      if (hsl.lightness < 0.08 || hsl.lightness > 0.94) continue;

      // A vivid pixel says more about what the picture "is" than a pale one,
      // and a mid-lightness pixel says more than a near-black or near-white
      // one — so both steer the vote rather than merely passing the filter.
      final weight =
          hsl.saturation *
          (1 - (hsl.lightness - 0.5).abs() * 1.2).clamp(0.15, 1.0);

      final bucket = ((hsl.hue / 360) * buckets).floor() % buckets;
      final radians = hsl.hue * math.pi / 180;

      weights[bucket] += weight;
      sinSum[bucket] += math.sin(radians) * weight;
      cosSum[bucket] += math.cos(radians) * weight;
      saturationSum[bucket] += hsl.saturation * weight;
      lightnessSum[bucket] += hsl.lightness * weight;
    }

    var best = -1;
    var bestWeight = 0.0;
    for (var i = 0; i < buckets; i++) {
      if (weights[i] > bestWeight) {
        bestWeight = weights[i];
        best = i;
      }
    }

    if (best < 0 || bestWeight <= 0) return null;

    // Circular mean, so a bucket straddling 0° does not average to cyan.
    final hue =
        (math.atan2(sinSum[best], cosSum[best]) * 180 / math.pi + 360) % 360;

    return HSLColor.fromAHSL(
      1,
      hue,
      (saturationSum[best] / bestWeight).clamp(
        seedMinSaturation,
        seedMaxSaturation,
      ),
      (lightnessSum[best] / bestWeight).clamp(
        seedMinLightness,
        seedMaxLightness,
      ),
    ).toColor();
  }

  /// The accent [provider]'s image suggests, or null when it holds none or
  /// cannot be loaded at all.
  ///
  /// Never throws: an eyedropper that crashes the settings screen because a
  /// presigned avatar link expired mid-tap is worse than one that says it
  /// could not find a colour.
  static Future<Color?> fromImage(
    ImageProvider provider, {
    Duration timeout = const Duration(seconds: 10),
  }) async {
    ui.Image? image;
    try {
      image = await _resolve(
        ResizeImage(
          provider,
          width: sampleSize,
          height: sampleSize,
          allowUpscaling: false,
        ),
      ).timeout(timeout);

      final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (data == null) return null;

      return fromPixels(data.buffer.asUint8List());
    } on Object {
      return null;
    } finally {
      image?.dispose();
    }
  }

  static Future<ui.Image> _resolve(ImageProvider provider) {
    final completer = Completer<ui.Image>();
    final stream = provider.resolve(ImageConfiguration.empty);

    late final ImageStreamListener listener;
    listener = ImageStreamListener(
      (info, _) {
        stream.removeListener(listener);
        if (!completer.isCompleted) {
          // Cloned, because the caller disposes what it is given and the
          // image cache still owns the original.
          completer.complete(info.image.clone());
        }
        info.dispose();
      },
      onError: (error, stackTrace) {
        stream.removeListener(listener);
        if (!completer.isCompleted) {
          completer.completeError(error, stackTrace);
        }
      },
    );

    stream.addListener(listener);
    return completer.future;
  }
}
