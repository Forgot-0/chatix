import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

import 'package:chatix/core/error/failures.dart';
import 'package:chatix/features/chat/domain/entities/chat_entity.dart';
import 'package:chatix/features/chat/domain/repositories/chat_repository.dart';
import 'package:chatix/features/chat/domain/usecases/update_chat_state_use_case.dart';

class MockChatRepository extends Mock implements ChatRepository {}

void main() {
  late MockChatRepository repository;
  late UpdateChatStateUseCase useCase;

  setUp(() {
    repository = MockChatRepository();
    useCase = UpdateChatStateUseCase(repository);

    when(
      () => repository.updateChatState(
        any(),
        pinned: any(named: 'pinned'),
        archived: any(named: 'archived'),
        notificationsMutedUntil: any(named: 'notificationsMutedUntil'),
        clearNotificationsMutedUntil: any(
          named: 'clearNotificationsMutedUntil',
        ),
        draft: any(named: 'draft'),
        clearDraft: any(named: 'clearDraft'),
      ),
    ).thenAnswer((_) async => const Right(ChatStateEntity()));
  });

  test('pinning passes the flag straight through', () async {
    await useCase.setPinned('c1', pinned: true);

    verify(
      () => repository.updateChatState(
        'c1',
        pinned: true,
        archived: null,
        notificationsMutedUntil: null,
        clearNotificationsMutedUntil: false,
        draft: null,
        clearDraft: false,
      ),
    ).called(1);
  });

  test('archiving touches nothing but the archive', () async {
    await useCase.setArchived('c1', archived: true);

    verify(
      () => repository.updateChatState(
        'c1',
        pinned: null,
        archived: true,
        notificationsMutedUntil: null,
        clearNotificationsMutedUntil: false,
        draft: null,
        clearDraft: false,
      ),
    ).called(1);
  });

  test('a mute with no end is a date far enough away to mean forever', () async {
    await useCase.mute('c1');

    final captured = verify(
      () => repository.updateChatState(
        'c1',
        pinned: any(named: 'pinned'),
        archived: any(named: 'archived'),
        notificationsMutedUntil: captureAny(named: 'notificationsMutedUntil'),
        clearNotificationsMutedUntil: any(
          named: 'clearNotificationsMutedUntil',
        ),
        draft: any(named: 'draft'),
        clearDraft: any(named: 'clearDraft'),
      ),
    ).captured;

    final until = captured.single as DateTime;
    expect(until.isAfter(DateTime.now().add(const Duration(days: 365))), isTrue);
  });

  test('a mute that has already run out is refused', () async {
    final result = await useCase.mute(
      'c1',
      until: DateTime.now().subtract(const Duration(minutes: 1)),
    );

    expect(result.isLeft(), isTrue);
    verifyNever(
      () => repository.updateChatState(
        any(),
        pinned: any(named: 'pinned'),
        archived: any(named: 'archived'),
        notificationsMutedUntil: any(named: 'notificationsMutedUntil'),
        clearNotificationsMutedUntil: any(
          named: 'clearNotificationsMutedUntil',
        ),
        draft: any(named: 'draft'),
        clearDraft: any(named: 'clearDraft'),
      ),
    );
  });

  test('unmuting clears the deadline rather than setting one', () async {
    await useCase.unmute('c1');

    verify(
      () => repository.updateChatState(
        'c1',
        pinned: null,
        archived: null,
        notificationsMutedUntil: null,
        clearNotificationsMutedUntil: true,
        draft: null,
        clearDraft: false,
      ),
    ).called(1);
  });

  group('drafts', () {
    test('an empty one clears rather than writing emptiness', () async {
      await useCase.setDraft('c1', '   ');

      verify(
        () => repository.updateChatState(
          'c1',
          pinned: null,
          archived: null,
          notificationsMutedUntil: null,
          clearNotificationsMutedUntil: false,
          draft: null,
          clearDraft: true,
        ),
      ).called(1);
    });

    test('one too long for the server is refused here', () async {
      final result = await useCase.setDraft(
        'c1',
        'x' * (UpdateChatStateUseCase.maxDraftLength + 1),
      );

      expect(result.isLeft(), isTrue);
    });
  });

  test('a request without a chat is an input failure, not a call', () async {
    final result = await useCase.setPinned('  ', pinned: true);

    result.match(
      (failure) => expect(failure, isA<InputFailure>()),
      (_) => fail('a chat id is required'),
    );
  });

  test('what the server answers with is what comes back', () async {
    when(
      () => repository.updateChatState(
        any(),
        pinned: any(named: 'pinned'),
        archived: any(named: 'archived'),
        notificationsMutedUntil: any(named: 'notificationsMutedUntil'),
        clearNotificationsMutedUntil: any(
          named: 'clearNotificationsMutedUntil',
        ),
        draft: any(named: 'draft'),
        clearDraft: any(named: 'clearDraft'),
      ),
    ).thenAnswer(
      (_) async => Right(
        ChatStateEntity(isPinned: true, pinnedAt: DateTime.utc(2026, 3, 10)),
      ),
    );

    final result = await useCase.setPinned('c1', pinned: true);

    expect(result.getRight().toNullable()?.isPinned, isTrue);
  });
}
