import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpdart/fpdart.dart';

import 'package:chatix/core/error/failures.dart';
import 'package:chatix/core/network/api_client.dart';
import 'package:chatix/core/providers/network_providers.dart';
import 'package:chatix/features/chat/data/datasources/chat_attachment_uploader_impl.dart';
import 'package:chatix/features/chat/data/repositories/chat_attachment_uploader.dart';
import 'package:chatix/features/chat/domain/entities/chat_avatar.dart';
import 'package:chatix/features/chat/domain/repositories/chat_avatar_repository.dart';

/// §5.10 over the wire. The PUT goes through the attachment uploader: the
/// same bare Dio, with no auth header and no base URL, since the slot is a
/// presigned storage URL.
class ChatAvatarRepositoryImpl implements ChatAvatarRepository {
  ChatAvatarRepositoryImpl(this._api, this._uploader);

  final ApiClient _api;
  final ChatAttachmentUploader _uploader;

  @override
  Future<Either<Failure, ChatAvatarUploadSlot>> requestUpload(
    String chatId, {
    required String mimeType,
    required int fileSize,
  }) async {
    final result = await _api.post(
      '/chats/$chatId/avatar/upload-requests/',
      data: {'mime_type': mimeType, 'file_size': fileSize},
    );

    return result.flatMap((data) {
      if (data is! Map) {
        return const Left(
          ServerFailure(message: 'The avatar slot came back empty'),
        );
      }
      final token = data['upload_token'];
      final url = data['upload_url'];
      if (token is! String || url is! String) {
        return const Left(
          ServerFailure(message: 'The avatar slot came back without a URL'),
        );
      }
      final expiresIn = data['expires_in'];
      return Right(
        ChatAvatarUploadSlot(
          uploadToken: token,
          uploadUrl: url,
          expiresIn: expiresIn is num ? expiresIn.toInt() : 0,
        ),
      );
    });
  }

  @override
  Future<Either<Failure, void>> upload(
    ChatAvatarUploadSlot slot, {
    required Uint8List bytes,
    required String mimeType,
  }) {
    return _uploader.upload(
      uploadUrl: slot.uploadUrl,
      mimeType: mimeType,
      contentLength: bytes.length,
      bytes: bytes,
    );
  }

  @override
  Future<Either<Failure, void>> confirmUpload(
    String chatId, {
    required String uploadToken,
  }) async {
    final result = await _api.post(
      '/chats/$chatId/avatar/upload-requests/confirm/',
      data: {'upload_token': uploadToken},
    );
    return result.map((_) {});
  }

  @override
  Future<Either<Failure, void>> remove(String chatId) async {
    final result = await _api.delete('/chats/$chatId/avatar/');
    return result.map((_) {});
  }
}

final chatAvatarRepositoryProvider = Provider<ChatAvatarRepository>((ref) {
  return ChatAvatarRepositoryImpl(
    ref.watch(apiClientProvider),
    ref.watch(chatAttachmentUploaderProvider),
  );
});
