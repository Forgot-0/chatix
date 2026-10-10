import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:chatix/core/utils/logger.dart';
import 'package:chatix/features/auth/presentation/providers/auth_provider.dart';
import 'package:chatix/features/chat/domain/entities/chat_pages.dart';
import 'package:chatix/features/chat/domain/usecases/get_members_use_case.dart';
import 'package:chatix/features/chat/presentation/providers/chat_providers.dart';

/// Presence, per chat, read off the member list and kept for a while.
///
/// Presence only ships as a side channel of the member list
/// (`GET /chats/{id}/members/?include_presence=true`, api-docs §5.3) — the
/// gateway publishes no online/offline events (§6.4) — so every answer costs
/// a request. Whoever needs one asks for it whenever it is drawn, and the
/// answer is cached here: a widget built again — a rebuild, a scroll back up,
/// a realtime patch to the same chat — reads the cache instead of asking
/// again, and nothing is re-fetched until [ttl] has passed or the cache is
/// dropped.
///
/// What is kept per chat is [T], read from the page by [answerFrom].
abstract class MemberPresenceCache<T> extends Notifier<Map<String, T>> {
  /// How long a presence answer is treated as still true.
  static const Duration ttl = Duration(seconds: 90);

  final Map<String, DateTime> _checkedAt = <String, DateTime>{};
  final Set<String> _inFlight = <String>{};

  /// How much of the member list to ask for.
  int get memberLimit;

  /// What [page] says, from the point of view of [myUserId]; null when it
  /// cannot honestly say anything.
  T? answerFrom(MembersPage page, int myUserId);

  @override
  Map<String, T> build() => <String, T>{};

  /// Fetches presence for [chatId] unless a fresh answer is already in hand
  /// or a request for it is already out.
  void ensureFresh(String chatId) {
    if (_inFlight.contains(chatId)) return;

    final checked = _checkedAt[chatId];
    if (checked != null && DateTime.now().difference(checked) < ttl) return;

    unawaited(_fetch(chatId));
  }

  /// Forgets everything, so the next widget that asks fetches again. What
  /// pull-to-refresh means for presence.
  void invalidate() {
    _checkedAt.clear();
    if (state.isNotEmpty) state = <String, T>{};
  }

  Future<void> _fetch(String chatId) async {
    final myUserId = ref.read(authProvider).value?.id;
    if (myUserId == null) return;

    _inFlight.add(chatId);
    try {
      final result = await ref
          .read(getMembersUseCaseProvider)
          .execute(chatId, limit: memberLimit, includePresence: true);

      if (!ref.mounted) return;

      // A failure is recorded like an answer: without that, a chat whose
      // members we cannot read would be retried by every rebuild.
      _checkedAt[chatId] = DateTime.now();

      result.match(
        (failure) => Logger.warning(
          'Chat presence: $chatId unavailable (${failure.message})',
        ),
        (page) => _publish(chatId, answerFrom(page, myUserId)),
      );
    } finally {
      _inFlight.remove(chatId);
    }
  }

  void _publish(String chatId, T? answer) {
    if (answer == null) {
      if (!state.containsKey(chatId)) return;
      state = {...state}..remove(chatId);
      return;
    }
    if (state[chatId] == answer) return;
    state = {...state, chatId: answer};
  }
}

/// Is the other side of a direct chat online right now?
class ChatPresenceController extends MemberPresenceCache<bool> {
  /// Both sides of a direct chat, which is all there is to fetch.
  @override
  int get memberLimit => 2;

  @override
  bool? answerFrom(MembersPage page, int myUserId) {
    for (final member in page.members) {
      if (member.userId == myUserId) continue;
      // No entry means offline (api-docs §5.3).
      return page.presenceOf(member.userId) ?? false;
    }
    return null;
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

/// How many members of a group are online right now.
///
/// Counted from one page as large as the endpoint allows. A chat with more
/// members than that has no count at all rather than a low one: presence of
/// the rest is simply unknown, and "3 online" in a chat where the first page
/// happened to hold three would be a number made up out of paging.
class ChatOnlineCountController extends MemberPresenceCache<int> {
  @override
  int get memberLimit => GetMembersUseCase.maxLimit;

  @override
  int? answerFrom(MembersPage page, int myUserId) {
    if (page.hasNext) return null;

    // Everyone the server says is here, the reader included — they are
    // reading, after all, and that is what a member count next to it means.
    return page.presence.where((entry) => entry.isOnline).length;
  }
}

final chatOnlineCountProvider =
    NotifierProvider<ChatOnlineCountController, Map<String, int>>(
      ChatOnlineCountController.new,
    );

/// The online count for one chat: null until it is known, or when it cannot
/// be known.
final chatMembersOnlineProvider = Provider.family<int?, String>((ref, chatId) {
  return ref.watch(chatOnlineCountProvider.select((cache) => cache[chatId]));
});
