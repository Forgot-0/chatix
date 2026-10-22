import 'package:fpdart/fpdart.dart';
import 'package:chatix/core/error/failures.dart';
import 'package:chatix/features/profile/domain/entities/profile_entity.dart';
import 'package:chatix/features/profile/domain/repositories/profile_repository.dart';

/// Finds a person by their `@handle` — what a profile link resolves through.
///
/// The server matches without regard to case and takes the handle with or
/// without its `@` in the account endpoints, but not in this path, so the
/// `@` and the surrounding space come off here (api-docs §3.17, §4.3).
class GetProfileByUsernameUseCase {
  final ProfileRepository _repository;

  GetProfileByUsernameUseCase(this._repository);

  /// [raw] without a leading `@` or the space around it; null when nothing
  /// is left.
  static String? normalize(String raw) {
    var value = raw.trim();
    if (value.startsWith('@')) value = value.substring(1).trim();
    return value.isEmpty ? null : value;
  }

  Future<Either<Failure, ProfileEntity>> execute(String username) {
    final handle = normalize(username);
    if (handle == null) {
      return Future.value(
        const Left(InputFailure(message: 'username cannot be empty')),
      );
    }
    return _repository.getProfileByUsername(handle);
  }
}
