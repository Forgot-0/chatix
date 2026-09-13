import 'package:equatable/equatable.dart';

abstract final class ReactionLimits {
  static const int maxPerUserPerMessage = 3;

  static const int maxDistinctPerMessage = 20;

  static const int maxEmojiLength = 32;

  static const int recentUsersLimit = 3;
}

enum ReactionAction {
  add,
  remove,
  replace,
  update;

  static ReactionAction fromWire(String? value) {
    return ReactionAction.values.firstWhere(
      (a) => a.name == value,
      orElse: () => ReactionAction.update,
    );
  }
}

/// Why one more emoji cannot go on a message right now.
///
/// Both caps come from §5.7.4 and both are enforced server-side with
/// `TOO_MANY_REACTIONS`. Working them out before the tap is what keeps the
/// picker honest: an emoji that would be refused is drawn as refused rather
/// than accepted, sent, and taken back a moment later.
enum ReactionBlock {
  /// `MAX_REACTIONS_PER_USER_PER_MESSAGE` — this reader already holds three.
  perUser,

  /// `MAX_DISTINCT_REACTIONS_PER_MESSAGE` — the message already carries
  /// twenty different emoji, so only the ones already there can be joined.
  perMessage,
}

class ReactionGroupEntity extends Equatable {
  final String emoji;

  final int count;

  final int version;

  final bool reactedByMe;

  final List<int> recentUserIds;

  const ReactionGroupEntity({
    required this.emoji,
    required this.count,
    this.version = 0,
    this.reactedByMe = false,
    this.recentUserIds = const [],
  });

  ReactionGroupEntity copyWith({
    int? count,
    int? version,
    bool? reactedByMe,
    List<int>? recentUserIds,
  }) {
    return ReactionGroupEntity(
      emoji: emoji,
      count: count ?? this.count,
      version: version ?? this.version,
      reactedByMe: reactedByMe ?? this.reactedByMe,
      recentUserIds: recentUserIds ?? this.recentUserIds,
    );
  }

  @override
  List<Object?> get props => [
    emoji,
    count,
    version,
    reactedByMe,
    recentUserIds,
  ];
}

class MessageReactionsEntity extends Equatable {
  final String messageId;

  final List<ReactionGroupEntity> groups;

  final String? emoji;

  final List<int> users;

  final bool hasNext;

  final int? nextUserId;

  const MessageReactionsEntity({
    required this.messageId,
    this.groups = const [],
    this.emoji,
    this.users = const [],
    this.hasNext = false,
    this.nextUserId,
  });

  factory MessageReactionsEntity.empty(String messageId) =>
      MessageReactionsEntity(messageId: messageId);

  factory MessageReactionsEntity.fromGroups(
    String messageId,
    List<ReactionGroupEntity> groups,
  ) => MessageReactionsEntity(messageId: messageId, groups: groups);

  bool get isEmpty => groups.isEmpty;

  List<String> get myEmojis => [
    for (final group in groups)
      if (group.reactedByMe) group.emoji,
  ];

  bool isMine(String emoji) => myEmojis.contains(emoji);

  bool get canAddMore =>
      myEmojis.length < ReactionLimits.maxPerUserPerMessage &&
      groups.length < ReactionLimits.maxDistinctPerMessage;

  /// What stands between this reader and this emoji, or null if nothing does.
  ///
  /// Taking one of ours back is never blocked, whichever cap has been hit —
  /// that is the only way out of a full set.
  ReactionBlock? blockFor(String emoji) {
    if (isMine(emoji)) return null;

    if (myEmojis.length >= ReactionLimits.maxPerUserPerMessage) {
      return ReactionBlock.perUser;
    }

    // Joining an emoji the message already carries adds no new group, so the
    // distinct cap does not apply to it.
    final joinsExisting = groups.any((g) => g.emoji == emoji);
    if (!joinsExisting &&
        groups.length >= ReactionLimits.maxDistinctPerMessage) {
      return ReactionBlock.perMessage;
    }

    return null;
  }

  /// Whether tapping [emoji] would do something the server accepts.
  bool canReactWith(String emoji) => blockFor(emoji) == null;

