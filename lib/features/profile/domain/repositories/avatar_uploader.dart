import 'dart:typed_data';

import 'package:fpdart/fpdart.dart';
import 'package:chatix/core/error/failures.dart';

/// Step 2 of the avatar upload flow (api-docs §4.5): the raw multipart
/// `POST` straight to the presigned S3/MinIO `url` returned by
/// `presignAvatar`.
///
/// Deliberately modeled as its own abstraction rather than a method on
/// [ProfileRepository]: unlike every other profile call, this request must
/// bypass the app's [ApiClient]/[Dio] instance entirely — the presigned URL
/// carries its own signature inside [AvatarPresignEntity.fields] and must
/// NOT receive our `Authorization: Bearer` header (api-docs §10.4). Keeping
/// it separate also means the request-building code can't accidentally
/// pick up the auth/retry/trailing-slash interceptors meant for
/// `{BASE_URL}/api/v1/*`.
abstract class AvatarUploader {
  /// Sends [bytes] (as [filename], with [contentType]) plus every entry of
  /// [fields] as-is to [url], `multipart/form-data`, file under the `file`
  /// key — the standard S3/MinIO presigned-POST form (api-docs §4.5 step
  /// 2). [fields] and [url] come straight from a prior `presignAvatar`
  /// call and must not be altered.
  Future<Either<Failure, void>> upload({
    required String url,
    required Map<String, String> fields,
    required Uint8List bytes,
    required String filename,
    required String contentType,
  });
}
