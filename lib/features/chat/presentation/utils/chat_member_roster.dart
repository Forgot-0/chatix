import 'package:chatix/features/chat/domain/entities/chat_entity.dart';
import 'package:chatix/features/chat/domain/entities/chat_member_entity.dart';

/// The three blocks a member list is read in.
enum MemberSection { administration, members, banned }

/// The roles that run the chat, in the order they outrank each other
/// (api-docs §8.1). Editor is in here because it is the lowest role that can
/// delete other people's messages and publish in a channel — from a reader's
/// point of view it is staff, even though it cannot kick anyone.
const Set<ChatRole> administrationRoles = {
  ChatRole.owner,
  ChatRole.admin,
  ChatRole.editor,
};

bool isAdministration(ChatMemberEntity member) =>
    administrationRoles.contains(member.role);

/// One block of the list: a heading and the people under it.
class MemberSectionEntry {
  const MemberSectionEntry({required this.section, required this.members});

  final MemberSection section;
  final List<ChatMemberEntity> members;

  bool get isEmpty => members.isEmpty;
}

/// Whether [query] picks this member out: their display name, their
/// `@username`, or their bare user id.
///
/// Matching is substring and case-insensitive, like the server's own people
/// search (api-docs §4.2), so typing "van" finds both `ivan_dev` and
/// "Ivan Petrov". A leading `@` is ignored, since that is how a handle is
/// written rather than part of it.
bool memberMatchesQuery(ChatMemberEntity member, String query) {
  final needle = query.trim().toLowerCase().replaceFirst(RegExp(r'^@+'), '');
  if (needle.isEmpty) return true;

  final profile = member.profile;

  final name = profile?.displayName?.trim().toLowerCase();
  if (name != null && name.contains(needle)) return true;

  final username = profile?.username?.trim().toLowerCase();
  if (username != null && username.contains(needle)) return true;

  return '${member.userId}' == needle;
}

/// Highest role first, then by name, then by id so the order never wobbles
/// between rebuilds.
int compareMembers(ChatMemberEntity a, ChatMemberEntity b) {
  final byRole = a.roleId.compareTo(b.roleId);
  if (byRole != 0) return byRole;

  final byName = a.displayLabel.toLowerCase().compareTo(
    b.displayLabel.toLowerCase(),
  );
  if (byName != 0) return byName;

  return a.userId.compareTo(b.userId);
}

/// The banned members, read off the chat detail rather than the member list.
///
/// `GET /chats/{id}/members/` drops banned members entirely — permanently and
/// temporarily banned alike — while `ChatDetailDTO.members` keeps them with
/// `is_banned: true` (api-docs §5.3). Building this list from the paged
/// endpoint would leave it empty forever.
List<ChatMemberEntity> bannedMembersOf(ChatEntity? chat) {
  final roster = chat?.members;
  if (roster == null) return const [];
  return [
    for (final member in roster)
      if (member.isBanned) member,
  ]..sort(compareMembers);
}

/// Splits the roster into the blocks the screen draws, filtered by [query].
///
/// [members] is the paged list (no banned members in it) and [banned] comes
/// from the chat detail. Anyone present in both — a roster that went stale
/// between the two responses — is counted as banned only.
List<MemberSectionEntry> buildMemberSections({
  required List<ChatMemberEntity> members,
  List<ChatMemberEntity> banned = const [],
  String query = '',
}) {
  final bannedIds = {for (final member in banned) member.userId};

  final seen = <int>{};
  final administration = <ChatMemberEntity>[];
  final ordinary = <ChatMemberEntity>[];

  for (final member in members) {
    if (bannedIds.contains(member.userId)) continue;
    if (!seen.add(member.userId)) continue;
    if (!memberMatchesQuery(member, query)) continue;

    (isAdministration(member) ? administration : ordinary).add(member);
  }

  final bannedMatches = <ChatMemberEntity>[];
  final bannedSeen = <int>{};
  for (final member in banned) {
    if (!bannedSeen.add(member.userId)) continue;
    if (!memberMatchesQuery(member, query)) continue;
    bannedMatches.add(member);
  }

  administration.sort(compareMembers);
  ordinary.sort(compareMembers);
  bannedMatches.sort(compareMembers);

  return [
    if (administration.isNotEmpty)
      MemberSectionEntry(
        section: MemberSection.administration,
        members: administration,
      ),
    if (ordinary.isNotEmpty)
      MemberSectionEntry(section: MemberSection.members, members: ordinary),
    if (bannedMatches.isNotEmpty)
      MemberSectionEntry(section: MemberSection.banned, members: bannedMatches),
  ];
}

/// How many people this kind of chat may hold (api-docs §5.1).
int chatMemberCapacity(ChatType type) => type.maxMembers;

/// How many more people fit before the server answers
/// `400 MEMBER_LIMIT_EXCEEDED`.
///
/// [knownMembers] is what the client has actually seen; it wins over
/// `member_count` when it is larger, so a stale count cannot talk the invite
/// screen into offering room that is not there.
int remainingMemberSlots(ChatEntity? chat, {int knownMembers = 0}) {
  if (chat == null) return 0;

  final used = chat.memberCount > knownMembers
      ? chat.memberCount
      : knownMembers;
  final left = chatMemberCapacity(chat.type) - used;
  return left < 0 ? 0 : left;
}

/// Whether anyone else can be added at all.
bool chatHasRoomForMembers(ChatEntity? chat, {int knownMembers = 0}) =>
    remainingMemberSlots(chat, knownMembers: knownMembers) > 0;
