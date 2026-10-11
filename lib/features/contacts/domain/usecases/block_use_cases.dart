import 'package:fpdart/fpdart.dart';

import 'package:chatix/core/error/failures.dart';
import 'package:chatix/features/contacts/domain/entities/blocked_user.dart';
import 'package:chatix/features/contacts/domain/entities/contact_failures.dart';
import 'package:chatix/features/contacts/domain/repositories/blocked_users_repository.dart';

/// `POST /contacts/{user_id}/block/` — and not for oneself, which the server
/// refuses with `400 SELF_CONTACT_NOT_ALLOWED` anyway (api-docs §4.13).
class BlockUserUseCase {
  const BlockUserUseCase(this._repository);

  final BlockedUsersRepository _repository;

  Future<Either<Failure, void>> execute(int userId, {required int ownerId}) {
    if (userId == ownerId) {
      return Future.value(const Left(SelfContactFailure()));
    }
    return _repository.block(userId, ownerId: ownerId);
  }
}

class UnblockUserUseCase {
  const UnblockUserUseCase(this._repository);

  final BlockedUsersRepository _repository;

  Future<Either<Failure, void>> execute(int userId, {required int ownerId}) =>
      _repository.unblock(userId, ownerId: ownerId);
}

/// One page of the block list for the screen.
class GetBlockedPageUseCase {
  const GetBlockedPageUseCase(this._repository);

  final BlockedUsersRepository _repository;

  Future<Either<Failure, BlockedPage>> execute({
    required int ownerId,
    int? afterTargetId,
  }) => _repository.fetchPage(ownerId: ownerId, afterTargetId: afterTargetId);
}

class SyncBlockListUseCase {
  const SyncBlockListUseCase(this._repository);

  final BlockedUsersRepository _repository;

  Future<Either<Failure, BlockList>> execute({required int ownerId}) =>
      _repository.sync(ownerId: ownerId);
}
