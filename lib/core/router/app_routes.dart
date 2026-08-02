library;
import 'package:go_router/go_router.dart';

/// Every route in the app, as a typed object.
///
/// ### Why not raw strings
///
/// The app used to build locations with `'/chat/${chat.id}'` interpolations
/// scattered across screens and a parallel set of `AppConstants.*Route`
/// helpers. Two problems: a renamed path meant grepping for string fragments,
/// and — worse — an id of the wrong *type* was undetectable. Chat ids are
/// UUID strings, project and profile ids are ints, position ids are UUIDs
/// again (api-docs §1.8); `'/projects/${position.id}'` compiles perfectly and
/// fails at runtime with a 404 or, more insidiously, a request for the wrong
/// entity.
///
/// Each route below is a small class whose constructor takes exactly the ids
/// that route needs, with the right types, and exposes:
///
/// * [ChatDetailRoute.path] — the go_router pattern (`/chats/:chatId`), used
///   once, in the route table;
/// * `location` — the concrete URL to navigate to;
/// * `from(state)` — parsing the other way, so a route builder gets a typed
///   id instead of digging in `state.pathParameters` and `int.tryParse`-ing.
///
/// ### Why hand-written and not `go_router_builder`
///
/// go_router 17 ships an optional codegen package (`go_router_builder`) that
/// generates exactly this from `@TypedGoRoute` annotations. It is not a
/// dependency here, and adding a third code generator to a build that already
/// runs freezed + json_serializable + riverpod_generator — for ~10 routes —
/// costs more than it saves. These classes give the same call-site safety
/// (`ChatDetailRoute(chat.id).location`, wrong type = compile error) with no
/// build step and no generated files to keep in sync.
///
/// ### Naming
///
/// Paths are plural and hierarchical: `/chats/:chatId`,
/// `/projects/:projectId/positions/:positionId`, `/profiles/:profileId`. The
/// nesting is not cosmetic — a position only exists within a project
/// (api-docs §5.3, its endpoints are `/projects/{id}/positions/...`), so the
/// URL carries the project id and the position screen can offer "back to the
/// project" without a second round trip to discover which project it was.


/// Shared parameter names, so the pattern and the parser can never disagree
/// about spelling.
abstract final class RouteParams {
  static const String chatId = 'chatId';
  static const String projectId = 'projectId';
  static const String positionId = 'positionId';
  static const String profileId = 'profileId';
}

/// Route names, for `context.goNamed`. Kept as constants rather than string
/// literals at call sites for the same reason as the paths.
abstract final class RouteNames {
  static const String splash = 'splash';
  static const String login = 'login';
  static const String register = 'register';
  static const String verifyEmail = 'verifyEmail';
  static const String resetPasswordRequest = 'resetPasswordRequest';
  static const String resetPasswordConfirm = 'resetPasswordConfirm';
  static const String oauthCallback = 'oauthCallback';

  static const String chats = 'chats';
  static const String createChat = 'createChat';
  static const String chatDetail = 'chatDetail';
  static const String chatMembers = 'chatMembers';
  static const String chatCall = 'chatCall';

  static const String projects = 'projects';
  static const String myProjects = 'myProjects';
  static const String createProject = 'createProject';
  static const String myInvites = 'myInvites';
  static const String myApplications = 'myApplications';
  static const String projectDetail = 'projectDetail';
  static const String positionDetail = 'positionDetail';

  static const String notifications = 'notifications';

  static const String profile = 'profile';
  static const String profileEdit = 'profileEdit';
  static const String profiles = 'profiles';
  static const String profileDetail = 'profileDetail';

  static const String settings = 'settings';
  static const String languageSettings = 'languageSettings';
  static const String localizationAssetsDemo = 'localizationAssetsDemo';
}

// ---------------------------------------------------------------------------
// Auth (public)
// ---------------------------------------------------------------------------

/// `/` — decides where a cold start lands. Has no screen of its own; the
/// router's redirect resolves it once auth is known.
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

