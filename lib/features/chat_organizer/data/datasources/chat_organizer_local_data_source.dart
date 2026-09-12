import 'dart:convert';

import 'package:chatix/core/storage/local_storage_service.dart';
import 'package:chatix/core/utils/logger.dart';
import 'package:chatix/features/chat_organizer/data/models/chat_folder_model.dart';
import 'package:chatix/features/chat_organizer/data/models/organizer_settings_model.dart';

/// Where the organizer's state is kept on this device.
///
/// Asynchronous on purpose even though shared preferences answer at once:
/// the day any of this gains a backend, the server data source drops in here
/// and nothing above the repository notices.
abstract interface class ChatOrganizerLocalDataSource {
  Future<Set<String>> readPinned();

  Future<void> writePinned(Set<String> chatIds);

  Future<Set<String>> readArchived();

  Future<void> writeArchived(Set<String> chatIds);

  Future<List<ChatFolderModel>> readFolders();

  Future<void> writeFolders(List<ChatFolderModel> folders);

  Future<OrganizerSettingsModel> readSettings();

  Future<void> writeSettings(OrganizerSettingsModel settings);
}

/// The real store.
///
/// Pins and the archive keep the keys the chat feature wrote them under
/// before the organizer existed, so nobody loses their list to an upgrade.
class SharedPrefsChatOrganizerDataSource
    implements ChatOrganizerLocalDataSource {
  SharedPrefsChatOrganizerDataSource(this._storage);

  static const String pinnedKey = 'chat_flags.pinned';
  static const String archivedKey = 'chat_flags.archived';
  static const String foldersKey = 'chat_organizer.folders';
  static const String settingsKey = 'chat_organizer.settings';

  final LocalStorageService _storage;

  @override
  Future<Set<String>> readPinned() async => _readIds(pinnedKey);

  @override
  Future<void> writePinned(Set<String> chatIds) => _writeIds(pinnedKey, chatIds);

  @override
  Future<Set<String>> readArchived() async => _readIds(archivedKey);

  @override
  Future<void> writeArchived(Set<String> chatIds) =>
      _writeIds(archivedKey, chatIds);

  @override
  Future<List<ChatFolderModel>> readFolders() async {
    final raw = _storage.getString(foldersKey);
    if (raw == null || raw.isEmpty) return const <ChatFolderModel>[];

    try {
      final decoded = json.decode(raw);
      if (decoded is! List) return const <ChatFolderModel>[];

      return [
        for (final entry in decoded)
          if (entry is Map<String, dynamic>) ChatFolderModel.fromJson(entry),
      ];
    } catch (error) {
      Logger.warning('Organizer: folders could not be read ($error)');
      return const <ChatFolderModel>[];
    }
  }

  @override
  Future<void> writeFolders(List<ChatFolderModel> folders) async {
    if (folders.isEmpty) {
      await _storage.remove(foldersKey);
      return;
    }
    await _storage.setString(
      foldersKey,
      json.encode(folders.map((f) => f.toJson()).toList()),
    );
  }

  @override
  Future<OrganizerSettingsModel> readSettings() async {
    final raw = _storage.getString(settingsKey);
    if (raw == null || raw.isEmpty) return const OrganizerSettingsModel();

    try {
      final decoded = json.decode(raw);
      if (decoded is! Map<String, dynamic>) {
        return const OrganizerSettingsModel();
      }
      return OrganizerSettingsModel.fromJson(decoded);
    } catch (error) {
      Logger.warning('Organizer: settings could not be read ($error)');
      return const OrganizerSettingsModel();
    }
  }

  @override
  Future<void> writeSettings(OrganizerSettingsModel settings) async {
    await _storage.setString(settingsKey, json.encode(settings.toJson()));
  }

  Set<String> _readIds(String key) {
    final stored = _storage.getStringList(key);
    if (stored == null || stored.isEmpty) return <String>{};
    return stored.toSet();
  }

  Future<void> _writeIds(String key, Set<String> chatIds) async {
    if (chatIds.isEmpty) {
      await _storage.remove(key);
      return;
    }
    await _storage.setStringList(key, chatIds.toList());
  }
}

/// The fallback for where shared preferences were never wired up — widget
/// tests, mostly. Everything works for the life of the process, it just does
/// not outlive it.
class InMemoryChatOrganizerDataSource implements ChatOrganizerLocalDataSource {
  InMemoryChatOrganizerDataSource({
    Set<String>? pinned,
    Set<String>? archived,
    List<ChatFolderModel>? folders,
    OrganizerSettingsModel? settings,
  }) : _pinned = {...?pinned},
       _archived = {...?archived},
       _folders = [...?folders],
       _settings = settings ?? const OrganizerSettingsModel();

  Set<String> _pinned;
  Set<String> _archived;
  List<ChatFolderModel> _folders;
  OrganizerSettingsModel _settings;

  @override
  Future<Set<String>> readPinned() async => {..._pinned};

  @override
  Future<void> writePinned(Set<String> chatIds) async =>
      _pinned = {...chatIds};

  @override
  Future<Set<String>> readArchived() async => {..._archived};

  @override
  Future<void> writeArchived(Set<String> chatIds) async =>
      _archived = {...chatIds};

  @override
  Future<List<ChatFolderModel>> readFolders() async => [..._folders];

  @override
  Future<void> writeFolders(List<ChatFolderModel> folders) async =>
      _folders = [...folders];

  @override
  Future<OrganizerSettingsModel> readSettings() async => _settings;

  @override
  Future<void> writeSettings(OrganizerSettingsModel settings) async =>
      _settings = settings;
}
