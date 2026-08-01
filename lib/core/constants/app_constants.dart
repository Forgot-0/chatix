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

  // Route constants
  static const String initialRoute = '/';
  static const String homeRoute = '/home';

  /// `/chat` — the chat list (api-docs §6.2). Kept under the historical
  /// `chatRoute` name so existing links (home screen, deep links) still work.
  static const String chatRoute = '/chat';

  /// `/chat/create` — new-chat form. Declared **before** the `/chat/{id}`
  /// route in `app_router.dart` so "create" is never parsed as a chat UUID.
  static const String createChatRoute = '/chat/create';

  /// `/chat/{id}` — one conversation. Chat ids are UUID strings
  /// (api-docs §1.8), not ints like project/profile ids.
  static String chatDetailRoute(String chatId) => '/chat/$chatId';

  /// `/chat/{id}/members` — roles, bans and kicks (api-docs §6.3).
  static String chatMembersRoute(String chatId) => '/chat/$chatId/members';

  /// `/chat/{id}/call` — the LiveKit call room (api-docs §6.6). A route of its
  /// own rather than a dialog, so the OS back gesture ends the call and the
  /// room is disposed in exactly one place.
  static String chatCallRoute(String chatId) => '/chat/$chatId/call';

  static const String surveyRoute = '/survey';
  static const String loginRoute = '/login';
  static const String registerRoute = '/register';
  static const String verifyEmailRoute = '/verify-email';
  static const String resetPasswordRequestRoute = '/reset-password';
  static const String resetPasswordConfirmRoute = '/reset-password/confirm';
  static const String profileRoute = '/profile';
  static const String profileEditRoute = '/profile/edit';
  static const String profilesListRoute = '/profiles';

  /// `/profile/{id}` — viewing someone else's profile. Kept as a helper
  /// rather than another constant since it needs the id interpolated;
  /// mirrors the [profileRoute] ("my own profile", no id) vs. this ("a
  /// specific profile") split in `app_router.dart`.
  static String profileDetailRoute(int profileId) => '/profile/$profileId';
  // Project feature (api-docs §5).
  static const String projectsListRoute = '/projects';
  static const String myProjectsRoute = '/projects/my';
  static const String createProjectRoute = '/projects/create';
  static const String myInvitesRoute = '/projects/invites';
  static const String myApplicationsRoute = '/applications/my';

  /// `/projects/{id}` — a specific project's detail (tabs: info/members/positions).
  static String projectDetailRoute(int projectId) => '/projects/$projectId';

  /// `/positions/{id}` — a specific position's detail (UUID). Public read.
  static String positionDetailRoute(String positionId) => '/positions/$positionId';

  static const String settingsRoute = '/settings';
  static const String languageSettingsRoute = '/settings/language';
  static const String localizationDemoRoute = '/demo/localization';
  static const String localizationAssetsDemoRoute = '/demo/localization/assets';

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
