import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import 'package:chatix/core/error/failures.dart';
import 'package:chatix/core/utils/logger.dart';
import 'package:chatix/core/websocket/chat_socket_service.dart';
import 'package:chatix/features/chat/domain/entities/message_entity.dart';
import 'package:chatix/features/chat/domain/entities/outbox_entry.dart';
import 'package:chatix/features/chat/domain/entities/outbox_rules.dart';
import 'package:chatix/features/chat/presentation/providers/chat_providers.dart';
import 'package:chatix/features/chat/presentation/providers/chat_socket_provider.dart';

const Uuid _uuid = Uuid();

/// What became of one queued write.
///
/// The screen that started it may be long gone — the whole point of the
/// queue is that it outlives the screen, and the app — so the result is
/// announced rather than returned. Whoever is showing that chat right now
/// picks it up; nobody listening is a perfectly good outcome.
class OutboxDelivery {
  const OutboxDelivery({
    required this.entry,
    this.message,
    this.failure,
    this.abandoned = false,
  });

  final OutboxEntry entry;

  /// The message the server created, for a send or a forward.
  final MessageEntity? message;

  /// Why this attempt did not work, if it did not.
  final Failure? failure;

  /// Whether the queue has stopped trying on its own and is waiting for a
  /// person to choose Retry or Delete.
  final bool abandoned;

  String get chatId => entry.chatId;

  bool get isSuccess => failure == null;
}

/// Everything this device still owes the server.
///
/// One queue for the whole app rather than one per screen: a message typed
/// in a chat that is then closed is still being sent, a reaction tapped on a
/// train still lands when the tunnel ends, and a read cursor reported as the
/// app was killed is reported again at the next start. The queue is written
/// to disk on every change, so all three survive the process.
///
/// Entries are retried with a widening backoff and kicked awake whenever the
/// socket reconnects — which is the closest thing the app has to "the
/// network is back". After [OutboxEntry.maxAutomaticAttempts], or on a
/// refusal that retrying cannot fix, an entry stops on its own and waits to
/// be retried or thrown away by hand.
class ChatOutboxController extends Notifier<List<OutboxEntry>> {
  Timer? _wakeUp;

  /// The pass currently running, so a second caller joins it rather than
  /// starting a competing one.
  Future<void>? _inFlight;

  /// Set when something was queued while a pass was running, so the pass
  /// takes another look before it finishes.
  bool _drainAgain = false;

  StreamSubscription<ChatSocketStatus>? _socketStatus;

  /// Synchronous on purpose: a delivery is the answer to something a screen
  /// is awaiting — a send, a reaction — and it has to have been applied by
  /// the time that await returns, not a microtask later.
  final StreamController<OutboxDelivery> _deliveries =
      StreamController<OutboxDelivery>.broadcast(sync: true);

  Stream<OutboxDelivery> get deliveries => _deliveries.stream;

  @override
  List<OutboxEntry> build() {
    ref.onDispose(() {
      _wakeUp?.cancel();
      _wakeUp = null;
      _socketStatus?.cancel();
      _socketStatus = null;
      _deliveries.close();
    });

    final restored = [
      for (final entry in ref.watch(chatOutboxUseCaseProvider).load())
        // Whatever backoff these were waiting out died with the process, and
        // the wait has already happened in wall-clock time. What is kept is
        // the attempt count, so a message that has failed six times does not
        // get six fresh chances every time the app is opened.
        entry.needsAttention ? entry : entry.copyWith(clearNextAttemptAt: true),
    ];

    _watchSocket();

    if (restored.isNotEmpty) scheduleMicrotask(drain);

    return restored;
  }

  /// A reconnect is the one signal the app gets that the network came back.
  void _watchSocket() {
    final socket = ref.read(chatSocketServiceProvider);
    _socketStatus = socket.statusStream.listen((status) {
      if (status == ChatSocketStatus.ready) unawaited(drain());
    });
  }

  List<OutboxEntry> of(String chatId) => [
    for (final entry in state)
      if (entry.chatId == chatId) entry,
  ];

  /// Queues a message and hands back the entry standing for it.
  ///
  /// The entry's id is its `Idempotency-Key` (api-docs §5.4) from this moment
  /// on: every retry, in this run or a later one, carries the same key, so a
  /// send that reached the server but whose answer did not reach us comes
  /// back as the original message rather than as a second copy.
  OutboxEntry enqueueMessage(
    String chatId, {
    String? content,
    String? replyToId,
    MessageType? messageType,
    List<String> uploadTokens = const [],
  }) {
    return _enqueue(
      chatId,
      OutboxSendMessage(
        content: content,
        replyToId: replyToId,
        messageType: messageType,
        uploadTokens: uploadTokens,
      ),
    );
  }

