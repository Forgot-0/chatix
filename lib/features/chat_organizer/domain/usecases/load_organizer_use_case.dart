import 'package:fpdart/fpdart.dart';

import 'package:chatix/core/error/failures.dart';
import 'package:chatix/features/chat_organizer/domain/entities/chat_organizer_data.dart';
import 'package:chatix/features/chat_organizer/domain/repositories/chat_organizer_repository.dart';

/// Reads back everything this device decided about its chat list.
class LoadOrganizerUseCase {
  const LoadOrganizerUseCase(this._repository);

  final ChatOrganizerRepository _repository;

  Future<Either<Failure, ChatOrganizerData>> execute() => _repository.load();
}
