import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import 'package:chatix/features/chat/data/datasources/photo_compressor.dart';
import 'package:chatix/features/chat/domain/entities/attachment_entity.dart';
import 'package:chatix/features/chat/domain/entities/photo_compression.dart';

/// A photo goes out at most 2560 px on its long side, upright, without its
/// EXIF (location included), as JPEG.
void main() {
  Uint8List jpeg(
    int width,
    int height, {
    int? orientation,
    bool withGps = false,
  }) {
    final image = img.Image(width: width, height: height);
    img.fill(image, color: img.ColorRgb8(30, 120, 200));
    // A red corner, to tell which way the picture ends up.
    img.fillRect(
      image,
      x1: 0,
      y1: 0,
      x2: width ~/ 4,
      y2: height ~/ 4,
      color: img.ColorRgb8(255, 0, 0),
    );
    if (orientation != null) image.exif.imageIfd.orientation = orientation;
    if (withGps) {
      image.exif.gpsIfd['GPSLatitudeRef'] = img.IfdValueAscii('N');
      image.exif.gpsIfd['GPSLatitude'] = img.IfdValueRational(55, 1);
    }
    return img.encodeJpg(image, quality: 95);
  }

  test('a big photo comes out with its long side at the cap', () {
    final source = jpeg(4000, 3000);

    final prepared = preparePhoto(source)!;

    expect(prepared.width, PhotoCompression.maxSide);
    expect(prepared.height, 1920);
    expect(prepared.bytes.length, lessThan(source.length));
    expect(img.decodeJpg(prepared.bytes)!.width, PhotoCompression.maxSide);
  });

  test('a portrait is capped on its height', () {
    final prepared = preparePhoto(jpeg(1500, 3000))!;

    expect(prepared.height, PhotoCompression.maxSide);
    expect(prepared.width, 1280);
  });

  test('a small photo is never blown up', () {
    final prepared = preparePhoto(jpeg(800, 600))!;

    expect((prepared.width, prepared.height), (800, 600));
  });

  test('the orientation tag is turned into the pixels', () {
    // 6: stored sideways, to be turned 90° clockwise for display.
    final prepared = preparePhoto(jpeg(400, 200, orientation: 6))!;
    final out = img.decodeJpg(prepared.bytes)!;

    expect((out.width, out.height), (200, 400));
    expect(out.exif.imageIfd.hasOrientation, isFalse);
    // The red corner, top-left before, is top-right once upright.
    final corner = out.getPixel(out.width - 5, 5);
    expect(corner.r, greaterThan(200));
    expect(corner.b, lessThan(80));
  });

  test('the location and every other EXIF field are gone', () {
    final source = jpeg(300, 200, withGps: true);
    expect(img.decodeJpg(source)!.exif.gpsIfd.isEmpty, isFalse);

    final out = img.decodeJpg(preparePhoto(source)!.bytes)!;

    expect(out.exif.gpsIfd.isEmpty, isTrue);
    expect(out.exif.isEmpty, isTrue);
  });

  test('transparency becomes white, not black', () {
    final image = img.Image(width: 20, height: 20, numChannels: 4);
    img.fill(image, color: img.ColorRgba8(0, 0, 0, 0));
    final png = img.encodePng(image);

    final out = img.decodeJpg(preparePhoto(png)!.bytes)!;

    expect(out.getPixel(10, 10).r, greaterThan(240));
  });

  test('bytes that are no photo are left alone', () {
    expect(preparePhoto(Uint8List.fromList([1, 2, 3, 4])), isNull);
  });

  group('in a background isolate', () {
    late Directory dir;

    setUp(() => dir = Directory.systemTemp.createTempSync('chatix_photo_'));
    tearDown(() => dir.deleteSync(recursive: true));

    AttachmentUploadRequestEntity picked(
      String name,
      List<int> bytes, {
      String mime = 'image/jpeg',
    }) {
      final file = File('${dir.path}/$name')..writeAsBytesSync(bytes);
      return AttachmentUploadRequestEntity(
        filename: name,
        mimeType: mime,
        fileSize: bytes.length,
        filePath: file.path,
      );
    }

    test(
      'a photo comes back as a smaller JPEG file, capped and clean',
      () async {
        final source = jpeg(3200, 2400, withGps: true);
        final progress = <double>[];

        final result = await IsolatePhotoCompressor(
          outputDirectory: Directory('${dir.path}/out'),
        ).compress(picked('IMG_1.png', source), onProgress: progress.add);

        expect(result, isNotNull);
        expect(result!.mimeType, 'image/jpeg');
        expect(result.filename, 'IMG_1.jpg');
        final bytes = File(result.filePath!).readAsBytesSync();
        expect(result.fileSize, bytes.length);
        expect(result.fileSize, lessThan(source.length));

        final out = img.decodeJpg(bytes)!;
        expect(out.width, PhotoCompression.maxSide);
        expect(out.exif.gpsIfd.isEmpty, isTrue);
        expect(progress.last, 1);
      },
    );

    test('HEIC goes through the platform decoder and comes out JPEG', () async {
      // Bytes no Dart decoder reads; the "platform" hands back pixels.
      final result = await IsolatePhotoCompressor(
        outputDirectory: Directory('${dir.path}/out'),
        platformDecoder: (bytes, maxSide) async => (
          rgba: Uint8List(8 * 6 * 4)..fillRange(0, 8 * 6 * 4, 200),
          width: 8,
          height: 6,
        ),
      ).compress(picked('IMG_2.HEIC', _heifStub, mime: 'image/heic'));

      expect(result?.mimeType, 'image/jpeg');
      expect(result?.filename, 'IMG_2.jpg');
      expect(
        img.decodeJpg(File(result!.filePath!).readAsBytesSync())!.width,
        8,
      );
    });

    test('what nothing can decode is sent as it is', () async {
      final result = await IsolatePhotoCompressor(
        outputDirectory: Directory('${dir.path}/out'),
        platformDecoder: (bytes, maxSide) async => null,
      ).compress(picked('broken.jpg', [1, 2, 3]));

      expect(result, isNull);
    });

    test('a GIF or a video is not touched', () async {
      final compressor = IsolatePhotoCompressor(
        outputDirectory: Directory('${dir.path}/out'),
      );

      expect(
        await compressor.compress(picked('a.gif', [1], mime: 'image/gif')),
        isNull,
      );
      expect(
        await compressor.compress(picked('a.mp4', [1], mime: 'video/mp4')),
        isNull,
      );
    });
  });

  test('progress only moves forward and ends at one', () {
    final steps = <double>[];
    preparePhoto(jpeg(100, 100), onProgress: steps.add);

    expect(steps, isNotEmpty);
    expect(steps.last, 1);
    for (var i = 1; i < steps.length; i++) {
      expect(steps[i], greaterThanOrEqualTo(steps[i - 1]));
    }
  });
}

/// The opening of an ISO box no Dart decoder reads: "....ftyp".
const List<int> _heifStub = [0, 0, 0, 24, 0x66, 0x74, 0x79, 0x70];
