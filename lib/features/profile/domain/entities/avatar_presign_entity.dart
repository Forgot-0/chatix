import 'package:equatable/equatable.dart';

/// `AvatarPresign` (api-docs §4.5, step 1 — `POST /profiles/avatar/presign/`).
///
/// ⚠️ **Presigned PUT, not a POST policy.** There are no form fields to
/// forward: the signature lives in [url]'s query string
/// (`X-Amz-Signature`/`X-Amz-Expires`), and step 2 is a plain `PUT` of the raw
/// bytes to it (§4.5, §10.4).
class AvatarPresignEntity extends Equatable {
  /// Presigned PUT URL — valid for **90 seconds only** (§4.5). Use it
  /// immediately; there is nothing to gain by holding it.
  final String url;

  /// The server-assigned S3 key, echoed back in step 3
  /// (`upload_complete`). Sanitised server-side, so it will not equal the
  /// filename that was sent.
  final String fileKey;

  const AvatarPresignEntity({required this.url, required this.fileKey});

  @override
  List<Object?> get props => [url, fileKey];
}
