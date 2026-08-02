import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConstants {
  AppConstants._();

  /// Backend origin without trailing slash (from `.env` BASE_URL).
  static String get serverBaseUrl {
    final raw = dotenv.env['BASE_URL']?.trim();
    if (raw == null || raw.isEmpty) {
      return 'https://api.yourdomain.com';
    }
    return raw.endsWith('/') ? raw.substring(0, raw.length - 1) : raw;
  }

  /// API v1 prefix for all versioned endpoints (api-docs §1.1).
  static String get apiBaseUrl => '$serverBaseUrl/api/v1';

  /// Health check lives outside `/api/v1` (api-docs §1.1).
  static String get healthCheckUrl => '$serverBaseUrl/health';

  // Storage constants
  static const String accessTokenKey = 'access_token';
  static const String userDataKey = 'userData';

  // App constants
  static const String appName = 'ChatiX';
  static const String appVersion = '1.0.0';
  static const String packageName = 'com.forgot.chatix';
  static const String iOSAppId = '123456789';
  static const String appcastUrl = 'https://your-appcast-url.com/appcast.xml';

  // Timeout durations
  static const int connectTimeout = 30000;
  static const int receiveTimeout = 30000;

  // ---------------------------------------------------------------------
  // Routes — REMOVED. See `core/router/app_routes.dart`.
  //
  // This class used to carry a parallel set of route strings
  // (`chatDetailRoute(id)`, `profileDetailRoute(id)`, `positionDetailRoute(id)`,
  // …). They are gone, deliberately and completely, because after the router
  // was rebuilt around the shell they were no longer merely redundant — they
  // were *wrong*:
  //
  //   ChatDetailRoute(id).location      -> '/chat/{id}'      (404: '/chats/{id}')
  //   ProfileDetailRoute(id).location   -> '/profile/{id}'   (404: '/profiles/{id}')
  //   AppConstants.positionDetailRoute(id)  -> '/positions/{id}' (404: nested under its project)
  //
  // A wrong route string fails at runtime, on a device, in whichever screen
  // nobody re-tested — while `ChatDetailRoute(chat.id).location` cannot even
  // be spelled with an int, and `PositionDetailRoute` will not compile
  // without the project id the URL needs. Keeping both sets and "just
  // updating them together" is the exact arrangement that produced the drift
  // in the first place, so there is now one source of truth.
  // ---------------------------------------------------------------------

  // Hive box names
  static const String settingsBox = 'settings';
  static const String cacheBox = 'cache';
  static const String offlineSyncBox = 'offlineSync';

  // Animation durations
  static const Duration defaultAnimationDuration = Duration(milliseconds: 300);

  // Accessibility
  static const Duration accessibilityTooltipDuration = Duration(seconds: 5);
  static const double accessibilityTouchTargetMinSize = 48.0;

  // App Review
  static const int minSessionsBeforeReview = 5;
  static const int minDaysBeforeReview = 7;
  static const int minActionsBeforeReview = 10;
}
