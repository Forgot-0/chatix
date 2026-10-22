import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpdart/fpdart.dart';

import 'package:chatix/core/error/failures.dart';

/// Turns a group into a supergroup — "a large group, up to 1 000 000
/// members" (api-docs §5.1).
typedef SupergroupUpgrader =
    Future<Either<Failure, void>> Function(String chatId);

/// How a group becomes a supergroup, or null while there is no way to.
///
/// Null today: a chat's type is fixed at `POST /chats/` — `UpdateChatRequest`
/// has no `chat_type`, and no endpoint changes it (api-docs §5.2,
/// docs/BACKEND_GAPS.md §18). The settings row and its confirmation are
/// built and hidden behind this: the day the backend can do it, this
/// provider returns the call and the row appears.
final supergroupUpgradeProvider = Provider<SupergroupUpgrader?>((ref) => null);
