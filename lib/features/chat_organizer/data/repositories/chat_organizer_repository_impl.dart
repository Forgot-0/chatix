import 'package:fpdart/fpdart.dart';

import 'package:chatix/core/error/exceptions.dart';
import 'package:chatix/core/error/failures.dart';
import 'package:chatix/core/utils/logger.dart';
import 'package:chatix/features/chat_organizer/data/datasources/chat_organizer_local_data_source.dart';
import 'package:chatix/features/chat_organizer/data/models/chat_folder_model.dart';
import 'package:chatix/features/chat_organizer/data/models/organizer_settings_model.dart';
import 'package:chatix/features/chat_organizer/domain/entities/chat_folder.dart';
import 'package:chatix/features/chat_organizer/domain/entities/chat_organizer_data.dart';
import 'package:chatix/features/chat_organizer/domain/entities/organizer_settings.dart';
import 'package:chatix/features/chat_organizer/domain/repositories/chat_organizer_repository.dart';

class ChatOrganizerRepositoryImpl implements ChatOrganizerRepository {
  const ChatOrganizerRepositoryImpl(this._local);

  final ChatOrganizerLocalDataSource _local;

  @override
  Future<Either<Failure, ChatOrganizerData>> load() {
    return _guard(() async {
      final folders = await _local.readFolders();

      return ChatOrganizerData(
        pinnedChatIds: await _local.readPinned(),
        archivedChatIds: await _local.readArchived(),
        folders: folders.map((f) => f.toEntity()).nonNulls.toList(),
        settings: (await _local.readSettings()).toEntity(),
      );
    });
  }

  @override
  Future<Either<Failure, Unit>> savePinned(Set<String> chatIds) =>
      _guard(() async {
        await _local.writePinned(chatIds);
        return unit;
      });

  @override
  Future<Either<Failure, Unit>> saveArchived(Set<String> chatIds) =>
      _guard(() async {
        await _local.writeArchived(chatIds);
        return unit;
      });

  @override
  Future<Either<Failure, Unit>> saveFolders(List<ChatFolder> folders) =>
      _guard(() async {
        await _local.writeFolders(
          folders.map(ChatFolderModel.fromEntity).toList(),
        );
        return unit;
      });

  @override
  Future<Either<Failure, Unit>> saveSettings(OrganizerSettings settings) =>
      _guard(() async {
        await _local.writeSettings(
          OrganizerSettingsModel.fromEntity(settings),
        );
        return unit;
      });

  Future<Either<Failure, T>> _guard<T>(Future<T> Function() body) async {
    try {
      return right(await body());
    } on CacheException catch (error) {
      Logger.warning('Organizer: storage refused (${error.message})');
      return left(CacheFailure(message: error.message));
    } catch (error, stackTrace) {
      Logger.error('Organizer: unexpected storage error', error, stackTrace);
      return left(CacheFailure(message: '$error'));
    }
  }
}
