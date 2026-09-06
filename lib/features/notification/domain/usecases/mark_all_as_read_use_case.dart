import 'package:fpdart/fpdart.dart';

import 'package:chatix/core/error/failures.dart';
import 'package:chatix/features/notification/domain/repositories/notification_repository.dart';

class MarkAllAsReadUseCase {
  final NotificationRepository _repository;

  MarkAllAsReadUseCase(this._repository);

  Future<Either<Failure, int>> execute() {
    return _repository.markAllAsRead();
  }
}
