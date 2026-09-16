import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chatix/core/error/failures.dart';
import 'package:chatix/core/utils/logger.dart';
import 'package:chatix/features/auth/presentation/providers/auth_provider.dart';
import 'package:chatix/features/chat/domain/entities/chat_entity.dart';
import 'package:chatix/features/chat/domain/entities/chat_member_entity.dart';
import 'package:chatix/features/chat/domain/entities/chat_pages.dart';
import 'package:chatix/features/chat/presentation/providers/chat_providers.dart';
import 'package:chatix/features/chat/presentation/utils/chat_member_roster.dart';

/// One page of `GET /chats/{id}/members/`. The endpoint allows up to 500
/// (api-docs §5.3); 50 is a screenful and change, and the rest arrives as the
/// reader scrolls.
const _pageSize = 50;

class ChatMembersState extends Equatable {
  final ChatEntity? chat;
  final List<ChatMemberEntity> members;
  final bool hasNext;
  final int? nextUserId;
  final bool isLoadingMore;

  /// Who is online, joined from the `presence` array the member list carries
  /// alongside `members` rather than inside it (api-docs §5.3). A user with
  /// no entry is offline.
  final Map<int, bool> presence;

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

  bool isOnline(int userId) => presence[userId] ?? false;

  /// The banned members, which only the chat detail reports — the paged
  /// member list drops them entirely (api-docs §5.3).
  List<ChatMemberEntity> get banned => bannedMembersOf(chat);

  /// How many people are known to be in the chat, banned included. Used to
  /// keep the invite screen honest when `member_count` lags behind.
  int get knownMemberCount {
    final ids = {
      for (final member in members) member.userId,
      for (final member in banned) member.userId,
    };
    return ids.length;
  }

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

/// What came of adding several people at once.
///
/// `POST /members/` takes one user at a time (api-docs §5.3), so an invite of
/// five is five requests and any of them can fail on its own — already a
/// member, the chat filled up in between. Both halves are reported so the
/// screen can say "three added, two not" instead of one blanket failure.
class AddMembersOutcome {
  const AddMembersOutcome({required this.added, required this.failed});

  final List<int> added;
  final Map<int, Failure> failed;

  bool get isCompleteSuccess => failed.isEmpty;

  Failure? get firstFailure => failed.isEmpty ? null : failed.values.first;
}

class ChatMembersController extends AsyncNotifier<ChatMembersState> {
  ChatMembersController(this._chatId);

  final String _chatId;

  @override
  Future<ChatMembersState> build() => _load();

  /// Reloads both halves without blanking the list first.
  ///
  /// A refresh that fails keeps the roster already on screen rather than
  /// replacing it with an error page: it is usually a moderation action's
  /// follow-up read, and the action itself already reported its own outcome.
  Future<void> refresh() async {
    final previous = state.value;
    final next = await AsyncValue.guard(_load);

    if (next.hasError && previous != null) {
      Logger.warning('ChatMembers($_chatId): refresh failed (${next.error})');
      state = AsyncValue.data(previous);
      return;
    }

    state = next;
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

    if (!ref.mounted) return;

    state = result.fold(
      (_) => AsyncValue.data(
        current.copyWith(isLoadingMore: false, nextUserId: current.nextUserId),
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

  /// Adds everyone in [userIds], one request each, and refreshes once.
  Future<AddMembersOutcome> addMembers(
    Iterable<int> userIds, {
    ChatRole role = ChatRole.member,
  }) async {
    final useCase = ref.read(addMemberUseCaseProvider);

    final added = <int>[];
    final failed = <int, Failure>{};

    for (final userId in userIds) {
      final result = await useCase.execute(_chatId, userId, role: role);
      result.match(
        (failure) => failed[userId] = failure,
        (_) => added.add(userId),
      );
    }

    if (added.isNotEmpty) await refresh();

    return AddMembersOutcome(added: added, failed: failed);
  }

  Future<void> changeRole(int userId, ChatRole role) async {
    final result = await ref
        .read(changeMemberRoleUseCaseProvider)
        .execute(_chatId, userId, role);
    result.match((failure) => throw failure, (_) {});
    await refresh();
  }

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

  /// Lets a banned member back in — the same endpoint with a past date
  /// (api-docs §5.3).
  Future<void> unbanMember(int userId) async {
    final result = await ref
        .read(banMemberUseCaseProvider)
        .lift(_chatId, userId);
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
    final myUserId = ref.watch(authProvider).value?.id;

    // Both at once: the chat detail is what carries the banned members and
    // the member limit, the paged list is everyone else.
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
