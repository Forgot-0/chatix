import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Opens the system file manager on a file — "Show in folder".
///
/// Desktop only: a phone has no file manager an app can point at a file
/// in, so on Android and iOS the action is not offered at all
/// ([isSupported]) rather than offered and failing.
class FileRevealer {
  const FileRevealer();

  bool get isSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.macOS ||
          defaultTargetPlatform == TargetPlatform.linux);

  /// Whether the file manager was opened. Explorer and Finder select the
  /// file itself; on Linux there is no common way to, so the folder is
  /// opened instead.
  Future<bool> reveal(File file) async {
    if (!isSupported) return false;

    try {
      switch (defaultTargetPlatform) {
        case TargetPlatform.windows:
          // `/select,` wants backslashes; saved paths are joined with '/'.
          await Process.run('explorer.exe', [
            '/select,',
            file.path.replaceAll('/', r'\'),
          ]);
          // Explorer exits with 1 even when it did exactly what was asked,
          // so its exit code says nothing.
          return true;
        case TargetPlatform.macOS:
          final result = await Process.run('open', ['-R', file.path]);
          return result.exitCode == 0;
        case TargetPlatform.linux:
          final result = await Process.run('xdg-open', [file.parent.path]);
          return result.exitCode == 0;
        case TargetPlatform.android:
        case TargetPlatform.iOS:
        case TargetPlatform.fuchsia:
          return false;
      }
    } on ProcessException {
      return false;
    }
  }
}

final fileRevealerProvider = Provider<FileRevealer>(
  (ref) => const FileRevealer(),
);
