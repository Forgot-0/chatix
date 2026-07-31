import 'package:flutter_test/flutter_test.dart';
import 'package:chatix/core/models/page_result.dart';

void main() {
  group('PageResult', () {
    test('computes totalPages by rounding up, not down', () {
      const page = PageResult<int>(items: [], total: 41, page: 1, pageSize: 20);
      expect(page.totalPages, 3);
    });

    test('hasNext is true while page < totalPages', () {
      const page = PageResult<int>(items: [], total: 41, page: 2, pageSize: 20);
      expect(page.totalPages, 3);
      expect(page.hasNext, isTrue);
    });

    test('hasNext is false on the last page', () {
      const page = PageResult<int>(items: [], total: 41, page: 3, pageSize: 20);
      expect(page.hasNext, isFalse);
    });

    test('hasPrevious is false on page 1 and true afterwards', () {
      const firstPage = PageResult<int>(items: [], total: 41, page: 1, pageSize: 20);
      const secondPage = PageResult<int>(items: [], total: 41, page: 2, pageSize: 20);
      expect(firstPage.hasPrevious, isFalse);
      expect(secondPage.hasPrevious, isTrue);
    });

    test('totalPages is 0 (not a crash) when pageSize is non-positive', () {
      const page = PageResult<int>(items: [], total: 10, page: 1, pageSize: 0);
      expect(page.totalPages, 0);
    });

    test('fromJson parses only the 4 documented fields (api-docs §1.5)', () {
      final json = {
        'items': [1, 2, 3],
        'total': 3,
        'page': 1,
        'page_size': 20,
        // Server never actually sends these (api-docs §0.3) — fromJson
        // must not depend on them being present.
      };

      final page = PageResult<int>.fromJson(json, (e) => e as int);

      expect(page.items, [1, 2, 3]);
      expect(page.total, 3);
      expect(page.page, 1);
      expect(page.pageSize, 20);
      expect(page.totalPages, 1);
    });

    test('map() transforms items and keeps pagination metadata', () {
      const page = PageResult<int>(items: [1, 2, 3], total: 3, page: 1, pageSize: 20);

      final mapped = page.map((item) => item.toString());

      expect(mapped.items, ['1', '2', '3']);
      expect(mapped.total, 3);
      expect(mapped.page, 1);
      expect(mapped.pageSize, 20);
    });
  });
}