/// `/reset-password/confirm` — nested under [ResetPasswordRoute] in the route
/// table so the static `confirm` segment is matched before anything dynamic.
abstract final class ResetPasswordConfirmRoute {
  static const String path = 'confirm';
  static const String location = '/reset-password/confirm';
}

/// `/oauth-callback` — the landing spot for the provider redirect described
/// in api-docs §3.8, step 3.
///
/// ⚠️ **No screen is registered for this path yet.** The hand-back mechanism
/// (app link vs. in-app WebView intercepting `redirect_uri`) is still an open
/// question on the backend side — `OAuthButtons` documents this and
/// deliberately stops at "opened the system browser". The constant exists,
/// and the path is already listed as public in the router's redirect, so that
/// when the deep link is wired the callback is reachable **while signed out**
/// without anyone having to remember to whitelist it. Getting that wrong is
/// the classic OAuth bug: the redirect arrives, the guard sees no session
/// yet, and bounces the user to `/login`, discarding the very token that was
/// about to sign them in.
abstract final class OAuthCallbackRoute {
  static const String path = '/oauth-callback';
  static const String location = '/oauth-callback';
}

// ---------------------------------------------------------------------------
// Shell tab roots
// ---------------------------------------------------------------------------

abstract final class ChatsRoute {
  static const String path = '/chats';
  static const String location = '/chats';
}

abstract final class ProjectsRoute {
  static const String path = '/projects';
  static const String location = '/projects';
}

abstract final class NotificationsRoute {
  static const String path = '/notifications';
  static const String location = '/notifications';
}

/// `/profile` — the signed-in person's own profile (the fourth tab). Distinct
/// from [ProfileDetailRoute], which is "somebody else's profile, by id".
abstract final class ProfileRoute {
  static const String path = '/profile';
  static const String location = '/profile';
}

// ---------------------------------------------------------------------------
// Chats
// ---------------------------------------------------------------------------

/// `/chats/create` — nested under [ChatsRoute] so the static `create` segment
/// wins over `:chatId`. go_router prefers a static child to a dynamic sibling
/// **only** when they are children of the same parent; as flat top-level
/// routes they would be matched in declaration order instead, and a stray
/// reorder would silently turn "create" into a chat id.
abstract final class CreateChatRoute {
  static const String path = 'create';
  static const String location = '/chats/create';
}

/// `/chats/{chatId}` — one conversation. Chat ids are UUID **strings**
/// (api-docs §1.8), never ints.
class ChatDetailRoute {
  const ChatDetailRoute(this.chatId);

  final String chatId;

  static const String path = ':chatId';
  String get location => '/chats/$chatId';

  /// The chat id carried by [state], or `null` if the segment is missing or
  /// empty. Empty is worth catching: it would produce a request to
  /// `/chats//` that 404s with no explanation.
  static String? idFrom(GoRouterState state) {
    final raw = state.pathParameters[RouteParams.chatId];
    if (raw == null || raw.isEmpty) return null;
    return raw;
  }
}

abstract final class ChatMembersRoute {
  static const String path = 'members';
  static String locationOf(String chatId) => '/chats/$chatId/members';
}

/// `/chats/{chatId}/call` — the LiveKit room (api-docs §6.6). A route rather
/// than a dialog so the OS back gesture leaves the call and the room is
/// disposed in exactly one place.
abstract final class ChatCallRoute {
  static const String path = 'call';
  static String locationOf(String chatId) => '/chats/$chatId/call';
}

// ---------------------------------------------------------------------------
// Projects & positions
// ---------------------------------------------------------------------------

abstract final class MyProjectsRoute {
  static const String path = 'my';
  static const String location = '/projects/my';
}

abstract final class CreateProjectRoute {
  static const String path = 'create';
  static const String location = '/projects/create';
}

abstract final class MyInvitesRoute {
  static const String path = 'invites';
  static const String location = '/projects/invites';
}

/// `/applications/my` — the current candidate's own applications
/// (api-docs §5.4). Top-level rather than under `/projects` because it spans
/// every project the user has applied to, not one of them.
abstract final class MyApplicationsRoute {
  static const String path = '/applications/my';
  static const String location = '/applications/my';
}

