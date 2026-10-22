import 'package:fpdart/fpdart.dart';

import 'package:chatix/core/error/failures.dart';
import 'package:chatix/features/settings/domain/entities/privacy_settings.dart';
import 'package:chatix/features/settings/domain/repositories/privacy_repository.dart';

/// Changes part of the privacy settings, refusing what the server would.
///
/// An empty change is a `422` there (api-docs §4.14), and a rule with more
/// than [PrivacyExceptions.limit] people across its two lists is a `400
/// PRIVACY_EXCEPTIONS_LIMIT` — both are cheaper to stop here, before a
/// request.
class UpdatePrivacySettingsUseCase {
  UpdatePrivacySettingsUseCase(this._repository);

  final PrivacyRepository _repository;

  Future<Either<Failure, PrivacySettings>> execute({
    Map<PrivacyRule, PrivacyVisibility> rules = const {},
    Map<PrivacyRule, PrivacyExceptions> exceptions = const {},
  }) {
    if (rules.isEmpty && exceptions.isEmpty) {
      return Future.value(
        const Left(InputFailure(message: 'nothing to change')),
      );
    }
    for (final lists in exceptions.values) {
      if (lists.total > PrivacyExceptions.limit) {
        return Future.value(
          const Left(InputFailure(message: 'too many exceptions for a rule')),
        );
      }
    }
    return _repository.update(rules: rules, exceptions: exceptions);
  }
}
