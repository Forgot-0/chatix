import 'dart:typed_data';

import 'package:fpdart/fpdart.dart';

import 'package:chatix/core/error/failures.dart';
import 'package:chatix/features/chat/domain/entities/chat_avatar.dart';
import 'package:chatix/features/chat/domain/repositories/chat_avatar_repository.dart';

/// Sends a group's or channel's picture: a slot, the bytes, the confirm
/// (api-docs §5.10).
///
/// `Right` means the server took the file in, not that the chat has a new
/// face yet — that is decided in the background and announced by
/// `chat_updated`. The type and size are checked here first, so the one
/// refusal the server would give synchronously never has to be read.
class UploadChatAvatarUseCase {
  UploadChatAvatarUseCase(this._repository);

  final ChatAvatarRepository _repository;

  Future<Either<Failure, void>> execute(
    String chatId, {
    required Uint8List bytes,
    required String mimeType,
  }) async {
    if (chatId.isEmpty) {
      return const Left(InputFailure(message: 'Chat id is required'));
    }
    if (!ChatAvatarLimits.mimeTypes.contains(mimeType)) {
      return Left(InputFailure(message: 'A chat photo cannot be $mimeType'));
    }
    if (bytes.isEmpty) {
      return const Left(InputFailure(message: 'The picture is empty'));
    }
    if (bytes.length > ChatAvatarLimits.maxBytes) {
      return const Left(
        InputFailure(message: 'A chat photo must be 5 MB or smaller'),
      );
    }

    final slot = await _repository.requestUpload(
      chatId,
      mimeType: mimeType,
      fileSize: bytes.length,
    );

    return slot.match((failure) async => Left(failure), (slot) async {
      final uploaded = await _repository.upload(
        slot,
        bytes: bytes,
        mimeType: mimeType,
      );
      if (uploaded.isLeft()) return uploaded;

      return _repository.confirmUpload(chatId, uploadToken: slot.uploadToken);
    });
  }
}

/// Takes a group's or channel's picture away (`DELETE /chats/{id}/avatar/`).
class RemoveChatAvatarUseCase {
  RemoveChatAvatarUseCase(this._repository);

  final ChatAvatarRepository _repository;

  Future<Either<Failure, void>> execute(String chatId) {
    if (chatId.isEmpty) {
      return Future.value(
        const Left(InputFailure(message: 'Chat id is required')),
      );
    }
    return _repository.remove(chatId);
  }
}
