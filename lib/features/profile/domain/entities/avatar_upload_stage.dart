/// Progress stages of the 3-step avatar upload flow (api-docs §4.5), as
/// emitted by `UploadAvatarUseCase.execute`. `done` is the only terminal
/// success stage; any step can instead fail, which the use case surfaces as
/// `Left(Failure)` on the same stream rather than as a stage.
enum AvatarUploadStage {
  /// Step 1: `POST /profiles/avatar/presign/` in flight.
  presigning,

  /// Step 2: raw multipart `POST` to the presigned S3/MinIO `url` in
  /// flight — deliberately bypasses the app's `ApiClient`/`Dio` (see
  /// `AvatarUploader`).
  uploading,

  /// Step 3: `POST /profiles/avatar/upload_complete/` in flight.
  confirming,

  /// All 3 steps succeeded. The resized variants (32/64/256/512 ×
  /// jpg/webp/avif) are generated asynchronously server-side, so they may
  /// not be visible on `GET /profiles/{id}/` the instant this fires.
  done,
}
