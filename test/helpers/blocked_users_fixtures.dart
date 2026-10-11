import 'package:fpdart/fpdart.dart';

import 'package:chatix/core/error/failures.dart';
import 'package:chatix/features/contacts/data/datasources/blocked_users_remote_data_source.dart';
import 'package:chatix/features/contacts/domain/entities/blocked_user.dart';
import 'package:chatix/features/contacts/domain/entities/contact.dart';

final DateTime kBlockedSince = DateTime.utc(2026, 10, 1, 12);

/// A block-list entry as the server would send it.
BlockedUser blockedUser(
  int userId, {
  String? displayName,
  String? username,
  bool withProfile = true,
}) {
  return BlockedUser(
    userId: userId,
    since: kBlockedSince,
    profile: withProfile
        ? ContactProfile(
            id: userId,
            username: username ?? 'user$userId',
            displayName: displayName,
          )
        : null,
  );
}

/// One recorded `GET /contacts/blocked/`.
typedef BlockedPageRequest = ({int limit, int? afterTargetId});

/// The block list with scripted answers and a record of what was asked.
class FakeBlockedUsersRemote implements BlockedUsersRemoteDataSource {
  FakeBlockedUsersRemote({List<BlockedUser>? users})
    : onPage = blockedPagesOf(users ?? const []);

  Future<Either<Failure, BlockedPage>> Function(BlockedPageRequest request)
  onPage;

  Future<Either<Failure, void>> Function(int userId)? onBlock;
  Future<Either<Failure, void>> Function(int userId)? onUnblock;

  final List<BlockedPageRequest> pages = [];
  final List<int> blocks = [];
  final List<int> unblocks = [];

  @override
  Future<Either<Failure, BlockedPage>> fetchPage({
    int limit = BlockedUsersApi.screenPageSize,
    int? afterTargetId,
  }) {
    final request = (limit: limit, afterTargetId: afterTargetId);
    pages.add(request);
    return onPage(request);
  }

  @override
  Future<Either<Failure, void>> block(int userId) {
    blocks.add(userId);
    return onBlock?.call(userId) ?? Future.value(const Right(null));
  }

  @override
  Future<Either<Failure, void>> unblock(int userId) {
    unblocks.add(userId);
    return onUnblock?.call(userId) ?? Future.value(const Right(null));
  }
}

/// [users] split into pages of the requested size, each pointing at the
/// next by the last id on it — the way the server pages (api-docs §4.13).
Future<Either<Failure, BlockedPage>> Function(BlockedPageRequest)
blockedPagesOf(List<BlockedUser> users) {
  final sorted = [...users]..sort((a, b) => a.userId.compareTo(b.userId));
  return (request) async {
    final after = request.afterTargetId;
    final rest = after == null
        ? sorted
        : sorted.where((user) => user.userId > after).toList();
    final page = rest.take(request.limit).toList();
    final hasNext = rest.length > request.limit;
    return Right(
      BlockedPage(
        users: page,
        hasNext: hasNext,
        nextTargetId: hasNext ? page.last.userId : null,
      ),
    );
  };
}
