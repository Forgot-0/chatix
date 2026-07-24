import 'package:dio/dio.dart';

import '../api_path.dart';

/// Normalizes relative paths before they leave the client.
class TrailingSlashInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (options.extra['skipTrailingSlash'] == true) {
      handler.next(options);
      return;
    }

    options.path = buildPath(options.path);
    handler.next(options);
  }
}
