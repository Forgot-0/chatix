import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

/// Which device a permission prompt is about.
///
/// Only the two a call needs. Both are asked for at the moment the user
/// reaches for them — the microphone when joining, the camera when turning
/// video on — rather than up front, so the prompt arrives with its reason
/// already on screen.
enum MediaDeviceKind { microphone, camera }

/// The answer to one request, flattened to the three cases the UI cares about.
///
/// `permanentlyDenied` is the only one that needs the settings app: the
/// platform will not show its own prompt again, so asking a second time from
/// inside the call would do nothing at all.
enum MediaPermissionStatus { granted, denied, permanentlyDenied }

extension MediaPermissionStatusX on MediaPermissionStatus {
  bool get isGranted => this == MediaPermissionStatus.granted;

  bool get needsSettings => this == MediaPermissionStatus.permanentlyDenied;
}

/// Asks the platform for the microphone and the camera.
///
/// An interface rather than a direct `permission_handler` call so the call
/// controller can be driven in tests without a platform channel.
abstract class MediaPermissions {
  /// What the platform currently thinks, without prompting.
  ///
  /// Lets the UI skip its own explanation when the permission is already
  /// granted: a rationale dialog in front of a prompt that will never appear
  /// is one tap of pure friction.
  Future<MediaPermissionStatus> check(MediaDeviceKind device);

  Future<MediaPermissionStatus> request(MediaDeviceKind device);

  /// Opens the app's settings page, for a permission the platform will no
  /// longer prompt for.
  Future<bool> openSettings();
}

/// The real implementation.
///
/// Android and iOS are the only platforms that gate capture behind a
/// permission this package can ask for; on desktop and web the browser or the
/// OS prompts on `getUserMedia` itself, so there is nothing to ask ahead of
/// time and the request reports [MediaPermissionStatus.granted].
class PlatformMediaPermissions implements MediaPermissions {
  const PlatformMediaPermissions();

  static bool get _isSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  @override
  Future<MediaPermissionStatus> check(MediaDeviceKind device) async {
    if (!_isSupported) return MediaPermissionStatus.granted;
    return _map(await _permissionFor(device).status);
  }

  @override
  Future<MediaPermissionStatus> request(MediaDeviceKind device) async {
    if (!_isSupported) return MediaPermissionStatus.granted;
    return _map(await _permissionFor(device).request());
  }

  static Permission _permissionFor(MediaDeviceKind device) => switch (device) {
    MediaDeviceKind.microphone => Permission.microphone,
    MediaDeviceKind.camera => Permission.camera,
  };

  static MediaPermissionStatus _map(PermissionStatus status) {
    if (status.isGranted || status.isLimited || status.isProvisional) {
      return MediaPermissionStatus.granted;
    }
    if (status.isPermanentlyDenied || status.isRestricted) {
      return MediaPermissionStatus.permanentlyDenied;
    }
    return MediaPermissionStatus.denied;
  }

  @override
  Future<bool> openSettings() {
    if (!_isSupported) return Future.value(false);
    return openAppSettings();
  }
}

final mediaPermissionsProvider = Provider<MediaPermissions>(
  (ref) => const PlatformMediaPermissions(),
);
