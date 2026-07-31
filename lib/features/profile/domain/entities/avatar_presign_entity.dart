import 'package:equatable/equatable.dart';

/// `AvatarPresignResponse` (api-docs §4.5, step 1 — `POST
/// /profiles/avatar/presign/`).
///
/// [fields] are the presigned-POST policy fields (S3/MinIO: `key`,
/// `policy`, `x-amz-*`...) and must be forwarded into the multipart body of
/// step 2 exactly as received, alongside the file itself. [keyBase] (format
/// `"avatars/{user_id}"`) is only needed again for step 3
/// (`completeAvatarUpload`).
class AvatarPresignEntity extends Equatable {
  final String url;
  final Map<String, String> fields;
  final String keyBase;

  const AvatarPresignEntity({
    required this.url,
    required this.fields,
    required this.keyBase,
  });

  @override
  List<Object?> get props => [url, fields, keyBase];
}
