import 'package:equatable/equatable.dart';
import 'package:chatix/features/chat/domain/entities/chat_member_entity.dart';

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

/// `ChatDTO` **and** `ChatDetaiDTO` (api-docs §6.2 — the "Detai" spelling
/// without the "l" is the real name in the backend code).
///
/// Both DTOs are modelled by this one entity because they describe the same
/// chat and share 12 of their fields; the difference is which extras the
/// endpoint bothers to compute:
///
/// | field | `ChatDTO` (list/create/update) | `ChatDetaiDTO` (`GET /chats/{id}/`) |
/// |---|---|---|
/// | [unreadCount] | ✅ | ❌ `null` |
/// | [me] | ✅ | ❌ `null` |
/// | [lastRead] | ✅ | ❌ `null` |
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

  /// `ChatDetaiDTO` only — `null` in list/create/update responses.
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
    this.members,
  });

  /// The caller's membership, wherever this instance happens to carry it:
  /// [me] for a `ChatDTO`, or the matching entry of [members] for a
  /// `ChatDetaiDTO`. Returns `null` when the caller isn't a member (e.g.
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
    members,
  ];
}
