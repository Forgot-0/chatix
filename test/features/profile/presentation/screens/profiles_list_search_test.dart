import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

import 'package:chatix/core/models/page_result.dart';
import 'package:chatix/features/profile/domain/entities/profile_entity.dart';
import 'package:chatix/features/profile/domain/usecases/get_profiles_use_case.dart';
import 'package:chatix/features/profile/presentation/providers/profile_providers.dart';
import 'package:chatix/features/profile/presentation/screens/profiles_list_screen.dart';
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

  void stubPage() {
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
  }

  setUp(() {
    useCase = _MockGetProfilesUseCase();
    stubPage();
  });

  Future<void> pumpScreen(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [getProfilesUseCaseProvider.overrideWithValue(useCase)],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const ProfilesListScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('the search box fills `q`, not display_name', (tester) async {
    await pumpScreen(tester);

    await tester.enterText(find.byType(TextField), 'van');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();

    // api-docs §4.2: `q` is a substring match over username OR display_name,
    // so `van` finds both `ivan_dev` and `Ivan Petrov` in one request.
    verify(
      () => useCase.execute(
        q: 'van',
        username: null,
        displayName: null,
        skills: null,
        page: 1,
        pageSize: any(named: 'pageSize'),
        sort: null,
        cancellation: any(named: 'cancellation'),
      ),
    ).called(1);
  });

  testWidgets('a one-character query is never sent', (tester) async {
    await pumpScreen(tester);
    clearInteractions(useCase);

    await tester.enterText(find.byType(TextField), 'v');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();

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
  });

  testWidgets('clearing the box asks for the whole directory again', (
    tester,
  ) async {
    await pumpScreen(tester);
    clearInteractions(useCase);

    await tester.enterText(find.byType(TextField), '');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();

    verify(
      () => useCase.execute(
        q: null,
        username: null,
        displayName: null,
        skills: null,
        page: 1,
        pageSize: any(named: 'pageSize'),
        sort: null,
        cancellation: any(named: 'cancellation'),
      ),
    ).called(1);
  });
}
