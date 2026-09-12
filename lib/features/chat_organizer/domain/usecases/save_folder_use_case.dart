import 'package:fpdart/fpdart.dart';

import 'package:chatix/core/error/failures.dart';
import 'package:chatix/features/chat_organizer/domain/entities/chat_folder.dart';
import 'package:chatix/features/chat_organizer/domain/entities/chat_organizer_data.dart';
import 'package:chatix/features/chat_organizer/domain/entities/organizer_failures.dart';
import 'package:chatix/features/chat_organizer/domain/repositories/chat_organizer_repository.dart';

/// Adds a folder or replaces the one with the same id.
///
/// A folder without rules would match the whole list, and one without a name
/// would be an unlabelled tab, so neither is allowed to reach the strip.
/// Presets carry their name and rules with them and skip both checks.
class SaveFolderUseCase {
  const SaveFolderUseCase(this._repository);

  final ChatOrganizerRepository _repository;

  Future<Either<Failure, ChatOrganizerData>> execute(
    ChatOrganizerData data,
    ChatFolder folder,
  ) async {
    final problem = validate(folder);
    if (problem != null) return left(InvalidFolderFailure(problem));

    final index = data.folders.indexWhere((f) => f.id == folder.id);

    if (index < 0 && data.folders.length >= ChatFolder.maxFolders) {
      return left(const FolderLimitFailure());
    }

    final folders = [...data.folders];
    if (index < 0) {
      folders.add(folder);
    } else {
      folders[index] = folder;
    }

    final saved = await _repository.saveFolders(folders);
    return saved.map((_) => data.copyWith(folders: folders));
  }

  /// What stops [folder] from being saved, or null when nothing does.
  static FolderProblem? validate(ChatFolder folder) {
    if (folder.rules.isEmpty) return FolderProblem.noRules;
    if (folder.isPreset) return null;

    final title = folder.title?.trim() ?? '';
    if (title.isEmpty) return FolderProblem.emptyTitle;
    if (title.length > ChatFolder.maxTitleLength) {
      return FolderProblem.titleTooLong;
    }

    return null;
  }
}
