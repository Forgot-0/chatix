import 'dart:io';
import 'dart:ui' show Rect;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

/// Hands a file to another app through the system share sheet.
///
/// A seam over `share_plus`, so a test can stand in for the platform and so
/// the one place that knows where sharing files works is here: Android,
/// iOS, macOS and Windows. Linux has no share sheet, and the action is not
/// offered there ([isSupported]).
class FileSharer {
  const FileSharer();

  bool get isSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS ||
          defaultTargetPlatform == TargetPlatform.windows);

  /// Opens the share sheet on [file], under [name] rather than its cache
  /// name. [origin] anchors the sheet's popover on an iPad.
  ///
  /// Throws when the platform cannot share at all.
  Future<void> share(
    File file, {
    required String name,
    String? mimeType,
    Rect? origin,
  }) async {
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: mimeType)],
        fileNameOverrides: [name],
        sharePositionOrigin: origin,
      ),
    );
  }
}

final fileSharerProvider = Provider<FileSharer>((ref) => const FileSharer());
