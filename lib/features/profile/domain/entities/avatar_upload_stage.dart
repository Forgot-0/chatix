/// Where an avatar upload has got to.
///
/// [processing] has no request behind it: the server's own validation runs in
/// a background task and reports nothing, so this stage is the client
/// watching `GET /profiles/{id}/` to find out whether the picture survived
/// (api-docs §4.5).
enum AvatarUploadStage { presigning, uploading, confirming, processing, done }
