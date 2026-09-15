import 'package:chatix/features/chat/domain/entities/chat_pages.dart';
import 'package:chatix/features/chat/domain/repositories/chat_local_repository.dart';

/// The chat list as this device last saw it.
///
/// What the list screen draws on its very first frame, before a request has
/// been sent. Null means this device has never loaded the list, which is the
/// only case where there is nothing to do but wait for the network.
class GetLocalChatsUseCase {
  GetLocalChatsUseCase(this._repository);

  final ChatLocalRepository _repository;

  ChatsPage? execute({bool archived = false}) =>
      _repository.localChats(archived: archived);
}
