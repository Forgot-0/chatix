import 'package:fpdart/fpdart.dart';
import 'package:chatix/core/error/failures.dart';
import 'package:chatix/features/chat/domain/entities/chat_entity.dart';
import 'package:chatix/features/chat/domain/entities/reaction_entity.dart';
import 'package:chatix/features/chat/domain/repositories/chat_repository.dart';

/// `PUT /chats/{chat_id}/messages/{message_id}/reactions/{emoji}/` 🔒 10/sec
/// → 204 (api-docs §6.7.1).
///
/// ⚠️ **Adds to a set; it does not replace one.** A user may hold up to
/// [ReactionLimits.maxPerUserPerMessage] different emoji on a single message
/// (§6.7.2), so reacting with a second one leaves the first in place.
/// Re-sending an emoji already held is a server-side no-op (still 204), so
/// this is not a toggle: to take one off use `RemoveReactionUseCase`, and to
/// swap the whole set atomically use `ReplaceReactionsUseCase`.
///
/// [execute] optionally takes the message's [MessageReactionsEntity] so the
/// per-user limit can be enforced *before* spending one of the 10/sec slots on
/// a request the backend would answer `400 TOO_MANY_REACTIONS`.
class SetReactionUseCase {
  /// `MAX_REACTION_LENGTH` (api-docs §6.7.4).
  static const int maxEmojiLength = ReactionLimits.maxEmojiLength;

  final ChatRepository _repository;

  SetReactionUseCase(this._repository);

  Future<Either<Failure, void>> execute(
    String chatId,
    String messageId,
    String emoji, {
    /// The message's current reactions, when the caller has them. Enables the
    /// local limit checks below; omit to rely on the server alone.
    MessageReactionsEntity? current,

    /// The chat's reaction settings (§6.7.5), when known. Lets a chat in
    /// `none`/`some` be refused locally instead of round-tripping to a
    /// `403 REACTIONS_DISABLED` / `400 REACTION_NOT_ALLOWED`.
    ChatReactionPolicy? policy,
  }) {
    if (chatId.trim().isEmpty) return _fail('Chat id is required');
    if (messageId.trim().isEmpty) return _fail('Message id is required');

    final validation = validateEmoji(emoji);
    if (validation != null) return _fail(validation);

    if (policy != null) {
      if (!policy.enabled) {
        return _fail('Reactions are turned off in this chat');
      }
      if (!policy.isAllowed(emoji)) {
        return _fail("That reaction isn't allowed in this chat");
      }
    }

    if (current != null) {
      // Already held — the server would no-op, so skip the round trip and let
      // the caller's optimistic state stand.
      if (current.isMine(emoji)) return Future.value(const Right(null));

      if (current.myEmojis.length >= ReactionLimits.maxPerUserPerMessage) {
        return _fail(
          'You can add at most ${ReactionLimits.maxPerUserPerMessage} '
          'reactions to a message',
        );
      }
      // A brand-new emoji on a message that already carries the maximum number
      // of distinct ones; joining an existing group is still fine.
      final exists = current.groups.any((g) => g.emoji == emoji);
      if (!exists &&
          current.groups.length >= ReactionLimits.maxDistinctPerMessage) {
        return _fail('This message has reached its reaction limit');
      }
    }

    return _repository.setReaction(chatId, messageId, emoji);
  }

  /// Mirrors the server's `INVALID_REACTION` shape check (§6.7.4): empty,
  /// blank, longer than [maxEmojiLength], or containing a NUL. Returns the
  /// reason, or `null` when the string is well-formed.
  ///
  /// ⚠️ Shape only — it cannot tell whether the emoji is in the backend's
  /// curated catalog (~73 entries, §6.7.2), which this client does not mirror.
  /// A `null` here still permits a `400 INVALID_REACTION`.
  ///
  /// ⚠️ The emoji is **not trimmed**: it is a path parameter *and* an
  /// identity, so the string sent must be byte-identical to the one that comes
  /// back in groups and in the WS snapshot, or the chip would never match.
  static String? validateEmoji(String emoji) {
    if (emoji.isEmpty || emoji.trim().isEmpty) return 'Pick a reaction';
    if (emoji.length > maxEmojiLength) {
      return 'A reaction can be at most $maxEmojiLength characters long';
    }
    if (emoji.codeUnits.contains(0)) {
      return 'That reaction contains an unsupported character';
    }
    return null;
  }

  Future<Either<Failure, void>> _fail(String message) =>
      Future.value(Left(InputFailure(message: message)));
}

/// The chat-level half of the reaction rules (§6.7.5), passed into the
/// reaction use cases so they can refuse a doomed request locally.
///
/// A tiny value type rather than a `ChatEntity` parameter on purpose: the use
/// cases need exactly two facts, and depending on the whole chat would make
/// them unusable from a context that only holds the settings (a composer
/// sheet, a cached row) and untestable without building a full `ChatEntity`.
/// Build one with [ChatReactionPolicyX.reactionPolicy] on a `ChatEntity`.
class ChatReactionPolicy {
  /// False when the chat's `reactions_mode` is `none`.
  final bool enabled;

  /// The whitelist when `reactions_mode` is `some`; `null` under `all`, which
  /// means "no restriction beyond the server's own catalog".
  final List<String>? whitelist;

  const ChatReactionPolicy({required this.enabled, this.whitelist});

  /// Everything the catalog allows — the `all` mode, and the safe default when
  /// the chat's settings aren't loaded yet (the server still enforces them).
  static const ChatReactionPolicy unrestricted = ChatReactionPolicy(
    enabled: true,
  );

  bool isAllowed(String emoji) {
    if (!enabled) return false;
    final list = whitelist;
    return list == null || list.contains(emoji);
  }
}

extension ChatReactionPolicyX on ChatEntity {
  /// This chat's reaction settings as a [ChatReactionPolicy] (§6.7.5).
  ChatReactionPolicy get reactionPolicy => ChatReactionPolicy(
    enabled: reactionsEnabled,
    whitelist: reactionWhitelist,
  );
}
