import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img;
import 'package:pasteboard/pasteboard.dart';
import 'package:path_provider/path_provider.dart';

import 'package:chatix/core/utils/logger.dart';
import 'package:chatix/features/chat/data/datasources/media_type_sniffer.dart';
import 'package:chatix/features/chat/domain/entities/attachment_entity.dart';
import 'package:chatix/features/chat/domain/entities/chat_attachment_limits.dart';

/// What Ctrl+V finds on the clipboard that can go into a message.
///
/// Files copied in the file manager come first — they are what the person
/// meant — then text, then a picture (a screenshot, an image copied from a
/// browser). Text is not this reader's business: an empty answer hands the
/// key back to the text field, which pastes it the ordinary way. It goes
/// before the picture because office apps put a picture of the copied cells
/// next to the text, and somebody pasting a table into a message wants the
/// words.
abstract interface class ClipboardAttachmentReader {
  Future<List<AttachmentUploadRequestEntity>> read();
}

final clipboardAttachmentReaderProvider = Provider<ClipboardAttachmentReader>(
  (ref) => const PasteboardAttachmentReader(),
);

/// [ClipboardAttachmentReader] over the system clipboard, through
/// `pasteboard` — one package for macOS, Windows and Linux, plain platform
/// channels, no native toolchain beyond the app's own.
class PasteboardAttachmentReader implements ClipboardAttachmentReader {
  const PasteboardAttachmentReader();

  @override
  Future<List<AttachmentUploadRequestEntity>> read() async {
    try {
      final paths = await Pasteboard.files();
      final files = [
        for (final path in paths)
          if (path.isNotEmpty) path,
      ];
      if (files.isNotEmpty) return LocalFileUploads.ofAll(files);

      if (await Clipboard.hasStrings()) return const [];

      final bytes = await Pasteboard.image;
      if (bytes == null || bytes.isEmpty) return const [];

      final image = await compute(ClipboardImage.normalize, bytes);
      if (image == null) return const [];

      final directory = await getTemporaryDirectory();
      final name = ClipboardImage.fileNameFor(DateTime.now(), image.extension);
      final file = File('${directory.path}${Platform.pathSeparator}$name');
      await file.writeAsBytes(image.bytes, flush: true);

      return [
        AttachmentUploadRequestEntity(
          filename: name,
          mimeType: image.mimeType,
          fileSize: image.bytes.length,
          filePath: file.path,
        ),
      ];
    } catch (error) {
      // No clipboard plugin here, a clipboard another app holds open, a
      // format nobody can decode: nothing to attach, and the field still
      // gets its chance at the text.
      Logger.warning('Paste: clipboard could not be read ($error)');
      return const [];
    }
  }
}

/// A file on this device as an upload request — for paths that arrive from
/// outside any picker: copied in the file manager, dropped on the window.
abstract final class LocalFileUploads {
  /// [paths] that are files this app can read, as upload requests, in the
  /// order given. A folder, or a file that went away in between, is left
  /// out rather than failing the rest.
  static Future<List<AttachmentUploadRequestEntity>> ofAll(
    Iterable<String> paths,
  ) async {
    final uploads = <AttachmentUploadRequestEntity>[];
    for (final path in paths) {
      if (!FileSystemEntity.isFileSync(path)) continue;
      try {
        uploads.add(await of(path));
      } on FileSystemException catch (error) {
        Logger.warning('Attachment: skipped $path ($error)');
      }
    }
    return uploads;
  }

  /// Its type read from its own first bytes, as the pickers do: the server
  /// holds the declared type against them (api-docs §5.5), and a name is
  /// only a guess.
  static Future<AttachmentUploadRequestEntity> of(String path) async {
    final file = File(path);
    final name = path.split(RegExp(r'[\\/]')).last;

    final header = <int>[];
    try {
      await for (final chunk in file.openRead(
        0,
        MediaTypeSniffer.headerLength,
      )) {
        header.addAll(chunk);
      }
    } on FileSystemException catch (error) {
      Logger.warning('Attachment: could not read $name ($error)');
    }

    return AttachmentUploadRequestEntity(
      filename: name,
      mimeType: MediaTypeSniffer.resolve(header: header, name: name),
      fileSize: await file.length(),
      filePath: path,
    );
  }
}

/// A pasted picture in a form the server takes.
@immutable
class ClipboardImage {
  const ClipboardImage({
    required this.bytes,
    required this.mimeType,
    required this.extension,
  });

  final Uint8List bytes;
  final String mimeType;
  final String extension;

  /// [raw] as it is when it is already a format the server accepts
  /// (api-docs §5.5: jpeg, png, gif, webp, heic, heif), re-encoded as PNG
  /// otherwise — Windows hands over a bitmap, Linux whatever the copying app
  /// offered. Null when the bytes are not a picture at all.
  ///
  /// Pure and synchronous, so it can run in a background isolate: decoding
  /// a 4K screenshot is not something to do between two frames.
  static ClipboardImage? normalize(Uint8List raw) {
    final sniffed = MediaTypeSniffer.sniff(
      raw.length > MediaTypeSniffer.headerLength
          ? raw.sublist(0, MediaTypeSniffer.headerLength)
          : raw,
    );
    if (sniffed != null &&
        ChatAttachmentLimits.imageMimeTypes.contains(sniffed)) {
      return ClipboardImage(
        bytes: raw,
        mimeType: sniffed,
        extension: _extensions[sniffed] ?? 'png',
      );
    }

    final decoded = img.decodeImage(raw);
    if (decoded == null) return null;

    return ClipboardImage(
      bytes: img.encodePng(decoded),
      mimeType: 'image/png',
      extension: 'png',
    );
  }

  /// "image_20261012_140305.png": what a pasted picture is called if it
  /// is sent as a file, and what the preview shows under it.
  static String fileNameFor(DateTime at, String extension) {
    String two(int value) => value.toString().padLeft(2, '0');
    final date = '${at.year}${two(at.month)}${two(at.day)}';
    final time = '${two(at.hour)}${two(at.minute)}${two(at.second)}';
    return 'image_${date}_$time.$extension';
  }

  static const Map<String, String> _extensions = {
    'image/jpeg': 'jpg',
    'image/png': 'png',
    'image/gif': 'gif',
    'image/webp': 'webp',
    'image/heic': 'heic',
    'image/heif': 'heif',
  };
}
