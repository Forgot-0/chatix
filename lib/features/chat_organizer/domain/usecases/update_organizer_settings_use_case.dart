import 'package:fpdart/fpdart.dart';

import 'package:chatix/core/error/failures.dart';
import 'package:chatix/features/chat_organizer/domain/entities/chat_organizer_data.dart';
import 'package:chatix/features/chat_organizer/domain/entities/organizer_settings.dart';
import 'package:chatix/features/chat_organizer/domain/repositories/chat_organizer_repository.dart';

/// Stores the organizer's own switches.
class UpdateOrganizerSettingsUseCase {
  const UpdateOrganizerSettingsUseCase(this._repository);

  final ChatOrganizerRepository _repository;

  Future<Either<Failure, ChatOrganizerData>> execute(
    ChatOrganizerData data,
    OrganizerSettings settings,
  ) async {
    if (data.settings == settings) return right(data);

    final saved = await _repository.saveSettings(settings);
    return saved.map((_) => data.copyWith(settings: settings));
  }
}
