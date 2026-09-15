import 'package:chatix/core/error/failures.dart';

/// The pinned zone is full.
///
/// The server enforces it too — a sixth pin answers
/// `400 PINNED_CHATS_LIMIT_EXCEEDED` (api-docs §2.x, §5.2) — but the client
/// checks first so the answer is instant and says which limit was hit.
class PinnedChatsLimitFailure extends Failure {
  const PinnedChatsLimitFailure({this.limit = 5})
    : super(message: 'Pinned chats limit reached');

  /// What the server's error detail calls `limit`.
  final int limit;

  @override
  List<Object?> get props => [...super.props, limit];
}
