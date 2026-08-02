import 'package:fpdart/fpdart.dart';

import 'package:chatix/core/error/failures.dart';
import 'package:chatix/features/notification/domain/entities/device_platform.dart';
import 'package:chatix/features/notification/domain/repositories/notification_repository.dart';

/// `POST /devices/` 🔒 (api-docs §8.1) — hand this device's FCM/APNs token to
/// the backend so it can be pushed to.
///
/// Two things are resolved here rather than at the call site:
///
/// 1. **The platform string.** `DevicePlatform.current` maps the running
///    platform onto the exact `"IOS"`/`"WEB"`/`"ANDROID"` the API accepts, and
///    yields `null` on desktop, which has no valid value. This use case turns
///    that `null` into a `Left(InputFailure)` instead of guessing.
/// 2. **Idempotency is the server's problem.** Registering the same token
///    twice is expected (every login re-registers) and the backend upserts by
///    token, so no client-side "already registered?" bookkeeping is kept.
class RegisterDeviceUseCase {
  final NotificationRepository _repository;

  RegisterDeviceUseCase(this._repository);

  /// [platform] defaults to the current platform; pass one explicitly only
  /// when registering on behalf of a different one (tests).
  ///
  /// [deviceName] is free-form and shown to the user in the backend's device
  /// list; blank input falls back to the platform name rather than sending an
  /// empty string.
  Future<Either<Failure, void>> execute({
    required String token,
    DevicePlatform? platform,
    String deviceName = '',
  }) async {
    // An empty token is what `NotificationService.getToken()` degrades to on
    // some platforms when push isn't configured. Sending it would register a
    // device the server can never deliver to.
    final trimmedToken = token.trim();
    if (trimmedToken.isEmpty) {
      return const Left(
        InputFailure(message: 'Push token is empty — device not registered'),
      );
    }

    final resolved = platform ?? DevicePlatform.current;
    if (resolved == null) {
      // Desktop (macOS/Windows/Linux). Not an error the user should ever be
      // shown — the caller in `AuthController.login` swallows it — but it is
      // reported rather than silently succeeding so tests and logs can tell
      // "we chose not to register" apart from "it worked".
      return const Left(
        InputFailure(
          message: 'This platform is not one of IOS/WEB/ANDROID — '
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
