import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chatix/core/network/api_client.dart';
import 'package:chatix/features/auth/data/datasources/auth_remote_data_source.dart';

/// Captures what actually went on the wire, body included.
class _CapturingAdapter implements HttpClientAdapter {
  _CapturingAdapter(this.response);

  final ResponseBody Function(RequestOptions options) response;

  RequestOptions? lastRequest;
  String? lastBody;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastRequest = options;

    if (requestStream != null) {
      final chunks = await requestStream.toList();
      lastBody = utf8.decode(chunks.expand((chunk) => chunk).toList());
    }

    return response(options);
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  late _CapturingAdapter adapter;
  late AuthRemoteDataSource dataSource;

  setUp(() {
    adapter = _CapturingAdapter(
      (options) => ResponseBody.fromString(
        jsonEncode({'access_token': 'token-value'}),
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      ),
    );

    final dio = Dio(BaseOptions(baseUrl: 'https://api.example.com/api/v1'))
      ..httpClientAdapter = adapter;

    dataSource = AuthRemoteDataSourceImpl(ApiClient(dio));
  });

  group('POST /auth/login/ (api-docs §0.4, §3.3)', () {
    test('is sent form-urlencoded, not as JSON', () async {
      await dataSource.login(username: 'ada', password: 'Str0ng!pass');

      expect(
        adapter.lastRequest!.headers[Headers.contentTypeHeader].toString(),
        contains(Headers.formUrlEncodedContentType),
      );
      expect(
        adapter.lastRequest!.headers[Headers.contentTypeHeader].toString(),
        isNot(contains('application/json')),
      );
    });

    test('names the fields username and password, never email', () async {
      await dataSource.login(username: 'ada@example.com', password: 'p@ssW0rd');

      final sent = Uri.splitQueryString(adapter.lastBody!);
      expect(sent, {
        'username': 'ada@example.com',
        'password': 'p@ssW0rd',
      });
      expect(sent.containsKey('email'), isFalse);
    });

    test('keeps the trailing slash — without it the server answers 404', () async {
      await dataSource.login(username: 'ada', password: 'x');

      expect(adapter.lastRequest!.path, '/auth/login/');
    });

    test('reads the access token out of the response', () async {
      final result = await dataSource.login(username: 'ada', password: 'x');

      expect(result.getRight().toNullable(), 'token-value');
    });
  });
}
