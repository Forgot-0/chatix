import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chatix/core/constants/app_constants.dart';

/// `BASE_URL` comes from `.env` as somebody typed it — with or without the
/// slash at the end — and every request, the socket and the share links
/// are built on top of it, so the slash must not double up anywhere.
void main() {
  test('a trailing slash on BASE_URL is dropped once', () {
    dotenv.testLoad(fileInput: 'BASE_URL=https://api.forgot01.store/');

    expect(AppConstants.serverBaseUrl, 'https://api.forgot01.store');
    expect(AppConstants.apiBaseUrl, 'https://api.forgot01.store/api/v1');
    expect(
      Uri.parse('${AppConstants.apiBaseUrl}/chats/ws/').path,
      '/api/v1/chats/ws/',
    );
  });

  test('a BASE_URL without one is taken as written', () {
    dotenv.testLoad(fileInput: 'BASE_URL=https://api.forgot01.store');

    expect(AppConstants.apiBaseUrl, 'https://api.forgot01.store/api/v1');
  });

  test('blank space around it does not end up in the address', () {
    dotenv.testLoad(fileInput: 'BASE_URL=  https://api.forgot01.store/  ');

    expect(AppConstants.serverBaseUrl, 'https://api.forgot01.store');
  });
}
