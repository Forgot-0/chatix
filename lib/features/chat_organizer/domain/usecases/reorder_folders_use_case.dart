import 'package:fpdart/fpdart.dart';

import 'package:chatix/core/error/failures.dart';
import 'package:chatix/features/chat_organizer/domain/entities/chat_folder.dart';
import 'package:chatix/features/chat_organizer/domain/entities/chat_organizer_data.dart';
import 'package:chatix/features/chat_organizer/domain/repositories/chat_organizer_repository.dart';

/// Moves one folder to a new place in the strip.
///
/// [newIndex] is the index the dragged tab is dropped *before*, which is what
/// `ReorderableListView` reports — hence the shift when a tab moves right.
class ReorderFoldersUseCase {
  const ReorderFoldersUseCase(this._repository);

  final ChatOrganizerRepository _repository;

  Future<Either<Failure, ChatOrganizerData>> execute(
    ChatOrganizerData data, {
    required int oldIndex,
    required int newIndex,
  }) async {
    final folders = reorder(
      data.folders,
      oldIndex: oldIndex,
      newIndex: newIndex,
    );
    if (folders == null) return right(data);

    final saved = await _repository.saveFolders(folders);
    return saved.map((_) => data.copyWith(folders: folders));
  }

  /// The moved list, or null when the move would change nothing or points
  /// outside the strip.
  static List<ChatFolder>? reorder(
    List<ChatFolder> folders, {
    required int oldIndex,
    required int newIndex,
  }) {
    if (oldIndex < 0 || oldIndex >= folders.length) return null;
    if (newIndex < 0 || newIndex > folders.length) return null;

    final target = newIndex > oldIndex ? newIndex - 1 : newIndex;
    if (target == oldIndex) return null;

    final next = [...folders];
    next.insert(target, next.removeAt(oldIndex));
    return next;
  }
}
