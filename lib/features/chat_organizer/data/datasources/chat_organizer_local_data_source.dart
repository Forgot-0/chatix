import 'dart:convert';

import 'package:chatix/core/storage/local_storage_service.dart';
import 'package:chatix/core/utils/logger.dart';
import 'package:chatix/features/chat_organizer/data/models/chat_folder_model.dart';
import 'package:chatix/features/chat_organizer/data/models/organizer_settings_model.dart';

/// Where the organizer's state is kept on this device.
///
/// Asynchronous on purpose even though shared preferences answer at once:
/// the day folders gain a backend, the server data source drops in here and
/// nothing above the repository notices. Pins and the archive already made
/// that trip — they are chat fields now, and no longer pass through here.
abstract interface class ChatOrganizerLocalDataSource {
  Future<List<ChatFolderModel>> readFolders();

  Future<void> writeFolders(List<ChatFolderModel> folders);

  Future<OrganizerSettingsModel> readSettings();

  Future<void> writeSettings(OrganizerSettingsModel settings);
}

/// The real store.
class SharedPrefsChatOrganizerDataSource
    implements ChatOrganizerLocalDataSource {
  SharedPrefsChatOrganizerDataSource(this._storage);

  static const String foldersKey = 'chat_organizer.folders';
  static const String settingsKey = 'chat_organizer.settings';

  final LocalStorageService _storage;

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


}

/// The fallback for where shared preferences were never wired up — widget
/// tests, mostly. Everything works for the life of the process, it just does
/// not outlive it.
class InMemoryChatOrganizerDataSource implements ChatOrganizerLocalDataSource {
  InMemoryChatOrganizerDataSource({
    List<ChatFolderModel>? folders,
    OrganizerSettingsModel? settings,
  }) : _folders = [...?folders],
       _settings = settings ?? const OrganizerSettingsModel();

  List<ChatFolderModel> _folders;
  OrganizerSettingsModel _settings;

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
