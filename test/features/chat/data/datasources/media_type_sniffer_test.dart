import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';

import 'package:chatix/features/chat/data/datasources/media_type_sniffer.dart';
import 'package:chatix/features/chat/domain/entities/attachment_entity.dart';
import 'package:chatix/features/chat/presentation/utils/chat_attachment_picker.dart';

/// The server checks the declared MIME against the file's magic bytes
/// (api-docs §5.5), so a picked file's type is read from those bytes —
/// above all for videos, which the platform pickers mostly leave untyped.
void main() {
  /// An ISO media file's opening `ftyp` box with [major] and [compatible]
  /// brands, as an MP4, a QuickTime movie or a HEIF photo starts.
  List<int> ftyp(String major, [List<String> compatible = const []]) {
    final body = [
      ...ascii.encode('ftyp'),
      ...ascii.encode(major),
      0, 0, 0, 0, // minor version
      for (final brand in compatible) ...ascii.encode(brand),
    ];
    final size = body.length + 4;
    return [
      (size >> 24) & 0xFF,
      (size >> 16) & 0xFF,
      (size >> 8) & 0xFF,
      size & 0xFF,
      ...body,
      // The next box, which must not be read as a brand.
      0, 0, 0, 8, ...ascii.encode('mdat'),
    ];
  }

  group('sniff', () {
    test('photos', () {
      expect(
        MediaTypeSniffer.sniff([0xFF, 0xD8, 0xFF, 0xE1, 0, 0]),
        'image/jpeg',
      );
      expect(
        MediaTypeSniffer.sniff([
          0x89,
          0x50,
          0x4E,
          0x47,
          0x0D,
          0x0A,
          0x1A,
          0x0A,
        ]),
        'image/png',
      );
      expect(MediaTypeSniffer.sniff(ascii.encode('GIF89a......')), 'image/gif');
      expect(
        MediaTypeSniffer.sniff([
          ...ascii.encode('RIFF'),
          0,
          0,
          0,
          0,
          ...ascii.encode('WEBPVP8 '),
        ]),
        'image/webp',
      );
      expect(
        MediaTypeSniffer.sniff(ftyp('heic', ['mif1', 'heic'])),
        'image/heic',
      );
      expect(MediaTypeSniffer.sniff(ftyp('mif1', ['heic'])), 'image/heif');
    });

    test('videos', () {
      expect(
        MediaTypeSniffer.sniff(ftyp('isom', ['isom', 'mp42'])),
        'video/mp4',
      );
      expect(MediaTypeSniffer.sniff(ftyp('mp42', ['mp41'])), 'video/mp4');
      expect(MediaTypeSniffer.sniff(ftyp('qt  ', ['qt  '])), 'video/quicktime');
      expect(
        MediaTypeSniffer.sniff([
          ...ascii.encode('RIFF'),
          0,
          0,
          0,
          0,
          ...ascii.encode('AVI LIST'),
        ]),
        'video/x-msvideo',
      );
      expect(
        MediaTypeSniffer.sniff([
          0x1A,
          0x45,
          0xDF,
          0xA3,
          0x9F,
          0x42,
          0x82,
          0x84,
          ...ascii.encode('webm'),
        ]),
        'video/webm',
      );
    });

    test('an unknown major brand is decided by the compatible ones', () {
      expect(MediaTypeSniffer.sniff(ftyp('XAVC', ['qt  '])), 'video/quicktime');
      expect(MediaTypeSniffer.sniff(ftyp('XXXX', ['avc1'])), 'video/mp4');
    });

    test('a format the server refuses is named, so it is refused up front', () {
      // Matroska and 3GP are not on the server's list (api-docs §5.5).
      expect(
        MediaTypeSniffer.sniff([
          0x1A,
          0x45,
          0xDF,
          0xA3,
          0x9F,
          0x42,
          0x82,
          0x88,
          ...ascii.encode('matroska'),
        ]),
        'video/x-matroska',
      );
      expect(MediaTypeSniffer.sniff(ftyp('3gp5')), 'video/3gpp');
    });

    test('anything else, or too little to tell, is unknown', () {
      expect(MediaTypeSniffer.sniff(const []), isNull);
      expect(MediaTypeSniffer.sniff(const [0xFF]), isNull);
      expect(MediaTypeSniffer.sniff(ascii.encode('%PDF-1.7')), isNull);
    });
  });

  group('resolve', () {
    test('the bytes beat the name', () {
      expect(
        MediaTypeSniffer.resolve(
          header: ftyp('qt  '),
          reported: null,
          name: 'clip.mp4',
        ),
        'video/quicktime',
      );
    });

    test('without telling bytes, the platform\'s word counts if the server '
        'takes it', () {
      expect(
        MediaTypeSniffer.resolve(
          header: const [],
          reported: 'video/mp4',
          name: 'clip',
        ),
        'video/mp4',
      );
      expect(
        MediaTypeSniffer.resolve(
          header: const [],
          reported: 'application/octet-stream',
          name: 'clip.mov',
        ),
        'video/quicktime',
      );
    });
  });

  group('a picked file becomes an upload', () {
    test(
      'a video with no type from the platform is typed by its bytes',
      () async {
        final bytes = Uint8List.fromList([
          ...ftyp('isom', ['mp42']),
          ...List.filled(200, 0),
        ]);
        final file = XFile.fromData(bytes, name: 'VID_0001', path: 'VID_0001');

        final upload = await ChatAttachmentPicker.uploadOf(file);

        expect(upload.mimeType, 'video/mp4');
        expect(upload.resolvedType, AttachmentType.video);
        expect(upload.fileSize, bytes.length);
        expect(upload.filename, 'VID_0001');
      },
    );

    test('a photo the platform mislabelled keeps its real type', () async {
      final bytes = Uint8List.fromList([
        0xFF,
        0xD8,
        0xFF,
        0xE0,
        ...List.filled(100, 0),
      ]);
      final file = XFile.fromData(
        bytes,
        name: 'IMG_0002.png',
        mimeType: 'image/png',
      );

      final upload = await ChatAttachmentPicker.uploadOf(file);

      expect(upload.mimeType, 'image/jpeg');
      expect(upload.resolvedType, AttachmentType.image);
    });
  });
}
