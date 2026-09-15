import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chatix/features/auth/domain/entities/user_entity.dart';
import 'package:chatix/features/auth/presentation/providers/auth_provider.dart';
import 'package:chatix/features/chat/data/datasources/chat_local_data_source.dart';
import 'package:chatix/features/chat/data/datasources/chat_local_store.dart';
import 'package:chatix/features/chat/presentation/providers/chat_cache_lifecycle_provider.dart';

class FakeAuthController extends AuthController {
  FakeAuthController(this._user);

  final UserEntity? _user;

  @override
  Future<UserEntity?> build() async => _user;

  void signOut() => state = const AsyncValue.data(null);
}

/// The store holds one account's chats, drafts and — the one that would be a
/// real bug — its outbox. None of it may outlive the session it belongs to.
void main() {
  const me = UserEntity(id: 7, username: 'me', email: 'me@example.com');

  late ChatLocalStore store;

  setUp(() async {
    store = inMemoryChatLocalStore();
    await store.writeDrafts({'c1': 'half-written'});
    await store.writeOutboxEntry({
      'id': 'e1',
      'chat_id': 'c1',
      'created_at': '2026-01-01T00:00:00Z',
    });
  });

  test('signing out clears the device copy', () async {
    late FakeAuthController auth;

    final container = ProviderContainer(
      overrides: [
        chatLocalDataSourceProvider.overrideWithValue(store),
        authProvider.overrideWith(() => auth = FakeAuthController(me)),
      ],
    );
    addTearDown(container.dispose);

    await container.read(authProvider.future);
    container.read(chatCacheLifecycleProvider);

    auth.signOut();
    await Future<void>.delayed(Duration.zero);

    expect(store.readDrafts(), isEmpty);
    expect(store.readOutbox(), isEmpty);
  });

  test('a cold start with nobody signed in keeps the cache', () async {
    // The launch that has not resolved auth yet is the launch the cache
    // exists for; clearing it here would empty it on every start.
    final container = ProviderContainer(
      overrides: [
        chatLocalDataSourceProvider.overrideWithValue(store),
        authProvider.overrideWith(() => FakeAuthController(null)),
      ],
    );
    addTearDown(container.dispose);

    container.read(chatCacheLifecycleProvider);
    await container.read(authProvider.future);
    await Future<void>.delayed(Duration.zero);

    expect(store.readDrafts(), isNotEmpty);
  });
}
