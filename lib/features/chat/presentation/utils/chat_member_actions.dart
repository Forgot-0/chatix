import 'package:chatix/features/chat/domain/entities/chat_entity.dart';
import 'package:chatix/features/chat/domain/entities/chat_member_entity.dart';
import 'package:chatix/features/chat/presentation/utils/chat_permissions.dart';

/// What a moderator can do to one member from the member list.
///
/// `member:mute` is missing on purpose: the permission exists in the matrix
/// (api-docs §8.1) and `MemberChatDTO.is_muted` is reported, but the members
/// router has no mute endpoint — only role, ban and kick (api-docs §5.3). A
/// button that cannot send anything is worse than no button, so the mute
/// state is shown and not offered. See docs/BACKEND_GAPS.md.
enum ChatMemberAction { openProfile, message, changeRole, kick, ban, unban }

/// The roles this member may hand out.
///
/// Strictly below their own, and never `direct`: role 4 is assigned
/// automatically to both sides of a 1:1 chat and the server has no use for it
/// anywhere else (api-docs §5.3, §8.1). `owner` never appears either — the
/// owner cannot grant it, because ownership is not transferred by changing a
/// role, and there is no endpoint that does it.
List<ChatRole> assignableRolesFor(ChatMemberEntity? me) => [
  for (final role in assignableChatRoles(me))
    if (role != ChatRole.direct) role,
];

/// Whether [me] can move [target] to some role other than the one they hold.
bool canChangeRoleOf(
  ChatEntity? chat,
  ChatMemberEntity? me,
  ChatMemberEntity target,
) {
  if (!canModerate(me, target)) return false;
  if (!hasChatPermission(chat, me, ChatPermissions.roleChange)) return false;
  if (target.isBanned) return false;

  return assignableRolesFor(me).any((role) => role != target.role);
}

/// Everything worth offering for [target], in the order it should be listed.
///
/// Decided up front from the permission matrix rather than by sending the
/// request and reading the `403` back (api-docs §5.3, §8.1).
List<ChatMemberAction> memberActionsFor({
  required ChatEntity? chat,
  required ChatMemberEntity? me,
  required ChatMemberEntity target,
  required int? myUserId,
}) {
  final isSelf = target.userId == (myUserId ?? me?.userId);

  final moderatable = canModerate(me, target);
  final canBan =
      moderatable && hasChatPermission(chat, me, ChatPermissions.memberBan);
  final canKick =
      moderatable && hasChatPermission(chat, me, ChatPermissions.memberKick);

  return [
    ChatMemberAction.openProfile,
    if (!isSelf) ChatMemberAction.message,
    if (canChangeRoleOf(chat, me, target)) ChatMemberAction.changeRole,
    if (canKick) ChatMemberAction.kick,
    if (canBan && !target.isBanned) ChatMemberAction.ban,
    if (canBan && target.isBanned) ChatMemberAction.unban,
  ];
}

/// The spans offered when banning someone, plus the two open-ended ends of
/// the range (api-docs §5.3: `banned_to` null bans forever, a future date
/// bans until then, a past date lifts the ban).
enum BanDuration { hour, day, week, forever, untilDate }

/// The `banned_to` value for [duration], or null for a permanent ban.
///
/// [date] is only read for [BanDuration.untilDate]; without one the caller
/// has nothing to send yet, which is what the null return says.
DateTime? banExpiryFor(
  BanDuration duration, {
  required DateTime now,
  DateTime? date,
}) => switch (duration) {
  BanDuration.hour => now.add(const Duration(hours: 1)),
  BanDuration.day => now.add(const Duration(days: 1)),
  BanDuration.week => now.add(const Duration(days: 7)),
  BanDuration.forever => null,
  BanDuration.untilDate => date,
};

/// Whether a ban with these settings is ready to send.
///
/// Only [BanDuration.untilDate] can be unfinished, and only until a date in
/// the future has been picked.
bool isBanRequestComplete(
  BanDuration duration, {
  required DateTime now,
  DateTime? date,
}) {
  if (duration != BanDuration.untilDate) return true;
  return date != null && date.isAfter(now);
}
