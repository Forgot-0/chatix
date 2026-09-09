import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:chatix/features/chat/presentation/providers/chat_providers.dart';

typedef AttachmentRef = ({
  String chatId,
  String messageId,
  String attachmentId,
});

final attachmentDownloadUrlProvider =
    FutureProvider.family<String, AttachmentRef>((ref, key) async {
      final result = await ref
          .read(getAttachmentDownloadUrlUseCaseProvider)
          .execute(key.chatId, key.messageId, key.attachmentId);

      return result.fold(
        (failure) => throw failure,
        (download) => download.url,
      );
    });
