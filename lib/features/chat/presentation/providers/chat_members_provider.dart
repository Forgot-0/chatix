import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chatix/features/auth/presentation/providers/auth_provider.dart';
import 'package:chatix/features/chat/domain/entities/chat_entity.dart';
import 'package:chatix/features/chat/domain/entities/chat_member_entity.dart';
import 'package:chatix/features/chat/domain/entities/chat_pages.dart';
import 'package:chatix/features/chat/presentation/providers/chat_providers.dart';

const _pageSize = 50;

class ChatMembersState extends Equatable {
  final ChatEntity? chat;
  final List<ChatMemberEntity> members;
  final bool hasNext;
  final int? nextUserId;
  final bool isLoadingMore;

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

class ChatMembersController
    extends AsyncNotifier<ChatMembersState> {
  ChatMembersController(this._chatId);

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
