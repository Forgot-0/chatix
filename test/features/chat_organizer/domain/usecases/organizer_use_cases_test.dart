import 'package:flutter_test/flutter_test.dart';

import 'package:chatix/core/error/failures.dart';
import 'package:chatix/features/chat/domain/entities/chat_entity.dart';
import 'package:chatix/features/chat_organizer/data/datasources/chat_organizer_local_data_source.dart';
import 'package:chatix/features/chat_organizer/data/repositories/chat_organizer_repository_impl.dart';
import 'package:chatix/features/chat_organizer/domain/entities/chat_folder.dart';
import 'package:chatix/features/chat_organizer/domain/entities/chat_organizer_data.dart';
import 'package:chatix/features/chat_organizer/domain/entities/folder_preset.dart';
import 'package:chatix/features/chat_organizer/domain/entities/folder_rule.dart';
import 'package:chatix/features/chat_organizer/domain/entities/organizer_failures.dart';
import 'package:chatix/features/chat_organizer/domain/entities/organizer_settings.dart';
import 'package:chatix/features/chat_organizer/domain/repositories/chat_organizer_repository.dart';
import 'package:chatix/features/chat_organizer/domain/usecases/delete_folder_use_case.dart';
import 'package:chatix/features/chat_organizer/domain/usecases/forget_chat_use_case.dart';
import 'package:chatix/features/chat_organizer/domain/usecases/load_organizer_use_case.dart';
import 'package:chatix/features/chat_organizer/domain/usecases/reorder_folders_use_case.dart';
import 'package:chatix/features/chat_organizer/domain/usecases/save_folder_use_case.dart';
import 'package:chatix/features/chat_organizer/domain/usecases/set_chat_archived_use_case.dart';
import 'package:chatix/features/chat_organizer/domain/usecases/set_chat_pinned_use_case.dart';
import 'package:chatix/features/chat_organizer/domain/usecases/update_organizer_settings_use_case.dart';

