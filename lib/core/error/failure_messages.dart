import 'package:chatix/core/error/failures.dart';
import 'package:chatix/gen/l10n/app_localizations.dart';

/// Turns a [Failure] into something worth showing a reader, in their language.
///
/// The table below is keyed by `body.error.code` (api-docs §0) rather than by
/// the message the server sent, because that message is English prose meant
/// for a log. A code nobody has mapped yet falls through to [fallback] — the
/// screen's own wording for "this did not load" — and only then to the
/// server's text, which is better than nothing but never shown in preference
/// to a real sentence.
String friendlyFailureMessage(
  Object? error, {
  required AppLocalizations l10n,
  String? fallback,
}) {
  final generic = fallback ?? l10n.failureGeneric;

  switch (error) {
    case null:
      return generic;

    case ApiFailure(:final code, :final message):
      final friendly = friendlyMessageForCode(code, l10n);
      if (friendly != null) return friendly;
      return message.trim().isEmpty ? generic : message;

    // 429 carries `body.detail`, not `body.error.code`, so there is never a
    // code to look up — the sentence is the same whatever was rate-limited.
    case RateLimitFailure():
      return l10n.failureRateLimited;

    case NetworkFailure():
      return l10n.failureNoConnection;

    case TimeoutFailure():
      return l10n.failureTimeout;

    // Every other Failure carries a diagnostic, not copy. `Chat id is
    // required` and `Unknown error occurred` are written for a log, in
    // English, and showing one is how English reaches a reader who asked
    // for Russian. A failure whose wording actually matters to somebody —
    // `FolderLimitFailure`, the auth ones — is matched on its type by the
    // screen that raises it, before it ever gets here.
    case Failure():
      return generic;

    default:
      return generic;
  }
}

/// The sentence for one `error.code`, or null where the code is unknown.
///
/// The four shape rules at the end are what keeps a code the backend adds
/// tomorrow from surfacing as raw SCREAMING_SNAKE: families are named
/// consistently (api-docs §0), so `NOT_FOUND_WIDGET` reads correctly without
/// anyone editing this file.
String? friendlyMessageForCode(String code, AppLocalizations l10n) {
  final exact = _exactMessage(code, l10n);
  if (exact != null) return exact;

  if (code.startsWith('NOT_FOUND_')) return l10n.apiErrorNotFoundGeneric;
  if (code.endsWith('ACCESS_DENIED')) return l10n.apiErrorAccessDenied;
  if (code.startsWith('TOO_LONG_')) return l10n.apiErrorTooLongGeneric;
  if (code.endsWith('LIMIT_EXCEEDED')) return l10n.apiErrorLimitExceededGeneric;

  return null;
}

String? _exactMessage(String code, AppLocalizations l10n) => switch (code) {
  'NOT_AUTHENTICATED' => l10n.apiErrorSessionEnded,
  'NOT_FOUND_OR_INACTIVE_SESSION' => l10n.apiErrorSessionEnded,
  'EXPIRED_TOKEN' => l10n.apiErrorSessionExpired,
  'INVALID_TOKEN' => l10n.apiErrorSessionInvalid,
  'TOKEN_IN_BLACKLIST' => l10n.apiErrorSessionSignedOut,
  'ACCESS_DENIED' => l10n.apiErrorAccessDenied,
  'VALIDATION' => l10n.apiErrorValidation,

  'WRONG_LOGIN_DATA' => l10n.apiErrorWrongLoginData,
  'PASSWORD_MISMATCH' => l10n.apiErrorPasswordMismatch,
  'DUPLICATE_USER' => l10n.apiErrorDuplicateUser,
  'EMAIL_NOT_CONFIRMED' => l10n.apiErrorEmailNotConfirmed,
  'NOT_EXIST_PROVIDER_OAUTH' => l10n.apiErrorOauthProviderUnsupported,
  'OAUTH_STATE_NOT_FOUND' => l10n.apiErrorOauthStateNotFound,
  'LINKED_ANOTHER_USER_OAUTH' => l10n.apiErrorOauthLinkedAnotherUser,

  // The server's spelling, not ours (api-docs §4.1).
  'ALREADE_EXIST_PROFILE' => l10n.apiErrorProfileExists,

  'NOT_CHAT_MEMBER' => l10n.apiErrorNotChatMember,
  'ALREADY_CHAT_MEMBER' => l10n.apiErrorAlreadyChatMember,
  'INVALID_CHAT_ROLE' => l10n.apiErrorInvalidChatRole,
  'DIRECT_CHAT_EXISTS' => l10n.apiErrorDirectChatExists,
  'MESSAGE_TOO_LONG' => l10n.apiErrorMessageTooLong,
  'INVALID_MESSAGE' => l10n.apiErrorInvalidMessage,
  'SLOW_MODE_LIMIT' => l10n.apiErrorSlowModeLimit,
  'SLOW_MODE_OUT_OF_RANGE' => l10n.apiErrorSlowModeOutOfRange,
  'ATTACHMENT_LIMIT_EXCEEDED' => l10n.apiErrorAttachmentLimitExceeded,
  'ATTACHMENT_NOT_FOUND' => l10n.apiErrorAttachmentNotFound,
  'ATTACHMENT_VALIDATION' => l10n.apiErrorAttachmentValidation,
  'EMPTY_ATTACHMENT_UPLOAD_REQUEST' => l10n.apiErrorEmptyAttachmentUpload,
  'INVALID_UPLOAD_TOKEN' => l10n.apiErrorInvalidUploadToken,
  'AVATAR_NOT_TYPE_IMAGE' => l10n.apiErrorAvatarNotImage,
  'ACTIVE_CALL_EXISTS' => l10n.apiErrorActiveCallExists,
  'NO_ACTIVE_CALL' => l10n.apiErrorNoActiveCall,
  'LIVEKIT_UNAUTHORIZED' => l10n.apiErrorLivekitUnauthorized,
  'LIVEKIT_ERROR' => l10n.apiErrorLivekitError,

  'INVALID_REACTION' => l10n.apiErrorInvalidReaction,
  'REACTION_NOT_ALLOWED' => l10n.apiErrorReactionNotAllowed,
  'REACTIONS_DISABLED' => l10n.apiErrorReactionsDisabled,
  'TOO_MANY_REACTIONS' => l10n.apiErrorTooManyReactions,

  'MAX_LIMIT_CURSOR' => l10n.apiErrorMaxLimitCursor,

  _ => null,
};
