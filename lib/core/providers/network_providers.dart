import 'package:chatix/core/constants/app_constants.dart';
import 'package:chatix/core/network/api_client.dart';
import 'package:chatix/core/network/interceptors/auth_interceptor.dart';
import 'package:chatix/core/network/interceptors/retry_interceptor.dart';
import 'package:chatix/core/network/interceptors/trailing_slash_interceptor.dart';
import 'package:chatix/core/providers/storage_providers.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'network_providers.g.dart';

/// Initialized in [main] — [PersistCookieJar] needs an app documents path.
final cookieJarProvider = Provider<CookieJar>((ref) {
  throw UnimplementedError(
    'cookieJarProvider must be overridden in main() after PersistCookieJar init',
  );
});

@riverpod
Dio dio(Ref ref) {
  final cookieJar = ref.watch(cookieJarProvider);
  final secureStorage = ref.watch(secureStorageServiceProvider);

  final dio = Dio(
    BaseOptions(
      baseUrl: AppConstants.apiBaseUrl,
      connectTimeout: const Duration(milliseconds: AppConstants.connectTimeout),
      receiveTimeout: const Duration(milliseconds: AppConstants.receiveTimeout),
      headers: const {
        // Default JSON headers. POST /auth/login/ must override to
        // application/x-www-form-urlencoded in the auth feature (api-docs §3.3).
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ),
  );

  dio.interceptors.add(CookieManager(cookieJar));
  dio.interceptors.add(TrailingSlashInterceptor());
  dio.interceptors.add(AuthInterceptor(dio: dio, secureStorage: secureStorage));
  dio.interceptors.add(RetryInterceptor(dio: dio));

  if (kDebugMode) {
    dio.interceptors.add(
      LogInterceptor(
        request: true,
        requestHeader: true,
        requestBody: true,
        responseHeader: true,
        responseBody: true,
        error: true,
      ),
    );
  }

  return dio;
}

/// Thin wrapper around [Dio] that maps responses/errors into
/// `Either<Failure, dynamic>` per the api-docs §2 error envelope. Feature
/// datasources should depend on this instead of touching [Dio] directly.
final apiClientProvider = Provider<ApiClient>((ref) {
  final dio = ref.watch(dioProvider);
  return ApiClient(dio);
});
