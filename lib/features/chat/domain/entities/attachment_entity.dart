import 'package:equatable/equatable.dart';
import 'package:chatix/features/chat/domain/entities/chat_attachment_limits.dart';

enum AttachmentType {
  image,
  video,
  file,
  voice,

  videoNote;

  String get wire => switch (this) {
    AttachmentType.videoNote => 'video_note',
    _ => name,
  };

  static AttachmentType fromWire(String? value) {
    return AttachmentType.values.firstWhere(
      (t) => t.wire == value,
      orElse: () => AttachmentType.file,
    );
  }
}

enum AttachmentStatus {
  pending,
  success,
  error;

  String get wire => name;

  static AttachmentStatus fromWire(String? value) {
    return AttachmentStatus.values.firstWhere(
      (s) => s.name == value,
      orElse: () => AttachmentStatus.pending,
    );
  }
}

class AttachmentEntity extends Equatable {
  final String id;

  final String? messageId;

  final String chatId;
  final int uploaderId;
  final AttachmentType attachmentType;
  final AttachmentStatus attachmentStatus;

  final String? url;
  final int? urlExpiresIn;

  final String s3Key;
  final String mimeType;
  final String originalFilename;
  final int size;

  final int? width;
  final int? height;
  final int? durationSeconds;

  final DateTime createdAt;

  const AttachmentEntity({
    required this.id,
    required this.messageId,
    required this.chatId,
    required this.uploaderId,
    required this.attachmentType,
    required this.attachmentStatus,
    required this.url,
    required this.urlExpiresIn,
    required this.s3Key,
    required this.mimeType,
    required this.originalFilename,
    required this.size,
    required this.width,
    required this.height,
    required this.durationSeconds,
    required this.createdAt,
  });

  @override
  List<Object?> get props => [
    id,
    messageId,
    chatId,
    uploaderId,
    attachmentType,
    attachmentStatus,
    url,
    urlExpiresIn,
    s3Key,
    mimeType,
    originalFilename,
    size,
    width,
    height,
    durationSeconds,
    createdAt,
  ];
}

class AttachmentDownloadUrlEntity extends Equatable {
  final String attachmentId;
  final String url;
  final int expiresIn;

  const AttachmentDownloadUrlEntity({
    required this.attachmentId,
    required this.url,
    required this.expiresIn,
  });

  @override
  List<Object?> get props => [attachmentId, url, expiresIn];
}

class AttachmentUploadTicketEntity extends Equatable {
  final String uploadToken;

  final String uploadUrl;

  final AttachmentType attachmentType;
  final int expiresIn;

  const AttachmentUploadTicketEntity({
    required this.uploadToken,
    required this.uploadUrl,
    required this.attachmentType,
    required this.expiresIn,
  });

  @override
  List<Object?> get props => [
    uploadToken,
    uploadUrl,
    attachmentType,
    expiresIn,
  ];
}

class AttachmentUploadRequestEntity extends Equatable {
  final String filename;
  final String mimeType;
  final int fileSize;

  final String? filePath;

  final List<int>? bytes;

  final AttachmentType? attachmentType;

  const AttachmentUploadRequestEntity({
    required this.filename,
    required this.mimeType,
    required this.fileSize,
    this.filePath,
    this.bytes,
    this.attachmentType,
  });

  const AttachmentUploadRequestEntity.voice({
    required this.filename,
    required this.mimeType,
    required this.fileSize,
    this.filePath,
    this.bytes,
  }) : attachmentType = AttachmentType.voice;

  const AttachmentUploadRequestEntity.videoNote({
    required this.filename,
    required this.mimeType,
    required this.fileSize,
    this.filePath,
    this.bytes,
  }) : attachmentType = AttachmentType.videoNote;

  AttachmentType? get resolvedType =>
      attachmentType ?? ChatAttachmentLimits.typeOf(mimeType);

  @override
  List<Object?> get props => [
    filename,
    mimeType,
    fileSize,
    filePath,
    bytes,
    attachmentType,
  ];
}
