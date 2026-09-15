import 'package:equatable/equatable.dart';
import 'package:chatix/features/chat/domain/entities/chat_member_entity.dart';
import 'package:chatix/features/chat/domain/entities/chat_profile_entity.dart';
import 'package:chatix/features/chat/domain/entities/message_entity.dart';

enum ChatType {
  direct,
  group,
  supergroup,
  channel;

  String get wire => name;

  static ChatType fromWire(String? value) {
    return ChatType.values.firstWhere(
      (t) => t.name == value,
      orElse: () => ChatType.direct,
    );
  }

  int get maxMembers {
    switch (this) {
      case ChatType.direct:
        return 2;
      case ChatType.group:
        return 500;
      case ChatType.supergroup:
        return 1000000;
      case ChatType.channel:
        return 10000000;
    }
  }
}

enum ChatReactionsMode {
  all,

  some,

  none;

  String get wire => name;

  static ChatReactionsMode fromWire(String? value) {
    return ChatReactionsMode.values.firstWhere(
      (m) => m.name == value,
      orElse: () => ChatReactionsMode.all,
    );
  }
}

class ReadDetailEntity extends Equatable {
  final int lastReadMessageSeq;
  final DateTime? lastReadAt;

  const ReadDetailEntity({
    required this.lastReadMessageSeq,
    required this.lastReadAt,
  });

  @override
  List<Object?> get props => [lastReadMessageSeq, lastReadAt];
}

/// The chat as *this* user has it set up: pinned, archived, silenced, with
/// an unsent draft.
///
/// Its own value rather than six fields on the chat because not every
/// response carries it. `GET /chats/` does; `GET /chats/{id}/` answers with
/// `ChatDetailDTO`, which has no state block at all (api-docs §5.2). Null
/// therefore means "this response did not say", which is what lets a chat
/// loaded by id be merged into the list without quietly unpinning it.
class ChatStateEntity extends Equatable {
  const ChatStateEntity({
    this.isPinned = false,
    this.pinnedAt,
    this.isArchived = false,
    this.notificationsMutedUntil,
    this.isMutedByMe = false,
    this.draft,
  });

  final bool isPinned;

  /// When it was pinned. The server orders the pinned block by this,
  /// newest first.
  final DateTime? pinnedAt;

  final bool isArchived;

  /// When the silence runs out. "Forever" is a date far in the future, not a
  /// flag (api-docs §5.2).
  final DateTime? notificationsMutedUntil;

  /// The server's own reading of [notificationsMutedUntil] at the moment the
  /// response was built. Trusted over a local clock comparison, which would
  /// disagree with it on a device whose time is off.
  final bool isMutedByMe;

  /// What was typed here and never sent.
  final String? draft;

  ChatStateEntity copyWith({
    bool? isPinned,
    DateTime? pinnedAt,
    bool? isArchived,
    DateTime? notificationsMutedUntil,
    bool? isMutedByMe,
    String? draft,
    bool clearPinnedAt = false,
    bool clearMutedUntil = false,
    bool clearDraft = false,
  }) {
    return ChatStateEntity(
      isPinned: isPinned ?? this.isPinned,
      pinnedAt: clearPinnedAt ? null : (pinnedAt ?? this.pinnedAt),
      isArchived: isArchived ?? this.isArchived,
      notificationsMutedUntil: clearMutedUntil
          ? null
          : (notificationsMutedUntil ?? this.notificationsMutedUntil),
      isMutedByMe: isMutedByMe ?? this.isMutedByMe,
      draft: clearDraft ? null : (draft ?? this.draft),
    );
  }

  @override
  List<Object?> get props => [
    isPinned,
    pinnedAt,
    isArchived,
    notificationsMutedUntil,
    isMutedByMe,
    draft,
  ];
}

class ChatEntity extends Equatable {
  final String id;

  final int seqCounter;

  final DateTime? lastActivityAt;
  final ChatType type;
  final String? name;
  final String? description;
  final String? avatarS3Key;
  final bool isPublic;

  final bool adminOnly;

  final int slowModeSeconds;

  final Map<String, bool> permissions;

  final ChatReactionsMode reactionsMode;

  final List<String> allowedReactions;

  final int createdBy;
  final int memberCount;

  final int? unreadCount;

  final ChatMemberEntity? me;

  final ReadDetailEntity? lastRead;

  final MessageEntity? lastMessage;

  final List<ChatMemberEntity>? members;

  /// The other person in a direct chat, as the list response names them.
  ///
  /// A direct chat has no `name` and no avatar of its own, and an empty one
  /// has no `last_message` either, so without this there is nothing to draw
  /// a row with. Only `GET /chats/` fills it (api-docs §5.2).
  final ChatProfileEntity? peer;

  /// Up to three members other than me, for the stack of faces on a group
  /// row. Only `GET /chats/` fills it, and only for group and supergroup.
  final List<ChatProfileEntity> membersPreview;

  /// Pinned, archived, silenced, draft. Null when the response did not say.
  final ChatStateEntity? state;

