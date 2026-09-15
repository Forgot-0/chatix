import 'package:chatix/core/error/failures.dart';
import 'package:chatix/features/chat/domain/entities/outbox_entry.dart';

/// What the outbox is allowed to do with itself.
///
/// All of it is a function of the queue and the clock, which is what makes
/// the awkward parts — a reaction toggled four times before the network came
/// back, a read cursor reported on every scroll tick, a message that must
/// not overtake the one queued before it — testable without a server.
abstract final class OutboxRules {
  /// Adds [entry], dropping whatever it makes pointless.
  ///
  /// Messages are never collapsed: two messages are two messages, however
  /// alike. Everything else describes a *state* rather than an event, and
  /// only the last description of a state is worth sending — a chat read to
  /// seq 400 does not also need to be told it was read to 380.
  ///
  /// Only entries that have never been on the wire are collapsed away. Once
  /// an attempt has been made the client no longer knows whether the server
  /// saw it, and cancelling a pair locally would leave the two sides
  /// disagreeing.
  static List<OutboxEntry> enqueue(List<OutboxEntry> queue, OutboxEntry entry) {
    return switch (entry.operation) {
      OutboxRead(seq: final seq) => _enqueueRead(queue, entry, seq),
      OutboxReaction() => _enqueueReaction(queue, entry),
      OutboxSendMessage() || OutboxForwardMessage() => [...queue, entry],
    };
  }

  static List<OutboxEntry> _enqueueRead(
    List<OutboxEntry> queue,
    OutboxEntry entry,
    int seq,
  ) {
    var collapsed = false;

    final next = <OutboxEntry>[];
    for (final queued in queue) {
      final operation = queued.operation;
      final isSameChatRead =
          operation is OutboxRead &&
          queued.chatId == entry.chatId &&
          queued.attempts == 0;

      if (!isSameChatRead) {
        next.add(queued);
        continue;
      }

      // Keep the entry already in the queue — its place in the order and its
      // id are as good as the newcomer's — and move its cursor forward.
      collapsed = true;
      final furthest = operation.seq;
      next.add(
        queued.copyWith(
          operation: OutboxRead(seq: seq > furthest ? seq : furthest),
          clearFailure: true,
          clearNextAttemptAt: true,
        ),
      );
    }

    return collapsed ? next : [...next, entry];
  }

  static List<OutboxEntry> _enqueueReaction(
    List<OutboxEntry> queue,
    OutboxEntry entry,
  ) {
    final incoming = entry.operation as OutboxReaction;

    final next = <OutboxEntry>[];
    var cancelled = false;

    for (final queued in queue) {
      final operation = queued.operation;

      final isSupersedable =
          operation is OutboxReaction &&
          queued.chatId == entry.chatId &&
          operation.messageId == incoming.messageId &&
          queued.attempts == 0;

      if (!isSupersedable) {
        next.add(queued);
        continue;
      }

      final queuedReaction = operation;

      // A replace or a clear restates the whole message, so nothing queued
      // before it for that message can still matter.
      if (incoming.action == OutboxReactionAction.replace ||
          incoming.action == OutboxReactionAction.clear) {
        continue;
      }

      final isSameEmoji = queuedReaction.emoji == incoming.emoji;
      if (!isSameEmoji) {
        next.add(queued);
        continue;
      }

      // Setting what is already queued to be set, or removing what is
      // already queued to be removed: the queued one says it.
      if (queuedReaction.action == incoming.action) {
        next.add(queued);
        cancelled = true;
        continue;
      }

      // Set then remove, or remove then set: the two cancel out and neither
      // needs to travel.
      cancelled = true;
    }

    return cancelled ? next : [...next, entry];
  }

  /// The entries that may be attempted right now, in the order to try them.
  ///
  /// Messages of one chat go out in the order they were written, so a
  /// message still sitting out its backoff holds back every later message of
  /// the same chat — otherwise a retry would land behind a message typed
  /// after it. Reads and reactions carry their own ordering in their content
  /// and are never held back.
  static List<OutboxEntry> due(List<OutboxEntry> queue, DateTime now) {
    final blocked = <String>{};
    final ready = <OutboxEntry>[];

    for (final entry in queue) {
      final isOrdered =
          entry.operation is OutboxSendMessage ||
          entry.operation is OutboxForwardMessage;

      if (!isOrdered) {
        if (entry.isDue(now)) ready.add(entry);
        continue;
      }

      if (blocked.contains(entry.chatId)) continue;

      if (entry.isDue(now)) {
        ready.add(entry);
      }
      // Due or not, everything ordered after it in this chat waits for it.
      blocked.add(entry.chatId);
    }

    return ready;
  }

  /// When the queue should next wake itself up, or null if it has nothing
  /// left to wait for.
  static Duration? nextWakeUp(List<OutboxEntry> queue, DateTime now) {
    Duration? soonest;

    for (final entry in queue) {
      if (entry.needsAttention) continue;

      final at = entry.nextAttemptAt;
      if (at == null) return Duration.zero;

      final wait = at.difference(now);
      final delay = wait.isNegative ? Duration.zero : wait;
      if (soonest == null || delay < soonest) soonest = delay;
    }

    return soonest;
  }

  /// The entry as it stands after a failed attempt.
  static OutboxEntry afterFailure(
    OutboxEntry entry,
    Failure failure,
    DateTime now,
  ) {
    final attempts = entry.attempts + 1;
    final givesUp =
        !isRetryable(failure) || attempts >= OutboxEntry.maxAutomaticAttempts;

    return entry.copyWith(
      attempts: attempts,
      failureMessage: failure.message,
      needsAttention: givesUp,
      nextAttemptAt: givesUp
          ? null
          : now.add(OutboxEntry.backoffFor(attempts)),
      clearNextAttemptAt: givesUp,
    );
  }

  /// The entry as it stands when a person has asked for it to be tried again.
  static OutboxEntry afterManualRetry(OutboxEntry entry) => entry.copyWith(
    attempts: 0,
    needsAttention: false,
    clearFailure: true,
    clearNextAttemptAt: true,
  );

  /// Whether trying the same request again could plausibly do better.
  ///
  /// Anything that never reached the server is worth repeating. Of the
  /// answers that did come back, only the ones about *this moment* are:
  /// `429` is the slow mode or the rate limiter saying "later" (api-docs
  /// §5.4), `409 IDEMPOTENCY_CONFLICT` is the previous attempt still being
  /// processed, and 5xx is the server having a bad time. A message refused
  /// for being too long, or for a chat this account is not in, will be
  /// refused identically forever — that one is for a person to resolve.
  static bool isRetryable(Failure failure) {
    if (failure is NetworkFailure || failure is TimeoutFailure) return true;
    if (failure is ServerFailure) return true;
    if (failure is RateLimitFailure) return true;
    if (failure is CancelledFailure) return true;

    final status = failure.statusCode;
    if (status == null) return true;
    if (status == 408 || status == 425 || status == 429) return true;
    if (status == 409) return true;
    return status >= 500;
  }
}
