import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpdart/fpdart.dart';

import 'package:chatix/core/error/failures.dart';
import 'package:chatix/features/settings/data/datasources/privacy_remote_data_source.dart';
import 'package:chatix/features/settings/domain/entities/privacy_settings.dart';
import 'package:chatix/features/settings/domain/repositories/privacy_repository.dart';

class PrivacyRepositoryImpl implements PrivacyRepository {
  PrivacyRepositoryImpl(this._remote);

  final PrivacyRemoteDataSource _remote;

  @override
  Future<Either<Failure, PrivacySettings>> get() => _remote.fetch();

  @override
  Future<Either<Failure, PrivacySettings>> update({
    Map<PrivacyRule, PrivacyVisibility> rules = const {},
    Map<PrivacyRule, PrivacyExceptions> exceptions = const {},
  }) => _remote.update(rules: rules, exceptions: exceptions);
}

final privacyRepositoryProvider = Provider<PrivacyRepository>(
  (ref) => PrivacyRepositoryImpl(ref.watch(privacyRemoteDataSourceProvider)),
);
