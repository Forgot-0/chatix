import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

import 'package:chatix/core/error/failures.dart';
import 'package:chatix/core/models/page_result.dart';
import 'package:chatix/core/network/request_cancellation.dart';
import 'package:chatix/features/chat/presentation/providers/chat_search_provider.dart';
import 'package:chatix/features/profile/domain/entities/profile_entity.dart';
import 'package:chatix/features/profile/domain/usecases/get_profiles_use_case.dart';
import 'package:chatix/features/profile/presentation/providers/profile_providers.dart';

class MockGetProfilesUseCase extends Mock implements GetProfilesUseCase {}

void main() {
  late MockGetProfilesUseCase getProfiles;

  setUp(() => getProfiles = MockGetProfilesUseCase());

  ProfileEntity profile(int id, String name) => ProfileEntity(
    id: id,
    avatars: const {},
    specialization: null,
    displayName: name,
    bio: null,
    dateBirthday: null,
    skills: const [],
    contacts: const [],
  );

  PageResult<ProfileEntity> page(
    List<ProfileEntity> items, {
    int total = 0,
    int number = 1,
  }) => PageResult<ProfileEntity>(
    items: items,
    total: total == 0 ? items.length : total,
    page: number,
    pageSize: PeopleSearchController.pageSize,
  );

  ProviderContainer boot() {
    final container = ProviderContainer(
      overrides: [getProfilesUseCaseProvider.overrideWithValue(getProfiles)],
    );
    addTearDown(container.dispose);
    return container;
  }

  /// Holds the provider open while it loads.
  ///
  /// It disposes itself the moment nothing is watching — which is exactly
  /// what cancels the request behind a query nobody wants any more — so a
  /// test that only awaits its future would be racing that.
  Future<PeopleSearchState> peopleFor(ProviderContainer container, String q) {
    final subscription = container.listen(peopleSearchProvider(q), (_, _) {});
    addTearDown(subscription.close);
    return container.read(peopleSearchProvider(q).future);
  }

  group('the query that results are for', () {
    test('waits for the typing to stop', () async {
      final container = boot();
      final controller = container.read(searchQueryProvider.notifier);

      controller.type('d');
      controller.type('de');
      controller.type('des');

      expect(container.read(searchQueryProvider), '');

      await Future<void>.delayed(
        SearchQueryController.debounce + const Duration(milliseconds: 60),
      );

      expect(container.read(searchQueryProvider), 'des');
    });

    test('clearing the field does not wait', () {
      final container = boot();
      final controller = container.read(searchQueryProvider.notifier);

      controller.submit('design');
      controller.type('');

      expect(container.read(searchQueryProvider), '');
    });

    test('the keyboard search key skips the wait', () {
      final container = boot();

      container.read(searchQueryProvider.notifier).submit('  design  ');

      expect(container.read(searchQueryProvider), 'design');
    });

    test('typing back to where it already was changes nothing', () async {
      final container = boot();
      final controller = container.read(searchQueryProvider.notifier);

      controller.submit('design');
      controller.type('design');

      await Future<void>.delayed(
        SearchQueryController.debounce + const Duration(milliseconds: 60),
      );

      expect(container.read(searchQueryProvider), 'design');
    });
  });

  group('people', () {
    void stubBoth({
      required List<ProfileEntity> byUsername,
      required List<ProfileEntity> byDisplayName,
      int usernameTotal = 0,
      int displayNameTotal = 0,
    }) {
      when(
        () => getProfiles.execute(
          username: any(named: 'username'),
          page: any(named: 'page'),
          pageSize: any(named: 'pageSize'),
          cancellation: any(named: 'cancellation'),
        ),
      ).thenAnswer(
        (invocation) async => Right(
          page(
            byUsername,
            total: usernameTotal,
            number: invocation.namedArguments[#page] as int,
          ),
        ),
      );

      when(
        () => getProfiles.execute(
          displayName: any(named: 'displayName'),
          page: any(named: 'page'),
          pageSize: any(named: 'pageSize'),
          cancellation: any(named: 'cancellation'),
        ),
      ).thenAnswer(
        (invocation) async => Right(
          page(
            byDisplayName,
            total: displayNameTotal,
            number: invocation.namedArguments[#page] as int,
          ),
        ),
      );
    }

    test('asks both fields the endpoint can filter on, and merges', () async {
      stubBoth(
        byUsername: [profile(1, 'Ann')],
        byDisplayName: [profile(2, 'Annie')],
      );

      final container = boot();
      final state = await peopleFor(container, 'ann');

      expect(state.people.map((p) => p.id), [1, 2]);

      verify(
        () => getProfiles.execute(
          username: 'ann',
          page: 1,
          pageSize: PeopleSearchController.pageSize,
          cancellation: any(named: 'cancellation'),
        ),
      ).called(1);
      verify(
        () => getProfiles.execute(
          displayName: 'ann',
          page: 1,
          pageSize: PeopleSearchController.pageSize,
          cancellation: any(named: 'cancellation'),
        ),
      ).called(1);
    });

    test('somebody matching on both fields appears once', () async {
      stubBoth(
        byUsername: [profile(1, 'Ann')],
        byDisplayName: [profile(1, 'Ann'), profile(2, 'Annie')],
      );

      final container = boot();
      final state = await peopleFor(container, 'ann');

      expect(state.people.map((p) => p.id), [1, 2]);
    });

    test('an empty query asks for nothing', () async {
      final container = boot();
      final state = await peopleFor(container, '  ');

      expect(state.isEmpty, isTrue);
      verifyNever(
        () => getProfiles.execute(
          username: any(named: 'username'),
          page: any(named: 'page'),
          pageSize: any(named: 'pageSize'),
          cancellation: any(named: 'cancellation'),
        ),
      );
    });

    test('has_next is worked out from the totals the API does send', () async {
      // PageResult carries only items/total/page/page_size (api-docs §1.5).
      stubBoth(
        byUsername: [profile(1, 'Ann')],
        byDisplayName: const [],
        usernameTotal: PeopleSearchController.pageSize * 3,
      );

      final container = boot();
      final state = await peopleFor(container, 'ann');

      expect(state.hasNext, isTrue);
      expect(state.usernameHasNext, isTrue);
      expect(state.displayNameHasNext, isFalse);
    });

    test('loading more asks only the half that has more', () async {
      stubBoth(
        byUsername: [profile(1, 'Ann')],
        byDisplayName: const [],
        usernameTotal: PeopleSearchController.pageSize * 3,
      );

      final container = boot();
      await peopleFor(container, 'ann');

      await container.read(peopleSearchProvider('ann').notifier).loadMore();

      final state = container.read(peopleSearchProvider('ann')).requireValue;
      expect(state.page, 2);

      verify(
        () => getProfiles.execute(
          username: 'ann',
          page: 2,
          pageSize: PeopleSearchController.pageSize,
          cancellation: any(named: 'cancellation'),
        ),
      ).called(1);
      verifyNever(
        () => getProfiles.execute(
          displayName: 'ann',
          page: 2,
          pageSize: PeopleSearchController.pageSize,
          cancellation: any(named: 'cancellation'),
        ),
      );
    });

    test('half an answer beats an error page', () async {
      when(
        () => getProfiles.execute(
          username: any(named: 'username'),
          page: any(named: 'page'),
          pageSize: any(named: 'pageSize'),
          cancellation: any(named: 'cancellation'),
        ),
      ).thenAnswer((_) async => const Left(ServerFailure()));

      when(
        () => getProfiles.execute(
          displayName: any(named: 'displayName'),
          page: any(named: 'page'),
          pageSize: any(named: 'pageSize'),
          cancellation: any(named: 'cancellation'),
        ),
      ).thenAnswer((_) async => Right(page([profile(2, 'Annie')])));

      final container = boot();
      final state = await peopleFor(container, 'ann');

      expect(state.people.map((p) => p.id), [2]);
    });

    test('both halves failing is an error the screen can show', () async {
      when(
        () => getProfiles.execute(
          username: any(named: 'username'),
          page: any(named: 'page'),
          pageSize: any(named: 'pageSize'),
          cancellation: any(named: 'cancellation'),
        ),
      ).thenAnswer((_) async => const Left(ServerFailure()));
      when(
        () => getProfiles.execute(
          displayName: any(named: 'displayName'),
          page: any(named: 'page'),
          pageSize: any(named: 'pageSize'),
          cancellation: any(named: 'cancellation'),
        ),
      ).thenAnswer((_) async => const Left(ServerFailure()));

      final container = boot();

      await expectLater(
        peopleFor(container, 'ann'),
        throwsA(isA<ServerFailure>()),
      );
    });

    test('the request for a query nobody is waiting for is cancelled', () async {
      final tokens = <RequestCancellation>[];

      when(
        () => getProfiles.execute(
          username: any(named: 'username'),
          page: any(named: 'page'),
          pageSize: any(named: 'pageSize'),
          cancellation: any(named: 'cancellation'),
        ),
      ).thenAnswer((invocation) async {
        tokens.add(
          invocation.namedArguments[#cancellation] as RequestCancellation,
        );
        return Right(page([profile(1, 'Ann')]));
      });
      when(
        () => getProfiles.execute(
          displayName: any(named: 'displayName'),
          page: any(named: 'page'),
          pageSize: any(named: 'pageSize'),
          cancellation: any(named: 'cancellation'),
        ),
      ).thenAnswer((_) async => Right(page(const [])));

      final container = boot();
      final subscription = container.listen(
        peopleSearchProvider('an'),
        (_, _) {},
      );
      await container.read(peopleSearchProvider('an').future);

      expect(tokens, hasLength(1));
      expect(tokens.single.isCancelled, isFalse);

      // The next keystroke makes a new query, and nothing holds the old one.
      subscription.close();
      await Future<void>.delayed(Duration.zero);

      expect(tokens.single.isCancelled, isTrue);
    });
  });
}
