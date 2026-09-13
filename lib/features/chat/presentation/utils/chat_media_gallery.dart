import 'package:equatable/equatable.dart';

import 'package:chatix/features/chat/domain/entities/attachment_entity.dart';
import 'package:chatix/features/chat/domain/entities/message_entity.dart';

/// One photo or video, together with the message it arrived in.
///
/// The message comes along because the viewer's header is about the message
/// — who sent it and when — and because forwarding forwards the message, not
/// the file.
class ChatMediaItem extends Equatable {
  const ChatMediaItem({required this.message, required this.attachment});

  final MessageEntity message;
  final AttachmentEntity attachment;

  String get messageId => message.id;
  String get attachmentId => attachment.id;

  bool get isVideo => attachment.attachmentType == AttachmentType.video;

  @override
  List<Object?> get props => [message.id, attachment.id];
}

/// The chat's media as one strip, so the viewer can be swiped sideways.
///
/// Built from the messages already loaded rather than from a gallery
/// endpoint, because the API has none: media is only ever reachable through
/// the message it hangs off (api-docs §5.4/§5.5). So the strip is exactly as
/// long as the window of history in hand — which grows as the feed pages
/// backwards, and is the same set the reader could scroll to.
abstract final class ChatMediaGallery {
  /// Oldest first, the order a reader swiping right-to-left expects.
  ///
  /// [messages] arrives newest-first, the way the feed keeps it.
  static List<ChatMediaItem> of(List<MessageEntity> messages) {
    final items = <ChatMediaItem>[];

    for (final message in messages.reversed) {
      for (final attachment in message.attachments) {
        if (!_isViewable(attachment)) continue;
        items.add(ChatMediaItem(message: message, attachment: attachment));
      }
    }

    return items;
  }

  /// Where [attachmentId] sits in [items], or -1 when it is not there — a
  /// message that has since been deleted, or media outside the loaded
  /// window.
  static int indexOf(List<ChatMediaItem> items, String attachmentId) {
    for (var i = 0; i < items.length; i++) {
      if (items[i].attachmentId == attachmentId) return i;
    }
    return -1;
  }

  /// Photos and videos the gateway has finished with. A slot still
  /// `pending` has no bytes to show yet and one in `error` never will.
  static bool _isViewable(AttachmentEntity attachment) {
    if (attachment.attachmentStatus != AttachmentStatus.success) return false;

    return attachment.attachmentType == AttachmentType.image ||
        attachment.attachmentType == AttachmentType.video;
  }
}
