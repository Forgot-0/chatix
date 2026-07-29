import 'package:fpdart/fpdart.dart';
import 'package:chatix/core/error/failures.dart';
import 'package:chatix/features/auth/domain/repositories/auth_repository.dart';

/// `GET /auth/oauth/{provider}/authorize/` (or `.../authorize/connect/`)
/// (api-docs §3.8). `provider` must be one of google|yandex|github — the
/// backend rejects anything else with `400 NOT_EXIST_PROVIDER_OAUTH`, we
/// just do a cheap client-side check to fail fast.
class GetOAuthUrlUseCase {
  static const supportedProviders = {'google', 'yandex', 'github'};

  final AuthRepository _repository;

  GetOAuthUrlUseCase(this._repository);

  Future<Either<Failure, String>> execute({
    required String provider,
    bool connect = false,
  }) {
    if (!supportedProviders.contains(provider)) {
      return Future.value(
        Left(InputFailure(message: 'Unsupported OAuth provider: $provider')),
      );
    }
    return _repository.getOAuthUrl(provider: provider, connect: connect);
  }
}
