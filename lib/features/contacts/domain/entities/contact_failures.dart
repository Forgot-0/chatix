import 'package:chatix/core/error/failures.dart';

/// Something the address book refused, with what the screen needs to say why.
///
/// Read from `body.error.code` and `body.error.detail` (api-docs §2.5) by
/// [contactFailureFrom]; anything that is not one of these stays the
/// [Failure] it was, and the generic wording covers it.
sealed class ContactFailure extends Failure {
  const ContactFailure({required super.message, super.statusCode});
}

/// `400 SELF_CONTACT_NOT_ALLOWED` — the owner tried to add themselves.
final class SelfContactFailure extends ContactFailure {
  const SelfContactFailure()
    : super(message: 'You cannot add yourself', statusCode: 400);
}

/// `409 CONTACT_BLOCKED` — the person is blocked and has to be unblocked
/// first.
final class ContactBlockedFailure extends ContactFailure {
  const ContactBlockedFailure({this.userId})
    : super(message: 'This user is blocked', statusCode: 409);

  final int? userId;

  @override
  List<Object?> get props => [...super.props, userId];
}

/// `409 CONTACT_LIMIT_EXCEEDED` — the book holds `MAX_CONTACTS_PER_USER`.
final class ContactLimitFailure extends ContactFailure {
  const ContactLimitFailure({this.limit = defaultLimit})
    : super(message: 'Contact limit reached', statusCode: 409);

  static const int defaultLimit = 5000;

  final int limit;

  @override
  List<Object?> get props => [...super.props, limit];
}

/// `404 NOT_FOUND_CONTACT_TARGET` — nobody with that id or username has a
/// profile (unverified accounts have none yet, api-docs §4.1).
final class ContactTargetNotFoundFailure extends ContactFailure {
  const ContactTargetNotFoundFailure({this.userId, this.username})
    : super(message: 'No such user', statusCode: 404);

  final int? userId;
  final String? username;

  @override
  List<Object?> get props => [...super.props, userId, username];
}

/// `404 NOT_FOUND_CONTACT` — not in the book (any more).
final class ContactNotFoundFailure extends ContactFailure {
  const ContactNotFoundFailure({this.contactId})
    : super(message: 'Not in your contacts', statusCode: 404);

  final int? contactId;

  @override
  List<Object?> get props => [...super.props, contactId];
}

/// `400 TOO_LONG_CONTACT_NAME` — a local name over 64 characters.
final class ContactNameTooLongFailure extends ContactFailure {
  const ContactNameTooLongFailure()
    : super(message: 'Name is too long', statusCode: 400);
}

/// `400 IMPORT_BATCH_TOO_LARGE` — more than 500 entries in one import.
final class ImportBatchTooLargeFailure extends ContactFailure {
  const ImportBatchTooLargeFailure({this.limit, this.current})
    : super(message: 'Import batch is too large', statusCode: 400);

  final int? limit;
  final int? current;

  @override
  List<Object?> get props => [...super.props, limit, current];
}

/// `429 IDENTIFIER_QUOTA_EXCEEDED` — today's quota of new addresses is used
/// up. Unlike the rate limiter's 429 it arrives in the error envelope.
final class IdentifierQuotaFailure extends ContactFailure {
  const IdentifierQuotaFailure({this.limit})
    : super(message: 'Daily import quota reached', statusCode: 429);

  final int? limit;

  @override
  List<Object?> get props => [...super.props, limit];
}

/// `409 IDEMPOTENCY_CONFLICT` — the same import is still being processed.
final class ImportInProgressFailure extends ContactFailure {
  const ImportInProgressFailure()
    : super(message: 'This import is already running', statusCode: 409);
}

/// `503 IDENTIFIER_PEPPER_NOT_CONFIGURED` — the server cannot hash addresses,
/// so import is off for everybody until it is fixed there.
final class ImportUnavailableFailure extends ContactFailure {
  const ImportUnavailableFailure()
    : super(message: 'Import is unavailable', statusCode: 503);
}

/// The contact-specific reading of [failure], or [failure] itself.
Failure contactFailureFrom(Failure failure) {
  if (failure is! ApiFailure) return failure;

  final detail = failure.detail is Map
      ? (failure.detail as Map).cast<Object?, Object?>()
      : const <Object?, Object?>{};

  return switch (failure.code) {
    'SELF_CONTACT_NOT_ALLOWED' => const SelfContactFailure(),
    'CONTACT_BLOCKED' => ContactBlockedFailure(userId: _int(detail['user_id'])),
    'CONTACT_LIMIT_EXCEEDED' => ContactLimitFailure(
      limit: _int(detail['limit']) ?? ContactLimitFailure.defaultLimit,
    ),
    'NOT_FOUND_CONTACT_TARGET' => ContactTargetNotFoundFailure(
      userId: _int(detail['user_id']),
      username: detail['username'] is String
          ? detail['username'] as String
          : null,
    ),
    'NOT_FOUND_CONTACT' => ContactNotFoundFailure(
      contactId: _int(detail['contact_id']),
    ),
    'TOO_LONG_CONTACT_NAME' => const ContactNameTooLongFailure(),
    'IMPORT_BATCH_TOO_LARGE' => ImportBatchTooLargeFailure(
      limit: _int(detail['limit']),
      current: _int(detail['current']),
    ),
    'IDENTIFIER_QUOTA_EXCEEDED' => IdentifierQuotaFailure(
      limit: _int(detail['limit']),
    ),
    'IDEMPOTENCY_CONFLICT' => const ImportInProgressFailure(),
    'IDENTIFIER_PEPPER_NOT_CONFIGURED' => const ImportUnavailableFailure(),
    _ => failure,
  };
}

int? _int(Object? value) {
  if (value is int) return value;
  if (value is num && value == value.roundToDouble()) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}
