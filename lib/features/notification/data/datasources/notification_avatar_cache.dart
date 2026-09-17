import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

/// Keeps sender avatars on disk so a notification can draw one.
///
/// The platform paints the large icon itself and has no network, so the file
/// has to exist before the notification is posted.
///
/// Keyed by the storage path rather than the URL: avatar links are presigned
/// and expire in 300 seconds (api-docs §0), so the same picture arrives under
/// a different URL every few minutes and a URL-keyed cache would never hit.
class NotificationAvatarCache {
  NotificationAvatarCache({Dio? dio, Directory? directory})
    : _dio = dio ?? Dio(),
      _directory = directory;

  final Dio _dio;

  Directory? _directory;

  /// How long a cached picture is reused before it is fetched again.
  static const Duration maxAge = Duration(days: 7);

  static const String _folder = 'notification_avatars';

  /// The largest picture worth holding for a 64 dp icon.
  static const int _maxBytes = 512 * 1024;

  /// A file path for [url], or `null` when there is nothing to draw.
  ///
  /// Never throws: an avatar is decoration, and a notification without one is
  /// still a notification.
  Future<String?> fileFor(String? url) async {
    if (url == null || url.isEmpty) return null;

    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme) return null;

    try {
      final directory = await _ensureDirectory();
      final file = File('${directory.path}/${_fileNameFor(uri)}');

      if (await file.exists()) {
        final age = DateTime.now().difference(await file.lastModified());
        if (age < maxAge && await file.length() > 0) return file.path;
      }

      final response = await _dio.getUri<List<int>>(
        uri,
        options: Options(
          responseType: ResponseType.bytes,
          receiveTimeout: const Duration(seconds: 10),
          // The picture may be gone, or the link expired; either way this is
          // not worth a retry while a notification waits on it.
          validateStatus: (status) => status != null && status < 400,
        ),
      );

      final bytes = response.data;
      if (bytes == null || bytes.isEmpty || bytes.length > _maxBytes) {
        return null;
      }

      await file.writeAsBytes(bytes, flush: true);
      return file.path;
    } on Object {
      return null;
    }
  }

  Future<Directory> _ensureDirectory() async {
    final cached = _directory;
    if (cached != null && cached.existsSync()) return cached;

    final base = await getTemporaryDirectory();
    final directory = Directory('${base.path}/$_folder');
    if (!directory.existsSync()) {
      await directory.create(recursive: true);
    }
    _directory = directory;
    return directory;
  }

  /// The storage key, reduced to something a filesystem accepts.
  static String _fileNameFor(Uri uri) {
    final key = uri.path.isEmpty ? uri.toString() : uri.path;
    final sanitized = key.replaceAll(RegExp(r'[^A-Za-z0-9]'), '_');
    final tail = sanitized.length <= 48
        ? sanitized
        : sanitized.substring(sanitized.length - 48);
    return '${key.hashCode.toUnsigned(32)}_$tail';
  }
}
