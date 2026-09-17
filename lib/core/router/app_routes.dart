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
  static const String chatInvite = 'chatInvite';
  static const String chatInfo = 'chatInfo';
  static const String chatSettings = 'chatSettings';
  static const String chatCall = 'chatCall';
  static const String chatMedia = 'chatMedia';
  static const String chatAttach = 'chatAttach';
  static const String chatFolders = 'chatFolders';
  static const String folderEditor = 'folderEditor';

  static const String notifications = 'notifications';

  static const String profile = 'profile';
  static const String profileEdit = 'profileEdit';
  static const String profileAvatar = 'profileAvatar';
  static const String profileDetailAvatar = 'profileDetailAvatar';
  static const String profiles = 'profiles';
  static const String profileDetail = 'profileDetail';

  static const String settings = 'settings';
  static const String languageSettings = 'languageSettings';
  static const String notificationSettings = 'notificationSettings';
  static const String sessions = 'sessions';
  static const String localizationAssetsDemo = 'localizationAssetsDemo';
  static const String componentShowcase = 'componentShowcase';
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

/// `/chats/create`, optionally pre-set to a chat type.
///
/// The type travels as its wire value (`ChatType.wire`) rather than as an enum
/// so the router stays clear of the chat feature's domain layer; the screen
/// parses it back with `ChatType.fromWire`, which falls back to a direct chat
/// for anything it does not recognise.
abstract final class CreateChatRoute {
  static const String path = 'create';
  static const String location = '/chats/create';

  static const String typeQueryParam = 'type';

  static const String directType = 'direct';
  static const String groupType = 'group';
  static const String channelType = 'channel';

  static String locationOf(String type) =>
      '$location?$typeQueryParam=${Uri.encodeQueryComponent(type)}';

  static String? typeFrom(GoRouterState state) {
    final raw = state.uri.queryParameters[typeQueryParam];
    if (raw == null || raw.isEmpty) return null;
    return raw;
  }
}

abstract final class ChatSearchRoute {
  static const String path = 'search';
  static const String location = '/chats/search';
}

/// `/chats/folders` — the folders this device keeps and the switches around
/// the chat list's pinned zone and archive.
abstract final class ChatFoldersRoute {
  static const String path = 'folders';
  static const String location = '/chats/folders';
}

/// `/chats/folders/edit`, on an existing folder when `id` says which.
///
/// The id travels as a query parameter rather than as a path segment so the
/// same route covers a folder that does not exist yet.
abstract final class FolderEditorRoute {
  static const String path = 'edit';
  static const String location = '/chats/folders/edit';

  static const String folderQueryParam = 'id';

  static String locationOf(String? folderId) {
    if (folderId == null || folderId.isEmpty) return location;
    return '$location?$folderQueryParam=${Uri.encodeQueryComponent(folderId)}';
  }

  static String? folderIdFrom(GoRouterState state) {
    final raw = state.uri.queryParameters[folderQueryParam];
    if (raw == null || raw.isEmpty) return null;
    return raw;
  }
}

/// `/chats/{chatId}`, optionally focused on one message.
///
/// Two ways to name that message, because the two callers have different
/// halves of it:
///
/// * `?message={seq}` — the per-chat sequence number. This is the deep-link
///   form: `seq` is all the context endpoint needs
///   (`GET /chats/{id}/messages/context/?target_seq=`), so the screen can jump
///   straight there without a lookup.
/// * `?message_id={uuid}` — a push notification carries `message_id` and no
///   `seq`, so the screen resolves the seq first and then loads the context.
///
/// A non-numeric `?message=` is read as an id, so links minted before the seq
/// form existed still land on the right message.
class ChatDetailRoute {
  const ChatDetailRoute(this.chatId, {this.messageSeq, this.messageId});

  final String chatId;

  /// Per-chat sequence number of the message to reveal.
  final int? messageSeq;

  /// Id of the message to reveal, when the seq is not known.
  final String? messageId;

  static const String path = ':chatId';
  static const String messageQueryParam = 'message';
  static const String messageIdQueryParam = 'message_id';

  String get location {
    final base = '/chats/$chatId';

    final seq = messageSeq;
    if (seq != null) return '$base?$messageQueryParam=$seq';

    final id = messageId;
    if (id == null || id.isEmpty) return base;
    return '$base?$messageIdQueryParam=${Uri.encodeQueryComponent(id)}';
  }

  static String? idFrom(GoRouterState state) {
    final raw = state.pathParameters[RouteParams.chatId];
    if (raw == null || raw.isEmpty) return null;
    return raw;
  }

  static int? messageSeqFrom(GoRouterState state) {
    final raw = state.uri.queryParameters[messageQueryParam];
    if (raw == null || raw.isEmpty) return null;

    final seq = int.tryParse(raw);
    if (seq == null || seq < 1) return null;
    return seq;
  }

