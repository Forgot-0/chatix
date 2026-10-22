import 'dart:typed_data';

import 'package:fpdart/fpdart.dart';

import 'package:chatix/core/error/failures.dart';
import 'package:chatix/features/chat/domain/entities/chat_avatar.dart';

/// A group's or channel's own picture (api-docs §5.10).
///
/// Its own repository rather than more of `ChatRepository`: the three calls
/// are a world of their own — a slot, a PUT straight to storage, a confirm —
/// and nothing else about a chat goes through them.
abstract class ChatAvatarRepository {
  /// `POST /chats/{chat_id}/avatar/upload-requests/`.
  Future<Either<Failure, ChatAvatarUploadSlot>> requestUpload(
    String chatId, {
    required String mimeType,
    required int fileSize,
  });

  /// `PUT <upload_url>` with the raw bytes.
  Future<Either<Failure, void>> upload(
    ChatAvatarUploadSlot slot, {
    required Uint8List bytes,
    required String mimeType,
  });

  /// `POST /chats/{chat_id}/avatar/upload-requests/confirm/` → `202`.
  ///
  /// Accepted is all it means: the picture is checked and cut into sizes
  /// later, and the result arrives as `chat_updated` — or, when the file
  /// is refused, never arrives at all.
  Future<Either<Failure, void>> confirmUpload(
    String chatId, {
    required String uploadToken,
  });

  /// `DELETE /chats/{chat_id}/avatar/`.
  Future<Either<Failure, void>> remove(String chatId);
}
