import 'package:chatix/features/chat/domain/entities/outbox_entry.dart';
import 'package:chatix/features/chat/domain/repositories/chat_local_repository.dart';

/// The queue of writes that have not reached the server, as it is kept
/// between runs.
///
/// Reading is synchronous and writing is not, which is the shape the queue
/// needs: an entry has to be in memory the instant it is created — the
/// message is already on screen — and on disk a moment later, before
/// anything can go wrong with the request it stands for.
class ChatOutboxUseCase {
  ChatOutboxUseCase(this._repository);

  final ChatLocalRepository _repository;

  List<OutboxEntry> load() => _repository.localOutbox();

  Future<void> save(OutboxEntry entry) => _repository.saveOutboxEntry(entry);

  Future<void> drop(String id) => _repository.dropOutboxEntry(id);
}
