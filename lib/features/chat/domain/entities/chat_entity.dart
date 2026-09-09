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
  });

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
    bool clearUnreadCount = false,
    bool clearMe = false,
    bool clearLastRead = false,
    bool clearLastMessage = false,
    bool clearMembers = false,
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
  ];
}
