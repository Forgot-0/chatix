import 'dart:typed_data';

import 'package:fpdart/fpdart.dart';
import 'package:chatix/core/error/failures.dart';
import 'package:chatix/features/profile/domain/entities/avatar_upload_stage.dart';
import 'package:chatix/features/profile/domain/repositories/avatar_uploader.dart';
import 'package:chatix/features/profile/domain/repositories/profile_repository.dart';

/// Encapsulates the full 3-step avatar upload flow (api-docs §4.5) behind a
/// single call, so screens never have to know it's 3 requests instead of
/// one:
///
///  1. `presignAvatar` — ask the backend for an upload URL + policy fields.
///  2. `AvatarUploader.upload` — raw multipart `POST` straight to that URL,
///     bypassing the app's authenticated `ApiClient` on purpose (§10.4).
///  3. `completeAvatarUpload` — tell the backend the upload finished, so it
///     can kick off resizing into the 4 sizes × 3 formats.
///
/// [execute] returns a `Stream` rather than a single `Future` specifically
/// so a screen can drive a step indicator (`AsyncValue<AvatarUploadStage>`
/// via a `StreamProvider`/`AsyncNotifier` maps onto this naturally) instead
/// of only learning "done" or "failed" at the very end. Each stage is
/// emitted right before its request goes out; the stream ends after
/// `Right(AvatarUploadStage.done)` on success, or after a single
/// `Left(Failure)` on the first step that fails — whichever step failed is
/// not retried automatically.
class UploadAvatarUseCase {
  // api-docs §4.5.
  static const maxSizeBytes = 5 * 1024 * 1024;

  final ProfileRepository _repository;
  final AvatarUploader _avatarUploader;

  UploadAvatarUseCase(this._repository, this._avatarUploader);

  Stream<Either<Failure, AvatarUploadStage>> execute({
    required Uint8List bytes,
    required String filename,
    required String contentType,
  }) async* {
    final size = bytes.length;

    // api-docs §4.5: content_type must start with "image/" (else 400
    // AVATAR_NOT_TYPE_IMAGE) and size is capped at 5MB (AVATAR_MAX_SIZE) —
    // both checked client-side first so a bad file never leaves the device.
    if (!contentType.startsWith('image/')) {
      yield const Left(InputFailure(message: 'File must be an image'));
      return;
    }

    if (size <= 0) {
      yield const Left(InputFailure(message: 'File is empty'));
      return;
    }

    if (size > maxSizeBytes) {
      yield const Left(InputFailure(message: 'Image must be 5MB or smaller'));
      return;
    }

    if (filename.isEmpty) {
      yield const Left(InputFailure(message: 'Filename cannot be empty'));
      return;
    }

    yield const Right(AvatarUploadStage.presigning);
    final presignResult = await _repository.presignAvatar(
      filename: filename,
      size: size,
      contentType: contentType,
    );

    if (presignResult.isLeft()) {
      yield Left(presignResult.getLeft().toNullable()!);
      return;
    }
    final presign = presignResult.getRight().toNullable()!;

    yield const Right(AvatarUploadStage.uploading);
    final uploadResult = await _avatarUploader.upload(
      url: presign.url,
      fields: presign.fields,
      bytes: bytes,
      filename: filename,
      contentType: contentType,
    );

    if (uploadResult.isLeft()) {
      yield Left(uploadResult.getLeft().toNullable()!);
      return;
    }

    yield const Right(AvatarUploadStage.confirming);
    final completeResult = await _repository.completeAvatarUpload(
      keyBase: presign.keyBase,
      size: size,
      contentType: contentType,
    );

    if (completeResult.isLeft()) {
      yield Left(completeResult.getLeft().toNullable()!);
      return;
    }

    yield const Right(AvatarUploadStage.done);
  }
}
