import 'package:equatable/equatable.dart';

/// What `POST /chats/{chat_id}/avatar/upload-requests/` accepts
/// (api-docs §5.10). Checked here before a request, because the server
/// answers anything else with `400 CHAT_AVATAR_VALIDATION` and nothing more
/// useful.
abstract final class ChatAvatarLimits {
  /// 5 MB, the same cap as a profile photo.
  static const int maxBytes = 5 * 1024 * 1024;

  /// HEIC is not on the list: the client converts it itself.
  static const Set<String> mimeTypes = {
    'image/jpeg',
    'image/png',
    'image/webp',
  };
}

/// The presigned slot for one picture — `ChatAvatarUploadSlotDTO`.
class ChatAvatarUploadSlot extends Equatable {
  const ChatAvatarUploadSlot({
    required this.uploadToken,
    required this.uploadUrl,
    required this.expiresIn,
  });

  /// Handed back on the confirm step.
  final String uploadToken;

  /// A presigned PUT, alive for [expiresIn] seconds.
  final String uploadUrl;

  final int expiresIn;

  @override
  List<Object?> get props => [uploadToken, uploadUrl, expiresIn];
}
