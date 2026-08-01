import 'package:fpdart/fpdart.dart';
import 'package:chatix/core/error/failures.dart';
import 'package:chatix/features/chat/domain/entities/chat_entity.dart';
import 'package:chatix/features/chat/domain/repositories/chat_repository.dart';

/// `POST /chats/` 🔒 4/5min (api-docs §6.2).
///
/// Validates locally what the backend would otherwise reject, because the
/// endpoint is rate-limited to 4 calls per 5 minutes — a wasted request here
/// costs the user a quarter of their creation budget, so every check that can
/// be done offline is done offline.
class CreateChatUseCase {
  /// `CreateChatRequest.member_ids` cap (api-docs §6.2). Note this is the
  /// limit on the *initial* list, not on the chat: bigger chats are filled up
  /// afterwards via `addMember`.
  static const int maxInitialMembers = 100;

  static const int maxNameLength = 255;
  static const int maxDescriptionLength = 1024;

  /// `slow_mode_seconds` range (api-docs §6.2) — 0 to 24 h.
  static const int maxSlowModeSeconds = 86400;

  final ChatRepository _repository;

  CreateChatUseCase(this._repository);

  Future<Either<Failure, ChatEntity>> execute({
    String? name,
    String? description,
    ChatType chatType = ChatType.direct,
    List<int> memberIds = const [],
    bool isPublic = false,
    bool adminOnly = false,
    int slowModeSeconds = 0,
    Map<String, bool>? permissions,
  }) {
    // ⚠️ api-docs §6.2: a direct chat must carry EXACTLY one member id — the
    // person you're messaging; the caller is added implicitly. Both zero and
    // two-plus produce `400 MEMBER_LIMIT_EXCEEDED`, a code whose name points
    // at the wrong problem ("limit exceeded" for an *empty* list), so we
    // never let it get that far and explain the actual mistake instead.
    if (chatType == ChatType.direct && memberIds.length != 1) {
      return _fail(
        memberIds.isEmpty
            ? 'Select the person you want to chat with — a direct chat needs '
                  'exactly one other participant'
            : 'A direct chat can have exactly one other participant, but '
                  '${memberIds.length} were selected — create a group chat '
                  'instead',
      );
    }

    // A group/supergroup/channel without a name is legal on the wire but
    // renders as an untitled row in every list, so require one: for these
    // types the name is the only thing identifying the chat, whereas a direct
    // chat is labelled by the other participant.
    if (chatType != ChatType.direct && (name == null || name.trim().isEmpty)) {
      return _fail('A ${chatType.wire} chat needs a name');
    }

    if (name != null && name.length > maxNameLength) {
      return _fail('Chat name must be $maxNameLength characters or fewer');
    }

    if (description != null && description.length > maxDescriptionLength) {
      return _fail(
        'Chat description must be $maxDescriptionLength characters or fewer',
      );
    }

    if (memberIds.length > maxInitialMembers) {
      return _fail(
        'You can add at most $maxInitialMembers members while creating a chat '
        '(${memberIds.length} selected) — add the rest afterwards',
      );
    }

    // +1 for the creator, who is always a member of the chat they create.
    if (memberIds.length + 1 > chatType.maxMembers) {
      return _fail(
        'A ${chatType.wire} chat holds at most ${chatType.maxMembers} members',
      );
    }

    if (memberIds.toSet().length != memberIds.length) {
      return _fail('The same person was added twice');
    }

    if (slowModeSeconds < 0 || slowModeSeconds > maxSlowModeSeconds) {
      return _fail(
        'Slow mode must be between 0 and $maxSlowModeSeconds seconds',
      );
    }

    return _repository.createChat(
      name: name?.trim(),
      description: description?.trim(),
      chatType: chatType,
      memberIds: memberIds,
      isPublic: isPublic,
      adminOnly: adminOnly,
      slowModeSeconds: slowModeSeconds,
      permissions: permissions,
    );
  }

  Future<Either<Failure, ChatEntity>> _fail(String message) =>
      Future.value(Left(InputFailure(message: message)));
}
