import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chatix/core/storage/cache_manager.dart';

final svgCacheProvider = Provider<CacheManager<ui.Image>>((ref) {
  return CacheManager<ui.Image>(maxItems: 50);
});

class SvgRenderer {
  final CacheManager<ui.Image> _cache;

  SvgRenderer(this._cache);

  Future<ui.Image> renderSvgAsset(
    String assetName, {
    double? width,
    double? height,
    BoxFit fit = BoxFit.contain,
    Color? color,
    BlendMode colorBlendMode = BlendMode.srcIn,
    String? semanticsLabel,
  }) async {
    final cacheKey =
        '${assetName}_${width}_${height}_${color?.hashCode}_${colorBlendMode.index}';

    final cachedImage = _cache.getItem(cacheKey);
    if (cachedImage != null) {
      return cachedImage;
    }

    debugPrint('🖼️ Rendering SVG asset: $assetName');

    await Future.delayed(const Duration(milliseconds: 300));

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final paint = Paint()
      ..color = color ?? Colors.blue
      ..style = PaintingStyle.fill;

    final size = Size(width ?? 100, height ?? 100);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);

    if (kDebugMode) {
      const textStyle = TextStyle(color: Colors.white, fontSize: 14);
      final textSpan = TextSpan(text: 'SVG\nPlaceholder', style: textStyle);
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
      );
      textPainter.layout(minWidth: 0, maxWidth: size.width);
      textPainter.paint(
        canvas,
        Offset(
          size.width / 2 - textPainter.width / 2,
          size.height / 2 - textPainter.height / 2,
        ),
      );
    }

    final picture = recorder.endRecording();
    final image = await picture.toImage(
      size.width.toInt(),
      size.height.toInt(),
    );

    _cache.setItem(cacheKey, image);

    return image;
  }

  Future<ui.Image> renderSvgNetwork(
    String url, {
    double? width,
    double? height,
    BoxFit fit = BoxFit.contain,
    Color? color,
    BlendMode colorBlendMode = BlendMode.srcIn,
    Map<String, String>? headers,
    String? semanticsLabel,
  }) async {
    final cacheKey =
        '${url}_${width}_${height}_${color?.hashCode}_${colorBlendMode.index}';

    final cachedImage = _cache.getItem(cacheKey);
    if (cachedImage != null) {
      return cachedImage;
    }

    debugPrint('🖼️ Rendering SVG from network: $url');

    await Future.delayed(const Duration(milliseconds: 600));

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final paint = Paint()
      ..color = color ?? Colors.green
      ..style = PaintingStyle.fill;

    final size = Size(width ?? 100, height ?? 100);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);

    if (kDebugMode) {
      const textStyle = TextStyle(color: Colors.white, fontSize: 14);
      final textSpan = TextSpan(
        text: 'Network SVG\nPlaceholder',
        style: textStyle,
      );
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
      );
      textPainter.layout(minWidth: 0, maxWidth: size.width);
      textPainter.paint(
        canvas,
        Offset(
          size.width / 2 - textPainter.width / 2,
          size.height / 2 - textPainter.height / 2,
        ),
      );
    }

    final picture = recorder.endRecording();
    final image = await picture.toImage(
      size.width.toInt(),
      size.height.toInt(),
    );

    _cache.setItem(cacheKey, image);

    return image;
  }
}

final svgRendererProvider = Provider<SvgRenderer>((ref) {
  final cache = ref.watch(svgCacheProvider);
  return SvgRenderer(cache);
});

class SvgImage extends ConsumerWidget {
  final String source;
  final bool isAsset;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Color? color;
  final BlendMode colorBlendMode;
  final String? semanticsLabel;
  final Map<String, String>? headers;
  final Widget? placeholder;
  final Widget? errorWidget;

  const SvgImage({
    super.key,
    required this.source,
    this.isAsset = false,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
    this.color,
    this.colorBlendMode = BlendMode.srcIn,
    this.semanticsLabel,
    this.headers,
    this.placeholder,
    this.errorWidget,
  });

  const SvgImage.network(
    String url, {
    super.key,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
    this.color,
    this.colorBlendMode = BlendMode.srcIn,
    this.semanticsLabel,
    this.headers,
    this.placeholder,
    this.errorWidget,
  }) : source = url,
       isAsset = false;

  const SvgImage.asset(
    String assetName, {
    super.key,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
    this.color,
    this.colorBlendMode = BlendMode.srcIn,
    this.semanticsLabel,
    this.placeholder,
    this.errorWidget,
  }) : source = assetName,
       isAsset = true,
       headers = null;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final renderer = ref.watch(svgRendererProvider);

    return FutureBuilder<ui.Image>(
      future: isAsset
          ? renderer.renderSvgAsset(
              source,
              width: width,
              height: height,
              fit: fit,
              color: color,
              colorBlendMode: colorBlendMode,
              semanticsLabel: semanticsLabel,
            )
          : renderer.renderSvgNetwork(
              source,
              width: width,
              height: height,
              fit: fit,
              color: color,
              colorBlendMode: colorBlendMode,
              headers: headers,
              semanticsLabel: semanticsLabel,
            ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return placeholder ??
              SizedBox(
                width: width,
                height: height,
                child: const Center(child: CircularProgressIndicator()),
              );
        }

        if (snapshot.hasError || !snapshot.hasData) {
          return errorWidget ??
              SizedBox(
                width: width,
                height: height,
                child: const Icon(Icons.error_outline, color: Colors.red),
              );
        }

        return RawImage(
          image: snapshot.data,
          width: width,
          height: height,
          fit: fit,
        );
      },
    );
  }
}
