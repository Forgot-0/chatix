import 'package:fpdart/fpdart.dart';

import 'package:chatix/core/error/failures.dart';
import 'package:chatix/features/chat_organizer/domain/entities/chat_folder.dart';
import 'package:chatix/features/chat_organizer/domain/entities/chat_organizer_data.dart';
import 'package:chatix/features/chat_organizer/domain/entities/organizer_settings.dart';

/// Where folders are kept.
///
/// Deliberately sliced rather than a single `save(everything)`: the day the
/// backend grows a folder resource, each slice maps onto its own call and
/// nothing above this line has to change. That is what already happened to
/// pins and the archive, which moved out of here onto the chat row.
abstract interface class ChatOrganizerRepository {
  Future<Either<Failure, ChatOrganizerData>> load();

  Future<Either<Failure, Unit>> saveFolders(List<ChatFolder> folders);

  Future<Either<Failure, Unit>> saveSettings(OrganizerSettings settings);
}
