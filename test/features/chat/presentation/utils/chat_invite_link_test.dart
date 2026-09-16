import 'package:flutter_test/flutter_test.dart';

import 'package:chatix/features/chat/presentation/utils/chat_invite_link.dart';

/// The API mints no invite token of any kind (api-docs §5.2), so the link is
/// built here — from the origin the build talks to, and the chat's own id.
void main() {
  test('the link points at the app route, not at the API path', () {
    expect(
      ChatInviteLink.of('abc', baseUrl: 'https://api.example.com/api/v1'),
      'https://api.example.com/chats/abc',
    );
  });

  test('a trailing slash on the base URL does not double up', () {
    expect(
      ChatInviteLink.of('abc', baseUrl: 'https://api.example.com/'),
      'https://api.example.com/chats/abc',
    );
  });

  test('a port on the origin is kept', () {
    expect(
      ChatInviteLink.of('abc', baseUrl: 'http://localhost:8000'),
      'http://localhost:8000/chats/abc',
    );
  });

  test('a base URL that is not a URL is still used as written', () {
    expect(ChatInviteLink.of('abc', baseUrl: 'nonsense'), 'nonsense/chats/abc');
  });
}
