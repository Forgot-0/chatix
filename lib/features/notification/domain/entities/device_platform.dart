import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;

/// The `platform` value of `CreateUserDeviceRequest` (api-docs §8.1).
///
/// ⚠️ The backend accepts **exactly** `"IOS"`, `"WEB"` or `"ANDROID"` —
/// upper-case, and only these three. Dart's own platform predicates do not
/// line up with that set, which is the whole reason this type exists:
///
/// * `Platform.operatingSystem` returns lower-case `"ios"`/`"android"` and
///   would be rejected;
/// * `Platform` itself **throws** on web (`dart:io` is unsupported there), so
///   `Platform.isIOS` cannot even be evaluated before `kIsWeb` is checked;
/// * macOS / Windows / Linux builds of this app map to no documented value at
///   all.
///
/// So the mapping is made explicit here, once, instead of being spelled out
/// (and mis-spelled) at each call site.
enum DevicePlatform {
  ios('IOS'),
  web('WEB'),
  android('ANDROID');

  const DevicePlatform(this.wire);

  /// The exact string the backend expects (api-docs §8.1).
  final String wire;

  /// The platform this build is running on, or `null` when it isn't one of
  /// the three the API knows about.
  ///
  /// Returning `null` for desktop is deliberate: registering a desktop client
  /// as, say, `"ANDROID"` would make the backend deliver FCM pushes for a
  /// device that can't receive them, and would corrupt the user's device list
  /// on the server. A `null` here simply means "don't register" — push is a
  /// best-effort extra, never a blocker (see `AuthController.login`).
  ///
  /// ⚠️ [kIsWeb] must be tested **first**: touching anything in `dart:io` on
  /// web throws at runtime.
  static DevicePlatform? get current {
    if (kIsWeb) return DevicePlatform.web;
    if (Platform.isIOS) return DevicePlatform.ios;
    if (Platform.isAndroid) return DevicePlatform.android;
    return null;
  }
}
