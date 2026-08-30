import 'package:equatable/equatable.dart';
import 'package:chatix/features/chat/domain/entities/chat_member_entity.dart';
import 'package:chatix/features/chat/domain/entities/message_entity.dart';

/// `ChatType` (api-docs §6.1). ⚠️ **Four** values — `supergroup` is a
/// separate type from `group` (different member cap, different default role
/// for invitees), so never collapse the two.
enum ChatType {
  direct,
  group,
  supergroup,
  channel;

  String get wire => name;

  static ChatType fromWire(String? value) {
    return ChatType.values.firstWhere(
      (t) => t.name == value,
      // The backend defaults `chat_type` to "direct" when it is omitted
      // (api-docs §6.2 `CreateChatRequest`), so an unknown/missing wire
      // value degrades to the same thing rather than throwing.
      orElse: () => ChatType.direct,
    );
  }

  /// Hard member cap enforced by the backend per chat type (api-docs §6.1).
  /// Anything outside these four types falls back to `MAX_MEMBERS = 1000`,
  /// which is why the constant lives here and not as a single global.
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

/// `ReadDetail` — the current user's read cursor in a chat, embedded in
/// `ChatDTO.last_read` (api-docs §6.2).
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

/// `ChatDTO` **and** `ChatDetailDTO` (api-docs §6.2).
///
/// ℹ️ This type used to be called `ChatDetaiDTO` (missing "l") in the backend
/// and in these docs; the typo has since been fixed server-side, so the
/// correct spelling is used throughout this file. Only the name changed —
/// the two responses still differ exactly as they always did.
///
/// Both DTOs are modelled by this one entity because they describe the same
/// chat and share most of their fields; the difference is which extras the
/// endpoint bothers to compute:
///
/// | field | `ChatDTO` (list/create/update) | `ChatDetailDTO` (`GET /chats/{id}/`) |
/// |---|---|---|
/// | [unreadCount] | ✅ | ❌ `null` |
/// | [me] | ✅ | ❌ `null` |
/// | [lastRead] | ✅ | ❌ `null` |
/// | [lastMessage] | ✅ | ❌ `null` |
/// | [members] | ❌ `null` | ✅ full list |
///
/// So `null` here means "this endpoint didn't send it", **not** "zero" or
/// "empty". Guard on it instead of defaulting: showing an unread badge of 0
/// after opening the detail endpoint would be a lie, and treating [members]
/// as `[]` in the list screen would render every group chat as empty. The
/// permission helpers take the two sources separately for the same reason —
/// see `hasChatPermission` in `presentation/utils/chat_permissions.dart`.
class ChatEntity extends Equatable {
  final String id;

  /// Monotonic per-chat message counter. The `seq` of the newest message
  /// equals this value; used as the upper bound for read cursors.
  final int seqCounter;

  final DateTime? lastActivityAt;
  final ChatType type;
  final String? name;
  final String? description;
  final String? avatarS3Key;
  final bool isPublic;

  /// When `true` only `message:send_admin_only` holders may post
  /// (api-docs §6.2, §9.1).
  final bool adminOnly;

  final int slowModeSeconds;

  /// Chat-level permission **override** map (api-docs §9.1) — it is *not*
  /// the effective permission set. Effective right = role default → this map
  /// → [ChatMemberEntity.permissionsOverrides].
  final Map<String, bool> permissions;

  final int createdBy;
  final int memberCount;

  /// `ChatDTO` only — `null` from `GET /chats/{id}/`.
  final int? unreadCount;

  /// `ChatDTO` only — the caller's own membership (role, mute, ban).
  /// `null` from `GET /chats/{id}/`; look the caller up in [members] there.
  final ChatMemberEntity? me;

  /// `ChatDTO` only — `null` from `GET /chats/{id}/`.
  final ReadDetailEntity? lastRead;

  /// `ChatDTO` only — the newest message of the chat, denormalized by the
  /// backend as a **preview for the chat list** (api-docs §6.2
  /// `ChatDTO.last_message`).
  ///
  /// Same nullability rule as the other `ChatDTO`-only fields: `null` means
  /// either "this endpoint didn't send it" (`GET /chats/{id}/` never does) or
  /// "this chat has no messages yet". Both render as "no preview", so the two
  /// cases don't need to be told apart here — but neither may be rendered as
  /// an empty message row.
  final MessageEntity? lastMessage;

  /// `ChatDetailDTO` only — `null` in list/create/update responses.
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
    required this.createdBy,
    required this.memberCount,
    this.unreadCount,
    this.me,
    this.lastRead,
    this.lastMessage,
    this.members,
  });

  /// The caller's membership, wherever this instance happens to carry it:
  /// [me] for a `ChatDTO`, or the matching entry of [members] for a
  /// `ChatDetailDTO`. Returns `null` when the caller isn't a member (e.g.
  /// previewing a public chat before `join`), which every permission check
  /// must treat as "deny".
  ChatMemberEntity? membershipOf(int userId) {
    if (me != null && me!.userId == userId) return me;
    final list = members;
    if (list == null) return null;
    for (final member in list) {
      if (member.userId == userId) return member;
    }
    return null;
  }

  /// Returns a copy with the given fields replaced.
  ///
  /// Added for the realtime layer (api-docs §7) — used by
  /// `ChatRealtimeMerge.applyNewMessageToRow` to bump [seqCounter]/
  /// [lastActivityAt]/[unreadCount] in place. `applyChatUpdated` deliberately
  /// does *not* use this: see that function's doc for why a `chat_updated`
  /// still goes through a direct constructor call instead.
  ///
  /// ⚠️ [unreadCount], [me], [lastRead], [lastMessage] and [members] use
  /// explicit `clearX` flags rather than plain `null` sentinels. For every
  /// other entity in this codebase `null` means "leave unchanged", but for
  /// these five `null` is a
  /// *meaningful value* — see the class doc: it distinguishes "this endpoint
  /// didn't send it" from zero/empty. A `?? this.x` fallback alone could never
  /// express "set this back to unknown", and silently promoting a `ChatDTO`'s
  /// `me` onto a `ChatDetailDTO` copy would make `membershipOf` answer from
  /// stale data.
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
      createdBy: createdBy ?? this.createdBy,
      memberCount: memberCount ?? this.memberCount,
      unreadCount: clearUnreadCount ? null : (unreadCount ?? this.unreadCount),
      me: clearMe ? null : (me ?? this.me),
      lastRead: clearLastRead ? null : (lastRead ?? this.lastRead),
      lastMessage: clearLastMessage
          ? null
          : (lastMessage ?? this.lastMessage),
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
    createdBy,
    memberCount,
    unreadCount,
    me,
    lastRead,
    lastMessage,
    members,
  ];
}
