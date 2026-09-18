import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:chatix/core/auth/app_lock_providers.dart';
import 'package:chatix/core/auth/app_lock_store.dart';
import 'package:chatix/core/providers/storage_providers.dart';
import 'package:chatix/core/storage/cache/attachment_file_cache.dart';
import 'package:chatix/core/websocket/chat_socket_service.dart';
import 'package:chatix/features/auth/presentation/providers/session_cleanup_provider.dart';
import 'package:chatix/features/chat/data/datasources/chat_local_data_source.dart';
import 'package:chatix/features/chat/data/datasources/chat_local_prefs_store.dart';
import 'package:chatix/features/chat/data/datasources/search_history_store.dart';
import 'package:chatix/features/chat/data/datasources/voice_local_store.dart';
import 'package:chatix/features/chat/domain/entities/voice_waveform.dart';
import 'package:chatix/features/chat/presentation/providers/chat_local_prefs_provider.dart';
import 'package:chatix/features/chat/presentation/providers/chat_socket_provider.dart';
import 'package:chatix/features/chat/presentation/providers/search_providers.dart';
import 'package:chatix/features/chat/presentation/providers/voice_playback_provider.dart';
import 'package:chatix/features/chat_organizer/data/datasources/chat_organizer_local_data_source.dart';
import 'package:chatix/features/chat_organizer/data/models/chat_folder_model.dart';
import 'package:chatix/features/chat_organizer/presentation/providers/chat_organizer_providers.dart';

import '../../../../helpers/fakes/fake_secure_storage_service.dart';

class _MockSocket extends Mock implements ChatSocketService {}

class _MockChatCache extends Mock implements ChatLocalDataSource {}

class _MockAttachmentCache extends Mock implements AttachmentFileCache {}

/// Signing out has to leave nothing of the account on the device.
///
/// `POST /auth/logout/` only ends the refresh session on the server
/// (api-docs §3.5) — the token, the cached messages, the drafts and the
/// downloaded files are all still here afterwards, and this is what removes
/// them.
void main() {
  late FakeSecureStorageService secureStorage;
  late _MockSocket socket;
  late _MockChatCache chatCache;
  late _MockAttachmentCache attachments;
  late InMemoryVoiceLocalStore voice;
  late InMemoryChatLocalPrefsStore chatPrefs;
  late InMemorySearchHistoryStore searchHistory;
  late InMemoryChatOrganizerDataSource organizer;
  late InMemoryAppLockStore appLock;

  ProviderContainer makeContainer() {
    final container = ProviderContainer(
      overrides: [
        secureStorageServiceProvider.overrideWithValue(secureStorage),
        chatSocketServiceProvider.overrideWithValue(socket),
        chatLocalDataSourceProvider.overrideWithValue(chatCache),
        attachmentFileCacheProvider.overrideWithValue(attachments),
        voiceLocalStoreProvider.overrideWithValue(voice),
        chatLocalPrefsStoreProvider.overrideWithValue(chatPrefs),
        searchHistoryStoreProvider.overrideWithValue(searchHistory),
        chatOrganizerDataSourceProvider.overrideWithValue(organizer),
        appLockStoreProvider.overrideWithValue(appLock),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  setUp(() async {
    secureStorage = FakeSecureStorageService(
      initialValues: {'access_token': 'token', 'something_else': 'x'},
    );

    socket = _MockSocket();
    when(socket.disconnect).thenAnswer((_) async {});

    chatCache = _MockChatCache();
    when(chatCache.clear).thenAnswer((_) async {});

    attachments = _MockAttachmentCache();
    when(attachments.clear).thenAnswer((_) async {});

    voice = InMemoryVoiceLocalStore();
    await voice.writeWaveform('a1', const VoiceWaveform([1, 2, 3]));
    await voice.markListened('a1');

    chatPrefs = InMemoryChatLocalPrefsStore();
    await chatPrefs.writeDrafts({'c1': 'half a sentence'});
    await chatPrefs.writeRecentReactions(['👍']);

    searchHistory = InMemorySearchHistoryStore(
      queries: ['invoice'],
      chatIds: ['c1'],
    );

    organizer = InMemoryChatOrganizerDataSource(
      folders: [const ChatFolderModel(id: 'f1', title: 'Work', rules: [])],
    );

    appLock = InMemoryAppLockStore(enabled: true);
  });

  test('clears every local trace of the session', () async {
    await makeContainer().read(sessionCleanerProvider).clearEverything();

    // The socket goes first: it holds a token and would reconnect with it.
    verify(socket.disconnect).called(1);

    expect(await secureStorage.readAll(), isEmpty);
    verify(chatCache.clear).called(1);
    verify(attachments.clear).called(1);

    expect(voice.readWaveform('a1'), isNull);
    expect(voice.readListened(), isEmpty);

    expect(chatPrefs.readDrafts(), isEmpty);
    expect(chatPrefs.readRecentReactions(), isEmpty);

    expect(searchHistory.readQueries(), isEmpty);
    expect(searchHistory.readChatIds(), isEmpty);

    expect(await organizer.readFolders(), isEmpty);

    // The lock guarded data that is now gone.
    expect(appLock.isBiometricUnlockEnabled, isFalse);
  });

  test('a step that throws does not leave the token behind', () async {
    when(chatCache.clear).thenThrow(StateError('disk is on fire'));

    await makeContainer().read(sessionCleanerProvider).clearEverything();

    expect(await secureStorage.readAll(), isEmpty);
    expect(chatPrefs.readDrafts(), isEmpty);
    expect(appLock.isBiometricUnlockEnabled, isFalse);
  });
}
