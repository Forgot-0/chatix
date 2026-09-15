import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

import 'package:chatix/core/error/failures.dart';
import 'package:chatix/features/chat/domain/entities/chat_entity.dart';
import 'package:chatix/features/chat/domain/entities/chat_pages.dart';
import 'package:chatix/features/chat/domain/entities/chat_state_failures.dart';
import 'package:chatix/features/chat/domain/usecases/get_chats_use_case.dart';
import 'package:chatix/features/chat/domain/usecases/update_chat_state_use_case.dart';
import 'package:chatix/features/chat/presentation/providers/chat_list_provider.dart';
import 'package:chatix/features/chat/presentation/providers/chat_providers.dart';
import 'package:chatix/features/chat/presentation/providers/chat_state_actions.dart';

class MockGetChatsUseCase extends Mock implements GetChatsUseCase {}

class MockUpdateChatStateUseCase extends Mock
    implements UpdateChatStateUseCase {}

/// Pin, archive and mute are `PATCH /chats/{id}/state/` now. The row has to
/// move the moment it is asked to, and move back if the server says no.
void main() {
  late MockGetChatsUseCase getChats;
  late MockUpdateChatStateUseCase updateState;

  late List<ChatEntity> mainChats;
  late List<ChatEntity> archivedChats;

  ChatEntity chat(
    String id, {
    bool pinned = false,
    bool archived = false,
    bool muted = false,
    int unread = 0,
  }) => ChatEntity(
    id: id,
    seqCounter: 3,
    lastActivityAt: DateTime.utc(2026, 3, 10),
    type: ChatType.group,
    name: 'Chat $id',
    description: null,
    avatarS3Key: null,
    isPublic: false,
    adminOnly: false,
    slowModeSeconds: 0,
    permissions: const {},
    createdBy: 1,
    memberCount: 2,
    unreadCount: unread,
    state: pinned || archived || muted
        ? ChatStateEntity(
            isPinned: pinned,
            isArchived: archived,
            isMutedByMe: muted,
          )
        : null,
  );

  setUp(() {
    getChats = MockGetChatsUseCase();
    updateState = MockUpdateChatStateUseCase();
    mainChats = [chat('a')];
    archivedChats = <ChatEntity>[];

    when(
      () => getChats.execute(
        limit: any(named: 'limit'),
        archived: any(named: 'archived'),
      ),
    ).thenAnswer(
      (invocation) async => Right(
        ChatsPage(
          chats: (invocation.namedArguments[#archived] as bool)
              ? archivedChats
              : mainChats,
          hasNext: false,
          nextDate: null,
          nextChatId: null,
        ),
      ),
    );

    when(
      () => updateState.setPinned(any(), pinned: any(named: 'pinned')),
    ).thenAnswer((_) async => const Right(ChatStateEntity(isPinned: true)));
    when(
      () => updateState.setArchived(any(), archived: any(named: 'archived')),
    ).thenAnswer((_) async => const Right(ChatStateEntity(isArchived: true)));
    when(() => updateState.mute(any(), until: any(named: 'until'))).thenAnswer(
      (_) async => const Right(ChatStateEntity(isMutedByMe: true)),
    );
    when(
      () => updateState.unmute(any()),
    ).thenAnswer((_) async => const Right(ChatStateEntity()));
  });

  Future<ProviderContainer> boot({bool withArchive = false}) async {
    final container = ProviderContainer(
      overrides: [
        getChatsUseCaseProvider.overrideWithValue(getChats),
        updateChatStateUseCaseProvider.overrideWithValue(updateState),
      ],
    );
    addTearDown(container.dispose);

    final subscription = container.listen(chatListProvider, (_, _) {});
    addTearDown(subscription.close);
    await container.read(chatListProvider.future);

    if (withArchive) {
      final archive = container.listen(archivedChatListProvider, (_, _) {});
      addTearDown(archive.close);
      await container.read(archivedChatListProvider.future);
    }

    return container;
  }

  List<ChatEntity> itemsOf(ProviderContainer container) =>
      container.read(chatListProvider).value?.items ?? const [];

  List<ChatEntity> archiveOf(ProviderContainer container) =>
      container.read(archivedChatListProvider).value?.items ?? const [];

  group('pinning', () {
    test('the row says pinned before the server has answered', () async {
      final container = await boot();
      final actions = container.read(chatStateActionsProvider);

      final pending = actions.setPinned('a', pinned: true);
      expect(itemsOf(container).single.isPinned, isTrue);

      expect(await pending, isNull);
      expect(itemsOf(container).single.isPinned, isTrue);
    });

    test('a refusal puts the row back the way it was', () async {
      when(
        () => updateState.setPinned(any(), pinned: any(named: 'pinned')),
      ).thenAnswer((_) async => const Left(ServerFailure()));

      final container = await boot();

      final failure = await container
          .read(chatStateActionsProvider)
          .setPinned('a', pinned: true);

      expect(failure, isA<ServerFailure>());
      expect(itemsOf(container).single.isPinned, isFalse);
    });

    test('a sixth pin is refused without asking the server', () async {
      mainChats = [
        for (var i = 0; i < UpdateChatStateUseCase.pinnedLimit; i++)
          chat('pinned-$i', pinned: true),
        chat('one-too-many'),
      ];

      final container = await boot();

      final failure = await container
          .read(chatStateActionsProvider)
          .setPinned('one-too-many', pinned: true);

      expect(failure, isA<PinnedChatsLimitFailure>());
      verifyNever(
        () => updateState.setPinned(any(), pinned: any(named: 'pinned')),
      );
    });

    test('unpinning is never blocked by the limit', () async {
      mainChats = [
        for (var i = 0; i < UpdateChatStateUseCase.pinnedLimit; i++)
          chat('pinned-$i', pinned: true),
      ];
      when(
        () => updateState.setPinned(any(), pinned: any(named: 'pinned')),
      ).thenAnswer((_) async => const Right(ChatStateEntity()));

      final container = await boot();

      expect(
        await container
            .read(chatStateActionsProvider)
            .setPinned('pinned-0', pinned: false),
        isNull,
      );
    });

    test("the server's own refusal is turned into the limit failure", () async {
      when(
        () => updateState.setPinned(any(), pinned: any(named: 'pinned')),
      ).thenAnswer(
        (_) async => const Left(
          ApiFailure(
            code: 'PINNED_CHATS_LIMIT_EXCEEDED',
            message: 'too many',
            detail: {'limit': 5},
            status: 400,
          ),
        ),
      );

      final container = await boot();

      final failure = await container
          .read(chatStateActionsProvider)
          .setPinned('a', pinned: true);

      expect(failure, isA<PinnedChatsLimitFailure>());
      expect((failure! as PinnedChatsLimitFailure).limit, 5);
    });
  });

  group('archiving', () {
    test('the row leaves the list and joins the archive', () async {
      final container = await boot(withArchive: true);

      await container
          .read(chatStateActionsProvider)
          .setArchived('a', archived: true);

      expect(itemsOf(container), isEmpty);
      expect(archiveOf(container).single.id, 'a');
      expect(archiveOf(container).single.isArchived, isTrue);
    });

    test('a refusal brings it back', () async {
      when(
        () => updateState.setArchived(any(), archived: any(named: 'archived')),
      ).thenAnswer((_) async => const Left(ServerFailure()));

      final container = await boot(withArchive: true);

      final failure = await container
          .read(chatStateActionsProvider)
          .setArchived('a', archived: true);

      expect(failure, isA<ServerFailure>());
      expect(itemsOf(container).single.id, 'a');
      expect(archiveOf(container), isEmpty);
    });

    test('unarchiving moves it the other way', () async {
      mainChats = <ChatEntity>[];
      archivedChats = [chat('b', archived: true)];
      when(
        () => updateState.setArchived(any(), archived: any(named: 'archived')),
      ).thenAnswer((_) async => const Right(ChatStateEntity()));

      final container = await boot(withArchive: true);

      await container
          .read(chatStateActionsProvider)
          .setArchived('b', archived: false);

      expect(archiveOf(container), isEmpty);
      expect(itemsOf(container).single.id, 'b');
    });

    test('an archive nobody has opened is not fetched to write to', () async {
      final container = await boot();

      await container
          .read(chatStateActionsProvider)
          .setArchived('a', archived: true);

      expect(itemsOf(container), isEmpty);
      verifyNever(() => getChats.execute(limit: any(named: 'limit'), archived: true));
    });
  });

  group('silencing', () {
    test('the row goes quiet at once and stays quiet', () async {
      final container = await boot();

      expect(
        await container
            .read(chatStateActionsProvider)
            .setMuted('a', muted: true),
        isNull,
      );
      expect(itemsOf(container).single.isMutedByMe, isTrue);
    });

    test('unmuting asks for the deadline to be cleared', () async {
      mainChats = [chat('a', muted: true)];

      final container = await boot();

      await container
          .read(chatStateActionsProvider)
          .setMuted('a', muted: false);

      verify(() => updateState.unmute('a')).called(1);
      expect(itemsOf(container).single.isMutedByMe, isFalse);
    });

    test("the server's answer replaces the guess", () async {
      // A device whose clock is off would read the deadline differently; the
      // server has already done that comparison.
      when(() => updateState.mute(any(), until: any(named: 'until'))).thenAnswer(
        (_) async => const Right(ChatStateEntity(isMutedByMe: false)),
      );

      final container = await boot();

      await container
          .read(chatStateActionsProvider)
          .setMuted('a', muted: true, until: DateTime.utc(2026, 5, 1));

      expect(itemsOf(container).single.isMutedByMe, isFalse);
    });
  });
}
