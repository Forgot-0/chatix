import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:chatix/features/auth/presentation/providers/auth_provider.dart';
import 'package:chatix/features/chat/domain/entities/chat_profile_entity.dart';
import 'package:chatix/features/chat/presentation/providers/chat_list_provider.dart';

/// Somebody a member rule can point at.
class KnownPerson extends Equatable {
  const KnownPerson({required this.userId, required this.name});

  final int userId;
  final String name;

  @override
  List<Object?> get props => [userId, name];
}

/// The people the chat list can name without asking the server.
///
/// `GET /chats/` carries no roster — members come from
/// `GET /chats/{id}/members/`, one call per chat (api-docs §5.5) — so this
/// is built from what the rows already hold: whoever wrote the last message
/// and any roster a screen has since loaded. It is the same ground a member
/// rule matches on, which keeps the picker honest about what it can find.
final knownPeopleProvider = Provider<List<KnownPerson>>((ref) {
  final chats = ref.watch(chatListProvider).value?.items ?? const [];
  final myUserId = ref.watch(authProvider.select((user) => user.value?.id));

  final byId = <int, String>{};

  void remember(ChatProfileEntity? profile) {
    if (profile == null) return;
    if (profile.userId == myUserId) return;
    byId.putIfAbsent(profile.userId, () => profile.bestName);
  }

  for (final chat in chats) {
    remember(chat.lastMessage?.profile);
    for (final member in chat.members ?? const []) {
      remember(member.profile);
    }
  }

  final people = byId.entries
      .map((entry) => KnownPerson(userId: entry.key, name: entry.value))
      .toList();

  people.sort(
    (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
  );

  return people;
});
