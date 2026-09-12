import 'package:fpdart/fpdart.dart';

import 'package:chatix/core/error/failures.dart';
import 'package:chatix/features/chat_organizer/domain/entities/chat_organizer_data.dart';
import 'package:chatix/features/chat_organizer/domain/repositories/chat_organizer_repository.dart';

/// Removes a folder. The chats it held are untouched — it never owned them,
/// it only described them.
class DeleteFolderUseCase {
  const DeleteFolderUseCase(this._repository);

  final ChatOrganizerRepository _repository;

  Future<Either<Failure, ChatOrganizerData>> execute(
    ChatOrganizerData data,
    String folderId,
  ) async {
    final folders = data.folders.where((f) => f.id != folderId).toList();
    if (folders.length == data.folders.length) return right(data);

    final saved = await _repository.saveFolders(folders);
    return saved.map((_) => data.copyWith(folders: folders));
  }
}
