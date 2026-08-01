import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chatix/features/auth/presentation/providers/auth_provider.dart';
import 'package:chatix/features/chat/domain/entities/chat_entity.dart';
import 'package:chatix/features/chat/domain/entities/chat_member_entity.dart';
import 'package:chatix/features/chat/domain/entities/chat_pages.dart';
import 'package:chatix/features/chat/presentation/providers/chat_providers.dart';

const _pageSize = 50;

/// Members of one chat, plus the chat itself.
///
/// The chat comes along because every permission decision needs all three
/// layers of api-docs §9.1 — the target's role, the *chat-level* override map
/// (`ChatEntity.permissions`) and the caller's own personal overrides. A
/// members list on its own cannot decide whether to show a Kick button.
class ChatMembersState extends Equatable {
  final ChatEntity? chat;
  final List<ChatMemberEntity> members;
  final bool hasNext;
  final int? nextUserId;
  final bool isLoadingMore;

  /// Online flags, only populated when `include_presence=true` was requested
  /// (api-docs §6.3). Keyed by `user_id` — a **missing** entry means "unknown",
  /// not "offline".
  final Map<int, bool> presence;

  /// The signed-in user's id, needed to pick [me] out of the roster.
  final int? myUserId;

  const ChatMembersState({
    this.chat,
    this.members = const [],
    this.hasNext = false,
    this.nextUserId,
    this.isLoadingMore = false,
    this.presence = const {},
    this.myUserId,
  });

  bool get canLoadMore => hasNext && nextUserId != null;

  /// The caller's own membership — the "me" side of every permission check.
  ///
  /// ⚠️ Resolved from the loaded data, not from `chat.me`: this screen's chat
  /// comes from `GET /chats/{id}/` (a `ChatDetaiDTO`), which has no `me` field
  /// at all — the caller's row lives in `members` (api-docs §6.2). The
  /// paginated [members] list is consulted first because it is the freshest
  /// copy after a role change, then the chat's own embedded roster, which also
  /// covers a caller whose row sits on a page not yet scrolled to.
  ChatMemberEntity? get me {
    final id = myUserId;
    if (id == null) return chat?.me;
    for (final member in members) {
      if (member.userId == id) return member;
    }
    return chat?.membershipOf(id);
  }

  ChatMembersState copyWith({
    ChatEntity? chat,
    List<ChatMemberEntity>? members,
    bool? hasNext,
    int? nextUserId,
    bool? isLoadingMore,
    Map<int, bool>? presence,
    int? myUserId,
  }) {
    return ChatMembersState(
      chat: chat ?? this.chat,
      members: members ?? this.members,
      hasNext: hasNext ?? this.hasNext,
      // Cursor is replaced wholesale, never `?? this` — see ChatsPage.
      nextUserId: nextUserId,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      presence: presence ?? this.presence,
      myUserId: myUserId ?? this.myUserId,
    );
  }

  @override
  List<Object?> get props => [
    chat,
    members,
    hasNext,
    nextUserId,
    isLoadingMore,
    presence,
    myUserId,
  ];
}

/// Drives `ChatMembersScreen`: cursor pagination plus the four moderation
/// actions (add / change role / ban / kick, api-docs §6.3).
///
/// Every action re-reads the list afterwards rather than patching state
/// locally. All four endpoints answer `204` with no body, so the client has no
/// authoritative post-action row to apply — and a role change can alter what
/// the *caller* is allowed to do next, which only fresh data reflects.
class ChatMembersController
    extends AsyncNotifier<ChatMembersState> {
  ChatMembersController(this._chatId);

  /// The chat this controller is scoped to. Riverpod 3's manual `family` API
  /// hands the argument to the constructor (there is no inherited `arg`).
  final String _chatId;

  @override
  Future<ChatMembersState> build() => _load();

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(_load);
  }

  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || !current.canLoadMore || current.isLoadingMore) {
      return;
    }

    state = AsyncValue.data(current.copyWith(isLoadingMore: true));

    final result = await ref
        .read(getMembersUseCaseProvider)
        .executeNextPage(
          _chatId,
          MembersPage(
            members: const [],
            hasNext: current.hasNext,
            nextUserId: current.nextUserId,
          ),
          limit: _pageSize,
          includePresence: true,
        );

    state = result.fold(
      (_) => AsyncValue.data(
        current.copyWith(
          isLoadingMore: false,
          nextUserId: current.nextUserId,
        ),
      ),
      (page) => AsyncValue.data(
        current.copyWith(
          members: [...current.members, ...page.members],
          hasNext: page.hasNext,
          nextUserId: page.nextUserId,
          isLoadingMore: false,
          presence: {
            ...current.presence,
            for (final entry in page.presence) entry.userId: entry.isOnline,
          },
        ),
      ),
    );
  }

  /// `POST /chats/{id}/members/` (api-docs §6.3). Rethrows the [Failure] so
  /// the screen can show it — e.g. `409 ALREADY_CHAT_MEMBER`.
  Future<void> addMember(int userId, {ChatRole role = ChatRole.member}) async {
    final result = await ref
        .read(addMemberUseCaseProvider)
        .execute(_chatId, userId, role: role);
    result.match((failure) => throw failure, (_) {});
    await refresh();
  }

  Future<void> changeRole(int userId, ChatRole role) async {
    final result = await ref
        .read(changeMemberRoleUseCaseProvider)
        .execute(_chatId, userId, role);
    result.match((failure) => throw failure, (_) {});
    await refresh();
  }

  /// `PATCH /chats/{id}/members/{user_id}/ban/` (api-docs §6.3).
  /// [bannedTo] omitted = permanent ban.
  Future<void> banMember(
    int userId, {
    String? reason,
    DateTime? bannedTo,
  }) async {
    final result = await ref
        .read(banMemberUseCaseProvider)
        .execute(_chatId, userId, reason: reason, bannedTo: bannedTo);
    result.match((failure) => throw failure, (_) {});
    await refresh();
  }

  Future<void> kickMember(int userId) async {
    final result = await ref
        .read(kickMemberUseCaseProvider)
        .execute(_chatId, userId);
    result.match((failure) => throw failure, (_) {});
    await refresh();
  }

  Future<ChatMembersState> _load() async {
    // Identifies "me" among the members for the §9.1 checks; watched so a
    // sign-in/out re-resolves the caller's row.
    final myUserId = ref.watch(authProvider).value?.id;

    final chatFuture = ref.read(getChatUseCaseProvider).execute(_chatId);
    final membersFuture = ref
        .read(getMembersUseCaseProvider)
        .execute(_chatId, limit: _pageSize, includePresence: true);

    final chat = (await chatFuture).getOrElse((failure) => throw failure);
    final page = (await membersFuture).getOrElse((failure) => throw failure);

    return ChatMembersState(
      chat: chat,
      members: page.members,
      hasNext: page.hasNext,
      nextUserId: page.nextUserId,
      presence: {
        for (final entry in page.presence) entry.userId: entry.isOnline,
      },
      myUserId: myUserId,
    );
  }
}

final chatMembersProvider =
    AsyncNotifierProvider.family<
      ChatMembersController,
      ChatMembersState,
      String
    >(ChatMembersController.new);
