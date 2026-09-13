import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chatix/features/chat/domain/entities/message_entity.dart';
import 'package:chatix/features/chat/presentation/providers/composer_provider.dart';

/// The composer's own state: which message it is rewriting, how much is in
/// it, and how long slow mode says it has to wait.
void main() {
  const chatId = 'c1';
  final now = DateTime.utc(2026, 3, 1, 12);

  MessageEntity message({String content = 'the original'}) => MessageEntity(
    id: 'm1',
    chatId: chatId,
    seq: 4,
    authorId: 7,
    type: MessageType.text,
    content: content,
    replyToId: null,
    forwardedFromChatId: null,
    forwardedFromMessageId: null,
    forwardedFromAuthorId: null,
    isEdited: false,
    createdAt: now,
    attachments: const [],
  );

  ProviderContainer boot() {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    return container;
  }

  ComposerController notifierOf(ProviderContainer c) =>
      c.read(composerProvider(chatId).notifier);

  ComposerState stateOf(ProviderContainer c) =>
      c.read(composerProvider(chatId));

  group('editing', () {
    test('starts empty', () {
      final container = boot();

      expect(stateOf(container).isEditing, isFalse);
      expect(stateOf(container).length, 0);
    });

    test('taking a message in brings its length with it', () {
      final container = boot();

      notifierOf(container).startEditing(message());

      expect(stateOf(container).editing?.id, 'm1');
      expect(stateOf(container).length, 'the original'.length);
    });

    test('cancelling lets go of the message', () {
      final container = boot();

      notifierOf(container)
        ..startEditing(message())
        ..cancelEditing();

      expect(stateOf(container).isEditing, isFalse);
    });
  });

  group('slow mode', () {
    test('a chat without it never holds the button', () {
      final container = boot();

      notifierOf(container)
        ..syncSlowMode(Duration.zero)
        ..markSent(now: now);

      expect(stateOf(container).slowMode.canSendAt(now), isTrue);
    });

    test('sending starts the wait', () {
      final container = boot();

      notifierOf(container)
        ..syncSlowMode(const Duration(seconds: 30))
        ..markSent(now: now);

      expect(stateOf(container).slowMode.secondsLeftAt(now), 30);
    });

    test('re-reading the chat leaves a running wait alone', () {
      final container = boot();

      notifierOf(container)
        ..syncSlowMode(const Duration(seconds: 30))
        ..markSent(now: now)
        ..syncSlowMode(const Duration(seconds: 30));

      expect(stateOf(container).slowMode.secondsLeftAt(now), 30);
    });

    test('slow mode being turned off releases the button', () {
      final container = boot();

      notifierOf(container)
        ..syncSlowMode(const Duration(seconds: 30))
        ..markSent(now: now)
        ..syncSlowMode(Duration.zero);

      expect(stateOf(container).slowMode.canSendAt(now), isTrue);
    });

    test('retry_after from a 429 overrides the local clock', () {
      final container = boot();

      notifierOf(container)
        ..syncSlowMode(const Duration(seconds: 30))
        ..markSent(now: now)
        ..applyRetryAfter(90, now: now);

      expect(stateOf(container).slowMode.secondsLeftAt(now), 90);
    });

    test('a 429 in a chat we thought was free still holds the button', () {
      final container = boot();

      notifierOf(container).applyRetryAfter(15, now: now);

      expect(stateOf(container).slowMode.secondsLeftAt(now), 15);
    });
  });

  group('in flight', () {
    test('a send in progress is visible to the button', () {
      final container = boot();

      notifierOf(container).setSending(value: true);
      expect(stateOf(container).isSending, isTrue);

      notifierOf(container).setSending(value: false);
      expect(stateOf(container).isSending, isFalse);
    });
  });

  test('each chat keeps its own composer', () {
    final container = boot();

    container.read(composerProvider('a').notifier).startEditing(message());

    expect(container.read(composerProvider('a')).isEditing, isTrue);
    expect(container.read(composerProvider('b')).isEditing, isFalse);
  });
}
