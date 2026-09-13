import 'package:flutter_test/flutter_test.dart';

import 'package:chatix/features/chat/domain/entities/message_limits.dart';
import 'package:chatix/features/chat/domain/usecases/send_message_use_case.dart';

/// 4096 characters is what `SendMessageRequest.content` takes, and anything
/// past it is `400 MESSAGE_TOO_LONG` (api-docs §5.4). The composer counts
/// against this itself so nobody watches a long message vanish into a 400.
void main() {
  group('the cap', () {
    test('is the documented one, and the use case shares it', () {
      expect(MessageLimits.maxContentLength, 4096);
      expect(SendMessageUseCase.maxContentLength, 4096);
    });

    test('isOverLimit trips one character past it, not at it', () {
      expect(MessageLimits.isOverLimit(4095), isFalse);
      expect(MessageLimits.isOverLimit(4096), isFalse);
      expect(MessageLimits.isOverLimit(4097), isTrue);
    });
  });

  group('the counter', () {
    test('stays out of the way of an ordinary message', () {
      expect(MessageLimits.showsCounter(0), isFalse);
      expect(MessageLimits.showsCounter(3799), isFalse);
    });

    test('appears at 3800 and stays', () {
      expect(MessageLimits.counterVisibleFrom, 3800);
      expect(MessageLimits.showsCounter(3800), isTrue);
      expect(MessageLimits.showsCounter(5000), isTrue);
    });

    test('counts what is left, and never below zero', () {
      expect(MessageLimits.remaining(3800), 296);
      expect(MessageLimits.remaining(4096), 0);
      expect(MessageLimits.remaining(4200), 0);
    });
  });

  group('pressure — how red the counter goes', () {
    test('is nothing until the counter is on screen', () {
      expect(MessageLimits.pressure(0), 0);
      expect(MessageLimits.pressure(3800), 0);
    });

    test('is full at the cap and stays full past it', () {
      expect(MessageLimits.pressure(4096), 1);
      expect(MessageLimits.pressure(9000), 1);
    });

    test('climbs in between', () {
      final half = MessageLimits.pressure(3948);

      expect(half, greaterThan(0.45));
      expect(half, lessThan(0.55));
      expect(
        MessageLimits.pressure(4000),
        greaterThan(MessageLimits.pressure(3900)),
      );
    });
  });
}
