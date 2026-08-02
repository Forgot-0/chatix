import 'package:chatix/core/error/failures.dart';

/// Turns a [Failure] (or any thrown object) into a sentence we are willing to
/// show a user.
///
/// ### Why a mapping at all — isn't `ApiFailure.message` enough?
///
/// `body.error.message` (api-docs §2.1) is written for whoever is reading the
/// logs: it is English, terse, sometimes leaks a field name ("User not found"
/// for a *chat* lookup by user id), and it is not a stable contract — the
/// backend may reword it at any time. `body.error.code`, on the other hand,
/// **is** the contract (api-docs §2.3–§2.8), and it is what the docs tell
/// clients to branch on.
///
/// So: when we recognise the code we phrase the failure ourselves; when we
/// don't, we fall back to the server's `message` rather than inventing a
/// vague "Something went wrong" that hides information the server bothered to
/// send. That ordering is the whole point — the map is an *improvement* layer,
/// never a filter.
///
/// ```dart
/// AppErrorState(error: asyncValue.error);          // widgets, or
/// friendlyFailureMessage(failure);                 // snackbars/dialogs
/// ```
///
/// ### Codes covered
///
/// Everything a user can realistically trip over while using the app is
/// listed below. Deliberately *not* covered: admin-only codes
/// (`DUPLICATE_ROLE`, `PROTECTED_PERMISSION`, …) and pure programmer errors
/// (`UNKNOWN_EXCEPTION`, `IDEMPOTENCY_CONFLICT`) — for those the server's own
/// message is as good as anything we would write, and pretending otherwise
/// just adds a translation layer nobody maintains.
String friendlyFailureMessage(Object? error, {String fallback = 'Something went wrong. Please try again.'}) {
  switch (error) {
    case null:
      return fallback;

    case ApiFailure(:final code, :final message):
      final friendly = friendlyMessageForCode(code);
      if (friendly != null) return friendly;
      // Unknown code: the server's own message beats a generic placeholder,
      // but an empty/whitespace one is worse than the fallback.
      return message.trim().isEmpty ? fallback : message;

    case RateLimitFailure():
      // api-docs §2.2: a 429 body is a bare `{"detail": "..."}`, so there is
      // no code to map and the raw detail ("Too Many Requests") is useless to
      // a user who doesn't know what a rate limit is.
      return 'Too many attempts. Please wait a minute and try again.';

    case NetworkFailure():
      return 'No internet connection. Check your network and try again.';

    case TimeoutFailure():
      return 'The server took too long to respond. Please try again.';

    case Failure(:final message):
      return message.trim().isEmpty ? fallback : message;

    default:
      // A non-Failure escapee (a bug in a repository that let a raw exception
      // through). Its `toString()` is developer text — don't show it.
      return fallback;
  }
}

/// The human phrasing for an api-docs error [code], or `null` when we have
/// nothing better to say than the server did.
///
/// Kept separate from [friendlyFailureMessage] so it can be unit-tested
/// against the api-docs catalogue directly, and so a caller that already has
/// a bare code string (e.g. a WebSocket `error` frame, api-docs §7.4) can use
/// it without constructing an [ApiFailure].
String? friendlyMessageForCode(String code) {
  final exact = _messages[code];
  if (exact != null) return exact;

  // Families. The catalogue has ~15 `NOT_FOUND_*` codes and every module has
  // its own `*_ACCESS_DENIED` — enumerating each one buys nothing over one
  // honest sentence per family, and a code added by a future backend release
  // still lands somewhere sensible instead of falling through.
  if (code.startsWith('NOT_FOUND_')) {
    return "We couldn't find that — it may have been deleted.";
  }
  if (code.endsWith('ACCESS_DENIED')) {
    return "You don't have permission to do that.";
  }
  if (code.startsWith('TOO_LONG_')) {
    return 'That value is too long. Please shorten it.';
  }
  if (code.endsWith('LIMIT_EXCEEDED')) {
    return 'A limit has been reached, so this action is not available.';
  }

  return null;
}

/// Exact code → sentence. Grouped by api-docs section for auditability.
const Map<String, String> _messages = {
  // ---- §2.3 core / auth infrastructure --------------------------------
  'NOT_AUTHENTICATED': 'Your session has ended. Please sign in again.',
  'EXPIRED_TOKEN': 'Your session has expired. Please sign in again.',
  'INVALID_TOKEN': 'Your session is no longer valid. Please sign in again.',
  'TOKEN_IN_BLACKLIST': 'This session was signed out. Please sign in again.',
  'NOT_FOUND_OR_INACTIVE_SESSION': 'Your session has ended. Please sign in again.',
  'ACCESS_DENIED': "You don't have permission to do that.",
  'VALIDATION': 'Some of the details are invalid. Please check and try again.',

  // ---- §2.4 auth ------------------------------------------------------
  'WRONG_LOGIN_DATA': 'Incorrect username or password.',
  'PASSWORD_MISMATCH': "The passwords don't match.",
  'DUPLICATE_USER': 'That username or email is already taken.',
  'EMAIL_NOT_CONFIRMED': 'Please confirm your email address before signing in.',
  'NOT_EXIST_PROVIDER_OAUTH': 'That sign-in provider is not supported.',
  'OAUTH_STATE_NOT_FOUND': 'The sign-in attempt expired. Please try again.',
  'LINKED_ANOTHER_USER_OAUTH': 'That account is already linked to another user.',

  // ---- §2.5 profiles --------------------------------------------------
  'ALREADE_EXIST_PROFILE': 'You already have a profile.',

  // ---- §2.6 projects --------------------------------------------------
  'ALREADY_MEMBER': 'That person is already a member of this project.',
  'MEMBER_LIMIT_EXCEEDED': 'This project has reached its member limit.',
  'MAX_PROJECTS_LIMIT_EXCEEDED': "You've reached the maximum number of projects.",
  'MAX_POSITIONS_PER_PROJECT_LIMIT_EXCEEDED':
      'This project has reached its maximum number of positions.',
  'NOT_PENDING_APPLICATION': 'This application has already been decided.',
  'NOT_VALID_MEMBER_STATUS': "This member's status doesn't allow that action.",

  // ---- §2.7 chats -----------------------------------------------------
  'NOT_CHAT_MEMBER': "You're not a member of this chat.",
  'ALREADY_CHAT_MEMBER': 'That person is already in this chat.',
  'DIRECT_CHAT_EXISTS': 'You already have a direct chat with this person.',
  'MESSAGE_TOO_LONG': 'That message is too long. Please shorten it.',
  'INVALID_MESSAGE': "That message can't be sent as written.",
  'SLOW_MODE_LIMIT': 'Slow mode is on — please wait before sending another message.',
  'ATTACHMENT_LIMIT_EXCEEDED': 'Too many attachments for one message.',
  'ATTACHMENT_NOT_FOUND': "That attachment isn't available any more.",
  'ATTACHMENT_VALIDATION': "That file can't be attached — check its type and size.",
  'EMPTY_ATTACHMENT_UPLOAD_REQUEST': 'Please choose a file to attach.',
  'INVALID_UPLOAD_TOKEN': 'The upload expired. Please attach the file again.',
  'AVATAR_NOT_TYPE_IMAGE': 'An avatar must be an image file.',
  'ACTIVE_CALL_EXISTS': 'There is already an active call in this chat.',
  'NO_ACTIVE_CALL': 'There is no active call in this chat.',
  'LIVEKIT_UNAUTHORIZED': "You can't join this call.",
  'LIVEKIT_ERROR': 'The call service is unavailable right now.',
};
