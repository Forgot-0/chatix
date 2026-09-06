import 'package:equatable/equatable.dart';
import 'package:chatix/features/chat/domain/entities/attachment_entity.dart';
import 'package:chatix/features/chat/domain/entities/chat_profile_entity.dart';
import 'package:chatix/features/chat/domain/entities/reaction_entity.dart';

enum MessageType {
  text,
  image,
  file,
  system,
  reply,
  forward,
  voice,

  videoNote;

  String get wire => switch (this) {
    MessageType.videoNote => 'video_note',
    _ => name,
  };

  static MessageType fromWire(String? value) {
    return MessageType.values.firstWhere(
      (t) => t.wire == value,
      orElse: () => MessageType.text,
    );
  }
}

class MessageEntity extends Equatable {
  final String id;
  final String chatId;

  final int seq;

  final int? authorId;

  final ChatProfileEntity? profile;

  final List<ReactionGroupEntity> reactions;

  final MessageType type;

  final String? content;

  final String? replyToId;
  final String? forwardedFromChatId;
  final String? forwardedFromMessageId;

  final int? forwardedFromAuthorId;

  final bool isEdited;
  final DateTime createdAt;
  final List<AttachmentEntity> attachments;

  final MessageEntity? replyTo;

  final MessageEntity? forwardedFrom;

  const MessageEntity({
    required this.id,
    required this.chatId,
    required this.seq,
    required this.authorId,
    required this.type,
    required this.content,
    required this.replyToId,
    required this.forwardedFromChatId,
    required this.forwardedFromMessageId,
    required this.forwardedFromAuthorId,
    required this.isEdited,
    required this.createdAt,
    this.attachments = const [],
    this.replyTo,
    this.forwardedFrom,
    this.profile,
    this.reactions = const [],
  });

  String get authorLabel => chatDisplayName(profile, authorId);

  MessageReactionsEntity get reactionSummary =>
      MessageReactionsEntity.fromGroups(id, reactions);

  bool get hasReactions => reactions.isNotEmpty;

  bool get isForward => forwardedFromMessageId != null || forwardedFrom != null;

  bool get isReply => replyToId != null || replyTo != null;

  bool get hasPendingAttachments =>
      attachments.any((a) => a.attachmentStatus == AttachmentStatus.pending);

  MessageEntity copyWith({
    String? id,
    String? chatId,
    int? seq,
    int? authorId,
    MessageType? type,
    String? content,
    String? replyToId,
    String? forwardedFromChatId,
    String? forwardedFromMessageId,
    int? forwardedFromAuthorId,
    bool? isEdited,
    DateTime? createdAt,
    List<AttachmentEntity>? attachments,
    MessageEntity? replyTo,
    MessageEntity? forwardedFrom,
    ChatProfileEntity? profile,
    List<ReactionGroupEntity>? reactions,
    bool clearContent = false,
  }) {
    return MessageEntity(
      id: id ?? this.id,
      chatId: chatId ?? this.chatId,
      seq: seq ?? this.seq,
      authorId: authorId ?? this.authorId,
      type: type ?? this.type,
      content: clearContent ? null : (content ?? this.content),
      replyToId: replyToId ?? this.replyToId,
      forwardedFromChatId: forwardedFromChatId ?? this.forwardedFromChatId,
      forwardedFromMessageId:
          forwardedFromMessageId ?? this.forwardedFromMessageId,
      forwardedFromAuthorId:
          forwardedFromAuthorId ?? this.forwardedFromAuthorId,
      isEdited: isEdited ?? this.isEdited,
      createdAt: createdAt ?? this.createdAt,
      attachments: attachments ?? this.attachments,
      replyTo: replyTo ?? this.replyTo,
      forwardedFrom: forwardedFrom ?? this.forwardedFrom,
      profile: profile ?? this.profile,
      reactions: reactions ?? this.reactions,
    );
  }

  @override
  List<Object?> get props => [
    id,
    chatId,
    seq,
    authorId,
    type,
    content,
    replyToId,
    forwardedFromChatId,
    forwardedFromMessageId,
    forwardedFromAuthorId,
    isEdited,
    createdAt,
    attachments,
    replyTo,
    forwardedFrom,
    profile,
    reactions,
  ];
}
