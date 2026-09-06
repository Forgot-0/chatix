import 'package:chatix/core/error/failures.dart';

String friendlyFailureMessage(Object? error, {String fallback = 'Something went wrong. Please try again.'}) {
  switch (error) {
    case null:
      return fallback;

    case ApiFailure(:final code, :final message):
      final friendly = friendlyMessageForCode(code);
      if (friendly != null) return friendly;
      return message.trim().isEmpty ? fallback : message;

    case RateLimitFailure():
      return 'Too many attempts. Please wait a minute and try again.';

    case NetworkFailure():
      return 'No internet connection. Check your network and try again.';

    case TimeoutFailure():
      return 'The server took too long to respond. Please try again.';

    case Failure(:final message):
      return message.trim().isEmpty ? fallback : message;

    default:
      return fallback;
  }
}

String? friendlyMessageForCode(String code) {
  final exact = _messages[code];
  if (exact != null) return exact;

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

const Map<String, String> _messages = {
  'NOT_AUTHENTICATED': 'Your session has ended. Please sign in again.',
  'EXPIRED_TOKEN': 'Your session has expired. Please sign in again.',
  'INVALID_TOKEN': 'Your session is no longer valid. Please sign in again.',
  'TOKEN_IN_BLACKLIST': 'This session was signed out. Please sign in again.',
  'NOT_FOUND_OR_INACTIVE_SESSION': 'Your session has ended. Please sign in again.',
  'ACCESS_DENIED': "You don't have permission to do that.",
  'VALIDATION': 'Some of the details are invalid. Please check and try again.',

  'WRONG_LOGIN_DATA': 'Incorrect username or password.',
  'PASSWORD_MISMATCH': "The passwords don't match.",
  'DUPLICATE_USER': 'That username or email is already taken.',
  'EMAIL_NOT_CONFIRMED': 'Please confirm your email address before signing in.',
  'NOT_EXIST_PROVIDER_OAUTH': 'That sign-in provider is not supported.',
  'OAUTH_STATE_NOT_FOUND': 'The sign-in attempt expired. Please try again.',
  'LINKED_ANOTHER_USER_OAUTH': 'That account is already linked to another user.',

  'ALREADE_EXIST_PROFILE': 'You already have a profile.',

  'NOT_CHAT_MEMBER': "You're not a member of this chat.",
  'ALREADY_CHAT_MEMBER': 'That person is already in this chat.',
  'INVALID_CHAT_ROLE': 'That is not a valid chat role.',
  'DIRECT_CHAT_EXISTS': 'You already have a direct chat with this person.',
  'MESSAGE_TOO_LONG': 'That message is too long. Please shorten it.',
  'INVALID_MESSAGE': "That message can't be sent as written.",
  'SLOW_MODE_LIMIT': 'Slow mode is on — please wait before sending another message.',
  'SLOW_MODE_OUT_OF_RANGE': 'Slow mode must be between 0 seconds and 24 hours.',
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

  'INVALID_REACTION': "That emoji can't be used as a reaction.",
  'REACTION_NOT_ALLOWED': "That reaction isn't allowed in this chat.",
  'REACTIONS_DISABLED': 'Reactions are turned off in this chat.',
  'TOO_MANY_REACTIONS': 'No more reactions can be added here.',

  'MAX_LIMIT_CURSOR': 'Too many chats were resumed at once.',
};
