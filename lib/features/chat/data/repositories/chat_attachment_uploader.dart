import 'dart:io';

import 'package:fpdart/fpdart.dart';
import 'package:chatix/core/error/failures.dart';

/// Step 2 of the attachment flow (api-docs §6.5): raw `PUT` of a file's bytes
/// to a pre-signed S3/MinIO URL, bypassing our backend entirely.
///
/// ⚠️ This is **not** the same mechanism as the avatar upload (§4.5), even
/// though both are "pre-signed uploads":
///
/// |  | avatar (§4.5) | chat attachment (§6.5) |
/// |---|---|---|
/// | verb | `POST` | **`PUT`** |
/// | body | `multipart/form-data` with policy fields + `file` part | **the raw bytes, nothing else** |
/// | `Content-Type` | multipart boundary | **the file's own MIME type** |
///
/// Sending multipart here corrupts the object: S3 would store the MIME
/// preamble and boundary markers as part of the file, and the stored size
/// wouldn't match the `file_size` the backend recorded at step 1, so its
/// async validation pass would flip the attachment to `error`.
abstract class ChatAttachmentUploader {
  /// PUTs [filePath] (preferred, streamed) or [bytes] to [uploadUrl] with
  /// `Content-Type: [mimeType]`.
  ///
  /// [contentLength] is the size the backend was told at step 1 and is sent as
  /// `Content-Length`; a mismatch with the actual bytes is what makes an
  /// upload fail validation later, so it is passed explicitly rather than
  /// re-measured here.
  Future<Either<Failure, void>> upload({
    required String uploadUrl,
    required String mimeType,
    required int contentLength,
    String? filePath,
    List<int>? bytes,
    void Function(int sent, int total)? onProgress,
  });
}

/// Uploader backed by a caller-supplied [File] factory so tests can avoid
/// touching the filesystem.
typedef FileFactory = File Function(String path);
