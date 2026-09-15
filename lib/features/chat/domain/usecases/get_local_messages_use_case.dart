import 'package:chatix/features/chat/domain/entities/message_entity.dart';
import 'package:chatix/features/chat/domain/repositories/chat_local_repository.dart';

/// The newest messages this device already holds for a chat, newest first.
///
/// The chat screen opens on these and then catches up: the socket is given
/// the highest `seq` among them so `ws.history` can replay what was missed
/// (api-docs §6.3), and `GET /messages/` is asked for the current window in
/// parallel.
class GetLocalMessagesUseCase {
  GetLocalMessagesUseCase(this._repository);

  final ChatLocalRepository _repository;

  List<MessageEntity> execute(String chatId, {int limit = 60}) {
    if (chatId.trim().isEmpty) return const [];
    return _repository.localMessages(chatId, limit: limit);
  }
}
