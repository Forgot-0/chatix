// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'attachment_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AttachmentModel _$AttachmentModelFromJson(Map<String, dynamic> json) =>
    AttachmentModel(
      id: json['id'] as String,
      messageId: json['message_id'] as String?,
      chatId: json['chat_id'] as String,
      uploaderId: (json['uploader_id'] as num).toInt(),
      attachmentType: json['attachment_type'] as String,
      attachmentStatus: json['attachment_status'] as String,
      url: json['url'] as String?,
      urlExpiresIn: (json['url_expires_in'] as num?)?.toInt(),
      s3Key: json['s3_key'] as String,
      mimeType: json['mime_type'] as String,
      originalFilename: json['original_filename'] as String,
      size: (json['size'] as num).toInt(),
      width: (json['width'] as num?)?.toInt(),
      height: (json['height'] as num?)?.toInt(),
      durationSeconds: (json['duration_seconds'] as num?)?.toInt(),
      createdAt: json['created_at'] as String,
    );

Map<String, dynamic> _$AttachmentModelToJson(AttachmentModel instance) =>
    <String, dynamic>{
      'id': instance.id,
      'message_id': instance.messageId,
      'chat_id': instance.chatId,
      'uploader_id': instance.uploaderId,
      'attachment_type': instance.attachmentType,
      'attachment_status': instance.attachmentStatus,
      'url': instance.url,
      'url_expires_in': instance.urlExpiresIn,
      's3_key': instance.s3Key,
      'mime_type': instance.mimeType,
      'original_filename': instance.originalFilename,
      'size': instance.size,
      'width': instance.width,
      'height': instance.height,
      'duration_seconds': instance.durationSeconds,
      'created_at': instance.createdAt,
    };

AttachmentUploadTicketModel _$AttachmentUploadTicketModelFromJson(
  Map<String, dynamic> json,
) => AttachmentUploadTicketModel(
  uploadToken: json['upload_token'] as String,
  uploadUrl: json['upload_url'] as String,
  attachmentType: json['attachment_type'] as String,
  expiresIn: (json['expires_in'] as num).toInt(),
);

Map<String, dynamic> _$AttachmentUploadTicketModelToJson(
  AttachmentUploadTicketModel instance,
) => <String, dynamic>{
  'upload_token': instance.uploadToken,
  'upload_url': instance.uploadUrl,
  'attachment_type': instance.attachmentType,
  'expires_in': instance.expiresIn,
};

AttachmentDownloadUrlModel _$AttachmentDownloadUrlModelFromJson(
  Map<String, dynamic> json,
) => AttachmentDownloadUrlModel(
  attachmentId: json['attachment_id'] as String,
  url: json['url'] as String,
  expiresIn: (json['expires_in'] as num).toInt(),
);

Map<String, dynamic> _$AttachmentDownloadUrlModelToJson(
  AttachmentDownloadUrlModel instance,
) => <String, dynamic>{
  'attachment_id': instance.attachmentId,
  'url': instance.url,
  'expires_in': instance.expiresIn,
};
