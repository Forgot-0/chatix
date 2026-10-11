import 'package:fpdart/fpdart.dart';

import 'package:chatix/core/error/failures.dart';
import 'package:chatix/features/contacts/domain/entities/blocked_user.dart';

/// The block list (`/contacts/blocked/`, `/contacts/{user_id}/block/`,
/// api-docs §4.13), with a copy of who is on it kept on this device.
///
/// The copy is what the client-side effects of a block read — notifications,
/// the unread badge, the composer — so it is written through on every
/// answer: a page read, a block, an unblock, a full sync.
abstract interface class BlockedUsersRepository {
  /// Who this device thinks is blocked, without asking anybody. Null when
  /// nothing has been stored yet.
  BlockList? cached();

  /// One page for the screen, from [afterTargetId]. Everybody on it is
  /// blocked, so they are added to the copy as they arrive.
  Future<Either<Failure, BlockedPage>> fetchPage({
    required int ownerId,
    int? afterTargetId,
  });

  /// Reads the whole list and makes the copy exactly that — the only way an
  /// unblock made on another device reaches this one.
  Future<Either<Failure, BlockList>> sync({required int ownerId});

  /// `POST /contacts/{user_id}/block/`. Blocking twice is not an error.
  Future<Either<Failure, void>> block(int userId, {required int ownerId});

  /// `DELETE /contacts/{user_id}/block/`. Neither is unblocking somebody who
  /// was not blocked.
  Future<Either<Failure, void>> unblock(int userId, {required int ownerId});

  /// Drops the copy — the account it belonged to signed out.
  Future<void> clear();
}
