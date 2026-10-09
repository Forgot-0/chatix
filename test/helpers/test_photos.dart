import 'dart:io';
import 'dart:typed_data';

/// Small, deterministic stand-ins for photos, written to disk as PNGs.
///
/// Goldens of the feed need pictures that read as pictures — a flat square
/// does not show whether a portrait was cropped or squashed — and they have
/// to come out byte-identical on every run, so nothing here is random and
/// nothing is fetched. Each one is a sky-to-ground gradient with a sun on it:
/// enough shape to see the framing, cheap to encode.
abstract final class TestPhotos {
  /// Writes a [width] × [height] picture into [directory] and returns it.
  ///
  /// [palette] picks one of a handful of colourings, so neighbouring tiles
  /// of an album are told apart at a glance.
  static File write(
    Directory directory, {
    required String name,
    required int width,
    required int height,
    int palette = 0,
  }) {
    final file = File('${directory.path}/$name.png');
    file.writeAsBytesSync(encode(width, height, palette: palette));
    return file;
  }

  static const List<(int, int, int, int, int, int)> _palettes = [
    // sky                ground
    (0x8E, 0xC5, 0xFF, 0x2F, 0x6B, 0x4F),
    (0xFF, 0xB3, 0x8A, 0x5A, 0x3A, 0x7A),
    (0x9C, 0xE6, 0xD8, 0x1F, 0x4E, 0x6E),
    (0xF6, 0xD3, 0x65, 0x8A, 0x4B, 0x2B),
    (0xC9, 0xB8, 0xFF, 0x3B, 0x2F, 0x63),
  ];

  /// The PNG bytes of the picture [write] puts on disk.
  static Uint8List encode(int width, int height, {int palette = 0}) {
    final (sr, sg, sb, gr, gg, gb) = _palettes[palette % _palettes.length];

    final horizon = (height * 0.62).round();
    final sunX = width * 0.68;
    final sunY = height * 0.34;
    final sunR = (width < height ? width : height) * 0.14;

    // One filter byte per row, then RGB.
    final raw = BytesBuilder();
    for (var y = 0; y < height; y++) {
      raw.addByte(0);
      for (var x = 0; x < width; x++) {
        final dx = x - sunX;
        final dy = y - sunY;
        if (dx * dx + dy * dy <= sunR * sunR) {
          raw.add(const [0xFF, 0xF4, 0xD6]);
          continue;
        }

        final t = y / height;
        if (y < horizon) {
          raw.add([
            _shade(sr, 1.1 - t * 0.4),
            _shade(sg, 1.1 - t * 0.4),
            _shade(sb, 1.1 - t * 0.4),
          ]);
        } else {
          raw.add([
            _shade(gr, 1.3 - t * 0.5),
            _shade(gg, 1.3 - t * 0.5),
            _shade(gb, 1.3 - t * 0.5),
          ]);
        }
      }
    }

    final header = ByteData(13)
      ..setUint32(0, width)
      ..setUint32(4, height)
      ..setUint8(8, 8) // bit depth
      ..setUint8(9, 2) // colour type: RGB
      ..setUint8(10, 0)
      ..setUint8(11, 0)
      ..setUint8(12, 0);

    return (BytesBuilder()
          ..add(const [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])
          ..add(_chunk('IHDR', header.buffer.asUint8List()))
          ..add(
            _chunk('IDAT', Uint8List.fromList(zlib.encode(raw.takeBytes()))),
          )
          ..add(_chunk('IEND', Uint8List(0))))
        .takeBytes();
  }

  static int _shade(int channel, double factor) =>
      (channel * factor).round().clamp(0, 255);

  static Uint8List _chunk(String type, Uint8List data) {
    final typeBytes = Uint8List.fromList(type.codeUnits);
    final length = ByteData(4)..setUint32(0, data.length);
    final crc = ByteData(4)
      ..setUint32(0, _crc32(Uint8List.fromList([...typeBytes, ...data])));

    return (BytesBuilder()
          ..add(length.buffer.asUint8List())
          ..add(typeBytes)
          ..add(data)
          ..add(crc.buffer.asUint8List()))
        .takeBytes();
  }

  static final List<int> _crcTable = List<int>.generate(256, (n) {
    var c = n;
    for (var k = 0; k < 8; k++) {
      c = (c & 1) != 0 ? 0xEDB88320 ^ (c >> 1) : c >> 1;
    }
    return c;
  });

  static int _crc32(Uint8List bytes) {
    var crc = 0xFFFFFFFF;
    for (final byte in bytes) {
      crc = _crcTable[(crc ^ byte) & 0xFF] ^ (crc >> 8);
    }
    return crc ^ 0xFFFFFFFF;
  }
}
