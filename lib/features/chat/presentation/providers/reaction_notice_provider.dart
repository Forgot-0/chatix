import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:chatix/core/error/failures.dart';

/// Why a reaction came back off the message after it had already appeared.
///
/// The reasons are the ones §5.7.4 can answer with, collapsed to what a
/// one-line toast can usefully say. Anything else is [failed] — the reader
/// cannot act on a 500 any differently than on a dropped connection.
enum ReactionNoticeReason {
  /// `REACTIONS_DISABLED` — the chat turned reactions off under us.
  disabled,

  /// `REACTION_NOT_ALLOWED` or `INVALID_REACTION`.
  notAllowed,

  /// `TOO_MANY_REACTIONS` with `scope: "user"` — three of ours already.
  tooManyForUser,

  /// `TOO_MANY_REACTIONS` with `scope: "message"` — twenty distinct emoji.
  tooManyForMessage,

  /// 429 on `.../reactions/` — 10 per second (§5.7.1).
  tooFast,

  failed,
}

/// One rollback, waiting to be shown.
///
/// [sequence] only exists so two identical failures in a row still read as
/// two events: the screen listens for changes, and a repeated reason with no
/// sequence would look like nothing happened.
class ReactionNotice extends Equatable {
  const ReactionNotice({required this.reason, required this.sequence});

  final ReactionNoticeReason reason;
  final int sequence;

  @override
  List<Object?> get props => [reason, sequence];
}

/// The channel between an optimistic reaction that was taken back and the
/// screen that has to mention it.
///
/// The provider layer has no `BuildContext` and the toast has to be
/// localised, so what travels is the reason, not a sentence.
class ReactionNoticeController extends Notifier<ReactionNotice?> {
  int _sequence = 0;

  @override
  ReactionNotice? build() => null;

  void report(Failure failure) => _emit(reasonOf(failure));

  void _emit(ReactionNoticeReason reason) {
    _sequence += 1;
    state = ReactionNotice(reason: reason, sequence: _sequence);
  }

  /// Maps a failure onto what the reader is told.
  ///
  /// Error codes are read off `ApiFailure.code`, which the envelope already
  /// pulled from `body.error.code` — except for 429, which the API answers
  /// with a bare `detail` (api-docs §2.2) and the client surfaces as
  /// [RateLimitFailure].
  static ReactionNoticeReason reasonOf(Failure failure) {
    if (failure is RateLimitFailure) return ReactionNoticeReason.tooFast;

    if (failure is ApiFailure) {
      return switch (failure.code) {
        'REACTIONS_DISABLED' => ReactionNoticeReason.disabled,
        'REACTION_NOT_ALLOWED' ||
        'INVALID_REACTION' => ReactionNoticeReason.notAllowed,
        'TOO_MANY_REACTIONS' => _scopeOf(failure.detail),
        _ => ReactionNoticeReason.failed,
      };
    }

    return ReactionNoticeReason.failed;
  }

  /// `TOO_MANY_REACTIONS` carries `{ limit, scope }`; which cap was hit
  /// decides which sentence is true.
  static ReactionNoticeReason _scopeOf(Object? detail) {
    final scope = detail is Map ? detail['scope'] : null;
    return scope == 'message'
        ? ReactionNoticeReason.tooManyForMessage
        : ReactionNoticeReason.tooManyForUser;
  }
}

final reactionNoticeProvider =
    NotifierProvider<ReactionNoticeController, ReactionNotice?>(
      ReactionNoticeController.new,
    );
