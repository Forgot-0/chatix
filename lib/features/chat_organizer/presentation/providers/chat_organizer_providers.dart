import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:chatix/core/providers/storage_providers.dart';
import 'package:chatix/core/utils/logger.dart';
import 'package:chatix/features/chat_organizer/data/datasources/chat_organizer_local_data_source.dart';
import 'package:chatix/features/chat_organizer/data/repositories/chat_organizer_repository_impl.dart';
import 'package:chatix/features/chat_organizer/domain/repositories/chat_organizer_repository.dart';
import 'package:chatix/features/chat_organizer/domain/usecases/delete_folder_use_case.dart';
import 'package:chatix/features/chat_organizer/domain/usecases/forget_chat_use_case.dart';
import 'package:chatix/features/chat_organizer/domain/usecases/load_organizer_use_case.dart';
import 'package:chatix/features/chat_organizer/domain/usecases/reorder_folders_use_case.dart';
import 'package:chatix/features/chat_organizer/domain/usecases/save_folder_use_case.dart';
import 'package:chatix/features/chat_organizer/domain/usecases/set_chat_archived_use_case.dart';
import 'package:chatix/features/chat_organizer/domain/usecases/set_chat_pinned_use_case.dart';
import 'package:chatix/features/chat_organizer/domain/usecases/update_organizer_settings_use_case.dart';

/// The store behind pins, the archive and folders.
///
/// Shared preferences are handed to the app at startup, so anywhere they
/// were not — a widget test that pumps the list without overriding them —
/// this falls back to memory rather than taking the screen down with it.
final chatOrganizerDataSourceProvider = Provider<ChatOrganizerLocalDataSource>((
  ref,
) {
  try {
    return SharedPrefsChatOrganizerDataSource(
      ref.watch(localStorageServiceProvider),
    );
  } catch (error) {
    Logger.debug('Organizer: no persistent storage, keeping it in memory');
    return InMemoryChatOrganizerDataSource();
  }
});

final chatOrganizerRepositoryProvider = Provider<ChatOrganizerRepository>(
  (ref) =>
      ChatOrganizerRepositoryImpl(ref.watch(chatOrganizerDataSourceProvider)),
);

final loadOrganizerUseCaseProvider = Provider<LoadOrganizerUseCase>(
  (ref) => LoadOrganizerUseCase(ref.watch(chatOrganizerRepositoryProvider)),
);

final setChatPinnedUseCaseProvider = Provider<SetChatPinnedUseCase>(
  (ref) => SetChatPinnedUseCase(ref.watch(chatOrganizerRepositoryProvider)),
);

final setChatArchivedUseCaseProvider = Provider<SetChatArchivedUseCase>(
  (ref) => SetChatArchivedUseCase(ref.watch(chatOrganizerRepositoryProvider)),
);

final forgetChatUseCaseProvider = Provider<ForgetChatUseCase>(
  (ref) => ForgetChatUseCase(ref.watch(chatOrganizerRepositoryProvider)),
);

final saveFolderUseCaseProvider = Provider<SaveFolderUseCase>(
  (ref) => SaveFolderUseCase(ref.watch(chatOrganizerRepositoryProvider)),
);

final deleteFolderUseCaseProvider = Provider<DeleteFolderUseCase>(
  (ref) => DeleteFolderUseCase(ref.watch(chatOrganizerRepositoryProvider)),
);

final reorderFoldersUseCaseProvider = Provider<ReorderFoldersUseCase>(
  (ref) => ReorderFoldersUseCase(ref.watch(chatOrganizerRepositoryProvider)),
);

final updateOrganizerSettingsUseCaseProvider =
    Provider<UpdateOrganizerSettingsUseCase>(
      (ref) => UpdateOrganizerSettingsUseCase(
        ref.watch(chatOrganizerRepositoryProvider),
      ),
    );