/// `/projects/{projectId}` — project ids are **ints** (api-docs §1.8).
class ProjectDetailRoute {
  const ProjectDetailRoute(this.projectId);

  final int projectId;

  static const String path = ':projectId';
  String get location => '/projects/$projectId';

  /// The project id carried by [state], or `null` when the segment is absent
  /// or not an integer (a hand-typed or stale deep link).
  static int? idFrom(GoRouterState state) =>
      int.tryParse(state.pathParameters[RouteParams.projectId] ?? '');
}

/// `/projects/{projectId}/positions/{positionId}` — a vacancy inside a
/// project. Position ids are UUID strings, project ids are ints; the
/// constructor makes mixing them up a compile error.
///
/// The project id is part of the path even though `GET /positions/{id}/`
/// doesn't need it: it lets the screen render "part of «Project X»" and offer
/// a way back up without first fetching the position to discover its parent,
/// and it makes the URL self-describing when it arrives from a notification
/// payload.
class PositionDetailRoute {
  const PositionDetailRoute({required this.projectId, required this.positionId});

  final int projectId;
  final String positionId;

  static const String path = 'positions/:positionId';
  String get location => '/projects/$projectId/positions/$positionId';

  static PositionDetailRoute? from(GoRouterState state) {
    final projectId = int.tryParse(
      state.pathParameters[RouteParams.projectId] ?? '',
    );
    final positionId = state.pathParameters[RouteParams.positionId];
    if (projectId == null || positionId == null || positionId.isEmpty) {
      return null;
    }
    return PositionDetailRoute(projectId: projectId, positionId: positionId);
  }
}

// ---------------------------------------------------------------------------
// Profiles
// ---------------------------------------------------------------------------

/// `/profile/edit` — editing one's own profile. Nested under [ProfileRoute],
/// which has no `:id` child, so there is no static-vs-dynamic ambiguity here
/// at all: other people's profiles live under the separate `/profiles/`
/// collection below.
abstract final class ProfileEditRoute {
  static const String path = 'edit';
  static const String location = '/profile/edit';
}

/// `/profiles` — browse/search all profiles (api-docs §4.2).
abstract final class ProfilesRoute {
  static const String path = '/profiles';
  static const String location = '/profiles';
}

/// `/profiles/{profileId}` — somebody else's profile. Profile ids are ints
/// and equal the user id (api-docs §4.1).
class ProfileDetailRoute {
  const ProfileDetailRoute(this.profileId);

  final int profileId;

  static const String path = ':profileId';
  String get location => '/profiles/$profileId';

  static int? idFrom(GoRouterState state) =>
      int.tryParse(state.pathParameters[RouteParams.profileId] ?? '');
}

// ---------------------------------------------------------------------------
// Settings & misc
// ---------------------------------------------------------------------------

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

// ---------------------------------------------------------------------------
// Access policy
// ---------------------------------------------------------------------------

/// Locations reachable **without** a session.
///
/// Email verification and password reset are here even though a signed-in
/// user can also reach them: someone who is logged in on an unverified
/// account still has to verify it, and "change my forgotten password" is a
/// perfectly normal thing to do from inside the app.
///
/// Matching is by prefix so query strings and sub-paths come along
/// (`/reset-password/confirm?token=…`, an eventual
/// `/oauth-callback?code=…`). Prefix matching is safe here only because every
/// entry is a complete first segment — `/login` cannot accidentally match
/// `/loginsomething` because the check requires either an exact match or a
/// following `/` or `?`.
const Set<String> publicRoutePrefixes = {
  LoginRoute.path,
  RegisterRoute.path,
  VerifyEmailRoute.path,
  ResetPasswordRoute.path,
  OAuthCallbackRoute.path,
};

/// Whether [location] (a path, optionally with a query string) may be visited
/// while signed out.
bool isPublicLocation(String location) {
  final path = location.split('?').first;
  for (final prefix in publicRoutePrefixes) {
    if (path == prefix) return true;
    if (path.startsWith('$prefix/')) return true;
  }
  return false;
}