  const ChatEntity({
    required this.id,
    required this.seqCounter,
    required this.lastActivityAt,
    required this.type,
    required this.name,
    required this.description,
    required this.avatarS3Key,
    required this.isPublic,
    required this.adminOnly,
    required this.slowModeSeconds,
    required this.permissions,
    this.reactionsMode = ChatReactionsMode.all,
    this.allowedReactions = const [],
    required this.createdBy,
    required this.memberCount,
    this.unreadCount,
    this.me,
    this.lastRead,
    this.lastMessage,
    this.members,
    this.peer,
    this.membersPreview = const [],
    this.state,
  });

  bool get isPinned => state?.isPinned ?? false;

  DateTime? get pinnedAt => state?.pinnedAt;

  bool get isArchived => state?.isArchived ?? false;

  /// Whether this device should stay quiet about the chat. The server has
  /// already compared the mute deadline with its own clock.
  bool get isMutedByMe => state?.isMutedByMe ?? false;

  DateTime? get notificationsMutedUntil => state?.notificationsMutedUntil;

  String? get draft => state?.draft;

  bool get reactionsEnabled => reactionsMode != ChatReactionsMode.none;

  bool isReactionAllowed(String emoji) {
    switch (reactionsMode) {
      case ChatReactionsMode.none:
        return false;
      case ChatReactionsMode.all:
        return true;
      case ChatReactionsMode.some:
        return allowedReactions.contains(emoji);
    }
  }

  List<String>? get reactionWhitelist =>
      reactionsMode == ChatReactionsMode.some ? allowedReactions : null;

  ChatProfileEntity? peerProfile(int? myUserId) {
    if (type != ChatType.direct) return null;

    // What the list response says, when it says anything: the server picked
    // the member who is not the caller, which is more than a roster the chat
    // may not carry can tell us.
    final named = peer;
    if (named != null) return named;

    final mine = myUserId ?? me?.userId;
    if (mine == null) return null;

    final roster = members;
    if (roster != null) {
      for (final member in roster) {
        if (member.userId != mine && member.profile != null) {
          return member.profile;
        }
      }
    }

    final author = lastMessage?.profile;
    if (author != null && author.userId != mine) return author;

    return null;
  }

  String? peerName(int? myUserId) => peerProfile(myUserId)?.bestName;

  ChatMemberEntity? membershipOf(int userId) {
    if (me != null && me!.userId == userId) return me;
    final list = members;
    if (list == null) return null;
    for (final member in list) {
      if (member.userId == userId) return member;
    }
    return null;
  }

  ChatEntity copyWith({
    String? id,
    int? seqCounter,
    DateTime? lastActivityAt,
    ChatType? type,
    String? name,
    String? description,
    String? avatarS3Key,
    bool? isPublic,
    bool? adminOnly,
    int? slowModeSeconds,
    Map<String, bool>? permissions,
    ChatReactionsMode? reactionsMode,
    List<String>? allowedReactions,
    int? createdBy,
    int? memberCount,
    int? unreadCount,
    ChatMemberEntity? me,
    ReadDetailEntity? lastRead,
    MessageEntity? lastMessage,
    List<ChatMemberEntity>? members,
    ChatProfileEntity? peer,
    List<ChatProfileEntity>? membersPreview,
    ChatStateEntity? state,
    bool clearUnreadCount = false,
    bool clearMe = false,
    bool clearLastRead = false,
    bool clearLastMessage = false,
    bool clearMembers = false,
    bool clearPeer = false,
    bool clearState = false,
  }) {
    return ChatEntity(
      id: id ?? this.id,
      seqCounter: seqCounter ?? this.seqCounter,
      lastActivityAt: lastActivityAt ?? this.lastActivityAt,
      type: type ?? this.type,
      name: name ?? this.name,
      description: description ?? this.description,
      avatarS3Key: avatarS3Key ?? this.avatarS3Key,
      isPublic: isPublic ?? this.isPublic,
      adminOnly: adminOnly ?? this.adminOnly,
      slowModeSeconds: slowModeSeconds ?? this.slowModeSeconds,
      permissions: permissions ?? this.permissions,
      reactionsMode: reactionsMode ?? this.reactionsMode,
      allowedReactions: allowedReactions ?? this.allowedReactions,
      createdBy: createdBy ?? this.createdBy,
      memberCount: memberCount ?? this.memberCount,
      unreadCount: clearUnreadCount ? null : (unreadCount ?? this.unreadCount),
      me: clearMe ? null : (me ?? this.me),
      lastRead: clearLastRead ? null : (lastRead ?? this.lastRead),
      lastMessage: clearLastMessage ? null : (lastMessage ?? this.lastMessage),
      members: clearMembers ? null : (members ?? this.members),
      peer: clearPeer ? null : (peer ?? this.peer),
      membersPreview: membersPreview ?? this.membersPreview,
      state: clearState ? null : (state ?? this.state),
    );
  }

  @override
  List<Object?> get props => [
    id,
    seqCounter,
    lastActivityAt,
    type,
    name,
    description,
    avatarS3Key,
    isPublic,
    adminOnly,
    slowModeSeconds,
    permissions,
    reactionsMode,
    allowedReactions,
    createdBy,
    memberCount,
    unreadCount,
    me,
    lastRead,
    lastMessage,
    members,
    peer,
    membersPreview,
    state,
  ];
}
