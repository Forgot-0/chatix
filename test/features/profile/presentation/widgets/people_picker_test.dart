import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:mocktail/mocktail.dart';

import 'package:chatix/core/models/page_result.dart';
import 'package:chatix/core/theme/app_theme.dart';
import 'package:chatix/features/chat/presentation/widgets/chat_avatar.dart';
import 'package:chatix/features/chat/presentation/widgets/search_result_tiles.dart';
import 'package:chatix/features/profile/domain/entities/profile_entity.dart';
import 'package:chatix/features/profile/domain/usecases/get_profiles_use_case.dart';
import 'package:chatix/features/profile/presentation/providers/profile_providers.dart';
import 'package:chatix/features/profile/presentation/widgets/user_search_field.dart';
import 'package:chatix/gen/l10n/app_localizations.dart';

import '../../../../helpers/pane_frame.dart';

class _MockGetProfilesUseCase extends Mock implements GetProfilesUseCase {}

/// Picking people — the chips of who is already in, the live results under
/// the field, and the people section of chat search — draws every person
/// with the same avatar as the rest of the app.
void main() {
  ProfileEntity person(int id, String username, String displayName) =>
      ProfileEntity(
        id: id,
        username: username,
        avatars: const {},
        specialization: null,
        displayName: displayName,
        bio: null,
        dateBirthday: null,
        skills: const [],
        contacts: const [],
      );

  final ada = person(42, 'ada', 'Ada Lovelace');
  final grace = person(43, 'grace', 'Grace Hopper');
  final linus = person(44, 'linus', 'Linus Torvalds');
  final margaret = person(45, 'margaret', 'Margaret Hamilton');
  final barbara = person(47, 'barbara', 'Barbara Liskov');

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
      (_) async => Right(
        PageResult<ProfileEntity>(
          items: [margaret, barbara],
          total: 2,
          page: 1,
          pageSize: 20,
        ),
      ),
    );
  });

  Future<void> pump(
    WidgetTester tester, {
    PaneWindow window = PaneWindow.phone,
    bool dark = false,
  }) async {
    await tester.pumpWidgetBuilder(
      ProviderScope(
        overrides: [getProfilesUseCaseProvider.overrideWithValue(useCase)],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: dark ? AppTheme.dark() : AppTheme.light(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: PaneFrame(
            window: window,
            child: Scaffold(
              body: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  MultiUserSearchField(
                    selected: [ada, grace, linus],
                    onAdd: (_) {},
                    onRemove: (_) {},
                  ),
                  const Divider(height: 32),
                  for (final profile in [ada, margaret])
                    PersonSearchResultTile(
                      profile: profile,
                      query: 'a',
                      onTap: () {},
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
      wrapper: (child) => child,
      surfaceSize: window.size,
    );
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.enterText(find.byType(TextField), 'ar');
    // Past the field's debounce, then the results.
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
  }

  Finder circleOf(Finder avatar) =>
      find.descendant(of: avatar, matching: find.byType(ClipPath)).first;

  testWidgets('a chip carries a round 24 px face, centred in its slot', (
    tester,
  ) async {
    await pump(tester);

    final chips = find.byType(InputChip);
    expect(chips, findsNWidgets(3));

    for (final chip in chips.evaluate()) {
      final avatar = find.descendant(
        of: find.byWidget(chip.widget),
        matching: find.byType(ChatAvatar),
      );
      expect(
        tester.getSize(circleOf(avatar)),
        Size.square(ChatAvatarSize.xxs.diameter),
      );
      expect(tester.getCenter(circleOf(avatar)), tester.getCenter(avatar));
    }
  });

  testWidgets('results and search rows carry round 40 px faces', (
    tester,
  ) async {
    await pump(tester);

    final rows = find.descendant(
      of: find.byType(ListTile),
      matching: find.byType(ChatAvatar),
    );
    // Two live results under the field, two people in the search section.
    expect(rows, findsNWidgets(4));
    for (final row in rows.evaluate()) {
      expect(
        tester.getSize(circleOf(find.byWidget(row.widget))),
        Size.square(ChatAvatarSize.md.diameter),
      );
    }
  });

  group('goldens', () {
    for (final window in [PaneWindow.phone, PaneWindow.desktop]) {
      for (final theme in {'light': false, 'dark': true}.entries) {
        testGoldens('people picker, ${window.name}, ${theme.key}', (
          tester,
        ) async {
          await pump(tester, window: window, dark: theme.value);

          await screenMatchesGolden(
            tester,
            'people_picker_${window.name}_${theme.key}',
          );
        });
      }
    }
  });
}