  OutboxEntry enqueueForward(
    String targetChatId, {
    required String sourceChatId,
    required String sourceMessageId,
    String? comment,
  }) {
    return _enqueue(
      targetChatId,
      OutboxForwardMessage(
        sourceChatId: sourceChatId,
        sourceMessageId: sourceMessageId,
        comment: comment,
      ),
    );
  }

  OutboxEntry enqueueReaction(
    String chatId,
    String messageId,
    OutboxReactionAction action, {
    String? emoji,
    List<String> emojis = const [],
  }) {
    return _enqueue(
      chatId,
      OutboxReaction(
        messageId: messageId,
        action: action,
        emoji: emoji,
        emojis: emojis,
      ),
    );
  }

  /// Reports how far the reader got. Collapses with whatever is already
  /// queued for this chat, so scrolling cannot fill the queue.
  OutboxEntry enqueueRead(String chatId, int seq) =>
      _enqueue(chatId, OutboxRead(seq: seq));

  OutboxEntry _enqueue(String chatId, OutboxOperation operation) {
    final entry = OutboxEntry(
      id: _uuid.v4(),
      chatId: chatId,
      operation: operation,
      createdAt: DateTime.now(),
    );

    final before = state;
    final after = OutboxRules.enqueue(before, entry);
    state = after;

    unawaited(_persistDifference(before, after));

    // Straight to the attempt rather than through a timer: the usual case is
    // a working connection, and a message should be on the wire in the same
    // turn it was typed in.
    unawaited(drain());

    // Collapsing can mean the entry that ended up standing for this request
    // is one that was already queued, under its own id.
    for (final queued in after) {
      if (queued.id == entry.id) return queued;
    }
    for (final queued in after) {
      if (queued.chatId == chatId && queued.operation.kind == operation.kind) {
        return queued;
      }
    }
    return entry;
  }

  /// Tries an entry a person asked to try again.
  Future<void> retry(String id) async {
    final entry = _find(id);
    if (entry == null) return;

    final retried = OutboxRules.afterManualRetry(entry);
    _replace(retried);
    await ref.read(chatOutboxUseCaseProvider).save(retried);
    await drain();
  }

  /// Throws an entry away unsent.
  Future<void> discard(String id) async {
    final entry = _find(id);
    if (entry == null) return;

    state = [
      for (final queued in state)
        if (queued.id != id) queued,
    ];
    await ref.read(chatOutboxUseCaseProvider).drop(id);

    _announce(
      OutboxDelivery(
        entry: entry,
        failure: const CancelledFailure(message: 'Discarded'),
      ),
    );
  }

  /// Works through everything that is due.
  ///
  /// One pass at a time, however many callers ask: two passes at once would
  /// put the same entry on the wire twice. A caller arriving mid-pass joins
  /// the one already running, and anything queued while it runs is picked up
  /// before it finishes.
  Future<void> drain() {
    final running = _inFlight;
    if (running != null) {
      _drainAgain = true;
      return running;
    }

    final pass = _drainOnce();
    _inFlight = pass;
    return pass;
  }

  Future<void> _drainOnce() async {
    try {
      do {
        _drainAgain = false;

        // A pass outlives the provider when the app closes a screen
        // mid-request; the request itself is already on its way and the
        // store is the one that has to be right about it, not this object.
        if (!ref.mounted) return;

        for (final entry in OutboxRules.due(state, DateTime.now())) {
          // The queue may have changed under us while awaiting the last one.
          if (_find(entry.id) == null) continue;
          await _attempt(entry);
          if (!ref.mounted) return;
        }
      } while (_drainAgain);
    } finally {
      _inFlight = null;
      if (ref.mounted) _scheduleWakeUp();
    }
  }

  Future<void> _attempt(OutboxEntry entry) async {
    final failure = switch (entry.operation) {
      OutboxSendMessage() => await _send(entry),
      OutboxForwardMessage() => await _forward(entry),
      OutboxReaction() => await _react(entry),
      OutboxRead() => await _read(entry),
    };

    if (failure == null) return;

    final settled = OutboxRules.afterFailure(entry, failure, DateTime.now());
    if (!ref.mounted) return;

    _replace(settled);
    await ref.read(chatOutboxUseCaseProvider).save(settled);

    _announce(
      OutboxDelivery(
        entry: settled,
        failure: failure,
        abandoned: settled.needsAttention,
      ),
    );

    if (settled.needsAttention) {
      Logger.warning(
        'Outbox: ${entry.operation.kind} in ${entry.chatId} given up after '
        '${settled.attempts} attempts (${failure.message})',
      );
    }
  }

