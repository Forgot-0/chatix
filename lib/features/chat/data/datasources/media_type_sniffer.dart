import 'dart:convert';

import 'package:chatix/features/chat/domain/entities/chat_attachment_limits.dart';

/// What a picked photo or video really is, read off its first bytes.
///
/// The server compares the MIME type it is handed with the file's magic
/// bytes and fails the attachment when they disagree (api-docs §5.5) — after
/// the upload, as `attachment_status: "error"`, with no reason given. The
/// name is a guess and the platform's own answer is often missing for videos
/// (`XFile.mimeType` is null on most of them), so the bytes come first.
abstract final class MediaTypeSniffer {
  /// Enough for every signature below, including the ISO media `ftyp` box
  /// and the first few of its compatible brands.
  static const int headerLength = 64;

  /// The MIME type the [header] bytes belong to, or null when they are not a
  /// photo or video format this knows.
  static String? sniff(List<int> header) {
    if (_startsWith(header, const [0xFF, 0xD8, 0xFF])) return 'image/jpeg';
    if (_startsWith(header, const [
      0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, //
    ])) {
      return 'image/png';
    }
    if (_ascii(header, 0, 6) case 'GIF87a' || 'GIF89a') return 'image/gif';

    if (_ascii(header, 0, 4) == 'RIFF') {
      return switch (_ascii(header, 8, 12)) {
        'WEBP' => 'image/webp',
        'AVI ' => 'video/x-msvideo',
        _ => null,
      };
    }

    // EBML: Matroska, of which WebM is the subset the server takes. The
    // DocType sits in the first few dozen bytes.
    if (_startsWith(header, const [0x1A, 0x45, 0xDF, 0xA3])) {
      final head = _ascii(header, 0, header.length);
      if (head.contains('webm')) return 'video/webm';
      if (head.contains('matroska')) return 'video/x-matroska';
      return null;
    }

    if (_ascii(header, 4, 8) == 'ftyp') return _isoMedia(header);

    return null;
  }

  /// The type to declare for a picked file: its bytes when they say, then
  /// what the platform reported if it is one the server takes, then the
  /// file's name.
  static String resolve({
    required List<int> header,
    String? reported,
    required String name,
  }) {
    final sniffed = sniff(header);
    if (sniffed != null) return sniffed;

    final platform = reported?.trim().toLowerCase();
    if (platform != null && ChatAttachmentLimits.typeOf(platform) != null) {
      return platform;
    }

    return ChatAttachmentLimits.mimeFromName(name);
  }

  /// An ISO base media file — MP4, QuickTime, HEIF — by its brands: the
  /// major one, then the compatible ones that follow it.
  static String? _isoMedia(List<int> header) {
    final size = header.length >= 4
        ? (header[0] << 24) | (header[1] << 16) | (header[2] << 8) | header[3]
        : 0;
    final end = size >= 16 && size <= header.length ? size : header.length;

    final brands = <String>[
      _ascii(header, 8, 12),
      for (var at = 16; at + 4 <= end; at += 4) _ascii(header, at, at + 4),
    ];

    for (final brand in brands) {
      final type = switch (brand) {
        'qt  ' => 'video/quicktime',
        'heic' ||
        'heix' ||
        'hevc' ||
        'hevx' ||
        'heim' ||
        'heis' => 'image/heic',
        'mif1' || 'msf1' || 'heif' => 'image/heif',
        'avif' || 'avis' => 'image/avif',
        'isom' || 'iso2' || 'iso4' || 'iso5' || 'iso6' => 'video/mp4',
        'mp41' || 'mp42' || 'mp71' || 'avc1' || 'dash' || 'M4V ' => 'video/mp4',
        'mmp4' || 'MSNV' || 'f4v ' => 'video/mp4',
        '3gp4' || '3gp5' || '3gp6' || '3g2a' => 'video/3gpp',
        _ => null,
      };
      if (type != null) return type;
    }
    return null;
  }

  static bool _startsWith(List<int> bytes, List<int> prefix) {
    if (bytes.length < prefix.length) return false;
    for (var i = 0; i < prefix.length; i++) {
      if (bytes[i] != prefix[i]) return false;
    }
    return true;
  }

  static String _ascii(List<int> bytes, int start, int end) {
    if (start >= bytes.length) return '';
    final stop = end > bytes.length ? bytes.length : end;
    return latin1.decode(bytes.sublist(start, stop), allowInvalid: true);
  }
}
