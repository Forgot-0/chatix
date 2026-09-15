import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

import 'package:chatix/core/models/page_result.dart';
import 'package:chatix/features/profile/domain/entities/profile_entity.dart';
import 'package:chatix/features/profile/domain/usecases/get_profiles_use_case.dart';
import 'package:chatix/features/profile/presentation/providers/profile_providers.dart';
import 'package:chatix/features/profile/presentation/widgets/user_search_field.dart';
import 'package:chatix/gen/l10n/app_localizations.dart';

class _MockGetProfilesUseCase extends Mock implements GetProfilesUseCase {}

void main() {
  const tProfile = ProfileEntity(
    id: 42,
    avatars: {},
    specialization: null,
    displayName: 'Ivan Petrov',
    bio: null,
    dateBirthday: null,
    skills: [],
    contacts: [],
  );

  late _MockGetProfilesUseCase useCase;

  setUp(() {
    useCase = _MockGetProfilesUseCase();
    when(
      () => useCase.execute(
        q: any(named: 'q'),
        username: any(named: 'username'),
        displayName: any(named: 'displayName'),
        skills: any(named: 'skills'),
        page: any(named: 'page'),
        pageSize: any(named: 'pageSize'),
        sort: any(named: 'sort'),
        cancellation: any(named: 'cancellation'),
      ),
    ).thenAnswer(
      (_) async => const Right(
        PageResult<ProfileEntity>(
          items: [tProfile],
          total: 1,
          page: 1,
          pageSize: 20,
        ),
      ),
    );
  });

  Future<void> pumpField(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [getProfilesUseCaseProvider.overrideWithValue(useCase)],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: UserSearchField(debounce: Duration.zero, onSelected: (_) {}),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('searches through `q`, not the legacy username filter', (
    tester,
  ) async {
    await pumpField(tester);

    await tester.enterText(find.byType(TextField), 'van');
    await tester.pumpAndSettle();

    // api-docs §4.2: one `q` matches username OR display_name, and combining
    // it with either of them is a 422 — so only `q` may be filled in.
    final captured = verify(
      () => useCase.execute(
        q: captureAny(named: 'q'),
        username: captureAny(named: 'username'),
        displayName: captureAny(named: 'displayName'),
        skills: any(named: 'skills'),
        page: any(named: 'page'),
        pageSize: any(named: 'pageSize'),
        sort: any(named: 'sort'),
        cancellation: any(named: 'cancellation'),
      ),
    ).captured;

    expect(captured, ['van', null, null]);
    expect(find.text('Ivan Petrov'), findsOneWidget);
  });

  testWidgets('stays quiet below the two-character minimum', (tester) async {
    await pumpField(tester);

    await tester.enterText(find.byType(TextField), 'v');
    await tester.pumpAndSettle();

    // A one-character `q` is a 422, so the field asks for another character
    // instead of spending one of the 20 requests a minute on it.
    verifyNever(
      () => useCase.execute(
        q: any(named: 'q'),
        username: any(named: 'username'),
        displayName: any(named: 'displayName'),
        skills: any(named: 'skills'),
        page: any(named: 'page'),
        pageSize: any(named: 'pageSize'),
        sort: any(named: 'sort'),
        cancellation: any(named: 'cancellation'),
      ),
    );
    expect(find.textContaining('at least 2 characters'), findsOneWidget);
  });
}
