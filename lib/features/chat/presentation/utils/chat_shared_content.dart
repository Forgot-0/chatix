import 'package:equatable/equatable.dart';

import 'package:chatix/features/chat/domain/entities/attachment_entity.dart';
import 'package:chatix/features/chat/domain/entities/message_entity.dart';
import 'package:chatix/features/chat/presentation/utils/message_linkifier.dart';

/// The four drawers of a chat's shared content.
enum SharedContentTab { media, files, links, voice }

/// One attachment, together with the message that carried it.
///
/// The message comes along for the same reason it does in [ChatMediaItem]:
/// the row says who sent it and when, and opening it means opening the
/// message.
class SharedAttachment extends Equatable {
  const SharedAttachment({required this.message, required this.attachment});

  final MessageEntity message;
  final AttachmentEntity attachment;

  String get messageId => message.id;
  String get attachmentId => attachment.id;

  @override
  List<Object?> get props => [message.id, attachment.id];
}

/// One web address someone typed, and where it was typed.
///
/// Links are not a kind of attachment — nothing on the server indexes them.
/// They are found by reading message text with the same parser the bubbles
/// use, so what the list offers is exactly what is tappable in the feed.
class SharedLink extends Equatable {
  const SharedLink({
    required this.message,
    required this.label,
    required this.target,
  });

  final MessageEntity message;

  /// The address as it was written, which is what to show.
  final String label;

  /// The address with a scheme on it, which is what to open.
  final String target;

  String get messageId => message.id;

  @override
  List<Object?> get props => [message.id, target];
}

/// What a chat has shared, sorted into the four tabs.
///
/// ⚠️ Built from the messages this device happens to hold, because the API
/// has no shared-media index: there is no `GET /chats/{id}/media/` or
/// anything like it, and attachments are only ever reachable through the
/// message they hang off (api-docs §5.4/§5.5). So these lists are exactly as
/// deep as the cached window of history — which is what the tabs say on
/// screen rather than pretending to be the whole chat.
class ChatSharedContent extends Equatable {
  const ChatSharedContent({
    this.media = const [],
    this.files = const [],
    this.links = const [],
    this.voice = const [],
  });

  static const ChatSharedContent empty = ChatSharedContent();

  /// Photos, videos and video notes.
  final List<SharedAttachment> media;

  /// Documents — the `file` bucket of api-docs §5.5.
  final List<SharedAttachment> files;

  final List<SharedLink> links;

  /// Voice messages only. A video note is something to look at, so it sits
  /// with the media.
  final List<SharedAttachment> voice;

  bool get isEmpty =>
      media.isEmpty && files.isEmpty && links.isEmpty && voice.isEmpty;

  @override
  List<Object?> get props => [media, files, links, voice];

  int countOf(SharedContentTab tab) => switch (tab) {
    SharedContentTab.media => media.length,
    SharedContentTab.files => files.length,
    SharedContentTab.links => links.length,
    SharedContentTab.voice => voice.length,
  };

  /// Sorts [messages] into the four tabs, newest first.
  ///
  /// [messages] may arrive in any order; what comes back is ordered by `seq`
  /// descending, the way a shared-content panel is read. A message with
  /// several attachments contributes each of them separately, in the order
  /// they were sent.
  static ChatSharedContent of(List<MessageEntity> messages) {
    final ordered = [...messages]..sort((a, b) => b.seq.compareTo(a.seq));

    final media = <SharedAttachment>[];
    final files = <SharedAttachment>[];
    final voice = <SharedAttachment>[];
    final links = <SharedLink>[];

    for (final message in ordered) {
      for (final attachment in message.attachments) {
        // A slot still `pending` has no bytes behind it yet and one in
        // `error` never will, so neither belongs in a list of what the chat
        // has.
        if (attachment.attachmentStatus != AttachmentStatus.success) continue;

        final bucket = switch (attachment.attachmentType) {
          AttachmentType.image ||
          AttachmentType.video ||
          AttachmentType.videoNote => media,
          AttachmentType.voice => voice,
          AttachmentType.file => files,
        };
        bucket.add(
          SharedAttachment(message: message, attachment: attachment),
        );
      }

      links.addAll(_linksIn(message));
    }

    return ChatSharedContent(
      media: media,
      files: files,
      links: links,
      voice: voice,
    );
  }

  /// Every distinct web address in one message's text.
  ///
  /// Only `url` spans: an email or a phone number is worth tapping in a
  /// bubble but is not a link anyone goes back to a chat looking for. The
  /// same address written twice in one message is listed once.
  static Iterable<SharedLink> _linksIn(MessageEntity message) {
    final content = message.content;
    if (content == null || content.isEmpty) return const [];

    final seen = <String>{};
    final found = <SharedLink>[];

    for (final span in MessageLinkifier.parse(content)) {
      if (span is! LinkSpan) continue;
      if (span.kind != MessageLinkKind.url) continue;
      if (!seen.add(span.target)) continue;

      found.add(
        SharedLink(message: message, label: span.text, target: span.target),
      );
    }

    return found;
  }
}

/// Folds two views of the same history into one list, newest first.
///
/// The feed on screen and the cache on disk overlap, and the feed's copy is
/// the fresher of the two — it has the edits and the reactions the cache was
/// written before. So a message present in both is taken from [live], and
/// [cached] only adds what the feed has scrolled past or never loaded.
List<MessageEntity> mergeSharedContentSources(
  List<MessageEntity> live,
  List<MessageEntity> cached,
) {
  final byId = <String, MessageEntity>{};

  for (final message in cached) {
    byId[message.id] = message;
  }
  for (final message in live) {
    byId[message.id] = message;
  }

  return byId.values.toList()..sort((a, b) => b.seq.compareTo(a.seq));
}
