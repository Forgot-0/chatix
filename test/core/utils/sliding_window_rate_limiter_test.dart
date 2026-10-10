import 'package:flutter_test/flutter_test.dart';

import 'package:chatix/core/utils/sliding_window_rate_limiter.dart';

/// "60 a minute", counted on the client so the server never has to say it.
void main() {
  final t0 = DateTime.utc(2026, 10, 11, 9);
  DateTime at(int seconds) => t0.add(Duration(seconds: seconds));

  SlidingWindowRateLimiter limiter() =>
      SlidingWindowRateLimiter(capacity: 3, window: const Duration(minutes: 1));

  test('waits for nothing while there is room', () {
    final l = limiter()
      ..record(at(0))
      ..record(at(1));

    expect(l.delayFor(at(2)), Duration.zero);
  });

  test('a full window waits until its oldest request ages out', () {
    final l = limiter()
      ..record(at(0))
      ..record(at(10))
      ..record(at(20));

    expect(l.delayFor(at(30)), const Duration(seconds: 30));
    expect(l.delayFor(at(60)), Duration.zero);
  });

  test('a reserve leaves room for writers that will not wait', () {
    final l = limiter()
      ..record(at(0))
      ..record(at(10));

    expect(l.delayFor(at(20)), Duration.zero);
    expect(l.delayFor(at(20), reserve: 1), const Duration(seconds: 40));
  });

  test('a 429 blocks a whole window, whatever the count says', () {
    final l = limiter()..blockFor(at(0));

    expect(l.delayFor(at(1)), const Duration(seconds: 59));
    expect(l.delayFor(at(60)), Duration.zero);
  });

  test('only the last window counts', () {
    final l = limiter()
      ..record(at(0))
      ..record(at(30))
      ..record(at(61));

    expect(l.sentIn(at(61)), 2);
  });
}