  Future<Failure?> _send(OutboxEntry entry) async {
    final operation = entry.operation as OutboxSendMessage;

    final result = await ref
        .read(sendMessageUseCaseProvider)
        .execute(
          entry.chatId,
          content: operation.content,
          replyToId: operation.replyToId,
          messageType: operation.messageType,
          uploadTokens: operation.uploadTokens.isEmpty
              ? null
              : operation.uploadTokens,
          idempotencyKey: entry.id,
        );

    return result.match((failure) => failure, (message) {
      _settle(entry, message: message);
      return null;
    });
  }

  Future<Failure?> _forward(OutboxEntry entry) async {
    final operation = entry.operation as OutboxForwardMessage;

    final result = await ref
        .read(forwardMessageUseCaseProvider)
        .execute(
          sourceChatId: operation.sourceChatId,
          sourceMessageId: operation.sourceMessageId,
          targetChatId: entry.chatId,
          comment: operation.comment,
          idempotencyKey: entry.id,
        );

    return result.match((failure) => failure, (message) {
      _settle(entry, message: message);
      return null;
    });
  }

  Future<Failure?> _react(OutboxEntry entry) async {
    final operation = entry.operation as OutboxReaction;
    final emoji = operation.emoji ?? '';

    final result = switch (operation.action) {
      OutboxReactionAction.set => await ref
          .read(setReactionUseCaseProvider)
          .execute(entry.chatId, operation.messageId, emoji),
      OutboxReactionAction.remove => await ref
          .read(removeReactionUseCaseProvider)
          .execute(entry.chatId, operation.messageId, emoji),
      OutboxReactionAction.replace => await ref
          .read(replaceReactionsUseCaseProvider)
          .execute(entry.chatId, operation.messageId, operation.emojis),
      OutboxReactionAction.clear => await ref
          .read(clearReactionsUseCaseProvider)
          .execute(entry.chatId, operation.messageId),
    };

    return result.match((failure) => failure, (_) {
      _settle(entry);
      return null;
    });
  }

  Future<Failure?> _read(OutboxEntry entry) async {
    final operation = entry.operation as OutboxRead;

    final result = await ref
        .read(markReadUseCaseProvider)
        .execute(entry.chatId, operation.seq);

    return result.match((failure) => failure, (_) {
      _settle(entry);
      return null;
    });
  }

  /// Takes a finished entry out of the queue and says so.
  void _settle(OutboxEntry entry, {MessageEntity? message}) {
    if (!ref.mounted) return;

    state = [
      for (final queued in state)
        if (queued.id != entry.id) queued,
    ];
    unawaited(ref.read(chatOutboxUseCaseProvider).drop(entry.id));
    _announce(OutboxDelivery(entry: entry, message: message));
  }

  void _announce(OutboxDelivery delivery) {
    if (_deliveries.isClosed) return;
    _deliveries.add(delivery);
  }

  OutboxEntry? _find(String id) {
    for (final entry in state) {
      if (entry.id == id) return entry;
    }
    return null;
  }

  void _replace(OutboxEntry entry) {
    state = [
      for (final queued in state)
        if (queued.id == entry.id) entry else queued,
    ];
  }

  /// Writes what changed, and only what changed.
  Future<void> _persistDifference(
    List<OutboxEntry> before,
    List<OutboxEntry> after,
  ) async {
    final store = ref.read(chatOutboxUseCaseProvider);

    final kept = {for (final entry in after) entry.id: entry};

    for (final entry in before) {
      if (!kept.containsKey(entry.id)) await store.drop(entry.id);
    }

    final had = {for (final entry in before) entry.id: entry};
    for (final entry in after) {
      if (had[entry.id] != entry) await store.save(entry);
    }
  }

  void _scheduleWakeUp() {
    _wakeUp?.cancel();
    _wakeUp = null;

    final delay = OutboxRules.nextWakeUp(state, DateTime.now());
    if (delay == null) return;

    _wakeUp = Timer(delay, () {
      _wakeUp = null;
      unawaited(drain());
    });
  }
}

final chatOutboxProvider =
    NotifierProvider<ChatOutboxController, List<OutboxEntry>>(
      ChatOutboxController.new,
    );
