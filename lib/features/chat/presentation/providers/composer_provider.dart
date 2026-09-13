import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:chatix/core/utils/logger.dart';
import 'package:chatix/features/chat/domain/entities/message_entity.dart';
import 'package:chatix/features/chat/domain/entities/slow_mode.dart';

/// Which of its four shapes the composer is wearing.
///
/// Ordered by how much they claim: an edit takes over the whole box and the
/// text in it, a reply only adds a banner, staged attachments only add a
/// tray. Two can be true at once — staging a photo while replying — so the
/// banner shows the one furthest up this list.
enum ComposerMode {
  idle,

  /// Staged uploads waiting to go out with the next message.
  attaching,

  /// `reply_to_id` is set for the next message.
  replying,

  /// The box holds one existing message's text, not a draft.
  editing,
}

/// Everything about the composer that is neither the text itself (the
/// `TextEditingController` owns that) nor something another provider already
/// keeps — the reply target lives in the chat, the staged uploads in the
/// attachment provider.
class ComposerState extends Equatable {
  const ComposerState({
    this.editing,
    this.length = 0,
    this.slowMode = SlowMode.off,
    this.isSending = false,
  });

  /// The message being rewritten, or null when the box holds a draft.
  final MessageEntity? editing;

  /// How many characters are in the box, mirrored out of the controller so
  /// the counter and the send button can be rebuilt without them all
  /// listening to it.
  final int length;

  final SlowMode slowMode;

  /// A send is in flight. Keeps a double tap from sending twice — the
  /// idempotency key would collapse it server-side, but the second tap
  /// would still clear the box under the first.
  final bool isSending;

  bool get isEditing => editing != null;

  @override
  List<Object?> get props => [editing, length, slowMode, isSending];

  ComposerState copyWith({
    MessageEntity? editing,
    bool clearEditing = false,
    int? length,
    SlowMode? slowMode,
    bool? isSending,
  }) {
    return ComposerState(
      editing: clearEditing ? null : (editing ?? this.editing),
      length: length ?? this.length,
      slowMode: slowMode ?? this.slowMode,
      isSending: isSending ?? this.isSending,
    );
  }
}

/// The composer's own state, per chat.
///
/// Per chat rather than per screen: a two-pane layout can have one chat open
/// beside the list, and an edit or a slow-mode wait belongs to the
/// conversation, not to whichever widget is currently drawing it.
class ComposerController extends Notifier<ComposerState> {
  ComposerController(this._chatId);

  final String _chatId;

  @override
  ComposerState build() => const ComposerState();

  void startEditing(MessageEntity message) {
    state = state.copyWith(editing: message, length: message.content?.length);
  }

  void cancelEditing() {
    if (!state.isEditing) return;
    state = state.copyWith(clearEditing: true);
  }

  void setLength(int length) {
    if (state.length == length) return;
    state = state.copyWith(length: length);
  }

  void setSending({required bool value}) {
    if (state.isSending == value) return;
    state = state.copyWith(isSending: value);
  }

  /// Re-reads `slow_mode_seconds` off the chat, keeping any wait already
  /// running. Called on every build, so a `chat_updated` that turns slow
  /// mode off releases the button without a round trip.
  void syncSlowMode(Duration interval) {
    final next = state.slowMode.withInterval(interval);
    if (next == state.slowMode) return;
    state = state.copyWith(slowMode: next);
  }

  /// Starts the local clock, optimistically — the message is on its way.
  void markSent({DateTime? now}) {
    if (!state.slowMode.isActive) return;
    state = state.copyWith(
      slowMode: state.slowMode.afterSendAt(now ?? DateTime.now()),
    );
  }

  /// The server disagreed about the clock, and it is the one that counts.
  ///
  /// `429 SLOW_MODE_LIMIT` carries `detail.retry_after` in seconds
  /// (api-docs §2.6); it replaces whatever the local timer believed.
  void applyRetryAfter(int seconds, {DateTime? now}) {
    Logger.info('Composer($_chatId): slow mode, ${seconds}s to wait');

    state = state.copyWith(
      slowMode: state.slowMode.afterRetryAfter(seconds, now ?? DateTime.now()),
    );
  }
}

final composerProvider =
    NotifierProvider.family<ComposerController, ComposerState, String>(
      ComposerController.new,
    );
