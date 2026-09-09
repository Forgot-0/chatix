import 'package:fpdart/fpdart.dart';

import 'package:chatix/core/error/failures.dart';
import 'package:chatix/features/notification/domain/entities/device_platform.dart';
import 'package:chatix/features/notification/domain/repositories/notification_repository.dart';

class RegisterDeviceUseCase {
  final NotificationRepository _repository;

  RegisterDeviceUseCase(this._repository);

  Future<Either<Failure, void>> execute({
    required String token,
    DevicePlatform? platform,
    String deviceName = '',
  }) async {
    final trimmedToken = token.trim();
    if (trimmedToken.isEmpty) {
      return const Left(
        InputFailure(message: 'Push token is empty — device not registered'),
      );
    }

    final resolved = platform ?? DevicePlatform.current;
    if (resolved == null) {
      return const Left(
        InputFailure(
          message:
              'This platform is not one of IOS/WEB/ANDROID — '
              'push registration skipped',
        ),
      );
    }

    return _repository.registerDevice(
      platform: resolved.wire,
      token: trimmedToken,
      deviceName: deviceName.trim().isEmpty ? resolved.wire : deviceName.trim(),
    );
  }
}
