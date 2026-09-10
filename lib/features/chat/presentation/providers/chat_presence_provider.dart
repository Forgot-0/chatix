import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:chatix/core/utils/logger.dart';
import 'package:chatix/features/auth/presentation/providers/auth_provider.dart';
import 'package:chatix/features/chat/presentation/providers/chat_providers.dart';

/// Is the other side of a direct chat online right now?
///
/// Presence only ships as a side channel of the member list
/// (`GET /chats/{id}/members/?include_presence=true`, api-docs §5.3), so it
/// costs a request per chat. Rows ask for it as they scroll into view and the
/// answer is cached here: a row that is built again — a rebuild, a scroll back
/// up, a realtime patch to the same chat — reads the cache instead of asking
/// again, and nothing is re-fetched until [ttl] has passed or the list is
/// refreshed.
class ChatPresenceController extends Notifier<Map<String, bool>> {
  /// How long a presence answer is treated as still true.
  static const Duration ttl = Duration(seconds: 90);

  /// Both sides of a direct chat, which is all there is to fetch.
  static const int _memberLimit = 2;

  final Map<String, DateTime> _checkedAt = <String, DateTime>{};
  final Set<String> _inFlight = <String>{};

  @override
  Map<String, bool> build() => const <String, bool>{};

  /// Fetches presence for [chatId] unless a fresh answer is already in hand
  /// or a request for it is already out.
  void ensureFresh(String chatId) {
    if (_inFlight.contains(chatId)) return;

    final checked = _checkedAt[chatId];
    if (checked != null && DateTime.now().difference(checked) < ttl) return;

    unawaited(_fetch(chatId));
  }

  /// Forgets everything, so the next row that asks fetches again. What
  /// pull-to-refresh means for presence.
  void invalidate() {
    _checkedAt.clear();
    if (state.isNotEmpty) state = const <String, bool>{};
  }

  Future<void> _fetch(String chatId) async {
    final myUserId = ref.read(authProvider).value?.id;
    if (myUserId == null) return;

    _inFlight.add(chatId);
    try {
      final result = await ref
          .read(getMembersUseCaseProvider)
          .execute(chatId, limit: _memberLimit, includePresence: true);

      if (!ref.mounted) return;

      // A failure is recorded like an answer: without that, a chat whose
      // members we cannot read would be retried by every rebuild.
      _checkedAt[chatId] = DateTime.now();

      result.match(
        (failure) => Logger.warning(
          'Chat presence: $chatId unavailable (${failure.message})',
        ),
        (page) {
          for (final member in page.members) {
            if (member.userId == myUserId) continue;
            _publish(chatId, page.presenceOf(member.userId) ?? false);
            return;
          }
        },
      );
    } finally {
      _inFlight.remove(chatId);
    }
  }

  void _publish(String chatId, bool isOnline) {
    if (state[chatId] == isOnline) return;
    state = {...state, chatId: isOnline};
  }
}

final chatPresenceProvider =
    NotifierProvider<ChatPresenceController, Map<String, bool>>(
      ChatPresenceController.new,
    );

/// Presence for one chat: null until it is known, and a rebuild only when
/// this chat's own answer changes.
final chatPeerOnlineProvider = Provider.family<bool?, String>((ref, chatId) {
  return ref.watch(chatPresenceProvider.select((cache) => cache[chatId]));
});
