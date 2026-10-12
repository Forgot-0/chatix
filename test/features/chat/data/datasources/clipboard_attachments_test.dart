import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import 'package:chatix/features/chat/data/datasources/clipboard_attachments.dart';

void main() {
  img.Image picture() =>
      img.Image(width: 4, height: 3)..clear(img.ColorRgb8(120, 80, 200));

  group('ClipboardImage.normalize', () {
    test('keeps a PNG as it is', () {
      final png = img.encodePng(picture());

      final image = ClipboardImage.normalize(png)!;

      expect(image.mimeType, 'image/png');
      expect(image.extension, 'png');
      expect(image.bytes, same(png));
    });

    test('keeps a JPEG as it is', () {
      final jpeg = img.encodeJpg(picture());

      final image = ClipboardImage.normalize(jpeg)!;

      expect(image.mimeType, 'image/jpeg');
      expect(image.extension, 'jpg');
    });

    test('turns a Windows bitmap into a PNG the server takes', () {
      // What `pasteboard` hands over on Windows: a BMP, which is not on the
      // server's list (api-docs §5.5).
      final bmp = img.encodeBmp(picture());

      final image = ClipboardImage.normalize(bmp)!;

      expect(image.mimeType, 'image/png');
      expect(image.extension, 'png');
      final decoded = img.decodePng(image.bytes)!;
      expect((decoded.width, decoded.height), (4, 3));
    });

    test('has nothing to give for bytes that are not a picture', () {
      expect(
        ClipboardImage.normalize(Uint8List.fromList(List.filled(64, 7))),
        isNull,
      );
    });
  });

  test('a pasted picture is named after the moment it was pasted', () {
    expect(
      ClipboardImage.fileNameFor(DateTime(2026, 10, 2, 9, 5, 7), 'png'),
      'image_20261002_090507.png',
    );
  });

  group('LocalFileUploads', () {
    late Directory dir;

    setUp(() => dir = Directory.systemTemp.createTempSync('chatix_paste'));
    tearDown(() {
      try {
        dir.deleteSync(recursive: true);
      } on FileSystemException {
        // Windows may still hold a handle for a moment.
      }
    });

    test('reads the type off the bytes, not the name', () async {
      final file = File('${dir.path}${Platform.pathSeparator}photo.bin')
        ..writeAsBytesSync(img.encodePng(picture()));

      final upload = await LocalFileUploads.of(file.path);

      expect(upload.filename, 'photo.bin');
      expect(upload.mimeType, 'image/png');
      expect(upload.fileSize, file.lengthSync());
      expect(upload.filePath, file.path);
    });

    test('leaves folders and vanished files out, keeps the order', () async {
      final first = File('${dir.path}${Platform.pathSeparator}a.png')
        ..writeAsBytesSync(img.encodePng(picture()));
      final folder = Directory('${dir.path}${Platform.pathSeparator}folder')
        ..createSync();
      final second = File('${dir.path}${Platform.pathSeparator}b.pdf')
        ..writeAsStringSync('%PDF-1.4');

      final uploads = await LocalFileUploads.ofAll([
        first.path,
        folder.path,
        '${dir.path}${Platform.pathSeparator}gone.png',
        second.path,
      ]);

      expect(uploads.map((upload) => upload.filename), ['a.png', 'b.pdf']);
      expect(uploads.last.mimeType, 'application/pdf');
    });
  });
}
