import 'dart:io';

import 'package:flutter/services.dart' show MissingPluginException;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

/// Copies a file out of the app's own storage into somewhere the person can
/// find it again.
///
/// Where that is depends on the platform: desktops have a Downloads folder,
/// mobiles hand apps a documents directory instead. Both are reachable
/// through `path_provider`, which is why saving does not need a
/// gallery/media-store plugin — and why the result carries the full path, so
/// the UI can say where the file actually went rather than claiming "saved"
/// and leaving it to be hunted for.
class DeviceFileSaver {
  DeviceFileSaver({Future<Directory> Function()? targetDirectory})
    : _targetDirectory = targetDirectory ?? _defaultTarget;

  final Future<Directory> Function() _targetDirectory;

  static Future<Directory> _defaultTarget() async {
    try {
      final downloads = await getDownloadsDirectory();
      if (downloads != null) return downloads;
    } on UnsupportedError {
      // Android and iOS have no Downloads directory to hand out.
    } on MissingPluginException {
      // Nothing to fall back from on a platform without the plugin either.
    }

    return getApplicationDocumentsDirectory();
  }

  /// Copies [source] next to the person's other downloads under [filename].
  ///
  /// An existing file of that name is never overwritten — the copy is
  /// numbered instead, the way a browser does it.
  Future<File> save({required File source, required String filename}) async {
    final directory = await _targetDirectory();
    if (!directory.existsSync()) {
      await directory.create(recursive: true);
    }

    final target = _freePath(directory, sanitize(filename));
    return source.copy(target);
  }

  /// A filename safe to write anywhere: no separators, no leading dots, and
  /// short enough for every filesystem the app runs on.
  static String sanitize(String filename) {
    final base = filename.split(RegExp(r'[/\\]')).last.trim();

    final cleaned = base
        .replaceAll(RegExp(r'[\x00-\x1f<>:"|?*]'), '_')
        .replaceAll(RegExp(r'^\.+'), '');

    if (cleaned.isEmpty) return 'attachment';
    return cleaned.length <= 120 ? cleaned : cleaned.substring(0, 120);
  }

  static String _freePath(Directory directory, String filename) {
    final dot = filename.lastIndexOf('.');
    final stem = dot > 0 ? filename.substring(0, dot) : filename;
    final extension = dot > 0 ? filename.substring(dot) : '';

    var candidate = '${directory.path}/$filename';
    var attempt = 1;
    while (File(candidate).existsSync()) {
      candidate = '${directory.path}/$stem ($attempt)$extension';
      attempt++;
    }
    return candidate;
  }
}

final deviceFileSaverProvider = Provider<DeviceFileSaver>((ref) {
  return DeviceFileSaver();
});
