import 'package:fpdart/fpdart.dart';

import 'package:chatix/core/error/failures.dart';
import 'package:chatix/features/chat_organizer/domain/entities/chat_folder.dart';
import 'package:chatix/features/chat_organizer/domain/entities/chat_organizer_data.dart';
import 'package:chatix/features/chat_organizer/domain/entities/organizer_settings.dart';

/// Where pins, the archive and folders are kept.
///
/// Deliberately sliced rather than a single `save(everything)`: the day the
/// backend grows fields for any of this, each slice maps onto its own call
/// and nothing above this line has to change.
abstract interface class ChatOrganizerRepository {
  Future<Either<Failure, ChatOrganizerData>> load();

  Future<Either<Failure, Unit>> savePinned(Set<String> chatIds);

  Future<Either<Failure, Unit>> saveArchived(Set<String> chatIds);

  Future<Either<Failure, Unit>> saveFolders(List<ChatFolder> folders);

  Future<Either<Failure, Unit>> saveSettings(OrganizerSettings settings);
}
