import 'package:fpdart/fpdart.dart';
import 'package:chatix/core/error/failures.dart';
import 'package:chatix/features/chat/domain/entities/chat_entity.dart';
import 'package:chatix/features/chat/domain/repositories/chat_repository.dart';

class CreateChatUseCase {
  static const int maxInitialMembers = 100;

  static const int maxNameLength = 255;
  static const int maxDescriptionLength = 1024;

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

String? existingDirectChatId(Failure failure) {
  if (failure is! ApiFailure) return null;
  if (failure.code != 'DIRECT_CHAT_EXISTS') return null;

  final detail = failure.detail;
  if (detail is! Map) return null;

  final chatId = detail['chat_id'];
  if (chatId is! String || chatId.isEmpty) return null;

  return chatId;
}

String? chatFailureMessage(Failure failure) {
  if (failure is! ApiFailure) return null;
  final detail = failure.detail;

  switch (failure.code) {
    case 'SLOW_MODE_OUT_OF_RANGE':
      final range = detail is Map ? detail['valid_range'] : null;
      if (range is List && range.length == 2) {
        return 'Slow mode must be between ${range[0]} and ${range[1]} seconds';
      }
      return 'Slow mode must be between 0 and '
          '${CreateChatUseCase.maxSlowModeSeconds} seconds';

    case 'MEMBER_LIMIT_EXCEEDED':
      return 'This chat cannot take that many members';

    default:
      return null;
  }
}
