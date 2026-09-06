import 'package:fpdart/fpdart.dart';
import 'package:chatix/core/error/failures.dart';
import 'package:chatix/features/auth/domain/repositories/auth_repository.dart';

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
