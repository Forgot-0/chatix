import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:chatix/core/storage/device_file_saver.dart';

void main() {
  late Directory target;
  late Directory source;

  setUp(() {
    target = Directory.systemTemp.createTempSync('saver_target');
    source = Directory.systemTemp.createTempSync('saver_source');
  });

  tearDown(() {
    for (final directory in [target, source]) {
      if (directory.existsSync()) directory.deleteSync(recursive: true);
    }
  });

  File fileOf(String name, List<int> bytes) =>
      File('${source.path}/$name')..writeAsBytesSync(bytes);

  DeviceFileSaver saverOf() =>
      DeviceFileSaver(targetDirectory: () async => target);

  group('names', () {
    test('a path is reduced to its last segment', () {
      expect(DeviceFileSaver.sanitize('a/b/c/holiday.jpg'), 'holiday.jpg');
      expect(DeviceFileSaver.sanitize(r'a\b\holiday.jpg'), 'holiday.jpg');
    });

    test('a name that is nothing but dots cannot climb out of the folder', () {
      expect(DeviceFileSaver.sanitize('..'), 'attachment');
      expect(DeviceFileSaver.sanitize('...hidden.txt'), 'hidden.txt');
    });

    test('characters no filesystem accepts are replaced', () {
      expect(DeviceFileSaver.sanitize('in<va>lid:name?.txt'), isNot(contains('<')));
      expect(DeviceFileSaver.sanitize('in<va>lid:name?.txt'), endsWith('.txt'));
    });

    test('an empty name still gives something to write', () {
      expect(DeviceFileSaver.sanitize('   '), 'attachment');
    });

    test('a very long name is cut to something writable', () {
      final name = '${'a' * 400}.jpg';

      expect(DeviceFileSaver.sanitize(name).length, lessThanOrEqualTo(120));
    });
  });

  group('saving', () {
    test('copies the bytes where the reader can find them', () async {
      final saved = await saverOf().save(
        source: fileOf('holiday.jpg', [1, 2, 3]),
        filename: 'holiday.jpg',
      );

      expect(saved.path, '${target.path}/holiday.jpg');
      expect(await saved.readAsBytes(), [1, 2, 3]);
    });

    test('never overwrites: a second copy is numbered', () async {
      final saver = saverOf();
      await saver.save(
        source: fileOf('holiday.jpg', [1]),
        filename: 'holiday.jpg',
      );

      final second = await saver.save(
        source: fileOf('other.jpg', [2]),
        filename: 'holiday.jpg',
      );

      expect(second.path, '${target.path}/holiday (1).jpg');
      expect(await second.readAsBytes(), [2]);
      expect(
        await File('${target.path}/holiday.jpg').readAsBytes(),
        [1],
        reason: 'the first copy is untouched',
      );
    });

    test('creates the folder when it is not there yet', () async {
      final missing = Directory('${target.path}/downloads');
      final saver = DeviceFileSaver(targetDirectory: () async => missing);

      final saved = await saver.save(
        source: fileOf('note.txt', [7]),
        filename: 'note.txt',
      );

      expect(saved.existsSync(), isTrue);
    });
  });
}
