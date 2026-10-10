import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

import 'package:chatix/core/error/failures.dart';
import 'package:chatix/features/chat/data/datasources/chat_local_data_source.dart';
import 'package:chatix/features/chat/data/datasources/chat_local_prefs_store.dart';
import 'package:chatix/features/chat/data/datasources/chat_local_store.dart';
import 'package:chatix/features/chat/data/models/chat_draft_model.dart';
import 'package:chatix/features/chat/domain/entities/chat_draft.dart';
import 'package:chatix/features/chat/domain/entities/chat_entity.dart';
import 'package:chatix/features/chat/domain/usecases/update_chat_state_use_case.dart';
import 'package:chatix/features/chat/presentation/providers/chat_drafts_provider.dart';
import 'package:chatix/features/chat/presentation/providers/chat_local_prefs_provider.dart';
import 'package:chatix/features/chat/presentation/providers/chat_providers.dart';

class _MockUpdateChatState extends Mock implements UpdateChatStateUseCase {}

/// A draft lives on the server (`PATCH /chats/{id}/state/ {draft}`,
/// api-docs §5.2) and on the device as its offline copy. These pin down how
/// the two are kept in step: when the server is written, how often, and
/// which copy wins when they disagree.
void main() {
  final t0 = DateTime.utc(2026, 10, 11, 9);

  late ChatLocalStore store;
  late InMemoryChatLocalPrefsStore legacyStore;
  late _MockUpdateChatState useCase;

  /// What the server answers a draft write with, as of [at].
  late DateTime Function() serverClock;

  setUp(() {
    store = inMemoryChatLocalStore();
    legacyStore = InMemoryChatLocalPrefsStore();
    useCase = _MockUpdateChatState();
    serverClock = () => t0;

    when(() => useCase.setDraft(any(), any())).thenAnswer((invocation) async {
      final text = invocation.positionalArguments[1] as String?;
      return Right(ChatStateEntity(draft: text, draftUpdatedAt: serverClock()));
    });
  });

  /// A run of the app. The store outlives it, the container does not, which
  /// is what makes "boot twice" a stand-in for a restart.
  ProviderContainer boot({DateTime Function()? now}) {
    final container = ProviderContainer(
      overrides: [
        chatLocalDataSourceProvider.overrideWithValue(store),
        chatLocalPrefsStoreProvider.overrideWithValue(legacyStore),
        updateChatStateUseCaseProvider.overrideWithValue(useCase),
        chatDraftClockProvider.overrideWithValue(now ?? () => t0),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  ChatDraftsController drafts(ProviderContainer c) =>
      c.read(chatDraftsProvider.notifier);

  /// A row of the chat list, carrying the server's copy of the draft.
  ChatEntity row(String id, {String? draft, DateTime? at}) => ChatEntity(
    id: id,
    seqCounter: 1,
    lastActivityAt: t0,
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
    state: ChatStateEntity(draft: draft, draftUpdatedAt: at),
  );

  group('on this device', () {
    test('a draft is trimmed and readable by chat', () {
      final container = boot();
      drafts(container).save('a', '  see you  ');

      expect(drafts(container).of('a'), 'see you');
      expect(container.read(chatDraftEntryProvider('a'))?.text, 'see you');
    });

    test('blank text is not a draft', () {
      final container = boot();

      drafts(container).save('a', 'hello');
      drafts(container).save('a', '   ');

      expect(drafts(container).of('a'), isNull);
    });

    test('clearing one chat leaves the others alone', () {
      final container = boot();

      drafts(container).save('a', 'one');
      drafts(container).save('b', 'two');
      drafts(container).clear('a');

      expect(drafts(container).of('a'), isNull);
      expect(drafts(container).of('b'), 'two');
    });

    test('a draft outlives the session it was typed in', () async {
      final container = boot();
      drafts(container).save('a', 'unsent');
      await drafts(container).flush();

      expect(drafts(boot()).of('a'), 'unsent');
    });

    test('a cleared draft is gone from storage too', () async {
      final first = boot();
      drafts(first).save('a', 'unsent');
      await drafts(first).flush();

      final second = boot();
      drafts(second).clear('a');
      await drafts(second).flush();

      expect(drafts(boot()).of('a'), isNull);
    });

    test('the debounced write lands without a flush', () async {
      final container = boot();
      drafts(container).save('a', 'unsent');

      await Future<void>.delayed(
        ChatDraftsController.writeDelay + const Duration(milliseconds: 50),
      );

      expect(drafts(boot()).of('a'), 'unsent');
    });

    test('drafts written by an older build are carried across once', () async {
      // They used to live in shared preferences, as bare text. An install
      // that predates the chat store has them only there, and losing them on
      // upgrade would mean losing half-written messages nobody discarded.
      await legacyStore.writeDrafts({'a': 'from the old store'});

      final container = boot();
      expect(drafts(container).of('a'), 'from the old store');

      await drafts(container).flush();
      expect(
        ChatDraftCodec.decode(store.readDrafts()['a']!)?.text,
        'from the old store',
      );
    });
  });

  group('the local format', () {
    test('round-trips everything the merge needs', () {
      final draft = ChatDraft(
        text: 'hello',
        updatedAt: t0,
        syncedAt: t0.add(const Duration(seconds: 3)),
        pending: true,
      );

      expect(ChatDraftCodec.decode(ChatDraftCodec.encode(draft)), draft);
    });

    test('bare text from before syncing reads as an unwritten draft', () {
      final legacy = ChatDraftCodec.decode('just text')!;

      expect(legacy.text, 'just text');
      expect(legacy.pending, isTrue);
      expect(legacy.syncedAt, isNull);
    });

    test('text that only looks like the format is still text', () {
      expect(ChatDraftCodec.decode('{not json')?.text, '{not json');
      expect(ChatDraftCodec.decode('{"a": 1}')?.text, '{"a": 1}');
    });
  });

  group('writing to the server', () {
    test('a burst of typing is one write, 1.5 s after the last key', () {
      fakeAsync((async) {
        final container = boot(now: () => t0.add(async.elapsed));
        final d = drafts(container);

        d.save('a', 'h');
        async.elapse(const Duration(milliseconds: 500));
        d.save('a', 'he');
        async.elapse(const Duration(milliseconds: 500));
        d.save('a', 'hey');
        async.elapse(const Duration(milliseconds: 1400));

        verifyNever(() => useCase.setDraft(any(), any()));

        async.elapse(const Duration(milliseconds: 200));

        verify(() => useCase.setDraft('a', 'hey')).called(1);
        expect(container.read(chatDraftEntryProvider('a'))?.pending, isFalse);
      });
    });

    test('never more often than the endpoint allows', () {
      fakeAsync((async) {
        final container = boot(now: () => t0.add(async.elapsed));

        // Seventy chats with a draft each, all at once.
        for (var i = 0; i < 70; i++) {
          drafts(container).save('chat$i', 'draft $i');
        }

        // 60 a minute, ten of them left for pins, mutes and the archive.
        async.elapse(const Duration(seconds: 2));
        verify(() => useCase.setDraft(any(), any())).called(50);

        async.elapse(const Duration(seconds: 59));
        verifyNever(() => useCase.setDraft(any(), any()));

        async.elapse(const Duration(seconds: 2));
        verify(() => useCase.setDraft(any(), any())).called(20);
      });
    });

    test('leaving the chat sends at once', () {
      fakeAsync((async) {
        final container = boot(now: () => t0.add(async.elapsed));

        drafts(container).save('a', 'bye');
        unawaited(drafts(container).flush());
        // Not a moment's debounce: due now.
        async.elapse(Duration.zero);

        verify(() => useCase.setDraft('a', 'bye')).called(1);
      });
    });

    test('sending the message clears the server draft too', () {
      fakeAsync((async) {
        final container = boot(now: () => t0.add(async.elapsed));
        drafts(container).reconcile([row('a', draft: 'half', at: t0)]);

        drafts(container).clear('a');
        async.elapse(const Duration(seconds: 2));

        verify(() => useCase.setDraft('a', null)).called(1);
        expect(container.read(chatDraftsProvider), isNot(contains('a')));
      });
    });

    test('a draft the server never had is cleared without asking it', () {
      fakeAsync((async) {
        final container = boot(now: () => t0.add(async.elapsed));
        drafts(container).reconcile([row('a')]);

        drafts(container).save('a', 'oops');
        drafts(container).clear('a');
        async.elapse(const Duration(seconds: 2));

        verifyNever(() => useCase.setDraft(any(), any()));
      });
    });

    test('typed offline, it goes up once the network is back', () {
      fakeAsync((async) {
        var calls = 0;
        when(() => useCase.setDraft(any(), any())).thenAnswer((i) async {
          calls++;
          if (calls == 1) return const Left(NetworkFailure());
          return Right(
            ChatStateEntity(
              draft: i.positionalArguments[1] as String?,
              draftUpdatedAt: t0,
            ),
          );
        });
        final container = boot(now: () => t0.add(async.elapsed));

        drafts(container).save('a', 'on the train');
        async.elapse(const Duration(seconds: 2));
        expect(calls, 1);
        expect(container.read(chatDraftEntryProvider('a'))?.pending, isTrue);

        async.elapse(ChatDraftsController.retryDelay);
        expect(calls, 2);
        expect(container.read(chatDraftEntryProvider('a'))?.pending, isFalse);
      });
    });

    test('a 429 backs off a whole minute', () {
      fakeAsync((async) {
        var calls = 0;
        when(() => useCase.setDraft(any(), any())).thenAnswer((i) async {
          calls++;
          if (calls == 1) return const Left(RateLimitFailure());
          return Right(ChatStateEntity(draft: 'x', draftUpdatedAt: t0));
        });
        final container = boot(now: () => t0.add(async.elapsed));

        drafts(container).save('a', 'x');
        async.elapse(const Duration(seconds: 2));
        async.elapse(const Duration(seconds: 58));
        expect(calls, 1);

        async.elapse(const Duration(seconds: 3));
        expect(calls, 2);
      });
    });

    test('what the server refuses for good is not retried, and stays here', () {
      fakeAsync((async) {
        when(() => useCase.setDraft(any(), any())).thenAnswer(
          (_) async => const Left(
            ApiFailure(
              code: 'NOT_FOUND_CHAT',
              message: 'Chat not found',
              detail: null,
              status: 404,
            ),
          ),
        );
        final container = boot(now: () => t0.add(async.elapsed));

        drafts(container).save('a', 'kept');
        async.elapse(const Duration(minutes: 5));

        verify(() => useCase.setDraft('a', 'kept')).called(1);
        expect(drafts(container).of('a'), 'kept');
      });
    });

    test('typing on while a write is out sends the newer text next', () {
      fakeAsync((async) {
        final first = Completer<Either<Failure, ChatStateEntity>>();
        var calls = 0;
        when(() => useCase.setDraft(any(), any())).thenAnswer((i) {
          calls++;
          if (calls == 1) return first.future;
          return Future.value(
            Right(
              ChatStateEntity(
                draft: i.positionalArguments[1] as String?,
                draftUpdatedAt: t0.add(const Duration(seconds: 9)),
              ),
            ),
          );
        });
        final container = boot(now: () => t0.add(async.elapsed));

        drafts(container).save('a', 'one');
        async.elapse(const Duration(seconds: 2));
        drafts(container).save('a', 'one two');
        first.complete(
          Right(ChatStateEntity(draft: 'one', draftUpdatedAt: t0)),
        );
        async.elapse(const Duration(seconds: 2));

        verify(() => useCase.setDraft('a', 'one two')).called(1);
        expect(drafts(container).of('a'), 'one two');
        expect(container.read(chatDraftEntryProvider('a'))?.pending, isFalse);
      });
    });
  });

  group('when the copies disagree', () {
    test('a newer draft from another device replaces this one, and this one '
        'is not written over it', () {
      fakeAsync((async) {
        final container = boot(now: () => t0.add(async.elapsed));

        drafts(container).save('a', 'mine'); // typed at t0
        drafts(container).reconcile([
          row('a', draft: 'theirs', at: t0.add(const Duration(seconds: 1))),
        ]);
        async.elapse(const Duration(seconds: 5));

        expect(drafts(container).of('a'), 'theirs');
        verifyNever(() => useCase.setDraft(any(), any()));
      });
    });

    test('a newer draft here wins and is written', () {
      fakeAsync((async) {
        final container = boot(
          now: () => t0.add(const Duration(minutes: 1)).add(async.elapsed),
        );

        drafts(container).save('a', 'mine');
        drafts(container).reconcile([row('a', draft: 'theirs', at: t0)]);
        async.elapse(const Duration(seconds: 2));

        expect(drafts(container).of('a'), 'mine');
        verify(() => useCase.setDraft('a', 'mine')).called(1);
      });
    });

    test('a draft cleared on another device is cleared here', () {
      final container = boot();
      drafts(container).reconcile([row('a', draft: 'old', at: t0)]);

      drafts(
        container,
      ).reconcile([row('a', at: t0.add(const Duration(seconds: 1)))]);

      expect(drafts(container).of('a'), isNull);
    });

    test('the same text on both sides is not written again', () {
      fakeAsync((async) {
        final container = boot(now: () => t0.add(async.elapsed));

        drafts(container).save('a', 'same');
        drafts(container).reconcile([row('a', draft: 'same', at: t0)]);
        async.elapse(const Duration(seconds: 5));

        verifyNever(() => useCase.setDraft(any(), any()));
        expect(container.read(chatDraftEntryProvider('a'))?.pending, isFalse);
      });
    });

    test('a stale row does not bring back what was already replaced', () {
      fakeAsync((async) {
        serverClock = () => t0.add(const Duration(minutes: 2));
        final container = boot(
          now: () => t0.add(const Duration(minutes: 1)).add(async.elapsed),
        );

        drafts(container).save('a', 'newer');
        async.elapse(const Duration(seconds: 2));
        verify(() => useCase.setDraft('a', 'newer')).called(1);

        // A list page fetched before that write landed.
        drafts(container).reconcile([row('a', draft: 'older', at: t0)]);
        async.elapse(const Duration(seconds: 5));

        expect(drafts(container).of('a'), 'newer');
        verifyNever(() => useCase.setDraft(any(), any()));
      });
    });

    test('a row without per-user state changes nothing', () {
      final container = boot();
      drafts(container).save('a', 'mine');

      drafts(container).reconcile([row('a').copyWith(clearState: true)]);

      expect(drafts(container).of('a'), 'mine');
    });
  });
}
