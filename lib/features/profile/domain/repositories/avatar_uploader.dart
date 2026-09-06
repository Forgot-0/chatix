import 'dart:typed_data';

import 'package:fpdart/fpdart.dart';
import 'package:chatix/core/error/failures.dart';

abstract class AvatarUploader {
  Future<Either<Failure, void>> upload({
    required String url,
    required Uint8List bytes,
    required String contentType,
  });
}
