import 'dart:typed_data';

import 'package:fpdart/fpdart.dart';
import 'package:chatix/core/error/failures.dart';

/// Step 2 of the avatar upload flow (api-docs §4.5, §10.4): a raw **`PUT`**
/// straight to the presigned S3/MinIO `url` returned by `presignAvatar`.
///
/// ⚠️ **PUT with the raw bytes as the body — not a multipart POST.** The
/// backend issues a query-signed presigned PUT (`X-Amz-Signature` inside the
/// URL), which is the same mechanism chat attachments use (§6.5 step 2). A
/// presigned *POST policy* — multipart, with a `fields` map replayed in the
/// form — is a different S3 feature this backend does not use, and a client
/// built for it fails at the presign step, before it ever reaches storage.
///
/// Deliberately modeled as its own abstraction rather than a method on
/// [ProfileRepository]: unlike every other profile call, this request must
/// bypass the app's [ApiClient]/[Dio] entirely — the URL carries its own
/// signature and must NOT receive our `Authorization: Bearer` header, nor the
/// auth/retry/trailing-slash interceptors meant for `{BASE_URL}/api/v1/*`
/// (a trailing slash appended to a signed URL invalidates the signature).
abstract class AvatarUploader {
  /// `PUT [url]` with [bytes] as the entire body and `Content-Type:
  /// [contentType]`.
  ///
  /// [url] comes straight from a prior `presignAvatar` call and must not be
  /// altered in any way — every character of it is covered by the signature.
  ///
  /// ⚠️ The URL expires **90 seconds** after it was issued (§4.5), so this
  /// must follow the presign immediately; a queued or retried-much-later
  /// upload gets a `403` from storage.
  Future<Either<Failure, void>> upload({
    required String url,
    required Uint8List bytes,
    required String contentType,
  });
}
