import 'package:equatable/equatable.dart';

import 'package:chatix/features/contacts/domain/entities/contact.dart';

/// One person on the owner's block list — an entry of `BlockedListDTO`
/// (api-docs §4.13).
class BlockedUser extends Equatable {
  const BlockedUser({required this.userId, required this.since, this.profile});

  /// `target_id`: the blocked person's user id, which is also their profile
  /// id.
  final int userId;

  /// `created_at`: when the block was set.
  final DateTime since;

  /// Null when the person has no profile (any more).
  final ContactProfile? profile;

  @override
  List<Object?> get props => [userId, since, profile];
}

/// One page of `GET /contacts/blocked/`, ordered by `target_id`.
class BlockedPage extends Equatable {
  const BlockedPage({
    required this.users,
    required this.hasNext,
    this.nextTargetId,
  });

  static const BlockedPage empty = BlockedPage(users: [], hasNext: false);

  final List<BlockedUser> users;
  final bool hasNext;

  /// What to send as `after_target_id` for the next page.
  final int? nextTargetId;

  @override
  List<Object?> get props => [users, hasNext, nextTargetId];
}

/// Whom the owner has blocked, as this device last heard it.
///
/// The server only keeps and serves the list: "the sender is blocked" is not
/// checked by the chats yet ("этап 2", api-docs §4.13), so a blocked person
/// can still write. Everything a block changes today — no notifications, no
/// unread badge, no composer in the direct chat — is done by this client
/// from this set.
class BlockList extends Equatable {
  const BlockList({required this.ownerId, this.userIds = const <int>{}});

  /// Whose list it is. A list left by another account is never applied.
  final int ownerId;

  final Set<int> userIds;

  bool contains(int userId) => userIds.contains(userId);

  BlockList copyWith({Set<int>? userIds}) =>
      BlockList(ownerId: ownerId, userIds: userIds ?? this.userIds);

  @override
  List<Object?> get props => [ownerId, userIds];
}
