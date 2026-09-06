import 'dart:io';

import 'package:fpdart/fpdart.dart';
import 'package:chatix/core/error/failures.dart';

abstract class ChatAttachmentUploader {
  Future<Either<Failure, void>> upload({
    required String uploadUrl,
    required String mimeType,
    required int contentLength,
    String? filePath,
    List<int>? bytes,
    void Function(int sent, int total)? onProgress,
  });
}

typedef FileFactory = File Function(String path);