  /// What stands in the way of one more emoji — any emoji not already here.
  ///
  /// This is what a picker needs to explain itself: [blockFor] answers for
  /// one emoji at a time, and the footer has to name the cap once.
  ReactionBlock? get nextBlock {
    if (myEmojis.length >= ReactionLimits.maxPerUserPerMessage) {
      return ReactionBlock.perUser;
    }
    if (groups.length >= ReactionLimits.maxDistinctPerMessage) {
      return ReactionBlock.perMessage;
    }
    return null;
  }

  MessageReactionsEntity copyWith({
    List<ReactionGroupEntity>? groups,
    String? emoji,
    List<int>? users,
    bool? hasNext,
    int? nextUserId,
    bool clearNextUserId = false,
  }) {
    return MessageReactionsEntity(
      messageId: messageId,
      groups: groups ?? this.groups,
      emoji: emoji ?? this.emoji,
      users: users ?? this.users,
      hasNext: hasNext ?? this.hasNext,
      nextUserId: clearNextUserId ? null : (nextUserId ?? this.nextUserId),
    );
  }

  MessageReactionsEntity applySnapshot(
    List<ReactionGroupEntity> snapshot, {
    int? actorId,
    int? myUserId,
  }) {
    final mine = {for (final group in groups) group.emoji: group.reactedByMe};
    final versions = {for (final group in groups) group.emoji: group.version};

    final selfId = (actorId != null && actorId == myUserId) ? myUserId : null;

    final next = <ReactionGroupEntity>[];
    for (final group in snapshot) {
      final known = versions[group.emoji];
      if (known != null && group.version < known) {
        final current = groups.firstWhere((g) => g.emoji == group.emoji);
        next.add(current);
        continue;
      }

      final local = mine[group.emoji] ?? false;
      final reactedByMe = selfId != null && group.recentUserIds.contains(selfId)
          ? true
          : local;

      next.add(group.copyWith(reactedByMe: reactedByMe));
    }

    return copyWith(groups: next);
  }

  MessageReactionsEntity addMine(String emoji, {int? myUserId}) {
    if (isMine(emoji)) return this;
    if (!canAddMore && !groups.any((g) => g.emoji == emoji)) return this;
    if (myEmojis.length >= ReactionLimits.maxPerUserPerMessage) return this;

    final next = [...groups];
    final index = next.indexWhere((g) => g.emoji == emoji);

    if (index >= 0) {
      final group = next[index];
      next[index] = group.copyWith(
        count: group.count + 1,
        reactedByMe: true,
        recentUserIds: myUserId == null
            ? group.recentUserIds
            : [
                myUserId,
                ...group.recentUserIds.where((id) => id != myUserId),
              ].take(ReactionLimits.recentUsersLimit).toList(),
      );
    } else {
      next.add(
        ReactionGroupEntity(
          emoji: emoji,
          count: 1,
          reactedByMe: true,
          recentUserIds: myUserId == null ? const [] : [myUserId],
        ),
      );
    }

    return copyWith(groups: next);
  }

  MessageReactionsEntity removeMine(String emoji, {int? myUserId}) {
    if (!isMine(emoji)) return this;

    final next = <ReactionGroupEntity>[];
    for (final group in groups) {
      if (group.emoji != emoji) {
        next.add(group);
        continue;
      }
      final count = group.count - 1;
      if (count <= 0) continue;
      next.add(
        group.copyWith(
          count: count,
          reactedByMe: false,
          recentUserIds: myUserId == null
              ? group.recentUserIds
              : group.recentUserIds.where((id) => id != myUserId).toList(),
        ),
      );
    }

    return copyWith(groups: next);
  }

  MessageReactionsEntity toggleMine(String emoji, {int? myUserId}) =>
      isMine(emoji)
      ? removeMine(emoji, myUserId: myUserId)
      : addMine(emoji, myUserId: myUserId);

  MessageReactionsEntity replaceMine(List<String> emojis, {int? myUserId}) {
    final wanted = emojis.take(ReactionLimits.maxPerUserPerMessage).toList();

    var next = this;
    for (final emoji in myEmojis) {
      if (!wanted.contains(emoji)) {
        next = next.removeMine(emoji, myUserId: myUserId);
      }
    }
    for (final emoji in wanted) {
      next = next.addMine(emoji, myUserId: myUserId);
    }

    return next;
  }

  @override
  List<Object?> get props => [
    messageId,
    groups,
    emoji,
    users,
    hasNext,
    nextUserId,
  ];
}
