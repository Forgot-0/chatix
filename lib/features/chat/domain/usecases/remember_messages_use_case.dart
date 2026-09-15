import 'package:chatix/features/chat/domain/entities/message_entity.dart';
import 'package:chatix/features/chat/domain/repositories/chat_local_repository.dart';

/// Writes down messages that did not come through a repository call.
///
/// Everything fetched is stored on the way out already; this is for the
/// other source — `new_message`, `message_edited` and `ws.history` frames,
/// which reach the screen directly from the socket and would otherwise be
/// missing from the cache the next time the chat is opened.
class RememberMessagesUseCase {
  RememberMessagesUseCase(this._repository);

  final ChatLocalRepository _repository;

  Future<void> execute(String chatId, List<MessageEntity> messages) {
    if (chatId.trim().isEmpty || messages.isEmpty) return Future.value();
    return _repository.rememberMessages(chatId, messages);
  }

  /// Moves the stored cursors forward without storing a message.
  Future<void> rememberSeq(String chatId, {int? lastSeq, int? reportedSeq}) =>
      _repository.rememberSeq(
        chatId,
        lastSeq: lastSeq,
        reportedSeq: reportedSeq,
      );

  /// How far this device has already told the server the reader got.
  int? reportedReadSeq(String chatId) =>
      _repository.localReportedReadSeq(chatId);

  Future<void> forgetChat(String chatId) => _repository.forgetChat(chatId);

  /// Drops a message the socket says is gone.
  Future<void> forgetMessage(String chatId, String messageId) =>
      _repository.forgetMessage(chatId, messageId);
}
