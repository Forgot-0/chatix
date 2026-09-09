library;

import 'package:go_router/go_router.dart';

abstract final class RouteParams {
  static const String chatId = 'chatId';
  static const String profileId = 'profileId';
}

abstract final class RouteNames {
  static const String splash = 'splash';
  static const String login = 'login';
  static const String register = 'register';
  static const String verifyEmail = 'verifyEmail';
  static const String resetPasswordRequest = 'resetPasswordRequest';
  static const String resetPasswordConfirm = 'resetPasswordConfirm';
  static const String oauthCallback = 'oauthCallback';

  static const String chats = 'chats';
  static const String chatSearch = 'chatSearch';
  static const String createChat = 'createChat';
  static const String chatDetail = 'chatDetail';
  static const String chatMembers = 'chatMembers';
  static const String chatInfo = 'chatInfo';
  static const String chatCall = 'chatCall';

  static const String notifications = 'notifications';

  static const String profile = 'profile';
  static const String profileEdit = 'profileEdit';
  static const String profiles = 'profiles';
  static const String profileDetail = 'profileDetail';

  static const String settings = 'settings';
  static const String languageSettings = 'languageSettings';
  static const String localizationAssetsDemo = 'localizationAssetsDemo';
}

abstract final class SplashRoute {
  static const String path = '/';
  static const String location = '/';
}

abstract final class LoginRoute {
  static const String path = '/login';
  static const String location = '/login';
}

abstract final class RegisterRoute {
  static const String path = '/register';
  static const String location = '/register';
}

abstract final class VerifyEmailRoute {
  static const String path = '/verify-email';
  static const String location = '/verify-email';
}

abstract final class ResetPasswordRoute {
  static const String path = '/reset-password';
  static const String location = '/reset-password';
}

abstract final class ResetPasswordConfirmRoute {
  static const String path = 'confirm';
  static const String location = '/reset-password/confirm';
}

abstract final class OAuthCallbackRoute {
  static const String path = '/oauth-callback';
  static const String location = '/oauth-callback';
}

abstract final class ChatsRoute {
  static const String path = '/chats';
  static const String location = '/chats';
}

abstract final class NotificationsRoute {
  static const String path = '/notifications';
  static const String location = '/notifications';
}

abstract final class ProfileRoute {
  static const String path = '/profile';
  static const String location = '/profile';
}

abstract final class CreateChatRoute {
  static const String path = 'create';
  static const String location = '/chats/create';
}

abstract final class ChatSearchRoute {
  static const String path = 'search';
  static const String location = '/chats/search';
}

class ChatDetailRoute {
  const ChatDetailRoute(this.chatId, {this.messageId});

  final String chatId;

  final String? messageId;

  static const String path = ':chatId';
  static const String messageQueryParam = 'message';

  String get location {
    final base = '/chats/$chatId';
    final target = messageId;
    if (target == null || target.isEmpty) return base;
    return '$base?$messageQueryParam=${Uri.encodeQueryComponent(target)}';
  }

  static String? idFrom(GoRouterState state) {
    final raw = state.pathParameters[RouteParams.chatId];
    if (raw == null || raw.isEmpty) return null;
    return raw;
  }

  static String? messageIdFrom(GoRouterState state) {
    final raw = state.uri.queryParameters[messageQueryParam];
    if (raw == null || raw.isEmpty) return null;
    return raw;
  }
}

abstract final class ChatMembersRoute {
  static const String path = 'members';
  static String locationOf(String chatId) => '/chats/$chatId/members';
}

abstract final class ChatInfoRoute {
  static const String path = 'info';
  static String locationOf(String chatId) => '/chats/$chatId/info';
}

abstract final class ChatCallRoute {
  static const String path = 'call';
  static String locationOf(String chatId) => '/chats/$chatId/call';
}

abstract final class ProfileEditRoute {
  static const String path = 'edit';
  static const String location = '/profile/edit';
}

abstract final class ProfilesRoute {
  static const String path = '/profiles';
  static const String location = '/profiles';
}

class ProfileDetailRoute {
  const ProfileDetailRoute(this.profileId);

  final int profileId;

  static const String path = ':profileId';
  String get location => '/profiles/$profileId';

  static int? idFrom(GoRouterState state) =>
      int.tryParse(state.pathParameters[RouteParams.profileId] ?? '');
}

abstract final class SettingsRoute {
  static const String path = '/settings';
  static const String location = '/settings';
}

abstract final class LanguageSettingsRoute {
  static const String path = 'language';
  static const String location = '/settings/language';
}

abstract final class LocalizationAssetsDemoRoute {
  static const String path = '/demo/localization/assets';
  static const String location = '/demo/localization/assets';
}

const Set<String> publicRoutePrefixes = {
  LoginRoute.path,
  RegisterRoute.path,
  VerifyEmailRoute.path,
  ResetPasswordRoute.path,
  OAuthCallbackRoute.path,
};

bool isPublicLocation(String location) {
  final path = location.split('?').first;
  for (final prefix in publicRoutePrefixes) {
    if (path == prefix) return true;
    if (path.startsWith('$prefix/')) return true;
  }
  return false;
}
