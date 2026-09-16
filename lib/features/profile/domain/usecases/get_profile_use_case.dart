import 'package:fpdart/fpdart.dart';
import 'package:chatix/core/error/failures.dart';
import 'package:chatix/features/profile/domain/entities/profile_entity.dart';
import 'package:chatix/features/profile/domain/repositories/profile_repository.dart';

/// Reads one profile, tolerating the window where it does not exist yet.
///
/// A profile row is written by the `profiles` consumer reacting to
/// `auth.user.verified`, and that travels outbox → Debezium → Kafka. For a
/// few seconds after somebody confirms their email, `GET /profiles/{id}/`
/// answers `404 NOT_FOUND_PROFILE` for an account that is perfectly real
/// (api-docs §0.8, §4.1). Showing "we couldn't find that" there is wrong, so
/// a missing profile is retried a handful of times before it is believed.
///
/// Only `NOT_FOUND_PROFILE` is retried: every other failure — no network, a
/// dead token, a rate limit — is answered at once, and the retry budget is
/// small enough that a genuinely absent profile still resolves quickly.
///
/// For the caller's *own* profile there is a better answer than waiting:
/// `GET /profiles/my/` creates the row on the spot, which is what
/// `EnsureMyProfileUseCase` does.
class GetProfileUseCase {
  /// Tries in total, the first one included.
  static const int maxAttempts = 4;

  /// Between tries. Four attempts one second apart cover roughly the delay
  /// the pipeline actually takes.
  static const Duration retryDelay = Duration(seconds: 1);

  static const String _missingProfileCode = 'NOT_FOUND_PROFILE';

  final ProfileRepository _repository;

  GetProfileUseCase(this._repository);

  Future<Either<Failure, ProfileEntity>> execute(
    int profileId, {
    /// Overridable so a caller that must answer now (and tests) can opt out
    /// of the wait.
    int attempts = maxAttempts,
    Duration delay = retryDelay,
  }) async {
    if (profileId <= 0) {
      return const Left(
        InputFailure(message: 'profileId must be a positive number'),
      );
    }

    final budget = attempts < 1 ? 1 : attempts;

    for (var attempt = 1; ; attempt++) {
      final result = await _repository.getProfile(profileId);

      if (result.isRight() || attempt >= budget) return result;

      final failure = result.getLeft().toNullable();
      if (!_isMissingProfile(failure)) return result;

      await Future<void>.delayed(delay);
    }
  }

  bool _isMissingProfile(Failure? failure) {
    return failure is ApiFailure && failure.code == _missingProfileCode;
  }
}
