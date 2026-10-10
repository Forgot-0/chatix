import 'package:equatable/equatable.dart';

import 'package:chatix/features/chat/domain/entities/chat_entity.dart';
import 'package:chatix/gen/l10n/app_localizations.dart';

/// The line under a chat's name in its app bar.
///
/// Only what the API can back up. Presence is a yes/no read off the member
/// list (api-docs §5.3) and there is no `last_seen_at` anywhere, so a person
/// who is not online gets no line at all rather than "last seen recently",
/// which would be a guess dressed up as a fact.
sealed class ChatHeaderStatus extends Equatable {
  const ChatHeaderStatus();

  /// What to say for [chat], or null when there is nothing true to say.
  ///
  /// [peerOnline] is the direct peer's presence and [membersOnline] a
  /// group's online count; either is null while unknown.
  static ChatHeaderStatus? of(
    ChatEntity chat, {
    bool? peerOnline,
    int? membersOnline,
  }) {
    switch (chat.type) {
      case ChatType.direct:
        return peerOnline == true ? const PeerOnlineStatus() : null;
      case ChatType.group:
      case ChatType.supergroup:
        return MembersStatus(
          members: chat.memberCount,
          // "0 online" next to the member count reads as a complaint, and
          // says less than leaving it out.
          online: membersOnline != null && membersOnline > 0
              ? membersOnline
              : null,
        );
      case ChatType.channel:
        return SubscribersStatus(subscribers: chat.memberCount);
    }
  }

  String label(AppLocalizations l10n);

  /// Whether the line is news about someone being here, drawn in the accent
  /// rather than in the quiet secondary colour.
  bool get isAccent => false;
}

/// The other person in a direct chat is online.
final class PeerOnlineStatus extends ChatHeaderStatus {
  const PeerOnlineStatus();

  @override
  String label(AppLocalizations l10n) => l10n.chatStatusOnline;

  @override
  bool get isAccent => true;

  @override
  List<Object?> get props => const [];
}

/// A group: how many are in it, and how many of them are here.
final class MembersStatus extends ChatHeaderStatus {
  const MembersStatus({required this.members, this.online});

  final int members;

  /// Null when unknown, or when nobody is.
  final int? online;

  @override
  String label(AppLocalizations l10n) {
    final count = l10n.membersCount(members);
    final here = online;
    if (here == null) return count;
    return l10n.chatStatusMembersOnline(
      count,
      l10n.chatStatusOnlineCount(here),
    );
  }

  @override
  List<Object?> get props => [members, online];
}

/// A channel: its audience, under the word a channel uses for it.
final class SubscribersStatus extends ChatHeaderStatus {
  const SubscribersStatus({required this.subscribers});

  final int subscribers;

  @override
  String label(AppLocalizations l10n) => l10n.subscribersCount(subscribers);

  @override
  List<Object?> get props => [subscribers];
}
