import 'package:chatix/features/chat/domain/entities/chat_entity.dart';
import 'package:chatix/gen/l10n/app_localizations.dart';

String chatTitleOf(
  ChatEntity chat,
  AppLocalizations l10n, {
  required int? myUserId,
}) {
  final name = chat.name?.trim();
  if (name != null && name.isNotEmpty) return name;

  final peer = chat.peerName(myUserId);
  if (peer != null && peer.isNotEmpty) return peer;

  return chatTypeLabel(chat.type, l10n);
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
