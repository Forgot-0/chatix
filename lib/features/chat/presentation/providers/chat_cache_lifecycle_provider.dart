import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:chatix/core/utils/logger.dart';
import 'package:chatix/features/auth/presentation/providers/auth_provider.dart';
import 'package:chatix/features/chat/data/repositories/chat_local_repository_impl.dart';

/// Throws the device's copy away when the account it belongs to signs out.
///
/// Everything in the store is one account's: its chats, its drafts, and —
/// the one that would be a real bug rather than a leak — its outbox, which
/// would otherwise be drained under whoever's token came next.
///
/// Only on a transition, and only once the answer is definite. A cold start
/// begins with `authProvider` still loading, and treating that as "signed
/// out" would clear the cache on every launch, which is exactly the launch
/// the cache exists for.
final chatCacheLifecycleProvider = Provider<void>((ref) {
  var wasSignedIn = ref.read(authProvider).value != null;

  ref.listen(authProvider, (_, next) {
    if (next.isLoading) return;

    final signedIn = next.hasValue && next.value != null;
    final signedOut = wasSignedIn && !signedIn;
    wasSignedIn = signedIn;

    if (!signedOut) return;

    Logger.info('Chat cache: signed out, clearing this device\'s copy');
    unawaited(ref.read(chatLocalRepositoryProvider).forgetEverything());
  });
}, dependencies: [authProvider]);
