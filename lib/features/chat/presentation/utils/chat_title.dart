import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:chatix/features/chat/domain/entities/chat_entity.dart';
import 'package:chatix/features/contacts/presentation/providers/contacts_providers.dart';
import 'package:chatix/gen/l10n/app_localizations.dart';

/// What a chat is called: its own name, or for a direct chat the person on
/// the other side — under [peerLocalName] when the reader gave them one.
String chatTitleOf(
  ChatEntity chat,
  AppLocalizations l10n, {
  required int? myUserId,
  String? peerLocalName,
}) {
  final name = chat.name?.trim();
  if (name != null && name.isNotEmpty) return name;

  final local = peerLocalName?.trim();
  if (chat.type == ChatType.direct && local != null && local.isNotEmpty) {
    return local;
  }

  final peer = chat.peerName(myUserId);
  if (peer != null && peer.isNotEmpty) return peer;

  return chatTypeLabel(chat.type, l10n);
}

/// The local name the reader gave a direct chat's peer in their address
/// book (api-docs §4.7), or null — watched, so a rename shows at once.
String? watchPeerLocalName(WidgetRef ref, ChatEntity chat, int? myUserId) {
  final peerId = _directPeerOf(chat, myUserId);
  if (peerId == null) return null;
  return ref.watch(contactLocalNameProvider(peerId));
}

/// [watchPeerLocalName] for a callback: read once, outside any build.
String? readPeerLocalName(WidgetRef ref, ChatEntity chat, int? myUserId) {
  final peerId = _directPeerOf(chat, myUserId);
  if (peerId == null) return null;
  return ref.read(contactLocalNameProvider(peerId));
}

int? _directPeerOf(ChatEntity chat, int? myUserId) {
  if (chat.type != ChatType.direct) return null;
  return chat.peerProfile(myUserId)?.userId;
}

/// [chatTitleOf], with the address book's name for a direct chat's peer —
/// what the chat list and a chat's header show, as Telegram does.
String watchChatTitle(
  WidgetRef ref,
  ChatEntity chat,
  AppLocalizations l10n, {
  required int? myUserId,
}) {
  return chatTitleOf(
    chat,
    l10n,
    myUserId: myUserId,
    peerLocalName: watchPeerLocalName(ref, chat, myUserId),
  );
}

String chatTypeLabel(ChatType type, AppLocalizations l10n) {
  switch (type) {
    case ChatType.direct:
      return l10n.chatDirect;
    case ChatType.group:
      return l10n.chatGroup;
    case ChatType.supergroup:
      return l10n.chatSupergroup;
    case ChatType.channel:
      return l10n.chatChannel;
  }
}
