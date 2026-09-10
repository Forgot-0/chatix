import 'package:flutter/material.dart';

import 'package:chatix/features/chat/domain/entities/attachment_entity.dart';
import 'package:chatix/features/chat/domain/entities/chat_entity.dart';
import 'package:chatix/features/chat/domain/entities/message_entity.dart';
import 'package:chatix/gen/l10n/app_localizations.dart';

/// The second line of a chat row, in the pieces the row draws differently.
@immutable
class ChatPreview {
  const ChatPreview({
    required this.body,
    this.author,
    this.icon,
    this.isDraft = false,
    this.isPlaceholder = false,
  });

  /// What was said, or what kind of thing was sent when nothing was said.
  final String body;

  /// "Ann" in a group, so you can tell who is talking without opening it.
  /// Null in a direct chat, where there is only one person it could be.
  final String? author;

  /// Stands in for an attachment nobody captioned.
  final IconData? icon;

  /// [body] is unsent text of your own, drawn in the draft accent.
  final bool isDraft;

  /// There is nothing to preview — an empty chat, or one whose description is
  /// standing in for a conversation that has not started.
  final bool isPlaceholder;
}

/// Builds the preview line for [chat].
///
/// A draft wins over anything the chat itself has to say: it is the one line
/// on the row that is about what *you* were doing.
ChatPreview chatPreviewOf(
  ChatEntity chat,
  AppLocalizations l10n, {
  String? draft,
  int? myUserId,
}) {
  final pending = draft?.trim();
  if (pending != null && pending.isNotEmpty) {
    return ChatPreview(body: _oneLine(pending), isDraft: true);
  }

  final message = chat.lastMessage;
  if (message == null) {
    final description = chat.description?.trim();
    return ChatPreview(
      body: description == null || description.isEmpty
          ? l10n.noMessagesYet
          : _oneLine(description),
      isPlaceholder: true,
    );
  }

  final (body, icon) = _bodyOf(message, l10n);

  return ChatPreview(
    body: body,
    icon: icon,
    author: _authorOf(chat, message, l10n, myUserId: myUserId),
  );
}

/// Who to credit in front of the preview.
///
/// Direct chats say nothing — the only two people in one are you and the row's
/// own title. Neither do channels, which speak with one voice and would just
/// repeat the row's own name on every line. Groups name the author, and name
/// you as "You" so your own last word is not mistaken for someone else's.
String? _authorOf(
  ChatEntity chat,
  MessageEntity message,
  AppLocalizations l10n, {
  required int? myUserId,
}) {
  if (chat.type == ChatType.direct || chat.type == ChatType.channel) {
    return null;
  }
  if (message.type == MessageType.system) return null;

  if (myUserId != null && message.authorId == myUserId) return l10n.previewYou;
  return message.authorLabel;
}

(String, IconData?) _bodyOf(MessageEntity message, AppLocalizations l10n) {
  final content = message.content?.trim();
  if (content != null && content.isNotEmpty) {
    return (_oneLine(content), _iconForCaption(message));
  }

  final attachment = message.attachments.isEmpty
      ? null
      : message.attachments.first;

  final type = attachment?.attachmentType ?? _fallbackType(message.type);

  return switch (type) {
    AttachmentType.image => (l10n.previewPhoto, Icons.photo_outlined),
    AttachmentType.video => (l10n.previewVideo, Icons.movie_outlined),
    AttachmentType.voice => (
      _voiceLabel(attachment, l10n),
      Icons.mic_none_outlined,
    ),
    AttachmentType.videoNote => (
      l10n.previewVideoNote,
      Icons.videocam_outlined,
    ),
    AttachmentType.file => (
      _fileLabel(attachment, l10n),
      Icons.insert_drive_file_outlined,
    ),
    null => (l10n.previewNoText, null),
  };
}

/// A captioned attachment keeps its glyph: the caption says what was written,
/// the glyph says what came with it.
IconData? _iconForCaption(MessageEntity message) {
  if (message.attachments.isEmpty) return null;

  return switch (message.attachments.first.attachmentType) {
    AttachmentType.image => Icons.photo_outlined,
    AttachmentType.video => Icons.movie_outlined,
    AttachmentType.voice => Icons.mic_none_outlined,
    AttachmentType.videoNote => Icons.videocam_outlined,
    AttachmentType.file => Icons.insert_drive_file_outlined,
  };
}

/// What an uncaptioned message is when its attachments have not arrived — the
/// WS delta for a message being uploaded carries the type before it carries
/// the files (api-docs §6.4).
AttachmentType? _fallbackType(MessageType type) => switch (type) {
  MessageType.image => AttachmentType.image,
  MessageType.file => AttachmentType.file,
  MessageType.voice => AttachmentType.voice,
  MessageType.videoNote => AttachmentType.videoNote,
  MessageType.text ||
  MessageType.reply ||
  MessageType.forward ||
  MessageType.system => null,
};

String _voiceLabel(AttachmentEntity? attachment, AppLocalizations l10n) {
  final seconds = attachment?.durationSeconds;
  if (seconds == null || seconds <= 0) return l10n.previewVoice;
  return l10n.previewVoiceWithDuration(formatVoiceDuration(seconds));
}

String _fileLabel(AttachmentEntity? attachment, AppLocalizations l10n) {
  final filename = attachment?.originalFilename.trim();
  if (filename == null || filename.isEmpty) return l10n.previewFile;
  return filename;
}

/// `0:14`, `12:05`, `1:02:30`.
String formatVoiceDuration(int seconds) {
  final total = seconds < 0 ? 0 : seconds;
  final minutes = (total ~/ 60) % 60;
  final hours = total ~/ 3600;
  final rest = (total % 60).toString().padLeft(2, '0');

  if (hours > 0) {
    return '$hours:${minutes.toString().padLeft(2, '0')}:$rest';
  }
  return '$minutes:$rest';
}

/// Newlines would give the row a second line it has no room for.
String _oneLine(String value) =>
    value.replaceAll(RegExp(r'\s*[\r\n]+\s*'), ' ').trim();
