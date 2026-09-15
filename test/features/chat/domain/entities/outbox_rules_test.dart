import 'package:flutter_test/flutter_test.dart';

import 'package:chatix/core/error/failures.dart';
import 'package:chatix/features/chat/domain/entities/outbox_entry.dart';
import 'package:chatix/features/chat/domain/entities/outbox_rules.dart';

/// The queue's own rules, without a server: what collapses into what, what
/// may go out now, and what a refusal means.
void main() {
  final now = DateTime.utc(2026, 9, 15, 12);

  var counter = 0;
  OutboxEntry entry(
    OutboxOperation operation, {
    String chatId = 'c1',
    int attempts = 0,
    DateTime? nextAttemptAt,
    bool needsAttention = false,
  }) {
    counter++;
    return OutboxEntry(
      id: 'e$counter',
      chatId: chatId,
      operation: operation,
      createdAt: now,
      attempts: attempts,
      nextAttemptAt: nextAttemptAt,
      needsAttention: needsAttention,
    );
  }

  setUp(() => counter = 0);

  group('read cursors collapse', () {
    test('a later report moves the queued one forward', () {
      final queue = OutboxRules.enqueue(
        [entry(const OutboxRead(seq: 10))],
        entry(const OutboxRead(seq: 40)),
      );

      expect(queue, hasLength(1));
      expect((queue.single.operation as OutboxRead).seq, 40);
    });

    test('an earlier report never walks the cursor back', () {
      final queue = OutboxRules.enqueue(
        [entry(const OutboxRead(seq: 40))],
        entry(const OutboxRead(seq: 12)),
      );

      expect((queue.single.operation as OutboxRead).seq, 40);
    });

    test('another chat is another cursor', () {
      final queue = OutboxRules.enqueue(
        [entry(const OutboxRead(seq: 10))],
        entry(const OutboxRead(seq: 3), chatId: 'c2'),
      );

      expect(queue, hasLength(2));
    });

    test('one already attempted is left alone', () {
      // It may have reached the server. Rewriting it would mean the two
      // sides disagreeing about what was said.
      final queue = OutboxRules.enqueue(
        [entry(const OutboxRead(seq: 10), attempts: 1)],
        entry(const OutboxRead(seq: 40)),
      );

      expect(queue, hasLength(2));
    });
  });

  group('reactions collapse', () {
    OutboxReaction react(OutboxReactionAction action, {String emoji = '👍'}) =>
        OutboxReaction(messageId: 'm1', action: action, emoji: emoji);

    test('adding and taking back cancels both', () {
      final queue = OutboxRules.enqueue(
        [entry(react(OutboxReactionAction.set))],
        entry(react(OutboxReactionAction.remove)),
      );

      expect(queue, isEmpty);
    });

    test('the same tap twice is one entry', () {
      final queue = OutboxRules.enqueue(
        [entry(react(OutboxReactionAction.set))],
        entry(react(OutboxReactionAction.set)),
      );

      expect(queue, hasLength(1));
    });

    test('a different emoji is a different entry', () {
      final queue = OutboxRules.enqueue(
        [entry(react(OutboxReactionAction.set))],
        entry(react(OutboxReactionAction.set, emoji: '🔥')),
      );

      expect(queue, hasLength(2));
    });

    test('clearing supersedes everything queued for that message', () {
      var queue = [
        entry(react(OutboxReactionAction.set)),
        entry(react(OutboxReactionAction.set, emoji: '🔥')),
      ];
      queue = OutboxRules.enqueue(
        queue,
        entry(
          const OutboxReaction(
            messageId: 'm1',
            action: OutboxReactionAction.clear,
          ),
        ),
      );

      expect(queue, hasLength(1));
      expect(
        (queue.single.operation as OutboxReaction).action,
        OutboxReactionAction.clear,
      );
    });

    test('another message is untouched', () {
      final other = entry(
        const OutboxReaction(
          messageId: 'm2',
          action: OutboxReactionAction.set,
          emoji: '👍',
        ),
      );
      final queue = OutboxRules.enqueue([
        other,
      ], entry(react(OutboxReactionAction.clear)));

      expect(queue, hasLength(2));
    });
  });

  test('messages are never collapsed', () {
    // Two messages are two messages, however alike.
    final queue = OutboxRules.enqueue(
      [entry(const OutboxSendMessage(content: 'ok'))],
      entry(const OutboxSendMessage(content: 'ok')),
    );

    expect(queue, hasLength(2));
  });

  group('what is due', () {
    test('a message waiting out its backoff holds back the chat behind it', () {
      // Otherwise a retry lands after a message typed later, and the chat
      // reads out of order for everyone.
      final blocked = entry(
        const OutboxSendMessage(content: 'first'),
        nextAttemptAt: now.add(const Duration(seconds: 5)),
      );
      final behind = entry(const OutboxSendMessage(content: 'second'));

      expect(OutboxRules.due([blocked, behind], now), isEmpty);
    });

    test('another chat is not held back', () {
      final blocked = entry(
        const OutboxSendMessage(content: 'first'),
        nextAttemptAt: now.add(const Duration(seconds: 5)),
      );
      final elsewhere = entry(
        const OutboxSendMessage(content: 'second'),
        chatId: 'c2',
      );

      expect(OutboxRules.due([blocked, elsewhere], now), [elsewhere]);
    });

    test('a read is never held back by a message', () {
      final blocked = entry(
        const OutboxSendMessage(content: 'first'),
        nextAttemptAt: now.add(const Duration(seconds: 5)),
      );
      final read = entry(const OutboxRead(seq: 12));

      expect(OutboxRules.due([blocked, read], now), [read]);
    });

    test('one waiting for a person is not due at all', () {
      final stuck = entry(
        const OutboxSendMessage(content: 'nope'),
        needsAttention: true,
      );

      expect(OutboxRules.due([stuck], now), isEmpty);
    });
  });

  group('after a failure', () {
    test('a retryable one widens the wait and stays in the queue', () {
      final settled = OutboxRules.afterFailure(
        entry(const OutboxSendMessage(content: 'hi')),
        const NetworkFailure(),
        now,
      );

      expect(settled.attempts, 1);
      expect(settled.needsAttention, isFalse);
      expect(settled.nextAttemptAt, now.add(OutboxEntry.backoffFor(1)));
    });

    test('the wait widens with every attempt', () {
      expect(
        OutboxEntry.backoffFor(3) > OutboxEntry.backoffFor(1),
        isTrue,
      );
      expect(
        OutboxEntry.backoffFor(99),
        OutboxEntry.backoffFor(OutboxEntry.maxAutomaticAttempts),
      );
    });

    test('a refusal that retrying cannot fix stops at once', () {
      final settled = OutboxRules.afterFailure(
        entry(const OutboxSendMessage(content: 'hi')),
        const ApiFailure(
          code: 'MESSAGE_TOO_LONG',
          message: 'too long',
          detail: null,
          status: 400,
        ),
        now,
      );

      expect(settled.needsAttention, isTrue);
      expect(settled.nextAttemptAt, isNull);
    });

    test('the last automatic attempt gives up', () {
      final settled = OutboxRules.afterFailure(
        entry(
          const OutboxSendMessage(content: 'hi'),
          attempts: OutboxEntry.maxAutomaticAttempts - 1,
        ),
        const NetworkFailure(),
        now,
      );

      expect(settled.needsAttention, isTrue);
    });

    test('a manual retry starts the entry over', () {
      final stuck = OutboxRules.afterFailure(
        entry(const OutboxSendMessage(content: 'hi')),
        const ApiFailure(
          code: 'MESSAGE_TOO_LONG',
          message: 'too long',
          detail: null,
          status: 400,
        ),
        now,
      );

      final retried = OutboxRules.afterManualRetry(stuck);

      expect(retried.attempts, 0);
      expect(retried.needsAttention, isFalse);
      expect(retried.failureMessage, isNull);
      expect(retried.id, stuck.id, reason: 'the idempotency key is the id');
    });
  });

  group('isRetryable', () {
    test('nothing that reached the server is given up on', () {
      expect(OutboxRules.isRetryable(const NetworkFailure()), isTrue);
      expect(OutboxRules.isRetryable(const TimeoutFailure()), isTrue);
    });

    test('the server saying "later" is worth waiting out', () {
      // 429 is slow mode or the rate limiter (api-docs §5.4), and 409 is the
      // previous attempt with this key still being processed.
      expect(OutboxRules.isRetryable(const RateLimitFailure()), isTrue);
      expect(
        OutboxRules.isRetryable(
          const ApiFailure(
            code: 'IDEMPOTENCY_CONFLICT',
            message: 'in flight',
            detail: null,
            status: 409,
          ),
        ),
        isTrue,
      );
    });

    test('a refusal about the request itself is not', () {
      expect(
        OutboxRules.isRetryable(
          const ApiFailure(
            code: 'NOT_CHAT_MEMBER',
            message: 'no',
            detail: null,
            status: 403,
          ),
        ),
        isFalse,
      );
    });
  });

  test('nextWakeUp ignores what nobody is waiting on', () {
    final stuck = entry(
      const OutboxSendMessage(content: 'nope'),
      needsAttention: true,
    );
    expect(OutboxRules.nextWakeUp([stuck], now), isNull);

    final waiting = entry(
      const OutboxRead(seq: 4),
      nextAttemptAt: now.add(const Duration(seconds: 7)),
    );
    expect(
      OutboxRules.nextWakeUp([stuck, waiting], now),
      const Duration(seconds: 7),
    );
  });
}
