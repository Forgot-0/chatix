import 'package:chatix/core/error/failures.dart';
import 'package:chatix/features/chat_organizer/domain/entities/chat_folder.dart';

/// This device already holds as many folders as the strip can carry.
class FolderLimitFailure extends Failure {
  const FolderLimitFailure({this.limit = ChatFolder.maxFolders})
    : super(message: 'Folder limit reached');

  final int limit;

  @override
  List<Object?> get props => [...super.props, limit];
}

/// What is wrong with a folder that cannot be saved.
enum FolderProblem { emptyTitle, titleTooLong, noRules }

class InvalidFolderFailure extends Failure {
  const InvalidFolderFailure(this.problem)
    : super(message: 'Folder is not valid');

  final FolderProblem problem;

  @override
  List<Object?> get props => [...super.props, problem];
}
