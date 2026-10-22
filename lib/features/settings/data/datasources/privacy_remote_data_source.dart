import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpdart/fpdart.dart';

import 'package:chatix/core/error/failures.dart';
import 'package:chatix/core/network/api_client.dart';
import 'package:chatix/core/providers/network_providers.dart';
import 'package:chatix/features/settings/data/models/privacy_settings_model.dart';
import 'package:chatix/features/settings/domain/entities/privacy_settings.dart';

/// `GET` and `PUT /profiles/privacy/` (api-docs §4.14).
class PrivacyRemoteDataSource {
  PrivacyRemoteDataSource(this._apiClient);

  final ApiClient _apiClient;

  static const String path = '/profiles/privacy/';

  Future<Either<Failure, PrivacySettings>> fetch() async {
    final result = await _apiClient.get(path);
    return result.map(
      (data) => PrivacySettingsModel.fromJson(data as Map<String, dynamic>),
    );
  }

  Future<Either<Failure, PrivacySettings>> update({
    Map<PrivacyRule, PrivacyVisibility> rules = const {},
    Map<PrivacyRule, PrivacyExceptions> exceptions = const {},
  }) async {
    final result = await _apiClient.put(
      path,
      data: PrivacySettingsModel.updateJson(
        rules: rules,
        exceptions: exceptions,
      ),
    );
    return result.map(
      (data) => PrivacySettingsModel.fromJson(data as Map<String, dynamic>),
    );
  }
}

final privacyRemoteDataSourceProvider = Provider<PrivacyRemoteDataSource>(
  (ref) => PrivacyRemoteDataSource(ref.watch(apiClientProvider)),
);
