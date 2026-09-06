import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:chatix/features/profile/domain/entities/avatar_presign_entity.dart';

part 'avatar_presign_model.g.dart';

/// `AvatarPresign` (api-docs §4.5, step 1) — `{ url, file_key }`.
///
/// ⚠️ This is a presigned **PUT**, not a presigned POST policy. The two look
/// similar and are not interchangeable: a POST policy returns a `fields` map
/// (`key`, `policy`, `x-amz-signature`, …) to be replayed in a multipart form,
/// whereas a presigned PUT carries its whole signature in the URL's query
/// string and takes the raw bytes as the request body. See §10.4, and
/// [AvatarUploader] for step 2.
@JsonSerializable(fieldRename: FieldRename.snake)
class AvatarPresignModel extends Equatable {
  /// Presigned PUT URL. ⚠️ Lives **90 seconds** (§4.5) — far shorter than the
  /// chat attachment equivalent's 3600 — so it must be used immediately, never
  /// stored or retried later.
  final String url;

  /// The S3 key the backend assigned, `{user_id}/{clean_filename}`. Needed
  /// again for step 3 (`upload_complete`) and for nothing else.
  ///
  /// The name is sanitised server-side (`[^\w.\-]` → `_`), so it will not
  /// match the filename that was sent — always echo this value back rather
  /// than rebuilding it locally.
  final String fileKey;

  const AvatarPresignModel({required this.url, required this.fileKey});

  @override
  List<Object?> get props => [url, fileKey];

  factory AvatarPresignModel.fromJson(Map<String, dynamic> json) =>
      _$AvatarPresignModelFromJson(json);

  Map<String, dynamic> toJson() => _$AvatarPresignModelToJson(this);
}

extension AvatarPresignModelX on AvatarPresignModel {
  AvatarPresignEntity toEntity() =>
      AvatarPresignEntity(url: url, fileKey: fileKey);
}
