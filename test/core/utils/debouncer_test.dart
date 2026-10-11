import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chatix/core/utils/debouncer.dart';

void main() {
  const delay = Duration(milliseconds: 300);

  test('a burst runs once, a full delay after its last call', () {
    fakeAsync((async) {
      final debouncer = Debouncer(delay);
      final runs = <String>[];

      for (final query in ['i', 'iv', 'iva', 'ivan']) {
        debouncer.run(() => runs.add(query));
        async.elapse(const Duration(milliseconds: 120));
      }
      expect(runs, isEmpty);

      // 120 ms have passed since "ivan"; 179 more is still short of 300.
      async.elapse(const Duration(milliseconds: 179));
      expect(runs, isEmpty);
      expect(debouncer.isPending, isTrue);

      async.elapse(const Duration(milliseconds: 1));
      expect(runs, ['ivan']);
      expect(debouncer.isPending, isFalse);
    });
  });

  test('cancel drops what was waiting', () {
    fakeAsync((async) {
      final debouncer = Debouncer(delay);
      var ran = false;

      debouncer.run(() => ran = true);
      debouncer.cancel();
      async.elapse(delay * 2);

      expect(ran, isFalse);
    });
  });

  test('runNow skips the wait and the waiting action', () {
    fakeAsync((async) {
      final debouncer = Debouncer(delay);
      final runs = <String>[];

      debouncer.run(() => runs.add('late'));
      debouncer.runNow(() => runs.add('now'));
      async.elapse(delay * 2);

      expect(runs, ['now']);
    });
  });
}
