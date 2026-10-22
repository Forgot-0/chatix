import 'package:fpdart/fpdart.dart';

import 'package:chatix/core/error/failures.dart';
import 'package:chatix/features/settings/domain/entities/privacy_settings.dart';

/// The signed-in person's own privacy settings (api-docs §4.14). There is
/// no id anywhere: the server takes it from the token, and nobody else's
/// can be read or changed.
abstract interface class PrivacyRepository {
  Future<Either<Failure, PrivacySettings>> get();

  /// Changes only what is passed: a rule's value, and a rule's lists, each
  /// of which replaces that rule's lists whole. Answers with everything as
  /// it now stands.
  Future<Either<Failure, PrivacySettings>> update({
    Map<PrivacyRule, PrivacyVisibility> rules = const {},
    Map<PrivacyRule, PrivacyExceptions> exceptions = const {},
  });
}