void main() {
  late InMemoryChatOrganizerDataSource store;
  late ChatOrganizerRepository repository;

  setUp(() {
    store = InMemoryChatOrganizerDataSource();
    repository = ChatOrganizerRepositoryImpl(store);
  });

  ChatFolder folder(String id, {String title = 'Work'}) => ChatFolder(
    id: id,
    title: title,
    rules: const [
      ChatTypeRule({ChatType.group}),
    ],
  );

  group('pinning', () {
    test('pins and unpins, and persists what it did', () async {
      final useCase = SetChatPinnedUseCase(repository);

      final pinned = await useCase.execute(
        const ChatOrganizerData(),
        chatId: 'a',
        pinned: true,
      );

      expect(pinned.getOrElse((_) => const ChatOrganizerData()).isPinned('a'),
          isTrue);
      expect(await store.readPinned(), {'a'});

      final released = await useCase.execute(
        pinned.getOrElse((_) => const ChatOrganizerData()),
        chatId: 'a',
        pinned: false,
      );

      expect(
        released.getOrElse((_) => const ChatOrganizerData()).isPinned('a'),
        isFalse,
      );
      expect(await store.readPinned(), isEmpty);
    });

    test('refuses the sixth pin instead of dropping one of the five',
        () async {
      final useCase = SetChatPinnedUseCase(repository);
      var data = const ChatOrganizerData();

      for (var i = 0; i < OrganizerLimits.pinnedChats; i++) {
        final result = await useCase.execute(
          data,
          chatId: 'chat-$i',
          pinned: true,
        );
        data = result.getOrElse((_) => data);
      }

      expect(data.pinnedChatIds, hasLength(OrganizerLimits.pinnedChats));
      expect(data.canPinMore, isFalse);

      final overflow = await useCase.execute(
        data,
        chatId: 'one-too-many',
        pinned: true,
      );

      expect(overflow.isLeft(), isTrue);
      overflow.match(
        (failure) => expect(failure, isA<PinLimitFailure>()),
        (_) => fail('the sixth pin should not have been taken'),
      );
      expect(await store.readPinned(), hasLength(5));
    });

    test('unpinning something already loose changes nothing', () async {
      const data = ChatOrganizerData();

      final result = await SetChatPinnedUseCase(
        repository,
      ).execute(data, chatId: 'a', pinned: false);

      expect(result.getOrElse((_) => const ChatOrganizerData()), same(data));
    });
  });

  group('archiving', () {
    test('archiving a pinned chat releases the pin', () async {
      const data = ChatOrganizerData(pinnedChatIds: {'a', 'b'});

      final result = await SetChatArchivedUseCase(
        repository,
      ).execute(data, chatId: 'a', archived: true);

      final next = result.getOrElse((_) => const ChatOrganizerData());
      expect(next.isArchived('a'), isTrue);
      expect(next.isPinned('a'), isFalse);
      expect(next.isPinned('b'), isTrue);
      expect(await store.readPinned(), {'b'});
    });

    test('taking a chat back out of the archive does not re-pin it', () async {
      const data = ChatOrganizerData(archivedChatIds: {'a'});

      final result = await SetChatArchivedUseCase(
        repository,
      ).execute(data, chatId: 'a', archived: false);

      final next = result.getOrElse((_) => const ChatOrganizerData());
      expect(next.isArchived('a'), isFalse);
      expect(next.isPinned('a'), isFalse);
    });
  });

  test('forgetting a chat drops every trace of it', () async {
    const data = ChatOrganizerData(
      pinnedChatIds: {'a', 'b'},
      archivedChatIds: {'a'},
    );

    final result = await ForgetChatUseCase(repository).execute(data, 'a');
    final next = result.getOrElse((_) => const ChatOrganizerData());

    expect(next.pinnedChatIds, {'b'});
    expect(next.archivedChatIds, isEmpty);
  });

  group('saving a folder', () {
    test('adds one and then replaces it in place', () async {
      final useCase = SaveFolderUseCase(repository);

      final added = await useCase.execute(
        const ChatOrganizerData(),
        folder('f1'),
      );
      var data = added.getOrElse((_) => const ChatOrganizerData());
      expect(data.folders, hasLength(1));

      final renamed = await useCase.execute(
        data,
        folder('f1', title: 'Renamed'),
      );
      data = renamed.getOrElse((_) => const ChatOrganizerData());

      expect(data.folders, hasLength(1));
      expect(data.folders.single.title, 'Renamed');
      expect(await store.readFolders(), hasLength(1));
    });

    test('turns away a folder with no rules or no name', () async {
      final useCase = SaveFolderUseCase(repository);

      final noRules = await useCase.execute(
        const ChatOrganizerData(),
        const ChatFolder(id: 'f1', title: 'Empty', rules: []),
      );
      noRules.match(
        (failure) => expect(
          failure,
          isA<InvalidFolderFailure>().having(
            (f) => f.problem,
            'problem',
            FolderProblem.noRules,
          ),
        ),
        (_) => fail('a folder with no rules should not save'),
      );

      final noName = await useCase.execute(
        const ChatOrganizerData(),
        folder('f1', title: '  '),
      );
      noName.match(
        (failure) => expect(
          failure,
          isA<InvalidFolderFailure>().having(
            (f) => f.problem,
            'problem',
            FolderProblem.emptyTitle,
          ),
        ),
        (_) => fail('a nameless folder should not save'),
      );
    });

    test('a preset needs no name of its own', () async {
      final result = await SaveFolderUseCase(repository).execute(
        const ChatOrganizerData(),
        ChatFolder.fromPreset(FolderPreset.unread),
      );

      expect(result.isRight(), isTrue);
    });

    test('stops at the folder limit', () async {
      final useCase = SaveFolderUseCase(repository);
      var data = const ChatOrganizerData();

      for (var i = 0; i < ChatFolder.maxFolders; i++) {
        final result = await useCase.execute(data, folder('f$i'));
        data = result.getOrElse((_) => data);
      }

      final overflow = await useCase.execute(data, folder('one-too-many'));

      overflow.match(
        (failure) => expect(failure, isA<FolderLimitFailure>()),
        (_) => fail('the folder past the limit should not save'),
      );
    });
  });

  test('deleting a folder leaves the others alone', () async {
    var data = const ChatOrganizerData();
    final save = SaveFolderUseCase(repository);

    data = (await save.execute(data, folder('f1'))).getOrElse((_) => data);
    data = (await save.execute(data, folder('f2'))).getOrElse((_) => data);

    final result = await DeleteFolderUseCase(repository).execute(data, 'f1');
    data = result.getOrElse((_) => data);

    expect(data.folders.map((f) => f.id), ['f2']);
    expect(await store.readFolders(), hasLength(1));
  });

  group('reordering', () {
    List<ChatFolder> ids(List<String> values) =>
        values.map(folder.call).toList();

    test('moves a folder right, accounting for the gap it leaves', () {
      final moved = ReorderFoldersUseCase.reorder(
        ids(['a', 'b', 'c']),
        oldIndex: 0,
        newIndex: 2,
      );

      expect(moved?.map((f) => f.id), ['b', 'a', 'c']);
    });

    test('moves a folder left', () {
      final moved = ReorderFoldersUseCase.reorder(
        ids(['a', 'b', 'c']),
        oldIndex: 2,
        newIndex: 0,
      );

      expect(moved?.map((f) => f.id), ['c', 'a', 'b']);
    });

    test('a move that changes nothing is not a move', () {
      expect(
        ReorderFoldersUseCase.reorder(
          ids(['a', 'b']),
          oldIndex: 0,
          newIndex: 0,
        ),
        isNull,
      );
      expect(
        ReorderFoldersUseCase.reorder(
          ids(['a', 'b']),
          oldIndex: 5,
          newIndex: 0,
        ),
        isNull,
      );
    });

    test('the stored order follows the one on screen', () async {
      var data = const ChatOrganizerData();
      final save = SaveFolderUseCase(repository);

      data = (await save.execute(data, folder('f1'))).getOrElse((_) => data);
      data = (await save.execute(data, folder('f2'))).getOrElse((_) => data);

      final result = await ReorderFoldersUseCase(
        repository,
      ).execute(data, oldIndex: 1, newIndex: 0);

      data = result.getOrElse((_) => data);

      expect(data.folders.map((f) => f.id), ['f2', 'f1']);
      expect(
        (await store.readFolders()).map((f) => f.id),
        ['f2', 'f1'],
      );
    });
  });

  test('settings are stored and read back', () async {
    final saved = await UpdateOrganizerSettingsUseCase(repository).execute(
      const ChatOrganizerData(),
      const OrganizerSettings(
        unarchiveOnNewMessage: false,
        foldersHidden: true,
      ),
    );

    expect(saved.isRight(), isTrue);

    final loaded = await LoadOrganizerUseCase(repository).execute();
    final data = loaded.getOrElse((_) => const ChatOrganizerData());

    expect(data.settings.unarchiveOnNewMessage, isFalse);
    expect(data.settings.foldersHidden, isTrue);
  });

  test('a load that fails comes back as a failure, not an exception',
      () async {
    final broken = ChatOrganizerRepositoryImpl(_ThrowingDataSource());

    final result = await LoadOrganizerUseCase(broken).execute();

    result.match(
      (failure) => expect(failure, isA<CacheFailure>()),
      (_) => fail('a store that throws should not look like an empty one'),
    );
  });
}

class _ThrowingDataSource extends InMemoryChatOrganizerDataSource {
  @override
  Future<Set<String>> readPinned() async => throw StateError('no storage');
}
