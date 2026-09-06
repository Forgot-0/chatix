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
///  1. `presignAvatar` — ask the backend for a presigned PUT URL and the
///     `file_key` it assigned.
///  2. `AvatarUploader.upload` — raw `PUT` of the bytes straight to that URL,
///     bypassing the app's authenticated `ApiClient` on purpose (§10.4).
///  3. `completeAvatarUpload` — hand the `file_key` back so the backend can
///     queue resizing into the 4 sizes × 3 formats.
///
/// ⚠️ **`done` means "queued", not "your avatar changed".** Neither the
/// presign nor the confirm validates the file: the backend sniffs the real
/// MIME and checks the size in a background job *after* step 3, and reports
/// the outcome nowhere (§0.10, §4.5). A rejected image simply never appears.
/// The caller should re-read `GET /profiles/{id}/` a few times after `done`
/// and treat an unchanged `avatars` as failure — which is also why the
/// client-side checks below matter: they are the only feedback a user gets
/// for the two most common mistakes.
///
/// ⚠️ Step 2 must follow step 1 **immediately** — the presigned URL is valid
/// for 90 seconds (§4.5).
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

    // api-docs §4.5: the backend caps avatars at 5 MB (`AVATAR_MAX_SIZE`) and
    // requires a real image (`AVATAR_NOT_TYPE_IMAGE`).
    //
    // ⚠️ Both are checked **only in the background job**, which surfaces
    // nothing to the client — so unlike most validation mirrors in this
    // codebase, these are not just a round-trip optimisation: they are the
    // only place a user is ever told why their avatar did not apply. Losing
    // them means an image silently failing with no message at all.
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
    final presignResult = await _repository.presignAvatar(filename: filename);

    if (presignResult.isLeft()) {
      yield Left(presignResult.getLeft().toNullable()!);
      return;
    }
    final presign = presignResult.getRight().toNullable()!;

    yield const Right(AvatarUploadStage.uploading);
    final uploadResult = await _avatarUploader.upload(
      url: presign.url,
      bytes: bytes,
      contentType: contentType,
    );

    if (uploadResult.isLeft()) {
      yield Left(uploadResult.getLeft().toNullable()!);
      return;
    }

    yield const Right(AvatarUploadStage.confirming);
    // ⚠️ `presign.fileKey`, not the local filename: the backend sanitised the
    // name when it signed the URL, so the two differ for anything with a
    // space or a special character in it.
    final completeResult = await _repository.completeAvatarUpload(
      fileKey: presign.fileKey,
    );

    if (completeResult.isLeft()) {
      yield Left(completeResult.getLeft().toNullable()!);
      return;
    }

    yield const Right(AvatarUploadStage.done);
  }
}
