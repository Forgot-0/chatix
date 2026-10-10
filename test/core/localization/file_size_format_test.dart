import 'package:flutter_test/flutter_test.dart';

import 'package:chatix/core/localization/file_size_format.dart';
import 'package:chatix/gen/l10n/app_localizations_en.dart';
import 'package:chatix/gen/l10n/app_localizations_ru.dart';

void main() {
  final en = AppLocalizationsEn();
  final ru = AppLocalizationsRu();

  String inEnglish(int bytes) => formatFileSize(bytes, en, locale: 'en');
  String inRussian(int bytes) => formatFileSize(bytes, ru, locale: 'ru');

  const kb = 1024;
  const mb = 1024 * kb;

  test('bytes, kilobytes, megabytes and gigabytes, each in its units', () {
    expect(inEnglish(512), '512 B');
    expect(inEnglish(48 * kb), '48 KB');
    expect(inEnglish(2 * mb), '2.0 MB');
    expect(inEnglish(3 * 1024 * mb), '3.0 GB');

    expect(inRussian(512), '512 Б');
    expect(inRussian(48 * kb), '48 КБ');
    expect(inRussian(2 * mb), '2,0 МБ');
    expect(inRussian(3 * 1024 * mb), '3,0 ГБ');
  });

  test('a megabyte and up carries one decimal, a kilobyte none', () {
    expect(inEnglish(1536 * kb), '1.5 MB');
    expect(inEnglish(1536), '2 KB');
  });

  test('rounding never prints the next unit in disguise', () {
    // 1023.6 KB would round to "1024 KB".
    expect(inEnglish(1048166), '1.0 MB');
    // 1023.96 MB would round to "1024.0 MB".
    expect(inEnglish(1073700000), '1.0 GB');
    expect(inEnglish(1023), '1023 B');
    expect(inEnglish(1024), '1 KB');
  });

  test('nothing is never negative', () {
    expect(inEnglish(0), '0 B');
    expect(inEnglish(-5), '0 B');
  });

  test('an unknown locale still gets digits', () {
    expect(formatFileSize(2 * mb, en, locale: 'xx'), '2.0 MB');
  });
}
