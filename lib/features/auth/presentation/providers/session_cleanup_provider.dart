import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:chatix/core/auth/app_lock_providers.dart';
import 'package:chatix/core/providers/storage_providers.dart';
import 'package:chatix/core/storage/cache/attachment_file_cache.dart';
import 'package:chatix/core/utils/logger.dart';
import 'package:chatix/features/chat/data/datasources/chat_local_data_source.dart';
import 'package:chatix/features/chat/presentation/providers/chat_local_prefs_provider.dart';
import 'package:chatix/features/chat/presentation/providers/chat_socket_provider.dart';
import 'package:chatix/features/chat/presentation/providers/search_providers.dart';
import 'package:chatix/features/chat/presentation/providers/voice_playback_provider.dart';
import 'package:chatix/features/chat_organizer/data/models/organizer_settings_model.dart';
import 'package:chatix/features/chat_organizer/presentation/providers/chat_organizer_providers.dart';

/// Everything signing out has to undo on this device.
///
/// Logging out is not one request. `POST /auth/logout/` only deactivates the
/// refresh session on the server and clears its cookie (api-docs §3.5) — the
/// access token, the cached chats, the drafts, the downloaded attachments
/// and the open socket all still exist here, and the next person to pick up
/// the phone would find them. This is the list, kept in one place so that
/// adding a new local store means adding one line to it.
///
/// Every step is best-effort and independent: a cache directory that will
/// not delete must not leave the token in place.
class SessionCleaner {
  const SessionCleaner(this._ref);

  final Ref _ref;

  Future<void> clearEverything() async {
    // The socket first — it holds a token and would otherwise reconnect with
    // it while the rest is still being torn down.
    await _step('socket', () => _ref.read(chatSocketServiceProvider).disconnect());

    await _step(
      'secure storage',
      () => _ref.read(secureStorageServiceProvider).deleteAll(),
    );

    // Cached chats, messages, read cursors, drafts and the outbox.
    await _step(
      'chat cache',
      () => _ref.read(chatLocalDataSourceProvider).clear(),
    );

    await _step(
      'attachments',
      () => _ref.read(attachmentFileCacheProvider).clear(),
    );

    await _step('voice', () => _ref.read(voiceLocalStoreProvider).clear());

    await _step('chat prefs', () async {
      final store = _ref.read(chatLocalPrefsStoreProvider);
      await store.writeDrafts(const <String, String>{});
      await store.writeRecentReactions(const <String>[]);
    });

    await _step('search history', () async {
      final store = _ref.read(searchHistoryStoreProvider);
      await store.writeQueries(const <String>[]);
      await store.writeChatIds(const <String>[]);
    });

    await _step('folders', () async {
      final store = _ref.read(chatOrganizerDataSourceProvider);
      await store.writeFolders(const []);
      await store.writeSettings(const OrganizerSettingsModel());
    });

    // The lock guarded local data that has just been deleted, and the next
    // account on this device gets to make its own choice about it.
    await _step(
      'app lock',
      () => _ref.read(biometricUnlockEnabledProvider.notifier).setEnabled(false),
    );
  }

  Future<void> _step(String what, Future<void> Function() run) async {
    try {
      await run();
    } catch (error) {
      // Nothing here is worth failing a sign-out over: the token is gone
      // either way, and a leftover cache entry is a nuisance, not a leak of
      // anything the next request could use.
      Logger.warning('Sign-out: $what could not be cleared ($error)');
    }
  }
}

final sessionCleanerProvider = Provider<SessionCleaner>(SessionCleaner.new);
