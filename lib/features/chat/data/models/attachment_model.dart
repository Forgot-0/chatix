import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:chatix/features/chat/domain/entities/attachment_entity.dart';

part 'attachment_model.g.dart';

@JsonSerializable(fieldRename: FieldRename.snake)
class AttachmentModel extends Equatable {
  final String id;
  final String? messageId;
  final String chatId;
  final int uploaderId;
  final String attachmentType;
  final String attachmentStatus;
  final String? url;
  final int? urlExpiresIn;
  final String s3Key;
  final String mimeType;
  final String originalFilename;
  final int size;
  final int? width;
  final int? height;
  final int? durationSeconds;
  final String createdAt;

  const AttachmentModel({
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

  factory AttachmentModel.fromJson(Map<String, dynamic> json) =>
      _$AttachmentModelFromJson(json);

  Map<String, dynamic> toJson() => _$AttachmentModelToJson(this);
}

extension AttachmentModelX on AttachmentModel {
  AttachmentEntity toEntity() {
    return AttachmentEntity(
      id: id,
      messageId: messageId,
      chatId: chatId,
      uploaderId: uploaderId,
      attachmentType: AttachmentType.fromWire(attachmentType),
      attachmentStatus: AttachmentStatus.fromWire(attachmentStatus),
      url: url,
      urlExpiresIn: urlExpiresIn,
      s3Key: s3Key,
      mimeType: mimeType,
      originalFilename: originalFilename,
      size: size,
      width: width,
      height: height,
      durationSeconds: durationSeconds,
      createdAt: DateTime.parse(createdAt),
    );
  }
}

@JsonSerializable(fieldRename: FieldRename.snake)
class AttachmentUploadTicketModel extends Equatable {
  final String uploadToken;
  final String uploadUrl;
  final String attachmentType;
  final int expiresIn;

  const AttachmentUploadTicketModel({
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

  factory AttachmentUploadTicketModel.fromJson(Map<String, dynamic> json) =>
      _$AttachmentUploadTicketModelFromJson(json);

  Map<String, dynamic> toJson() => _$AttachmentUploadTicketModelToJson(this);
}

extension AttachmentUploadTicketModelX on AttachmentUploadTicketModel {
  AttachmentUploadTicketEntity toEntity() {
    return AttachmentUploadTicketEntity(
      uploadToken: uploadToken,
      uploadUrl: uploadUrl,
      attachmentType: AttachmentType.fromWire(attachmentType),
      expiresIn: expiresIn,
    );
  }
}

@JsonSerializable(fieldRename: FieldRename.snake)
class AttachmentDownloadUrlModel extends Equatable {
  final String attachmentId;
  final String url;
  final int expiresIn;

  const AttachmentDownloadUrlModel({
    required this.attachmentId,
    required this.url,
    required this.expiresIn,
  });

  @override
  List<Object?> get props => [attachmentId, url, expiresIn];

  factory AttachmentDownloadUrlModel.fromJson(Map<String, dynamic> json) =>
      _$AttachmentDownloadUrlModelFromJson(json);

  Map<String, dynamic> toJson() => _$AttachmentDownloadUrlModelToJson(this);
}

extension AttachmentDownloadUrlModelX on AttachmentDownloadUrlModel {
  AttachmentDownloadUrlEntity toEntity() {
    return AttachmentDownloadUrlEntity(
      attachmentId: attachmentId,
      url: url,
      expiresIn: expiresIn,
    );
  }
}

extension AttachmentEntityX on AttachmentEntity {
  /// The DTO this attachment came from.
  ///
  /// [withUrl] is off by default because the one field that cannot survive
  /// being written down is `url`: it is a presigned link with 300 seconds on
  /// it (api-docs §5.5), so a stored copy is a link that will be dead by the
  /// time anything reads it. The row keeps `s3_key`, which is what the file
  /// cache is keyed by and what a fresh link is fetched with.
  AttachmentModel toModel({bool withUrl = false}) => AttachmentModel(
    id: id,
    messageId: messageId,
    chatId: chatId,
    uploaderId: uploaderId,
    attachmentType: attachmentType.wire,
    attachmentStatus: attachmentStatus.wire,
    url: withUrl ? url : null,
    urlExpiresIn: withUrl ? urlExpiresIn : null,
    s3Key: s3Key,
    mimeType: mimeType,
    originalFilename: originalFilename,
    size: size,
    width: width,
    height: height,
    durationSeconds: durationSeconds,
    createdAt: createdAt.toIso8601String(),
  );
}