  static String? messageIdFrom(GoRouterState state) {
    final explicit = state.uri.queryParameters[messageIdQueryParam];
    if (explicit != null && explicit.isNotEmpty) return explicit;

    final raw = state.uri.queryParameters[messageQueryParam];
    if (raw == null || raw.isEmpty) return null;

    // A numeric `?message=` is a seq, and messageSeqFrom already has it.
    return int.tryParse(raw) == null ? raw : null;
  }
}

abstract final class ChatMembersRoute {
  static const String path = 'members';
  static String locationOf(String chatId) => '/chats/$chatId/members';
}

/// `/chats/{chatId}/members/invite` — picking people out of `GET /profiles/`
/// and adding them to this chat.
///
/// Under the member list rather than beside it: it is reached from there, and
/// going back lands on the list the new people just joined.
abstract final class ChatInviteRoute {
  static const String path = 'invite';
  static String locationOf(String chatId) =>
      '${ChatMembersRoute.locationOf(chatId)}/$path';
}

/// `/chats/{chatId}/info` — the chat's profile: its face, what it has
/// shared, and what can be done to it.
abstract final class ChatInfoRoute {
  static const String path = 'info';
  static String locationOf(String chatId) => '/chats/$chatId/info';
}

/// `/chats/{chatId}/settings` — the form behind `PATCH /chats/{chat_id}/`.
///
/// A screen of its own rather than a section of the profile: it needs
/// `chat:update`, it is a form with a save button, and everything on the
/// profile above it is readable by any member.
abstract final class ChatSettingsRoute {
  static const String path = 'settings';
  static String locationOf(String chatId) => '/chats/$chatId/settings';
}

abstract final class ChatCallRoute {
  static const String path = 'call';
  static String locationOf(String chatId) => '/chats/$chatId/call';
}

/// `/chats/{chatId}/media?message={id}&attachment={id}` — one photo or video
/// full screen, with the rest of the chat's media a swipe away.
///
/// Both ids travel in the URL rather than only in `extra` so the screen can
/// stand on its own: `extra` carries the strip already built from the loaded
/// feed when there is one, and without it the viewer fetches that single
/// message and shows it alone.
class ChatMediaRoute {
  const ChatMediaRoute(
    this.chatId, {
    required this.messageId,
    required this.attachmentId,
  });

  final String chatId;
  final String messageId;
  final String attachmentId;

  static const String path = 'media';
  static const String messageQueryParam = 'message';
  static const String attachmentQueryParam = 'attachment';

  String get location =>
      '/chats/$chatId/$path'
      '?$messageQueryParam=${Uri.encodeQueryComponent(messageId)}'
      '&$attachmentQueryParam=${Uri.encodeQueryComponent(attachmentId)}';

  static String? messageIdFrom(GoRouterState state) =>
      _nonEmpty(state.uri.queryParameters[messageQueryParam]);

  static String? attachmentIdFrom(GoRouterState state) =>
      _nonEmpty(state.uri.queryParameters[attachmentQueryParam]);
}

/// `/chats/{chatId}/attach` — what was picked, before it is sent.
///
/// The files themselves travel in `extra`; there is nothing to put in a URL
/// for a handful of paths on this device, and a link to someone else's
/// gallery would mean nothing. Reached with an empty `extra`, the screen has
/// nothing to show and closes.
abstract final class ChatAttachRoute {
  static const String path = 'attach';

  static String locationOf(String chatId) => '/chats/$chatId/$path';
}

String? _nonEmpty(String? value) =>
    value == null || value.isEmpty ? null : value;

abstract final class ProfileEditRoute {
  static const String path = 'edit';
  static const String location = '/profile/edit';
}

/// `/profile/avatar` — the signed-in user's own picture, full screen.
abstract final class ProfileAvatarRoute {
  static const String path = 'avatar';
  static const String location = '/profile/avatar';
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

/// `/profiles/{profileId}/avatar` — somebody else's picture, full screen.
abstract final class ProfileDetailAvatarRoute {
  static const String path = 'avatar';

  static String locationOf(int profileId) => '/profiles/$profileId/$path';
}

abstract final class SettingsRoute {
  static const String path = '/settings';
  static const String location = '/settings';
}

abstract final class SessionsRoute {
  static const String path = 'devices';
  static const String location = '/settings/devices';
}

abstract final class LanguageSettingsRoute {
  static const String path = 'language';
  static const String location = '/settings/language';
}

/// `/settings/notifications` — sound, quiet hours and the per-chat exceptions.
///
/// All of it local: api-docs §7 stores devices and a read flag, and nothing
/// about how a notification should behave, so there is no server screen this
/// mirrors.
abstract final class NotificationSettingsRoute {
  static const String path = 'notifications';
  static const String location = '/settings/notifications';
}

/// The design-system showcase. Debug-only, like the other demo surfaces.
abstract final class ComponentShowcaseRoute {
  static const String path = '/demo/design-system';
  static const String location = '/demo/design-system';
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
