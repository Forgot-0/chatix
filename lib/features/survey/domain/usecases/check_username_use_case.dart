import 'package:chatix/core/error/failures.dart';
import 'package:fpdart/fpdart.dart';
import 'package:chatix/features/survey/domain/repositories/survey_repository.dart';

class CheckUsernameUseCase {
  final SurveyRepository _repository;

  CheckUsernameUseCase(this._repository);

  Future<Either<Failure, bool>> call(String username) {
    return _repository.isUsernameAvailable(username);
  }
}
