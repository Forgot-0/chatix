import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chatix/core/providers/localization_providers.dart';

class LocalizedAssetService {
  static String getLocalizedImagePath(BuildContext context, String imageName) {
    final locale = Localizations.localeOf(context);
    return 'assets/images/${locale.languageCode}/$imageName';
  }

  static String getImagePathForLanguage(String languageCode, String imageName) {
    return 'assets/images/$languageCode/$imageName';
  }

  static String getFallbackImagePath(String imageName) {
    return 'assets/images/en/$imageName';
  }

  static String getCommonImagePath(String imageName) {
    return 'assets/images/$imageName';
  }
}

class LocalizedImage extends ConsumerWidget {
  final String imageName;
  final double? width;
  final double? height;
  final BoxFit? fit;
  final Color? color;
  final bool useCommonPath;

  const LocalizedImage({
    super.key,
    required this.imageName,
    this.width,
    this.height,
    this.fit,
    this.color,
    this.useCommonPath = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(persistentLocaleProvider);

    return Image.asset(
      useCommonPath
          ? LocalizedAssetService.getCommonImagePath(imageName)
          : LocalizedAssetService.getImagePathForLanguage(
              locale.languageCode,
              imageName,
            ),
      width: width,
      height: height,
      fit: fit,
      color: color,
      errorBuilder: (context, error, stackTrace) {
        return Image.asset(
          LocalizedAssetService.getFallbackImagePath(imageName),
          width: width,
          height: height,
          fit: fit,
          color: color,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              width: width,
              height: height,
              color: Colors.grey.withValues(alpha: 0.3),
              child: const Icon(Icons.broken_image, color: Colors.grey),
            );
          },
        );
      },
    );
  }
}
