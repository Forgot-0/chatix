import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpdart/fpdart.dart';

import 'package:chatix/core/error/failures.dart';
import 'package:chatix/features/auth/presentation/providers/auth_provider.dart';
import 'package:chatix/features/chat/domain/entities/chat_entity.dart';
import 'package:chatix/features/chat/domain/usecases/create_chat_use_case.dart';
import 'package:chatix/features/chat/presentation/providers/chat_list_provider.dart';
import 'package:chatix/features/chat/presentation/providers/chat_providers.dart';
import 'package:chatix/features/chat/presentation/utils/direct_chat_lookup.dart';

/// The id of the 1:1 chat with [userId], creating it if this device has not
/// seen one.
///
/// The dedup happens here rather than on the server: `409 DIRECT_CHAT_EXISTS`
/// is documented but never actually raised, so a second `POST /chats/` would
/// quietly make a duplicate (api-docs §5.2). The code is still read back as a
/// fallback, since a chat this device has not loaded cannot be found locally.
Future<Either<Failure, String>> resolveDirectChatWith(
  WidgetRef ref,
  int userId,
) async {
  final existing = findDirectChatWith(
    ref.read(chatListProvider).value?.items ?? const [],
    userId,
    myUserId: ref.read(authProvider).value?.id,
  );
  if (existing != null) return Right(existing.id);

  final result = await ref
      .read(createChatUseCaseProvider)
      .execute(chatType: ChatType.direct, memberIds: [userId]);

  return result.match<Either<Failure, String>>(
    (failure) {
      final chatId = existingDirectChatId(failure);
      if (chatId == null) return Left(failure);

      ref.read(chatListProvider.notifier).refresh();
      return Right(chatId);
    },
    (chat) {
      ref.read(chatListProvider.notifier).refresh();
      return Right(chat.id);
    },
  );
}
